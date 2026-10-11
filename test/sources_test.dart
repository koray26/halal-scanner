// Weitere Produktquellen: USDA FoodData Central (GTIN-Abgleich) und die
// Produktsuche von Open Food Facts. Alle Netzwerkzugriffe sind simuliert.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/data/off_search.dart';
import 'package:halal_scanner/data/open_food_facts.dart';
import 'package:halal_scanner/data/usda_fdc.dart';
import 'package:halal_scanner/domain/models.dart';
import 'package:halal_scanner/domain/rules/halal_engine.dart';
import 'package:halal_scanner/state/app_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime.utc(2026, 10, 11);
const upc = '049000055375'; // UPC-A, wie gescannt
const gtin14 = '00049000055375'; // so speichert FDC denselben Code

// Aufbau entspricht einer echten FDC-Antwort (Abruf Oktober 2026);
// Zutaten und Namen sind Testdaten.
Map<String, dynamic> food({
  String gtin = gtin14,
  String ingredients = 'CARBONATED WATER, SUGAR, NATURAL FLAVORS, CAFFEINE.',
  String published = '2025-09-18',
  int fdcId = 2742338,
}) =>
    {
      'fdcId': fdcId,
      'description': 'Test Cola 1.25 L',
      'dataType': 'Branded',
      'gtinUpc': gtin,
      'brandOwner': 'Test Beverages Inc.',
      'brandName': 'TESTCOLA',
      'ingredients': ingredients,
      'marketCountry': 'United States',
      'publishedDate': published,
      'dataSource': 'GDSN',
    };

http.Response foods(List<Map<String, dynamic>> f) =>
    http.Response.bytes(utf8.encode(jsonEncode({'totalHits': f.length, 'foods': f})), 200);

