/// Produktsuche nach Name, Marke oder Hersteller über die offizielle
/// Suchschnittstelle von Open Food Facts (Search-a-licious).
/// https://search.openfoodfacts.org/docs
///
/// Die Suche ist unscharf und kann ähnliche oder falsch erfasste Produkte
/// liefern. Treffer werden deshalb NIE zusammengeführt: Der Nutzer wählt
/// einen Treffer, danach läuft die normale Prüfung für genau diesen Barcode.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'open_food_facts.dart';

class ProductSearchHit {
  const ProductSearchHit({
    required this.code,
    this.name,
    this.brand,
    this.imageUrl,
    this.countries = const [],
  });
  final String code;
  final String? name;
  final String? brand;
  final String? imageUrl;
  final List<String> countries;
}

class OffSearchClient {
  OffSearchClient({
    http.Client? client,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final Duration timeout;
  final http.Client _client;
  final DateTime Function() _clock;
  final List<DateTime> _recent = [];

  /// Open Food Facts bittet um höchstens 10 Suchanfragen pro Minute.
  static const _maxPerMinute = 10;
  static const minQueryLength = 3;

  Future<List<ProductSearchHit>> search(String query, {String lang = 'en'}) async {
    final q = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.length < minQueryLength) return const [];
    final now = _clock();
    _recent.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (_recent.length >= _maxPerMinute) {
      throw LookupException(LookupError.rateLimited);
    }
    _recent.add(now);

    final uri = Uri.parse(AppConfig.offSearchUrl).replace(queryParameters: {
      'q': q,
      'langs': {lang, 'en'}.join(','),
      'page_size': '20',
      'fields': 'code,product_name,brands,image_front_small_url,countries_tags',
    });
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
    final hits = parse(utf8.decode(res.bodyBytes, allowMalformed: true));
    if (hits == null) throw LookupException(LookupError.invalidResponse);
    return hits;
  }

  /// Format (geprüft mit echter Antwort, Oktober 2026):
  /// {"hits":[{"code":"…","product_name":"…","brands":["…"],…}],"count":…}
  static List<ProductSearchHit>? parse(String body) {
    Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (json is! Map || json['hits'] is! List) return null;
    final out = <ProductSearchHit>[];
    final seen = <String>{};
    for (final h in json['hits'] as List) {
      if (h is! Map) continue;
      final code = h['code'];
      // Nur numerische Codes: Sie können über die normale Barcode-Prüfung laufen.
      if (code is! String || !RegExp(r'^\d{8,14}$').hasMatch(code)) continue;
      if (!seen.add(code)) continue;
      final brands = h['brands'];
      final brand = brands is List
          ? brands.map(OpenFoodFactsClient.cleanName).nonNulls.join(', ')
          : OpenFoodFactsClient.cleanName(brands);
      final img = h['image_front_small_url'];
      out.add(ProductSearchHit(
        code: code,
        name: OpenFoodFactsClient.cleanName(h['product_name']),
        brand: (brand == null || brand.isEmpty) ? null : brand,
        imageUrl: img is String && img.startsWith('https://') ? img : null,
        countries: (h['countries_tags'] is List)
            ? (h['countries_tags'] as List).whereType<String>().toList()
            : const [],
      ));
    }
    return out;
  }
}
