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
import '../domain/research/research.dart';

enum LookupError { network, timeout, rateLimited, server, invalidResponse }

class LookupException implements Exception {
  LookupException(this.error, [this.detail]);
  final LookupError error;
  final String? detail;
  @override
  String toString() => 'LookupException($error, $detail)';
}

class OpenFoodFactsClient {
  OpenFoodFactsClient({
    http.Client? client,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final Duration timeout;
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
          .timeout(timeout);
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
    if (res.bodyBytes.isEmpty) {
      if (res.statusCode == 404) return null;
      throw LookupException(LookupError.invalidResponse, 'empty');
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true)) as Map<String, dynamic>;
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

  /// Sprachcode nach ISO 639-1/-3, wie Open Food Facts ihn verwendet.
  static final _langCode = RegExp(r'^[a-z]{2,3}$');

  /// Bereinigt einen Produktnamen: Leerraum zusammenfassen; Werte ohne
  /// Buchstaben oder Ziffern (z. B. "", "-", "?") gelten als kein Name.
  static String? cleanName(Object? value) {
    if (value is! String) return null;
    final n = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(n)) return null;
    return n;
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

    int? intOf(String key) {
      final v = p[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    List<OffIngredient> parseIngredients(Object? raw, int depth) {
      if (raw is! List || depth > 8) return const [];
      final out = <OffIngredient>[];
      for (final e in raw) {
        if (e is! Map) continue;
        final id = e['id'];
        final text = e['text'];
        if (id is! String && text is! String) continue;
        out.add(OffIngredient(
          id: id is String ? id : '',
          text: text is String ? text : '',
          inTaxonomy: e['is_in_taxonomy'] == 1 || e['is_in_taxonomy'] == true,
          vegan: e['vegan'] is String ? e['vegan'] as String : null,
          vegetarian: e['vegetarian'] is String ? e['vegetarian'] as String : null,
          children: parseIngredients(e['ingredients'], depth + 1),
        ));
      }
      return out;
    }

    // Produktnamen je Sprache aus `product_name_languages` und einzelnen
    // `product_name_xx`-Feldern. Leere, ungültige und doppelte Namen entfallen;
    // interne Varianten wie `product_name_fr_imported` werden ignoriert.
    final names = <String, String>{};
    void addName(Object? lang, Object? value) {
      final n = cleanName(value);
      if (lang is String && _langCode.hasMatch(lang) && n != null) {
        names.putIfAbsent(lang, () => n);
      }
    }

    final byLang = p['product_name_languages'];
    if (byLang is Map) byLang.forEach(addName);
    for (final e in p.entries) {
      if (e.key.startsWith('product_name_')) {
        addName(e.key.substring('product_name_'.length), e.value);
      }
    }
    final mainName = cleanName(p['product_name']);
    if (mainName != null && mainLang != null) addName(mainLang, mainName);

    // Hauptname: Hauptsprache, dann Deutsch/Englisch, dann alphabetisch.
    final ordered = [
      if (mainLang != null) mainLang,
      'de',
      'en',
      ...(names.keys.toList()..sort()),
    ];
    final name = mainName ??
        ordered.map((l) => names[l]).nonNulls.firstOrNull ??
        cleanName(p['generic_name']);
    String norm(String s) => s.toLowerCase();
    names.removeWhere((_, n) => name != null && norm(n) == norm(name));

    return ProductRecord(
      barcode: code,
      source: source,
      name: name,
      localizedNames: names,
      brand: str('brands'),
      quantity: str('quantity'),
      countries: list('countries_tags'),
      imageUrl: str('image_front_url'),
      lastModified: lastModified,
      ingredientTexts: texts,
      labelTags: list('labels_tags'),
      additiveTags: list('additives_tags'),
      structuredIngredients: parseIngredients(p['ingredients'], 0),
      analysisTags: list('ingredients_analysis_tags'),
      categoryTags: list('categories_tags'),
      allergenTags: list('allergens_tags'),
      dataQualityWarnings: list('data_quality_warnings_tags'),
      manufacturerLink: str('link'),
      manufacturingPlaces: str('manufacturing_places'),
      customerService: str('customer_service'),
      unknownIngredientsN: intOf('unknown_ingredients_n'),
      ingredientsN: intOf('ingredients_n'),
    );
  }
}

/// Allgemeine Stoffinformationen aus der Open-Food-Facts-Taxonomie
/// (`/api/v2/taxonomy`). Diese Daten beschreiben einen Stoff allgemein und
/// sind KEIN Beleg für die Zusammensetzung eines bestimmten Produkts.
class OffTaxonomyClient {
  OffTaxonomyClient({http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;
  final Map<String, TaxonomyEntry> _cache = {};
  final List<DateTime> _recent = [];
  static const _maxPerMinute = 10;

  /// Liefert gefundene Einträge. Wirft [LookupException], wenn die Quelle
  /// nicht erreichbar ist – der Aufrufer darf dann keine Recherche behaupten.
  Future<Map<String, TaxonomyEntry>> fetch(Set<String> ids,
      {Duration timeout = const Duration(seconds: 10)}) async {
    final wanted = ids.where((i) => RegExp(r'^[a-z]{2}:[\w-]+$').hasMatch(i)).toSet();
    final missing = wanted.where((i) => !_cache.containsKey(i)).toList();
    if (missing.isNotEmpty) {
      final now = _clock();
      _recent.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
      if (_recent.length >= _maxPerMinute) {
        throw LookupException(LookupError.rateLimited);
      }
      _recent.add(now);
      final uri = Uri.parse('${AppConfig.offBaseUrl}/api/v2/taxonomy'
          '?tagtype=ingredients&tags=${missing.map(Uri.encodeComponent).join(',')}'
          '&fields=name,vegan,vegetarian,wikidata,description&lc=de,en');
      http.Response res;
      try {
        res = await _client
            .get(uri, headers: {'User-Agent': AppConfig.userAgent})
            .timeout(timeout);
      } on TimeoutException {
        throw LookupException(LookupError.timeout);
      } on SocketException catch (e) {
        throw LookupException(LookupError.network, e.message);
      } on http.ClientException catch (e) {
        throw LookupException(LookupError.network, e.message);
      }
      if (res.statusCode == 429) throw LookupException(LookupError.rateLimited);
      if (res.statusCode >= 400) {
        throw LookupException(LookupError.server, '${res.statusCode}');
      }
      final parsed = parse(utf8.decode(res.bodyBytes, allowMalformed: true));
      if (parsed == null) throw LookupException(LookupError.invalidResponse);
      _cache.addAll(parsed);
    }
    return {for (final i in wanted) if (_cache[i] != null) i: _cache[i]!};
  }

  /// Format (geprüft mit echter Antwort, Oktober 2026):
  /// {"en:e471":{"name":{"de":"E471"},"vegan":{"en":"maybe"},"wikidata":{"en":"Q416711"}}}
  static Map<String, TaxonomyEntry>? parse(String body) {
    Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (json is! Map) return null;
    String? en(Object? v) {
      if (v is String) return v;
      if (v is Map) {
        final e = v['en'] ?? (v.values.isEmpty ? null : v.values.first);
        return e is String ? e : null;
      }
      return null;
    }

    final out = <String, TaxonomyEntry>{};
    json.forEach((k, v) {
      if (k is! String || v is! Map) return;
      final names = <String, String>{};
      final n = v['name'];
      if (n is Map) {
        n.forEach((lk, lv) {
          if (lk is String && lv is String) names[lk] = lv;
        });
      }
      out[k] = TaxonomyEntry(
        id: k,
        names: names,
        vegan: en(v['vegan']),
        vegetarian: en(v['vegetarian']),
        description: en(v['description']),
        wikidata: en(v['wikidata']),
      );
    });
    return out;
  }
}