void main() {
  group('USDA FoodData Central', () {
    test('GTIN-Schreibweisen: 14, 13 und 12 Stellen', () {
      expect(UsdaFdcClient.gtinVariants(upc),
          containsAll(['00049000055375', '0049000055375', '049000055375']));
      expect(UsdaFdcClient.gtinVariants('4006381333931'),
          containsAll(['04006381333931', '4006381333931']));
    });

    test('Ohne Schlüssel: keine Abfrage, kein Ergebnis', () async {
      final c = UsdaFdcClient(
          apiKey: '',
          client: MockClient((_) async => fail('darf nicht abfragen')),
          clock: () => now);
      expect(c.isConfigured, isFalse);
      expect(await c.fetchByGtin(upc), isNull);
    });

    test('Exakte GTIN wird übernommen, Schlüssel und Datentyp gesetzt', () async {
      final seen = <Uri>[];
      final c = UsdaFdcClient(
        apiKey: 'TEST',
        clock: () => now,
        client: MockClient((r) async {
          seen.add(r.url);
          return r.url.queryParameters['query'] == gtin14 ? foods([food()]) : foods([]);
        }),
      );
      final p = (await c.fetchByGtin(upc))!;
      expect(seen.first.queryParameters['api_key'], 'TEST');
      expect(seen.first.queryParameters['dataType'], 'Branded');
      expect(p.source.kind, SourceKind.usdaFdc);
      expect(p.source.url, contains('2742338'));
      expect(p.name, 'Test Cola 1.25 L');
      expect(p.brand, 'TESTCOLA');
      expect(p.ingredientTexts.single.text, contains('NATURAL FLAVORS'));
      expect(p.ingredientTexts.single.source.kind, SourceKind.usdaFdc);
    });

    test('Ähnliche, aber andere GTIN wird NICHT übernommen', () async {
      final c = UsdaFdcClient(
        apiKey: 'TEST',
        clock: () => now,
        client: MockClient((_) async => foods([food(gtin: '00049000055376')])),
      );
      expect(await c.fetchByGtin(upc), isNull);
    });

    test('Mehrere Datensätze derselben GTIN: der neueste gilt', () async {
      final c = UsdaFdcClient(
        apiKey: 'TEST',
        clock: () => now,
        client: MockClient((_) async => foods([
              food(ingredients: 'ALT: WATER, GELATIN', published: '2019-01-01', fdcId: 1),
              food(ingredients: 'NEU: WATER, SUGAR', published: '2025-09-18', fdcId: 2),
            ])),
      );
      final p = (await c.fetchByGtin(upc))!;
      expect(p.ingredientTexts.single.text, startsWith('NEU'));
      expect(p.source.version, '2025-09-18');
    });

    test('API-Limit, gesperrter Schlüssel, kaputte Antwort, offline', () async {
      Future<void> expectError(http.Response Function() r, LookupError e) async {
        final c = UsdaFdcClient(
            apiKey: 'TEST', clock: () => now, client: MockClient((_) async => r()));
        await expectLater(c.fetchByGtin(upc),
            throwsA(isA<LookupException>().having((x) => x.error, 'error', e)));
      }

      await expectError(() => http.Response('', 429), LookupError.rateLimited);
      await expectError(() => http.Response('{"error":"API_KEY_INVALID"}', 403),
          LookupError.server);
      await expectError(() => http.Response('<html>', 200), LookupError.invalidResponse);
      final offline = UsdaFdcClient(
          apiKey: 'TEST',
          clock: () => now,
          client: MockClient((_) async => throw http.ClientException('offline')));
      await expectLater(offline.fetchByGtin(upc),
          throwsA(isA<LookupException>().having((x) => x.error, 'error', LookupError.network)));
    });

    test('Eigenes Limit: höchstens 15 Anfragen pro Minute', () async {
      final c = UsdaFdcClient(
          apiKey: 'TEST', clock: () => now, client: MockClient((_) async => foods([])));
      // Für diesen Code gibt es 3 Schreibweisen: 5 erfolglose Suchen = 15 Anfragen.
      expect(UsdaFdcClient.gtinVariants(upc), hasLength(3));
      for (var i = 0; i < 5; i++) {
        await c.fetchByGtin(upc);
      }
      await expectLater(
          c.fetchByGtin(upc),
          throwsA(isA<LookupException>()
              .having((x) => x.error, 'error', LookupError.rateLimited)));
    });

    group('Zusammenführung', () {
      final offSource = SourceRef(kind: SourceKind.openFoodFacts, retrievedAt: now);
      final fdc = UsdaFdcClient.mapFood(food(), retrievedAt: now)!;

      test('OFF ohne Zutaten + FDC mit gleicher GTIN -> Zutaten ergänzt, OFF bleibt führend', () {
        final off = ProductRecord(barcode: '0049000055375', source: offSource, name: 'Cola');
        final m = mergeProductSources(off, fdc)!;
        expect(m.source.kind, SourceKind.openFoodFacts);
        expect(m.name, 'Cola');
        expect(m.ingredientTexts.single.source.kind, SourceKind.usdaFdc);
      });

      test('OFF ohne Namen übernimmt den FDC-Produktnamen, nie die Marke', () {
        final off = ProductRecord(barcode: upc, source: offSource, brand: 'Marke');
        final m = mergeProductSources(off, fdc)!;
        expect(m.name, 'Test Cola 1.25 L');
        expect(m.brand, 'Marke');
      });

      test('Andere GTIN -> keine Zusammenführung', () {
        final off = ProductRecord(barcode: '4006381333931', source: offSource);
        expect(mergeProductSources(off, fdc)!.ingredientTexts, isEmpty);
      });

      test('Nur FDC -> FDC-Datensatz', () {
        expect(mergeProductSources(null, fdc)!.source.kind, SourceKind.usdaFdc);
        expect(mergeProductSources(null, null), isNull);
      });
    });

    group('Bewertung mit FDC-Daten (Regeln unverändert)', () {
      Verdict eval(String ingredients) => HalalEngine().evaluate(
          product: UsdaFdcClient.mapFood(food(ingredients: ingredients), retrievedAt: now),
          scannedBarcode: upc,
          now: now);

      test('Unkritische FDC-Liste -> nie grün (Freigabe nur mit Open-Food-Facts-Daten)', () {
        final v = eval('CARBONATED WATER, SUGAR, CITRIC ACID, SALT');
        expect(v.status, isNot(HalalStatus.halalByIngredients));
        expect(v.greenConditions[GreenCondition.databaseSource], isFalse);
      });

      test('FDC-Liste mit Schweinegelatine -> HARAM', () {
        expect(eval('SUGAR, PORK GELATIN, CITRIC ACID').status, HalalStatus.haram);
      });

      test('FDC-Liste mit Aroma -> UNKLAR', () {
        expect(eval('CARBONATED WATER, SUGAR, NATURAL FLAVORS').status, HalalStatus.unclear);
      });
    });

    group('Abfragereihenfolge im App-Zustand', () {
      setUp(() => SharedPreferences.setMockInitialValues({'language': 'de'}));

      AppState makeState({
        required http.Response Function() off,
        UsdaFdcClient? fdc,
      }) =>
          AppState(
            off: OpenFoodFactsClient(client: MockClient((_) async => off()), clock: () => now),
            taxonomy: OffTaxonomyClient(
                client: MockClient((_) async => http.Response('{}', 200)), clock: () => now),
            fdc: fdc,
            clock: () => now,
          );

      http.Response notFound() =>
          http.Response(jsonEncode({'status': 0, 'status_verbose': 'product not found'}), 404);

      test('OFF ohne Treffer -> FDC wird abgefragt und protokolliert', () async {
        final state = makeState(
          off: notFound,
          fdc: UsdaFdcClient(
              apiKey: 'TEST', clock: () => now, client: MockClient((_) async => foods([food()]))),
        );
        final e = (await state.lookup(upc)).entry!;
        expect(e.product!.source.kind, SourceKind.usdaFdc);
        expect(e.sourceChecks.map((c) => (c.kind, c.status)), [
          (SourceKind.openFoodFacts, SourceCheckStatus.notFound),
          (SourceKind.usdaFdc, SourceCheckStatus.found),
        ]);
        expect(e.verdict.status, HalalStatus.unclear); // NATURAL FLAVORS
      });

      test('OFF mit Zutaten -> FDC wird nicht abgefragt', () async {
        final state = makeState(
          off: () => http.Response.bytes(
              utf8.encode(jsonEncode({
                'status': 1,
                'product': {
                  'code': upc,
                  'product_name': 'Test',
                  'lang': 'en',
                  'ingredients_text': 'water, sugar',
                },
              })),
              200),
          fdc: UsdaFdcClient(
              apiKey: 'TEST',
              clock: () => now,
              client: MockClient((_) async => fail('darf nicht abfragen'))),
        );
        final e = (await state.lookup(upc)).entry!;
        expect(e.sourceChecks.last.status, SourceCheckStatus.skipped);
      });

      test('Ohne Schlüssel -> „nicht eingerichtet“, Ergebnis NICHT VERIFIZIERT', () async {
        final state = makeState(off: notFound, fdc: UsdaFdcClient(apiKey: ''));
        final e = (await state.lookup(upc)).entry!;
        expect(e.sourceChecks.last.status, SourceCheckStatus.notConfigured);
        expect(e.verdict.status, HalalStatus.notVerified);
      });

      test('FDC nicht erreichbar -> protokolliert, keine erfundenen Daten', () async {
        final state = makeState(
          off: notFound,
          fdc: UsdaFdcClient(
              apiKey: 'TEST',
              clock: () => now,
              client: MockClient((_) async => throw http.ClientException('offline'))),
        );
        final e = (await state.lookup(upc)).entry!;
        expect(e.product, isNull);
        expect(e.sourceChecks.last.status, SourceCheckStatus.unavailable);
        expect(e.verdict.status, HalalStatus.notVerified);
      });

      test('Geprüfte Quellen bleiben im Verlauf gespeichert', () async {
        final state = makeState(off: notFound, fdc: UsdaFdcClient(apiKey: ''));
        final e = (await state.lookup(upc)).entry!;
        final back = jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>;
        expect((back['sourceChecks'] as List), hasLength(2));
      });
    });
  });

  group('Produktsuche (Open Food Facts)', () {
    test('Echte Antwort wird gelesen; nur numerische Codes, keine Duplikate', () {
      final hits = OffSearchClient.parse(
          File('test/fixtures/off/search-leader-price.json').readAsStringSync())!;
      expect(hits, isNotEmpty);
      expect(hits.every((h) => RegExp(r'^\d{8,14}$').hasMatch(h.code)), isTrue);
      expect(hits.map((h) => h.code).toSet().length, hits.length);
      expect(hits.first.brand, isNotNull);
    });

    test('Ungültige Einträge werden verworfen', () {
      final hits = OffSearchClient.parse(jsonEncode({
        'hits': [
          {'code': 'abc', 'product_name': 'X'},
          {'code': '4006381333931', 'product_name': '  ', 'brands': ['A', ' ', 'B']},
          {'code': '4006381333931', 'product_name': 'Doppelt'},
          {'code': '3263850373626', 'image_front_small_url': 'http://unsicher'},
        ],
      }))!;
      expect(hits.map((h) => h.code), ['4006381333931', '3263850373626']);
      expect(hits.first.name, isNull);
      expect(hits.first.brand, 'A, B');
      expect(hits.last.imageUrl, isNull);
      expect(OffSearchClient.parse('<html>'), isNull);
    });

    test('Zu kurze Suche -> keine Anfrage', () async {
      final c = OffSearchClient(
          client: MockClient((_) async => fail('darf nicht abfragen')), clock: () => now);
      expect(await c.search('ab'), isEmpty);
    });

    test('Anfrage enthält Suchtext und Sprache; Limit 10 pro Minute', () async {
      late Uri seen;
      final c = OffSearchClient(
        clock: () => now,
        client: MockClient((r) async {
          seen = r.url;
          return http.Response(jsonEncode({'hits': []}), 200);
        }),
      );
      await c.search('  leader   price ', lang: 'de');
      expect(seen.queryParameters['q'], 'leader price');
      expect(seen.queryParameters['langs'], 'de,en');
      for (var i = 0; i < 9; i++) {
        await c.search('leader price');
      }
      await expectLater(c.search('leader price'),
          throwsA(isA<LookupException>().having((x) => x.error, 'error', LookupError.rateLimited)));
    });

    test('Serverfehler und API-Limit', () async {
      final c = OffSearchClient(
          clock: () => now, client: MockClient((_) async => http.Response('', 429)));
      await expectLater(c.search('leader price'),
          throwsA(isA<LookupException>().having((x) => x.error, 'error', LookupError.rateLimited)));
    });
  });
}
