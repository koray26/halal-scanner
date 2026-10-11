import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/data/open_food_facts.dart';
import 'package:halal_scanner/domain/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Aufbau entspricht der dokumentierten v2-Antwort (status/product).
// Inhalte sind Testdaten, kein echtes Produkt.
Map<String, dynamic> sample({
  String code = '4006381333931',
  String? ingredients = 'Zucker, _Milch_, Gelatine',
  List<String> states = const ['en:complete'],
}) =>
    {
      'code': code,
      'status': 1,
      'product': {
        'code': code,
        'product_name': 'Testgummi',
        'brands': 'Testmarke',
        'quantity': '200 g',
        'lang': 'de',
        'countries_tags': ['en:germany'],
        if (ingredients != null) 'ingredients_text': ingredients,
        if (ingredients != null) 'ingredients_text_de': ingredients,
        'ingredients_text_en': 'sugar, milk, gelatin',
        'labels_tags': ['en:halal'],
        'additives_tags': ['en:e471'],
        'states_tags': states,
        'last_modified_t': 1700000000,
      },
    };

void main() {
  final now = DateTime.utc(2026, 10, 11);

  test('Mapping übernimmt nur vorhandene Daten, Duplikate entfernt', () {
    final p = OpenFoodFactsClient.mapProduct(sample(), retrievedAt: now)!;
    expect(p.barcode, '4006381333931');
    expect(p.name, 'Testgummi');
    expect(p.brand, 'Testmarke');
    expect(p.ingredientTexts.length, 2); // de == Haupttext, + en
    expect(p.ingredientTexts.first.lang, 'de');
    expect(p.source.kind, SourceKind.openFoodFacts);
    expect(p.source.url, contains('4006381333931'));
    expect(p.lastModified!.year, 2023);
    expect(p.labelTags, contains('en:halal'));
  });

  test('Unvollständig markierte Zutaten werden übernommen', () {
    final p = OpenFoodFactsClient.mapProduct(
        sample(states: ['en:ingredients-to-be-completed']),
        retrievedAt: now)!;
    expect(p.ingredientTexts.every((t) => t.markedIncomplete), isTrue);
  });

  test('Abgeschnittener Text (…) wird erkannt', () {
    final p = OpenFoodFactsClient.mapProduct(
        sample(ingredients: 'Zucker, Weizenmehl, Gelat...'),
        retrievedAt: now)!;
    expect(p.ingredientTexts.first.possiblyTruncated, isTrue);
  });

  test('Ungültige Produktdaten -> null', () {
    expect(OpenFoodFactsClient.mapProduct({'status': 1, 'product': 'x'},
        retrievedAt: now), isNull);
    expect(OpenFoodFactsClient.mapProduct({'status': 1, 'product': {}},
        retrievedAt: now), isNull);
  });

  test('fetch: Produkt gefunden, User-Agent gesetzt', () async {
    late http.Request seen;
    final client = OpenFoodFactsClient(
      client: MockClient((req) async {
        seen = req;
        return http.Response.bytes(utf8.encode(jsonEncode(sample())), 200);
      }),
      clock: () => now,
    );
    final p = await client.fetch('4006381333931');
    expect(p, isNotNull);
    expect(seen.headers['User-Agent'], startsWith('HalalScanner/'));
    expect(seen.url.path, '/api/v2/product/4006381333931.json');
  });

  test('fetch: unbekannter Barcode -> null', () async {
    final client = OpenFoodFactsClient(
      client: MockClient((_) async => http.Response(
          jsonEncode({'status': 0, 'status_verbose': 'product not found'}),
          404)),
      clock: () => now,
    );
    expect(await client.fetch('4006381333931'), isNull);
  });

  test('fetch: Netzwerkfehler -> LookupException', () async {
    final client = OpenFoodFactsClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
      clock: () => now,
    );
    expect(client.fetch('4006381333931'),
        throwsA(isA<LookupException>()
            .having((e) => e.error, 'error', LookupError.network)));
  });

  test('fetch: Serverfehler und kaputtes JSON', () async {
    final c1 = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response('oops', 503)),
        clock: () => now);
    expect(c1.fetch('4006381333931'), throwsA(isA<LookupException>()));
    final c2 = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response('<html>', 200)),
        clock: () => now);
    expect(c2.fetch('4006381333931'),
        throwsA(isA<LookupException>()
            .having((e) => e.error, 'error', LookupError.invalidResponse)));
  });

  test('Eigenes Limit: mehr als 15 Abfragen/Minute werden abgelehnt', () async {
    final client = OpenFoodFactsClient(
      client: MockClient((_) async =>
          http.Response.bytes(utf8.encode(jsonEncode(sample())), 200)),
      clock: () => now,
    );
    for (var i = 0; i < 15; i++) {
      await client.fetch('4006381333931');
    }
    expect(client.fetch('4006381333931'),
        throwsA(isA<LookupException>()
            .having((e) => e.error, 'error', LookupError.rateLimited)));
  });
}
