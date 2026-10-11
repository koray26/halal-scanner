// Sprachabhängige Zutaten-Erkennung (getrennt von der Benutzeroberfläche).
//
// Diese Tests halten fest, was die App HEUTE tatsächlich erkennt. Sie fügen
// keine neuen Zutatenbegriffe hinzu. Grundsatz: Unbekannte Sprachen,
// nicht unterstützte Schriften und unzureichende Daten führen nie zu Grün.
// Siehe docs/SPRACHEN.md.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/core/i18n/digits.dart';
import 'package:halal_scanner/domain/barcode.dart';
import 'package:halal_scanner/domain/models.dart';
import 'package:halal_scanner/domain/rules/catalog.dart';
import 'package:halal_scanner/domain/rules/dimensions.dart';
import 'package:halal_scanner/domain/rules/halal_engine.dart';
import 'package:halal_scanner/domain/script.dart';
import 'package:halal_scanner/features/ocr/ocr_screen.dart';

final now = DateTime.utc(2026, 10, 11);
final offSource = SourceRef(kind: SourceKind.openFoodFacts, retrievedAt: now);
const code = '4006381333931';

ProductRecord productWith(List<IngredientText> texts,
        {List<OffIngredient> structured = const []}) =>
    ProductRecord(
      barcode: code,
      source: offSource,
      name: 'Testprodukt',
      ingredientTexts: texts,
      structuredIngredients: structured,
    );

IngredientText off(String text, String lang) =>
    IngredientText(text: text, lang: lang, source: offSource);

Verdict evalTexts(List<IngredientText> texts,
        {List<OffIngredient> structured = const []}) =>
    HalalEngine().evaluate(
        product: productWith(texts, structured: structured),
        scannedBarcode: code,
        now: now);

Verdict evalLang(String text, String lang) => evalTexts([off(text, lang)]);

Set<String> ruleIds(Verdict v) => v.findings
    .where((f) => !f.isResolved && f.effect != RuleEffect.info)
    .map((f) => f.ruleId)
    .toSet();

