// Pflichtfälle 1–15 aus der Anforderung "automatische Zutatenprüfung",
// plus Netzwerk-/Datenfehler und echte Open-Food-Facts-Antworten.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/data/feedback_store.dart';
import 'package:halal_scanner/data/open_food_facts.dart';
import 'package:halal_scanner/domain/barcode.dart';
import 'package:halal_scanner/domain/knowledge/substances.dart';
import 'package:halal_scanner/domain/models.dart';
import 'package:halal_scanner/domain/research/research.dart';
import 'package:halal_scanner/domain/rules/catalog.dart';
import 'package:halal_scanner/domain/rules/halal_engine.dart';
import 'package:halal_scanner/state/app_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime.utc(2026, 10, 11);
const code = '4006381333931';
final src = SourceRef(kind: SourceKind.openFoodFacts, retrievedAt: now,
    url: 'https://world.openfoodfacts.org/product/$code');

ProductRecord product(String? ingredients,
        {List<String> labels = const [],
        List<String> warnings = const [],
        List<OffIngredient> structured = const [],
        List<Certification> certs = const [],
        String lang = 'de',
        String barcode = code,
        String? link}) =>
    ProductRecord(
      barcode: barcode,
      source: src,
      name: 'Testprodukt',
      labelTags: labels,
      dataQualityWarnings: warnings,
      structuredIngredients: structured,
      certifications: certs,
      manufacturerLink: link,
      ingredientTexts: ingredients == null
          ? const []
          : [IngredientText(text: ingredients, lang: lang, source: src)],
    );

Verdict eval(ProductRecord? p, {ResearchContext? research, String scanned = code}) =>
    HalalEngine().evaluate(
        product: p, scannedBarcode: scanned, research: research, now: now);

Investigation inv(Verdict v, String ruleId) =>
    v.investigations.firstWhere((i) => i.ruleId == ruleId);

ProductRecord fixture(String name) {
  final json = jsonDecode(File('test/fixtures/off/$name.json').readAsStringSync())
      as Map<String, dynamic>;
  return OpenFoodFactsClient.mapProduct(json, retrievedAt: now)!;
}

