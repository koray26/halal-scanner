// Getrennte Sachaussagen zu Schweinebestandteilen und Alkohol.
// Die Halal-Regeln selbst werden hier nicht verändert – geprüft wird nur,
// dass die abgeleiteten Aussagen zu den bestehenden Ergebnissen passen.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/core/i18n/strings.dart';
import 'package:halal_scanner/data/open_food_facts.dart';
import 'package:halal_scanner/domain/knowledge/pubchem_data.dart';
import 'package:halal_scanner/domain/knowledge/substances.dart';
import 'package:halal_scanner/domain/models.dart';
import 'package:halal_scanner/domain/rules/dimensions.dart';
import 'package:halal_scanner/domain/rules/halal_engine.dart';
import 'package:halal_scanner/features/result/dimensions_card.dart';

final now = DateTime.utc(2026, 10, 11);
const code = '4006381333931';
final offSource = SourceRef(kind: SourceKind.openFoodFacts, retrievedAt: now);

ProductRecord product(List<IngredientText> texts,
        {List<String> labels = const [], String? name = 'Testprodukt'}) =>
    ProductRecord(
      barcode: code,
      source: offSource,
      name: name,
      labelTags: labels,
      ingredientTexts: texts,
    );

IngredientText text(String t, {String lang = 'de', bool incomplete = false}) =>
    IngredientText(text: t, lang: lang, source: offSource, markedIncomplete: incomplete);

Verdict evalTexts(List<IngredientText> texts, {List<String> labels = const []}) =>
    HalalEngine().evaluate(
        product: product(texts, labels: labels), scannedBarcode: code, now: now);

SubstanceDimensions dims(String ingredients, {String lang = 'de'}) =>
    assessDimensions(evalTexts([text(ingredients, lang: lang)]));