void main() {
  group('Zuordnung Sprache -> Zutaten-Erkennung', () {
    test('Grün nur für Deutsch und Englisch; Französisch/Türkisch eingeschränkt', () {
      expect(greenRuleLanguages, {'de', 'en'});
      expect(supportedRuleLanguages, containsAll(greenRuleLanguages));
      expect(ingredientSupportFor('de'), IngredientSupport.full);
      expect(ingredientSupportFor('en'), IngredientSupport.full);
      expect(ingredientSupportFor('fr'), IngredientSupport.limited);
      expect(ingredientSupportFor('tr'), IngredientSupport.limited);
      // Grund-Erkennung (gleiche Regeln, Begriffe aus dem Open-Food-Facts-
      // Wörterbuch): HARAM/UNKLAR möglich, nie Grün.
      for (final l in ['ar', 'id', 'ms', 'ur', 'bn', 'hi', 'fa', 'ha']) {
        expect(ingredientSupportFor(l), IngredientSupport.basic, reason: l);
      }
      expect(ingredientSupportFor('zh'), IngredientSupport.none);
    });

    test('Regelversion für die Sperre von Grün bei fr/tr', () {
      expect(rulesetVersion, '2026.10-4');
    });
  });

  group('Priorität 1: Deutsch/Englisch können Grün ergeben', () {
    test('Deutsch, unkritisch -> Grün', () {
      expect(evalLang('Weizenmehl, Wasser, Sonnenblumenöl, Salz, Hefe', 'de').status,
          HalalStatus.halalByIngredients);
    });

    test('Englisch, unkritisch -> Grün', () {
      expect(evalLang('wheat flour, water, sunflower oil, salt, yeast', 'en').status,
          HalalStatus.halalByIngredients);
    });

    test('Deutsch + Französisch: die deutsche Liste trägt, Französisch wird mitgeprüft', () {
      final v = evalTexts([
        off('Weizenmehl, Wasser, Salz', 'de'),
        off('farine de blé, eau, sel', 'fr'),
      ]);
      expect(v.status, HalalStatus.halalByIngredients);
      expect(v.unknowns, isNot(contains(UnknownReason.languageLimited)));
    });

    test('Deutsch unkritisch, Französisch mit Schwein -> Widerspruch, nie Grün', () {
      // Die französische Fassung wird mitgeprüft. Widersprechen sich die
      // Sprachfassungen, gilt bewusst NICHT VERIFIZIERT (Regel E).
      final v = evalTexts([
        off('Weizenmehl, Wasser, Salz', 'de'),
        off('farine de blé, eau, porc', 'fr'),
      ]);
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.conflictingSources));
    });
  });

  group('Priorität 1: Französisch – erkannt, aber vorerst kein Grün', () {
    test('Unkritische Liste -> NICHT VERIFIZIERT (Sprache eingeschränkt)', () {
      final v = evalLang('farine de blé, eau, huile de tournesol, sel, levure', 'fr');
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.languageLimited));
      expect(v.greenConditions[GreenCondition.languageSupported], isFalse);
    });

    test('Verbotene Bestandteile werden erkannt -> HARAM', () {
      expect(evalLang('sucre, gélatine de porc', 'fr').status, HalalStatus.haram);
      expect(evalLang('farine, saindoux, sel', 'fr').status, HalalStatus.haram);
      expect(evalLang('eau, vin rouge, sel', 'fr').status, HalalStatus.haram);
      expect(evalLang('sucre, alcool', 'fr').status, HalalStatus.haram);
      expect(evalLang('boudin noir', 'fr').status, HalalStatus.haram);
    });

    test('Ungeklärte Herkunft wird erkannt -> UNKLAR', () {
      expect(ruleIds(evalLang('sucre, gélatine', 'fr')), contains('gelatine'));
      expect(ruleIds(evalLang('sucre, arômes', 'fr')), contains('flavouring'));
      expect(ruleIds(evalLang('lait, présure', 'fr')), contains('rennet'));
      expect(ruleIds(evalLang('poulet, sel', 'fr')), contains('meat'));
      expect(evalLang('sucre, gélatine', 'fr').status, HalalStatus.unclear);
    });

    test('Schweine-Angabe wird als Sachaussage erkannt', () {
      final v = evalLang('sucre, gélatine de porc', 'fr');
      expect(assessDimensions(v).pork.state, DimensionState.detected);
    });

    test('Ohne Fund: Schwein/Alkohol „ungeklärt“ statt „nicht nachgewiesen“', () {
      final v = evalLang('farine de blé, eau, sel', 'fr');
      expect(assessDimensions(v).pork.state, DimensionState.unresolved);
      expect(assessDimensions(v).alcohol.state, DimensionState.unresolved);
    });
  });

  group('Priorität 1: Türkisch – erkannt, aber vorerst kein Grün', () {
    test('Unkritische Liste -> NICHT VERIFIZIERT (Sprache eingeschränkt)', () {
      final v = evalLang('buğday unu, su, ayçiçek yağı, tuz, maya', 'tr');
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.languageLimited));
    });

    test('Verbotene Bestandteile werden erkannt -> HARAM', () {
      expect(evalLang('şeker, domuz jelatini', 'tr').status, HalalStatus.haram);
      expect(evalLang('su, alkol', 'tr').status, HalalStatus.haram);
      expect(evalLang('üzüm, şarap', 'tr').status, HalalStatus.haram);
    });

    test('Ungeklärte Herkunft wird erkannt -> UNKLAR', () {
      expect(ruleIds(evalLang('şeker, jelatin', 'tr')), contains('gelatine'));
      expect(ruleIds(evalLang('süt, peynir mayası', 'tr')), contains('rennet'));
      expect(ruleIds(evalLang('tavuk, tuz', 'tr')), contains('meat'));
    });

    test('Großbuchstaben mit İ und I (ı) werden erkannt', () {
      // Unicode behandelt „İ“ nicht wie „i“ und „I“ nicht wie „ı“.
      expect(ruleIds(evalLang('ŞEKER, JELATİN', 'tr')), contains('gelatine'));
      expect(ruleIds(evalLang('SIĞIR ETİ, TUZ', 'tr')), contains('meat'));
      expect(evalLang('ŞEKER, DOMUZ JELATİNİ', 'tr').status, HalalStatus.haram);
      expect(evalLang('SU, RAKI', 'tr').status, HalalStatus.haram);
    });

    test('Fundstelle zeigt den Wortlaut der Quelle', () {
      final v = evalLang('ŞEKER, JELATİN', 'tr');
      final f = v.findings.firstWhere((f) => f.ruleId == 'gelatine');
      expect(f.matchedText, 'JELATİN');
    });

    test('Vereinheitlichung ändert Länge und andere Zeichen nicht', () {
      expect(turkicFold('JELATİN sığır'), 'JELATiN siğir');
      expect(turkicFold('JELATİN').length, 'JELATİN'.length);
      expect(turkicFold('Zucker, Gelatine'), 'Zucker, Gelatine');
    });
  });

  group('Priorität 2 und weitere: keine getesteten Wortlisten -> nie Grün', () {
    // Unkritisch wirkende Listen. Ohne getestete Wortlisten darf die App
    // daraus kein Grün machen – auch nicht, wenn nichts gefunden wird.
    const samples = {
      'ar': 'سكر، ملح، ماء',
      'id': 'tepung terigu, air, garam',
      'ms': 'tepung gandum, air, garam',
      'ur': 'چینی، نمک، پانی',
      'bn': 'চিনি, লবণ, পানি',
      'hi': 'चीनी, नमक, पानी',
      'fa': 'شکر، نمک، آب',
      'ha': 'sukari, gishiri, ruwa',
      'zh': '糖、盐、水',
    };

    for (final e in samples.entries) {
      test('${e.key}: unkritisch wirkend -> NICHT VERIFIZIERT', () {
        final v = evalLang(e.value, e.key);
        expect(v.status, HalalStatus.notVerified);
        expect(v.status, isNot(HalalStatus.halalByIngredients));
        expect(v.unknowns, contains(UnknownReason.languageNotSupported));
      });
    }

    test('Text wird mit denselben Regeln geprüft (Grund-Erkennung)', () {
      // „babi“ steht bereits in den sprachübergreifenden Schweine-Begriffen.
      expect(evalLang('gula, lemak babi', 'id').status, HalalStatus.haram);
      // Unbekanntes bleibt NICHT VERIFIZIERT – nichts wird erfunden.
      expect(evalLang('gula, garam', 'id').status, HalalStatus.notVerified);
    });

    test('Chinesisch: weder Wortlisten noch Grund-Erkennung', () {
      final v = evalLang('糖、明胶、盐', 'zh');
      expect(v.status, HalalStatus.notVerified);
      expect(v.findings, isEmpty);
    });

    test('Strukturierte Datenbank-Analyse kann HARAM/UNKLAR liefern, nie Grün', () {
      final pork = evalTexts([off('gula, lemak babi', 'id')], structured: const [
        OffIngredient(id: 'en:sugar', text: 'gula', inTaxonomy: true),
        OffIngredient(id: 'id:lemak babi', text: 'lemak babi'),
      ]);
      expect(pork.status, HalalStatus.haram);

      final gelatin = evalTexts([off('gula, gelatin', 'id')], structured: const [
        OffIngredient(id: 'en:sugar', text: 'gula', inTaxonomy: true),
        OffIngredient(id: 'en:gelatin', text: 'gelatin', inTaxonomy: true),
      ]);
      expect(gelatin.status, HalalStatus.unclear);

      final clean = evalTexts([off('gula, garam', 'id')], structured: const [
        OffIngredient(id: 'en:sugar', text: 'gula', inTaxonomy: true),
        OffIngredient(id: 'en:salt', text: 'garam', inTaxonomy: true),
      ]);
      expect(clean.status, HalalStatus.notVerified);
    });
  });

  group('Nicht unterstützte Schriften', () {
    test('Anteil nicht-lateinischer Buchstaben', () {
      expect(nonLatinShare('Zucker, Salz'), 0);
      expect(nonLatinShare('sukari, gishiri, ɓaure, ƙwai'), 0); // Hausa (Latein)
      expect(hasUnsupportedScript('سكر، ملح'), isTrue); // Arabisch
      expect(hasUnsupportedScript('چینی، نمک'), isTrue); // Urdu/Persisch
      expect(hasUnsupportedScript('চিনি, লবণ'), isTrue); // Bengalisch
      expect(hasUnsupportedScript('चीनी, नमक'), isTrue); // Devanagari
      expect(hasUnsupportedScript('糖、盐'), isTrue); // Chinesisch
      expect(hasUnsupportedScript('น้ำตาล, เกลือ'), isTrue); // Thai
      expect(hasUnsupportedScript('сахар, соль'), isTrue); // Kyrillisch
      // Kleiner Anteil (Halal-Hinweis in arabischer Schrift) bleibt unter 20 %.
      expect(hasUnsupportedScript('Zucker, Salz, Weizenmehl, Wasser (حلال)'), isFalse);
    });

    test('Als Deutsch/Englisch markierter Text in fremder Schrift -> nie Grün', () {
      final v = evalLang('سكر، ملح، ماء، دقيق', 'en');
      expect(v.status, isNot(HalalStatus.halalByIngredients));
      expect(v.unknowns, contains(UnknownReason.unsupportedScript));
      expect(v.greenConditions[GreenCondition.languageSupported], isFalse);
    });

    test('Foto-Texterkennung: jede nicht-lateinische Schrift wird gemeldet', () {
      for (final t in [
        'سكر، جيلاتين، ملح، ماء',
        'چینی، جیلاٹن، نمک',
        'شکر، ژلاتین، نمک',
        'চিনি, জেলাটিন, লবণ',
        'चीनी, जिलेटिन, नमक',
        '糖、明胶、盐',
        'น้ำตาล, เจลาติน, เกลือ',
      ]) {
        expect(OcrText.looksLikeUnsupportedScript(t), isTrue, reason: t);
      }
      for (final t in ['Zucker, Gelatine, Salz', 'gula, gelatin, garam', 'sukari, gishiri']) {
        expect(OcrText.looksLikeUnsupportedScript(t), isFalse, reason: t);
      }
    });
  });

  group('Ziffern anderer Schriften im Barcode', () {
    const ean = '4006381333931';
    test('Arabisch-indische, persische, Devanagari- und bengalische Ziffern', () {
      for (final input in [
        '٤٠٠٦٣٨١٣٣٣٩٣١', // Arabisch-indisch
        '۴۰۰۶۳۸۱۳۳۳۹۳۱', // Persisch/Urdu
        '४००६३८१३३३९३१', // Devanagari
        '৪০০৬৩৮১৩৩৩৯৩১', // Bengalisch
      ]) {
        expect(Barcode.asciiDigits(input), ean, reason: input);
        final check = Barcode.check(input);
        expect(check.isValid, isTrue, reason: input);
        expect(check.normalized, ean);
      }
    });

    test('Andere Zeichen bleiben unverändert und werden weiter abgelehnt', () {
      expect(Barcode.asciiDigits('40063abc'), '40063abc');
      expect(Barcode.check('4006abc381333').problem, BarcodeProblem.notNumeric);
    });

    test('Eingabefeld wandelt beim Tippen um', () {
      const f = NativeDigitsInputFormatter();
      final out = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
            text: '۴۰۰۶', selection: TextSelection.collapsed(offset: 4)),
      );
      expect(out.text, '4006');
      expect(out.selection.baseOffset, 4);
    });
  });

  group('Wurstwaren ohne Zutatenangabe (Pepperoni, Chorizo, Mortadella)', () {
    test('Ohne Unterzutaten -> NICHT VERIFIZIERT (Liste nicht vollständig)', () {
      for (final e in const {
        'Weizenmehl, Tomaten, Pepperoni, Salz': 'de',
        'wheat flour, chorizo, salt': 'en',
        'Weizenmehl, Mortadella': 'de',
        'PEPPERONI, SALZ': 'de',
      }.entries) {
        final v = evalLang(e.key, e.value);
        expect(v.status, HalalStatus.notVerified, reason: e.key);
        expect(v.unknowns, contains(UnknownReason.compositeUnspecified), reason: e.key);
        expect(v.greenConditions[GreenCondition.listComplete], isFalse, reason: e.key);
      }
    });

    test('Schwein/Alkohol gelten dann als ungeklärt, nicht als „nicht nachgewiesen“', () {
      final v = evalLang('Weizenmehl, Pepperoni, Salz', 'de');
      expect(assessDimensions(v).pork.state, DimensionState.unresolved);
    });

    test('Mit Unterzutaten werden diese normal geprüft', () {
      final pork = evalLang('Weizenmehl, Pepperoni (Schweinefleisch, Salz)', 'de');
      expect(pork.status, HalalStatus.haram);
      expect(pork.unknowns, isNot(contains(UnknownReason.compositeUnspecified)));

      final beef = evalLang('Mortadella (Rindfleisch, Salz, Gewürze)', 'de');
      expect(beef.status, HalalStatus.unclear);
      expect(beef.unknowns, isNot(contains(UnknownReason.compositeUnspecified)));
    });

    test('Belegtes UNKLAR hat Vorrang vor der fehlenden Angabe', () {
      final v = evalLang('Weizenmehl, Gelatine, Chorizo', 'de');
      expect(v.status, HalalStatus.unclear);
      expect(v.unknowns, contains(UnknownReason.compositeUnspecified));
    });

    test('„Peperoni“ (Gemüse, ein p) ist nicht betroffen', () {
      final v = evalLang('Weizenmehl, Peperoni, Salz', 'de');
      expect(v.status, HalalStatus.halalByIngredients);
      expect(v.unknowns, isNot(contains(UnknownReason.compositeUnspecified)));
    });
  });
}