void main() {
  test('1. Eindeutig problematischer Stoff mit Fundstelle -> HARAM', () {
    final v = eval(product('Zucker, Glukosesirup, Schweinegelatine, Citronensäure'));
    expect(v.status, HalalStatus.haram);
    final i = inv(v, 'gelatine');
    expect(i.effect, RuleEffect.haram);
    expect(i.originalText, 'Schweinegelatine');
    expect(i.ingredient, 'Schweinegelatine');
    expect(i.steps.first.kind, StepKind.identity);
    expect(v.greenConditions[GreenCondition.noProhibited], isFalse);
  });

  group('2./3. Aroma', () {
    test('2. Aroma ohne Informationen: Recherche läuft, Ergebnis UNKLAR', () {
      final v = eval(product('Zucker, Kakaobutter, Aroma'));
      expect(v.status, HalalStatus.unclear);
      final i = inv(v, 'flavouring');
      // Recherche wurde ausgelöst: alle Schritte sind dokumentiert.
      expect(i.steps.map((s) => s.kind), containsAll(StepKind.values));
      expect(i.openQuestions,
          containsAll([OriginQuestion.animalSource, OriginQuestion.alcohol]));
      expect(i.resolved, isFalse);
      expect(i.evidence.where((e) => e.strength == EvidenceStrength.productSpecific),
          isEmpty);
    });

    test('2b. Allgemeine Taxonomie-Daten klären nichts', () {
      final v = eval(product('Zucker, Aroma'),
          research: const ResearchContext(
            taxonomyStatus: OnlineSourceStatus.ok,
            taxonomy: {
              'en:flavouring': TaxonomyEntry(
                  id: 'en:flavouring', vegan: 'yes', vegetarian: 'yes'),
            },
          ));
      expect(v.status, HalalStatus.unclear);
      final i = inv(v, 'flavouring');
      expect(i.steps.firstWhere((s) => s.kind == StepKind.taxonomy).outcome,
          StepOutcome.found);
      expect(i.evidence.any((e) => e.kind == EvidenceKind.taxonomy &&
          e.strength == EvidenceStrength.general), isTrue);
      expect(i.openQuestions, isNotEmpty);
    });

    test('2c. Vegan-Kennzeichnung allein klärt Alkohol nicht -> UNKLAR', () {
      final v = eval(product('Zucker, Aroma', labels: ['en:vegan']));
      expect(v.status, HalalStatus.unclear);
      final i = inv(v, 'flavouring');
      expect(i.questions[OriginQuestion.animalSource], QuestionState.answeredNo);
      expect(i.openQuestions, [OriginQuestion.alcohol]);
    });

    test('3. Aroma mit produktbezogener Herkunftsangabe -> Neubewertung', () {
      final v = eval(product('Zucker, Aroma (alkoholfrei)', labels: ['en:vegan']));
      final i = inv(v, 'flavouring');
      expect(i.resolved, isTrue);
      expect(v.status, HalalStatus.halalByIngredients);
      expect(v.allGreenConditionsMet, isTrue);
      expect(v.findings.single.resolutionKeys,
          containsAll(['qualifier.alcoholFree', 'labelVegan']));
    });

    test('3b. Herstellerangabe "halal" an der Zutat klärt Aroma', () {
      final v = eval(product('Zucker, Aroma (halal)'));
      expect(inv(v, 'flavouring').resolved, isTrue);
      expect(v.status, HalalStatus.halalByIngredients);
    });
  });

  test('4. E471 ohne belegte Herkunft -> keine Freigabe', () {
    final v = eval(product('Weizenmehl, Emulgator: E471, Salz'),
        research: const ResearchContext(taxonomyStatus: OnlineSourceStatus.ok, taxonomy: {
          'en:e471': TaxonomyEntry(id: 'en:e471', vegan: 'maybe'),
        }));
    expect(v.status, HalalStatus.unclear);
    final i = inv(v, 'e_number_animal_possible');
    expect(i.additiveCode, 'E471');
    expect(i.additiveName, contains('Mono- und Diglyceride'));
    expect(i.functionClass, 'emulsifier');
    expect(i.possibleOrigins, contains(PossibleOrigin.animal));
  });

  test('4b. Klartextname ohne Nummer wird E471 zugeordnet', () {
    final v = eval(product('Mehl, Mono- und Diglyceride von Speisefettsäuren'));
    expect(inv(v, 'e_number_animal_possible').additiveCode, 'E471');
  });

  test('5. Gelatine ohne Herkunftsangabe -> UNKLAR', () {
    final v = eval(product('Zucker, Gelatine'));
    expect(v.status, HalalStatus.unclear);
    expect(inv(v, 'gelatine').openQuestions,
        containsAll([OriginQuestion.animalSpecies, OriginQuestion.slaughter]));
  });

  test('5b. Vegan-Label + Gelatine ist ein Widerspruch -> NICHT VERIFIZIERT', () {
    final v = eval(product('Zucker, Gelatine', labels: ['en:vegan']));
    expect(v.status, HalalStatus.notVerified);
    expect(v.unknowns, contains(UnknownReason.labelContradiction));
  });

  group('6. Grün nur mit allen Voraussetzungen', () {
    test('vollständige unkritische Liste -> grün, alle Bedingungen erfüllt', () {
      final v = eval(product('Weizenmehl, Wasser, Sonnenblumenöl, Salz, Hefe'));
      expect(v.status, HalalStatus.halalByIngredients);
      expect(v.allGreenConditionsMet, isTrue);
      expect(v.validCertification, isNull);
    });

    test('Datenqualitätswarnung -> nicht grün', () {
      final v = eval(product('Weizenmehl, Salz',
          warnings: ['en:ingredients-language-mismatch-de-contains-en']));
      expect(v.status, HalalStatus.notVerified);
      expect(v.greenConditions[GreenCondition.languageSupported], isFalse);
    });

    test('Unausgeglichene Klammern (abgeschnitten?) -> nicht grün', () {
      final v = eval(product('Weizenmehl, Füllung (Zucker, Salz'));
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.possiblyTruncated));
    });

    test('Strittiger Stoff -> nie grün', () {
      final v = eval(product('Gurken, Weinessig, Salz'));
      expect(v.status, HalalStatus.unclear);
      expect(v.greenConditions[GreenCondition.noDisputedSubstance], isFalse);
      expect(inv(v, 'wine_vinegar').disputed, isTrue);
    });
  });

  test('7. Fehlende oder unvollständige Zutatenliste -> NICHT VERIFIZIERT', () {
    expect(eval(product(null)).status, HalalStatus.notVerified);
    final incomplete = HalalEngine().evaluate(
      product: ProductRecord(barcode: code, source: src, name: 'X', ingredientTexts: [
        IngredientText(text: 'Zucker, Salz', lang: 'de', source: src, markedIncomplete: true),
      ]),
      scannedBarcode: code,
      now: now,
    );
    expect(incomplete.status, HalalStatus.notVerified);
  });

  test('8. Widersprüchliche Quellen -> keine grüne Freigabe', () {
    final v = HalalEngine().evaluate(
      product: ProductRecord(barcode: code, source: src, name: 'X', ingredientTexts: [
        IngredientText(text: 'Zucker, Schweinegelatine', lang: 'de', source: src),
        IngredientText(text: 'sugar, beef gelatin', lang: 'en', source: src),
      ]),
      scannedBarcode: code,
      now: now,
    );
    expect(v.status, HalalStatus.notVerified);
    expect(v.greenConditions[GreenCondition.noConflicts], isFalse);
  });

  group('9. Foto/OCR', () {
    final ocr = SourceRef(kind: SourceKind.ocrPhoto, retrievedAt: now);
    test('abgeschnitten/unleserlich -> keine Freigabe', () {
      final v = HalalEngine().evaluate(product: null, now: now, overrideTexts: [
        IngredientText(text: 'Zucker, Weizenm', source: ocr,
            possiblyTruncated: true, uncertainFragments: const ['Weizenm']),
      ]);
      expect(v.status, isNot(HalalStatus.halalByIngredients));
    });
    test('nicht unterstützte Schrift -> keine Freigabe', () {
      final v = HalalEngine().evaluate(product: product('x'), scannedBarcode: code,
          now: now, overrideTexts: [
            IngredientText(text: 'Zucker, Salz', source: ocr, unsupportedScript: true),
          ]);
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.unsupportedScript));
    });
    test('vollständiges, korrigiertes Foto -> trotzdem nie grün', () {
      final v = HalalEngine().evaluate(product: product('x'), scannedBarcode: code,
          now: now, overrideTexts: [
            IngredientText(text: 'Zucker, Salz',
                source: SourceRef(kind: SourceKind.userEdited, retrievedAt: now)),
          ]);
      expect(v.status, HalalStatus.notVerified);
      expect(v.greenConditions[GreenCondition.databaseSource], isFalse);
    });
    test('Foto durchläuft dieselbe Recherche', () {
      final v = HalalEngine().evaluate(product: null, now: now, overrideTexts: [
        IngredientText(text: 'Zucker, Gelatine', source: ocr),
      ]);
      expect(v.status, HalalStatus.unclear);
      expect(inv(v, 'gelatine').steps, isNotEmpty);
    });
  });

  group('10.–12. AppState: Feedback, offline, Quelle nicht erreichbar', () {
    late http.Response Function(http.Request) productHandler;
    late Future<http.Response> Function(http.Request) taxonomyHandler;

    AppState makeState() => AppState(
          off: OpenFoodFactsClient(
              client: MockClient((r) async => productHandler(r)), clock: () => now),
          taxonomy: OffTaxonomyClient(
              client: MockClient((r) => taxonomyHandler(r)), clock: () => now),
          clock: () => now,
        );

    http.Response productJson(String ingredients) => http.Response.bytes(
        utf8.encode(jsonEncode({
          'status': 1,
          'product': {
            'code': code,
            'product_name': 'Test',
            'lang': 'de',
            'ingredients_text': ingredients,
          }
        })),
        200);

    setUp(() {
      SharedPreferences.setMockInitialValues({'language': 'de'});
      taxonomyHandler = (_) async => http.Response.bytes(
          File('test/fixtures/off/taxonomy-ingredients.json').readAsBytesSync(), 200);
    });

    test('10. Nutzer-Feedback ändert den Status nicht', () async {
      productHandler = (_) => productJson('Zucker, Aroma');
      final state = makeState();
      final before = (await state.lookup(code)).entry!.verdict;
      await state.addFeedback(
          kind: FeedbackKind.manufacturerSource,
          text: 'Das Aroma ist pflanzlich und ohne Alkohol',
          barcode: code,
          ingredient: 'Aroma');
      final after = (await state.lookup(code)).entry!.verdict;
      expect(before.status, HalalStatus.unclear);
      expect(after.status, HalalStatus.unclear);
      expect(state.feedback.single.status, 'unconfirmed');
      expect(state.feedbackFor(code), hasLength(1));
    });

    test('11. Offline: keine Behauptung einer erfolgreichen Recherche', () async {
      productHandler = (_) => throw http.ClientException('offline');
      final state = makeState();
      final o = await state.lookup(code);
      expect(o.entry, isNull);
      expect(o.error, LookupError.network);
    });

    test('12. Recherchequelle nicht erreichbar -> Unsicherheit + erneut prüfbar', () async {
      productHandler = (_) => productJson('Zucker, Aroma');
      taxonomyHandler = (_) async => throw http.ClientException('down');
      final state = makeState();
      final v = (await state.lookup(code)).entry!.verdict;
      expect(v.status, HalalStatus.unclear);
      final step = inv(v, 'flavouring').steps.firstWhere((s) => s.kind == StepKind.taxonomy);
      expect(step.outcome, StepOutcome.unavailable);
      expect(v.unknowns, contains(UnknownReason.researchSourceUnavailable));
      // Erneute Prüfung, wenn die Quelle wieder erreichbar ist:
      taxonomyHandler = (_) async => http.Response.bytes(
          File('test/fixtures/off/taxonomy-ingredients.json').readAsBytesSync(), 200);
      final v2 = (await state.lookup(code)).entry!.verdict;
      expect(inv(v2, 'flavouring').steps.firstWhere((s) => s.kind == StepKind.taxonomy).outcome,
          StepOutcome.found);
      expect(v2.status, HalalStatus.unclear, reason: 'allgemeine Daten klären nichts');
    });

    test('Offline mit gespeichertem Ergebnis -> Ergebnis aus Speicher, markiert', () async {
      productHandler = (_) => productJson('Zucker, Salz');
      final state = makeState();
      await state.lookup(code);
      productHandler = (_) => throw http.ClientException('offline');
      final o = await state.lookup(code);
      expect(o.fromCache, isTrue);
      expect(o.error, LookupError.network);
    });
  });

  test('13. Falscher oder nicht existierender Barcode -> NICHT VERIFIZIERT', () {
    expect(Barcode.check('4006381333932').isValid, isFalse);
    final v = eval(null);
    expect(v.status, HalalStatus.notVerified);
    expect(v.unknowns, contains(UnknownReason.productNotFound));
    final notFound = OpenFoodFactsClient.mapProduct(
        jsonDecode(File('test/fixtures/off/product-notfound.json').readAsStringSync())
            as Map<String, dynamic>,
        retrievedAt: now);
    expect(notFound, isNull);
  });

  test('14. Zertifikat nur für andere Variante -> keine Zertifizierung', () {
    final v = eval(product('Zucker, Salz', certs: [
      Certification(
        certifier: 'Test',
        gtins: const ['4006381333948'],
        verified: true,
        validFrom: DateTime.utc(2025),
        validUntil: DateTime.utc(2027),
        source: SourceRef(kind: SourceKind.certificationRegistry, retrievedAt: now),
      ),
    ]));
    expect(v.status, isNot(HalalStatus.halalCertified));
    expect(v.validCertification, isNull);
    expect(v.unknowns, contains(UnknownReason.certificationNotApplicable));
  });

  test('15. Jede grüne Einstufung erfüllt alle Freigabebedingungen', () {
    final inputs = <ProductRecord?>[
      null,
      product(null),
      product('Zucker'),
      product('Zucker, Salz', labels: ['en:vegan']),
      product('Zucker, Aroma'),
      product('Zucker, Aroma (alkoholfrei)', labels: ['en:vegan']),
      product('Mehl, E471 (pflanzlich)'),
      product('Mehl, E471'),
      product('Milch, mikrobielles Lab'),
      product('Fischgelatine, Zucker'),
      product('Zucker, Salz', warnings: ['en:ingredients-80-percent-unknown']),
      product('zucker, sale', lang: 'it'),
      product('Wasser, Weinessig'),
      product('Schweinefleisch'),
      product('Zucker (Rüben'),
      product('Zucker, Gelatine', labels: ['en:vegetarian']),
    ];
    var greens = 0;
    for (final p in inputs) {
      for (final research in [
        null,
        const ResearchContext(taxonomyStatus: OnlineSourceStatus.unavailable),
      ]) {
        final v = eval(p, research: research);
        expect(v.greenConditions.keys.toSet(), GreenCondition.values.toSet());
        if (v.status == HalalStatus.halalByIngredients) {
          greens++;
          expect(v.allGreenConditionsMet, isTrue, reason: '${p?.ingredientTexts}');
          expect(v.haramFindings, isEmpty);
          expect(v.unclearFindings, isEmpty);
        }
        if (!v.allGreenConditionsMet) {
          expect(v.status, isNot(HalalStatus.halalByIngredients));
        }
      }
    }
    expect(greens, greaterThan(0));
  });

  group('Netzwerk und fehlerhafte Daten', () {
    test('langsame Verbindung -> Zeitüberschreitung', () async {
      final c = OpenFoodFactsClient(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        }),
        timeout: const Duration(milliseconds: 20),
        clock: () => now,
      );
      expect(c.fetch(code), throwsA(isA<LookupException>()
          .having((e) => e.error, 'error', LookupError.timeout)));
    });

    test('leere Antwort -> invalidResponse', () async {
      final c = OpenFoodFactsClient(
          client: MockClient((_) async => http.Response('', 200)), clock: () => now);
      expect(c.fetch(code), throwsA(isA<LookupException>()
          .having((e) => e.error, 'error', LookupError.invalidResponse)));
    });

    test('API-Limit (429) -> rateLimited', () async {
      final c = OpenFoodFactsClient(
          client: MockClient((_) async => http.Response('', 429)), clock: () => now);
      expect(c.fetch(code), throwsA(isA<LookupException>()
          .having((e) => e.error, 'error', LookupError.rateLimited)));
    });

    test('Taxonomie: Zeitüberschreitung und kaputtes JSON', () async {
      final slow = OffTaxonomyClient(client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('{}', 200);
      }));
      expect(slow.fetch({'en:e471'}, timeout: const Duration(milliseconds: 20)),
          throwsA(isA<LookupException>()));
      final broken = OffTaxonomyClient(
          client: MockClient((_) async => http.Response('<html>', 200)));
      expect(broken.fetch({'en:e471'}), throwsA(isA<LookupException>()));
    });

    test('fehlerhafte strukturierte Zutaten werden robust ignoriert', () {
      final p = OpenFoodFactsClient.mapProduct({
        'product': {
          'code': code,
          'product_name': 'X',
          'ingredients': [1, 'x', {'id': 5}, {'text': 'Zucker', 'ingredients': 'kaputt'}],
          'unknown_ingredients_n': 'abc',
        }
      }, retrievedAt: now)!;
      expect(p.structuredIngredients.single.text, 'Zucker');
      expect(p.unknownIngredientsN, isNull);
    });

    test('Taxonomie-Format (echte Antwort) wird gelesen', () {
      final t = OffTaxonomyClient.parse(
          File('test/fixtures/off/taxonomy-additives.json').readAsStringSync())!;
      expect(t['en:e471']!.vegan, 'maybe');
      expect(t['en:e471']!.wikidata, 'Q416711');
      expect(t['en:e120']!.vegan, 'no');
    });
  });

  group('Echte Open-Food-Facts-Antworten (Oktober 2026)', () {
    test('Nutella (DE): vollständige Liste ohne kritische Stoffe -> grün', () {
      final p = fixture('product-4008400402222');
      expect(p.structuredIngredients, isNotEmpty);
      expect(p.manufacturerLink, startsWith('https://'));
      final v = eval(p, scanned: '4008400402222');
      expect(v.status, HalalStatus.halalByIngredients);
      expect(v.allGreenConditionsMet, isTrue);
    });

    test('Mars (EN): natürlicher Vanilleextrakt -> UNKLAR', () {
      final v = eval(fixture('product-5000159407236'), scanned: '5000159407236');
      expect(v.status, HalalStatus.unclear);
      expect(v.investigations.map((i) => i.ruleId), contains('flavouring'));
    });

    test('Fruchtgummi (IT, nicht unterstützte Sprache): Gelatine über Datenbankanalyse erkannt', () {
      final v = eval(fixture('product-4001686301265'), scanned: '4001686301265');
      expect(v.status, HalalStatus.unclear);
      expect(v.unknowns, contains(UnknownReason.languageNotSupported));
      expect(v.findings.any((f) => f.ruleId == 'gelatine'), isTrue);
      expect(v.greenConditions[GreenCondition.languageSupported], isFalse);
    });

    test('Datensatz mit Sprachfehler und unbekannten Zutaten -> NICHT VERIFIZIERT', () {
      final v = eval(fixture('product-3017624010701'), scanned: '3017624010701');
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, containsAll([
        UnknownReason.languageMismatch,
        UnknownReason.ingredientsMostlyUnrecognized,
      ]));
    });
  });

  test('Regelversion erhöht', () => expect(rulesetVersion, '2026.10-2'));

  test('Verdict mit Recherche ist serialisierbar (Verlauf/Offline)', () {
    final v = eval(product('Zucker, Aroma, E471', link: 'https://example.org/p'));
    final back = Verdict.fromJson(jsonDecode(jsonEncode(v.toJson())) as Map<String, dynamic>);
    expect(jsonEncode(back.toJson()), jsonEncode(v.toJson()));
    expect(back.investigations.length, v.investigations.length);
  });
}