void main() {
  group('Schweinebestandteile', () {
    test('Bestätigte Schweinegelatine -> nachgewiesen', () {
      final d = dims('Zucker, Schweinegelatine, Citronensäure');
      expect(d.pork.state, DimensionState.detected);
      expect(d.pork.ingredients.single, contains('Schweinegelatine'));
      expect(d.alcohol.state, DimensionState.notDetected);
    });

    test('Gelatine unbekannter Herkunft -> ungeklärt, nicht Schwein', () {
      final d = dims('Zucker, Gelatine, Citronensäure');
      expect(d.pork.state, DimensionState.unresolved);
      expect(d.pork.reasons, contains(DimensionReason.possibleSource));
      expect(d.pork.ingredients, contains('Gelatine'));
    });

    test('Fischgelatine -> in den geprüften Quellen nicht nachgewiesen', () {
      expect(dims('Zucker, Fischgelatine').pork.state, DimensionState.notDetected);
    });

    test('E471 unbekannter Herkunft -> ungeklärt; pflanzlich -> nicht nachgewiesen', () {
      expect(dims('Weizenmehl, Emulgator: E471, Salz').pork.state, DimensionState.unresolved);
      expect(dims('Weizenmehl, Emulgator (E471 pflanzlich), Salz').pork.state,
          DimensionState.notDetected);
    });

    test('Mehrsprachige Bezeichnungen und Synonyme', () {
      expect(dims('sugar, pork gelatin', lang: 'en').pork.state, DimensionState.detected);
      expect(dims('sucre, gélatine de porc', lang: 'fr').pork.state,
          DimensionState.detected);
      expect(dims('şeker, domuz jelatini', lang: 'tr').pork.state,
          DimensionState.detected);
      expect(dims('Zucker, Schmalz vom Schwein').pork.state, DimensionState.detected);
    });

    test('Einfache pflanzliche Liste -> nicht nachgewiesen (kein „garantiert“)', () {
      final d = dims('Wasser, Zucker, Zitronensaft, Salz');
      expect(d.pork.state, DimensionState.notDetected);
      expect(d.pork.reasons, isEmpty);
    });
  });

  group('Ethanol und andere Alkohole', () {
    test('Ausdrücklich deklarierter Alkohol / Ethanol -> nachgewiesen', () {
      expect(dims('Zucker, Kakaobutter, Alkohol 2%, Vollmilchpulver').alcohol.state,
          DimensionState.detected);
      expect(dims('Zucker, Ethanol, Aroma').alcohol.state, DimensionState.detected);
      expect(dims('sugar, rum, cocoa', lang: 'en').alcohol.state, DimensionState.detected);
    });

    test('Cetylalkohol ist kein Trinkalkohol -> nicht nachgewiesen', () {
      final d = dims('Wasser, Zucker, Cetylalkohol, Salz');
      expect(d.alcohol.state, DimensionState.notDetected);
      // PubChem unterscheidet die Stoffe eindeutig (allgemeine Stoffidentität).
      expect(pubchemSubstances['cetyl_alcohol']!.cid,
          isNot(pubchemSubstances['ethanol']!.cid));
    });

    test('Zuckeralkohole sind kein Ethanol', () {
      expect(dims('Zuckeralkohole (Sorbit), Kakaobutter').alcohol.state,
          DimensionState.notDetected);
    });

    test('Aroma mit unbekanntem Trägerstoff -> Alkohol und Schwein ungeklärt', () {
      final d = dims('Zucker, Aroma');
      expect(d.alcohol.state, DimensionState.unresolved);
      expect(d.alcohol.ingredients, contains('Aroma'));
      expect(d.pork.state, DimensionState.unresolved);
    });

    test('Weinessig -> Alkohol ungeklärt (kein Restalkohol-Wert belegt)', () {
      expect(dims('Wasser, Weinessig, Salz').alcohol.state, DimensionState.unresolved);
    });
  });

  group('Fehlende oder unsichere Daten', () {
    test('Fehlende Zutatenliste -> beides ungeklärt', () {
      final d = assessDimensions(evalTexts(const []));
      expect(d.pork.state, DimensionState.unresolved);
      expect(d.alcohol.state, DimensionState.unresolved);
      expect(d.pork.reasons, contains(DimensionReason.noIngredients));
    });

    test('Produkt nicht gefunden -> beides ungeklärt', () {
      final d = assessDimensions(
          HalalEngine().evaluate(product: null, scannedBarcode: code, now: now));
      expect(d.pork.state, DimensionState.unresolved);
      expect(d.alcohol.reasons, contains(DimensionReason.noIngredients));
    });

    test('Als unvollständig markierte Liste ohne Befund -> ungeklärt', () {
      final d = assessDimensions(
          evalTexts([text('Wasser, Zucker, Salz', incomplete: true)]));
      expect(d.pork.state, DimensionState.unresolved);
      expect(d.pork.reasons, contains(DimensionReason.ingredientsIncomplete));
    });

    test('Unsichere Texterkennung (Foto) ohne Befund -> ungeklärt', () {
      final ocr = IngredientText(
        text: 'Wasser, Zucker, Sa',
        lang: 'de',
        source: SourceRef(kind: SourceKind.ocrPhoto, retrievedAt: now),
        possiblyTruncated: true,
        uncertainFragments: const ['Sa'],
      );
      final v = HalalEngine().evaluate(product: null, overrideTexts: [ocr], now: now);
      expect(assessDimensions(v).pork.state, DimensionState.unresolved);
    });

    test('Widersprüchliche Quellen: Befund bleibt nachgewiesen, Widerspruch wird genannt', () {
      final v = evalTexts([
        text('Zucker, Schweinegelatine'),
        text('sugar, beef gelatin', lang: 'en'),
      ]);
      expect(v.status, HalalStatus.notVerified);
      final d = assessDimensions(v);
      expect(d.pork.state, DimensionState.detected);
      expect(d.pork.reasons, contains(DimensionReason.conflicting));
    });

    test('Echtes Produkt ohne Namen und Zutaten (3263850373626) -> ungeklärt, NICHT VERIFIZIERT', () {
      final json = jsonDecode(
              File('test/fixtures/off/product-3263850373626.json').readAsStringSync())
          as Map<String, dynamic>;
      final p = OpenFoodFactsClient.mapProduct(json, retrievedAt: now)!;
      final v = HalalEngine().evaluate(product: p, scannedBarcode: '3263850373626', now: now);
      expect(v.status, HalalStatus.notVerified);
      final d = assessDimensions(v);
      expect(d.pork.state, DimensionState.unresolved);
      expect(d.alcohol.state, DimensionState.unresolved);
    });

    test('Halal-Status bleibt unverändert (nur abgeleitete Aussage)', () {
      final v = evalTexts([text('Zucker, Gelatine')]);
      final before = jsonEncode(v.toJson());
      assessDimensions(v);
      expect(jsonEncode(v.toJson()), before);
      expect(v.status, HalalStatus.unclear);
    });
  });

  group('PubChem-Stoffidentität', () {
    test('Nur eindeutige Stoffe; Gemische wie E471 haben keinen Eintrag', () {
      expect(pubchemByAdditive.containsKey('471'), isFalse);
      expect(pubchemByAdditive.containsKey('433'), isFalse); // Polysorbat 80
      expect(pubchemByAdditive['422']!.cid, 753); // Glycerin
      expect(pubchemSubstances['ethanol']!.cas, '64-17-5');
      for (final k in pubchemByAdditive.keys) {
        expect(additivesByNumber.containsKey(k), isTrue, reason: k);
      }
    });
  });

  testWidgets('Anzeige: drei getrennte Aussagen mit Hinweis', (tester) async {
    Map<String, String> load(String c) =>
        (jsonDecode(File('assets/i18n/$c.json').readAsStringSync()) as Map<String, dynamic>)
            .cast<String, String>();
    final s = AppStrings.fromMaps('de', load('de'), load('en'));
    final v = evalTexts([text('Zucker, Schweinegelatine, Aroma')]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: DimensionsCard(verdict: v, strings: s))),
    ));
    expect(find.text('Schweinebestandteile'), findsOneWidget);
    expect(find.text('Nachgewiesen'), findsOneWidget);
    expect(find.text('Ungeklärt'), findsOneWidget); // Alkohol: Aroma
    expect(find.textContaining('Nicht nachgewiesen'), findsOneWidget);
  });
}
