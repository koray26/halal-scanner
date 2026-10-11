/// Adapter für die Open Food Facts API v2 (kostenlos, ODbL).
/// https://openfoodfacts.github.io/openfoodfacts-server/api/
///
/// Nutzungsbedingungen: eigener User-Agent, max. 15 Produktabfragen/Minute,
/// Quellenangabe in der App.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../domain/models.dart';

enum LookupError { network, timeout, rateLimited, server, invalidResponse }

class LookupException implements Exception {
  LookupException(this.error, [this.detail]);
  final LookupError error;
  final String? detail;
  @override
  String toString() => 'LookupException($error, $detail)';
}

class OpenFoodFactsClient {
  OpenFoodFactsClient({http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;
  final List<DateTime> _recent = [];

  static const _maxPerMinute = 15;

  /// Liefert `null`, wenn das Produkt nicht in der Datenbank ist.
  Future<ProductRecord?> fetch(String barcode) async {
    _throttle();
    final uri = Uri.parse(
        '${AppConfig.offBaseUrl}/api/v2/product/$barcode.json'
        '?fields=${AppConfig.offFields.join(',')}');
    http.Response res;
    try {
      res = await _client
          .get(uri, headers: {'User-Agent': AppConfig.userAgent})
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw LookupException(LookupError.timeout);
    } on SocketException catch (e) {
      throw LookupException(LookupError.network, e.message);
    } on http.ClientException catch (e) {
      throw LookupException(LookupError.network, e.message);
    }

    if (res.statusCode == 429) throw LookupException(LookupError.rateLimited);
    if (res.statusCode >= 500) {
      throw LookupException(LookupError.server, '${res.statusCode}');
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      if (res.statusCode == 404) return null;
      throw LookupException(LookupError.invalidResponse);
    }
    if (res.statusCode == 404 || json['status'] == 0 || json['product'] == null) {
      return null;
    }
    return mapProduct(json, retrievedAt: _clock());
  }

  void _throttle() {
    final now = _clock();
    _recent.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (_recent.length >= _maxPerMinute) {
      throw LookupException(LookupError.rateLimited);
    }
    _recent.add(now);
  }

  /// Wandelt die API-Antwort in ein [ProductRecord]. Öffentlich für Tests.
  static ProductRecord? mapProduct(Map<String, dynamic> json,
      {required DateTime retrievedAt}) {
    final p = json['product'];
    if (p is! Map<String, dynamic>) return null;
    final code = (p['code'] ?? json['code'])?.toString();
    if (code == null || code.isEmpty) return null;

    String? str(String key) {
      final v = p[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return null;
    }

    List<String> list(String key) =>
        (p[key] is List) ? (p[key] as List).whereType<String>().toList() : const [];

    final lastModifiedT = p['last_modified_t'];
    final lastModified = lastModifiedT is int
        ? DateTime.fromMillisecondsSinceEpoch(lastModifiedT * 1000, isUtc: true)
        : null;

    final source = SourceRef(
      kind: SourceKind.openFoodFacts,
      retrievedAt: retrievedAt,
      url: '${AppConfig.offBaseUrl}/product/$code',
      version: lastModifiedT?.toString(),
    );

    final states = list('states_tags');
    final incomplete = states.contains('en:ingredients-to-be-completed');
    final mainLang = str('lang');

    // Haupttext + sprachspezifische Texte, Duplikate entfernen.
    final texts = <IngredientText>[];
    final seen = <String>{};
    void addText(String? text, String? lang) {
      if (text == null) return;
      final key = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (!seen.add(key)) return;
      texts.add(IngredientText(
        text: text,
        lang: lang,
        source: source,
        markedIncomplete: incomplete,
        possiblyTruncated: RegExp(r'(\.\.\.|…)\s*$').hasMatch(text),
      ));
    }

    addText(str('ingredients_text'), mainLang);
    for (final l in const ['de', 'en', 'fr', 'tr', 'ar']) {
      addText(str('ingredients_text_$l'), l);
    }

    return ProductRecord(
      barcode: code,
      source: source,
      name: str('product_name') ??
          str('product_name_de') ??
          str('product_name_en') ??
          str('generic_name'),
      brand: str('brands'),
      quantity: str('quantity'),
      countries: list('countries_tags'),
      imageUrl: str('image_front_url'),
      lastModified: lastModified,
      ingredientTexts: texts,
      labelTags: list('labels_tags'),
      additiveTags: list('additives_tags'),
    );
  }
}
