import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/data/open_food_facts.dart';
import 'package:halal_scanner/domain/models.dart';
import 'package:halal_scanner/domain/rules/halal_engine.dart';
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

  group('Produktnamen und Sprach-Fallback', () {
    Map<String, dynamic> named(Map<String, dynamic> fields, {String lang = 'fr'}) => {
          'code': '4006381333931',
          'status': 1,
          'product': {'code': '4006381333931', 'lang': lang, ...fields},
        };
    ProductRecord map(Map<String, dynamic> json) =>
        OpenFoodFactsClient.mapProduct(json, retrievedAt: now)!;

    test('Name in der App-Sprache wird bevorzugt, sonst Hauptname', () {
      final p = map(named({
        'product_name': 'Biscuits au chocolat',
        'product_name_languages': {
          'fr': 'Biscuits au chocolat',
          'de': 'Schokoladenkekse',
          'tr': 'Çikolatalı bisküvi',
          'ar': 'بسكويت بالشوكولاتة',
        },
      }));
      expect(p.name, 'Biscuits au chocolat');
      expect(p.nameFor('de'), 'Schokoladenkekse');
      expect(p.nameFor('tr'), 'Çikolatalı bisküvi');
      expect(p.nameFor('ar'), 'بسكويت بالشوكولاتة');
      expect(p.nameFor('en'), 'Biscuits au chocolat'); // kein en -> Hauptname
    });

    test('Nur ein Name in einer anderen Sprache -> dieser wird verwendet', () {
      final p = map(named({
        'product_name_languages': {'es': 'Galletas de chocolate'},
      }));
      expect(p.name, 'Galletas de chocolate');
      expect(p.nameFor('de'), 'Galletas de chocolate');
    });

    test('Ohne Hauptname: Hauptsprache vor Deutsch/Englisch vor alphabetisch', () {
      expect(
          map(named({
            'product_name_languages': {'it': 'Biscotti', 'en': 'Cookies', 'pl': 'Ciastka'},
          }, lang: 'pl')).name,
          'Ciastka');
      expect(
          map(named({
            'product_name_languages': {'it': 'Biscotti', 'en': 'Cookies', 'de': 'Kekse'},
          })).name,
          'Kekse');
      expect(
          map(named({
            'product_name_languages': {'it': 'Biscotti', 'es': 'Galletas'},
          })).name,
          'Galletas');
    });

    test('Einzelne product_name_xx-Felder werden ebenfalls gelesen', () {
      final p = map(named({'product_name_tr': 'Bisküvi'}));
      expect(p.name, 'Bisküvi');
      expect(p.nameFor('tr'), 'Bisküvi');
    });

    test('Leere, ungültige und doppelte Namen werden verworfen', () {
      final p = map(named({
        'product_name': '  Kekse   Classic ',
        'product_name_fr_imported': 'Importiert',
        'product_name_languages': {
          'fr': 'kekse classic', // gleich wie Hauptname
          'de': '   ',
          'en': '-',
          'it': 42,
          'x-y': 'Ungültiger Code',
          'tr': 'Bisküvi\n Klasik',
        },
      }));
      expect(p.name, 'Kekse Classic');
      expect(p.localizedNames, {'tr': 'Bisküvi Klasik'});
      expect(p.nameFor('de'), 'Kekse Classic');
      expect(p.nameFor('en'), 'Kekse Classic');
    });

    test('Ohne jeden Namen bleibt name leer; generic_name als letzter Ersatz', () {
      final none = map(named({'product_name_languages': {}, 'brands': 'Marke'}));
      expect(none.name, isNull);
      expect(none.nameFor('de'), isNull);
      expect(none.brand, 'Marke');
      expect(map(named({'generic_name': 'Kekse'})).name, 'Kekse');
    });

    test('Namen je Sprache bleiben im Verlauf erhalten', () {
      final p = map(named({
        'product_name': 'Biscuits',
        'product_name_languages': {'de': 'Kekse'},
      }));
      final back = ProductRecord.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.nameFor('de'), 'Kekse');
      expect(back.nameFor('en'), 'Biscuits');
      // Ältere gespeicherte Einträge ohne localizedNames bleiben lesbar.
      final old = p.toJson()..remove('localizedNames');
      expect(ProductRecord.fromJson(old).localizedNames, isEmpty);
    });

    test('fetch fragt product_name_languages ab', () async {
      late Uri seen;
      final client = OpenFoodFactsClient(
        client: MockClient((req) async {
          seen = req.url;
          return http.Response.bytes(utf8.encode(jsonEncode(sample())), 200);
        }),
        clock: () => now,
      );
      await client.fetch('4006381333931');
      expect(seen.queryParameters['fields']!.split(','),
          containsAll(['product_name', 'product_name_languages']));
    });

    // Echte Antwort (Oktober 2026): Produkt vorhanden, aber ohne Namen und
    // ohne Zutaten. Die Marke darf nicht als Produktname gelten.
    test('Echtes Produkt ohne Namen (3263850373626) bleibt NICHT VERIFIZIERT', () {
      final json = jsonDecode(
              File('test/fixtures/off/product-3263850373626.json').readAsStringSync())
          as Map<String, dynamic>;
      final p = map(json);
      expect(p.name, isNull);
      expect(p.localizedNames, isEmpty);
      expect(p.brand, 'Leader Price');
      for (final lang in ['de', 'en', 'tr', 'ar']) {
        expect(p.nameFor(lang), isNull);
      }
      final v = HalalEngine()
          .evaluate(product: p, scannedBarcode: '3263850373626', now: now);
      expect(v.status, HalalStatus.notVerified);
      expect(v.identity, IdentityStatus.weak);
      expect(v.unknowns, contains(UnknownReason.noIngredients));
    });
  });
}
