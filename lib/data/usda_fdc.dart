/// Adapter für USDA FoodData Central (Datentyp „Branded Foods“).
/// https://fdc.nal.usda.gov/api-guide
///
/// - Daten: Public Domain (CC0 1.0); Quellenangabe „USDA FoodData Central“.
/// - Zugang: kostenloser api.data.gov-Schlüssel, Standardlimit 1.000
///   Anfragen pro Stunde. In der App ist KEIN Schlüssel eingebaut; nur ein
///   vom Nutzer selbst eingetragener Schlüssel wird verwendet und im
///   Kopf der Anfrage (`X-Api-Key`) gesendet, nie in der Adresse.
///   Ohne Schlüssel wird nichts abgefragt.
/// - Inhalt: Herstellerangaben für den US-Markt (GTIN, Marke, Zutaten).
///
/// Die Suche ist eine Volltextsuche. Übernommen werden ausschließlich
/// Datensätze, deren GTIN exakt zum gescannten Barcode passt
/// (gleiche Ziffern ohne führende Nullen).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../domain/barcode.dart';
import '../domain/models.dart';
import 'open_food_facts.dart';

class UsdaFdcClient {
  UsdaFdcClient({
    http.Client? client,
    DateTime Function()? clock,
    String? apiKey,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now,
        _apiKey = apiKey ?? '';

  final Duration timeout;
  final http.Client _client;
  final DateTime Function() _clock;
  String _apiKey;
  final List<DateTime> _recent = [];

  /// Kennung in [LookupException.detail], wenn USDA den Schlüssel ablehnt.
  static const keyRejected = 'usda-key-rejected';

  /// Eigenes, vorsichtiges Limit (deutlich unter 1.000/Stunde).
  static const _maxPerMinute = 15;

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Setzt oder entfernt (`null`/leer) den persönlichen Schlüssel.
  void setApiKey(String? key) => _apiKey = key?.trim() ?? '';

  /// GTIN-Schreibweisen, in denen FDC Barcodes speichert (14, 13, 12 Stellen).
  static List<String> gtinVariants(String barcode) {
    final key = Barcode.key(barcode);
    return {
      for (final len in const [14, 13, 12])
        if (key.length <= len) key.padLeft(len, '0'),
      barcode,
    }.toList();
  }

  /// Liefert `null`, wenn kein Datensatz mit exakt dieser GTIN existiert.
  /// Wirft [LookupException] bei Netzwerk-, Limit- oder Formatfehlern.
  Future<ProductRecord?> fetchByGtin(String barcode) async {
    if (!isConfigured) return null;
    for (final q in gtinVariants(barcode)) {
      final foods = await _search(q);
      final matches = foods
          .where((f) =>
              f['gtinUpc'] is String &&
              Barcode.sameProduct(f['gtinUpc'] as String, barcode))
          .toList();
      if (matches.isEmpty) continue;
      // Mehrere Datensätze derselben GTIN: der zuletzt veröffentlichte gilt.
      matches.sort((a, b) =>
          '${b['publishedDate'] ?? ''}'.compareTo('${a['publishedDate'] ?? ''}'));
      return mapFood(matches.first, retrievedAt: _clock());
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _search(String query) async {
    final now = _clock();
    _recent.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (_recent.length >= _maxPerMinute) {
      throw LookupException(LookupError.rateLimited);
    }
    _recent.add(now);
    final uri = Uri.parse('${AppConfig.fdcBaseUrl}/foods/search').replace(
      queryParameters: {
        'query': query,
        'dataType': 'Branded',
        'pageSize': '5',
      },
    );
    http.Response res;
    try {
      res = await _client
          .get(uri, headers: {
            'User-Agent': AppConfig.userAgent,
            'X-Api-Key': _apiKey,
          })
          .timeout(timeout);
    } on TimeoutException {
      throw LookupException(LookupError.timeout);
    } on SocketException catch (e) {
      throw LookupException(LookupError.network, e.message);
    } on http.ClientException catch (e) {
      throw LookupException(LookupError.network, e.message);
    }
    if (res.statusCode == 429) throw LookupException(LookupError.rateLimited);
    if (res.statusCode == 401 || res.statusCode == 403) {
      // Schlüssel ungültig, gesperrt oder noch nicht freigeschaltet.
      throw LookupException(LookupError.server, keyRejected);
    }
    if (res.statusCode >= 400) {
      throw LookupException(LookupError.server, '${res.statusCode}');
    }
    Object? json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
    } catch (_) {
      throw LookupException(LookupError.invalidResponse);
    }
    final foods = json is Map ? json['foods'] : null;
    if (foods is! List) throw LookupException(LookupError.invalidResponse);
    return foods.whereType<Map<String, dynamic>>().toList();
  }

  /// Wandelt einen FDC-Datensatz in ein [ProductRecord]. Öffentlich für Tests.
  static ProductRecord? mapFood(Map<String, dynamic> f,
      {required DateTime retrievedAt}) {
    final gtin = f['gtinUpc'];
    if (gtin is! String || !RegExp(r'^\d{8,14}$').hasMatch(gtin)) return null;
    final fdcId = f['fdcId'];
    String? str(String key) => OpenFoodFactsClient.cleanName(f[key]);

    final source = SourceRef(
      kind: SourceKind.usdaFdc,
      retrievedAt: retrievedAt,
      url: fdcId == null ? null : 'https://fdc.nal.usda.gov/food-details/$fdcId/nutrients',
      version: str('publishedDate'),
      note: str('dataSource'),
    );
    final ingredients = str('ingredients');
    return ProductRecord(
      barcode: gtin,
      source: source,
      name: str('description'),
      brand: str('brandName') ?? str('brandOwner'),
      quantity: str('packageWeight'),
      countries: str('marketCountry') == null ? const [] : [str('marketCountry')!],
      ingredientTexts: [
        if (ingredients != null)
          IngredientText(
            text: ingredients,
            lang: 'en',
            source: source,
            possiblyTruncated: RegExp(r'(\.\.\.|…)\s*$').hasMatch(ingredients),
          ),
      ],
    );
  }
}

/// Ergänzt einen Open-Food-Facts-Datensatz um die Zutatenliste aus FDC.
///
/// - Nur bei exakt gleicher GTIN; sonst bleibt [off] unverändert.
/// - Der Datensatz aus Open Food Facts bleibt führend; FDC-Zutaten werden als
///   eigene Liste mit eigener Quelle angehängt (nichts wird vermischt).
/// - Fehlt in Open Food Facts der Name, wird der FDC-Produktname übernommen
///   (Herstellerangabe zu genau dieser GTIN, keine Marke).
ProductRecord? mergeProductSources(ProductRecord? off, ProductRecord? fdc) {
  if (fdc == null) return off;
  if (off == null) return fdc;
  if (!Barcode.sameProduct(off.barcode, fdc.barcode)) return off;
  return off.copyWith(
    ingredientTexts: [...off.ingredientTexts, ...fdc.ingredientTexts],
    name: off.name ?? fdc.name,
  );
}
