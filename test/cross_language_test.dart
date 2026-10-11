// Gleiche Zutat – gleiche Regel, unabhängig von der Sprache der Zutatenliste
// und unabhängig von der Sprache der App.
//
// Die Tests halten fest, welche Sprachen eine Zutat HEUTE erkennen und wo
// (ehrlich dokumentiert) noch Begriffe fehlen. Fehlende Begriffe führen nie zu
// Grün, sondern zu NICHT VERIFIZIERT. Siehe docs/SPRACHEN.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/domain/models.dart';
import 'package:halal_scanner/domain/rules/catalog.dart';
import 'package:halal_scanner/domain/rules/halal_engine.dart';

final now = DateTime.utc(2026, 10, 11);
final offSource = SourceRef(kind: SourceKind.openFoodFacts, retrievedAt: now);
const code = '4006381333931';

IngredientText off(String text, String lang,
        {bool incomplete = false, bool truncated = false}) =>
    IngredientText(
        text: text,
        lang: lang,
        source: offSource,
        markedIncomplete: incomplete,
        possiblyTruncated: truncated);

Verdict evalTexts(List<IngredientText> texts,
        {int? ingredientsN, int? unknownN, List<String> warnings = const []}) =>
    HalalEngine().evaluate(
      product: ProductRecord(
        barcode: code,
        source: offSource,
        name: 'Testprodukt',
        ingredientTexts: texts,
        ingredientsN: ingredientsN,
        unknownIngredientsN: unknownN,
        dataQualityWarnings: warnings,
      ),
      scannedBarcode: code,
      now: now,
    );

Verdict evalLang(String text, String lang) => evalTexts([off(text, lang)]);

Set<String> ruleIds(Verdict v) => v.findings
    .where((f) => !f.isResolved && f.effect != RuleEffect.info)
    .map((f) => f.ruleId)
    .toSet();

/// Dieselbe Zutat in verschiedenen Sprachen (Wortlaut aus den gepflegten
/// Wortlisten bzw. aus dem Open-Food-Facts-Wörterbuch, nicht erfunden).
const gelatine = {
  'de': 'Zucker, Gelatine',
  'en': 'sugar, gelatin',
  'fr': 'sucre, gélatine',
  'tr': 'şeker, jelatin',
  'ar': 'سكر، جيلاتين',
  'id': 'gula, gelatin',
  'ms': 'gula, gelatin',
  'hi': 'चीनी, जिलेटिन',
  'bn': 'চিনি, জেলাটিন',
  'fa': 'شکر، ژلاتین',
  'ha': 'sukari, gelatin',
};

const pork = {
  'de': 'Zucker, Schweinegelatine',
  'en': 'sugar, pork gelatin',
  'fr': 'sucre, gélatine de porc',
  'tr': 'şeker, domuz jelatini',
  'ar': 'سكر، دهن الخنزير',
  'id': 'gula, lemak babi',
  'ms': 'gula, lemak babi',
  'fa': 'شکر، چربی خوک',
};

const wine = {
  'de': 'Wasser, Rotwein',
  'en': 'water, red wine',
  'fr': 'eau, vin rouge',
  'tr': 'su, şarap',
  'ar': 'ماء، نبيذ أحمر',
  'ms': 'air, wain',
  'ur': 'پانی، شراب',
  'hi': 'पानी, शराब',
  'fa': 'آب، شراب سرخ',
};

const ethanol = {
  'de': 'Wasser, Ethanol',
  'ar': 'ماء، إيثانول',
  'ur': 'پانی، ایتھنول',
  'hi': 'पानी, इथेनॉल',
  'bn': 'পানি, ইথানল',
  'fa': 'آب، اتانول',
};

void main() {
  group('Gleiche Zutat -> gleiche Regel (gemeinsame Kennung)', () {
    for (final e in gelatine.entries) {
      test('Gelatine (${e.key}) -> Regel „gelatine“, UNKLAR', () {
        final v = evalLang(e.value, e.key);
        expect(ruleIds(v), contains('gelatine'));
        expect(v.status, HalalStatus.unclear);
      });
    }

    for (final e in pork.entries) {
      test('Schwein (${e.key}) -> Schwein erkannt, HARAM', () {
        final v = evalLang(e.value, e.key);
        // Entweder eigene Regel „pork“ oder ein Bestandteil „vom Schwein“
        // (z. B. Schweinegelatine = Gelatine, durch Schwein auf HARAM gesetzt).
        expect(
            v.findings.any((f) =>
                !f.isResolved && (f.ruleId == 'pork' || f.escalatedByPork)),
            isTrue);
        expect(v.status, HalalStatus.haram);
      });
    }

    for (final e in wine.entries) {
      test('Wein (${e.key}) -> Regel „alcoholic_beverage“, HARAM', () {
        final v = evalLang(e.value, e.key);
        expect(ruleIds(v), contains('alcoholic_beverage'));
        expect(v.status, HalalStatus.haram);
      });
    }

    for (final e in ethanol.entries) {
      test('Ethanol (${e.key}) -> Regel „alcohol_declared“, HARAM', () {
        final v = evalLang(e.value, e.key);
        expect(ruleIds(v), contains('alcohol_declared'));
        expect(v.status, HalalStatus.haram);
      });
    }

    test('E-Nummern werden in jeder Sprache gleich erkannt', () {
      for (final l in ['de', 'en', 'fr', 'tr', 'ar', 'id', 'ur', 'ha']) {
        expect(ruleIds(evalLang('E120, E441', l)),
            containsAll(['insect_derived', 'gelatine']),
            reason: l);
      }
    });

    test('Gleiches Ergebnis: Regel-IDs sind über alle Sprachen identisch', () {
      final ids = {for (final e in gelatine.entries) e.key: ruleIds(evalLang(e.value, e.key))};
      for (final s in ids.values) {
        expect(s, ids['de']);
      }
    });
  });

  group('Grundsatz: nur Deutsch/Englisch können Grün ergeben', () {
    test('Grund-Erkennung liefert nie Grün, auch ohne Fund', () {
      for (final l in detectOnlyLanguages) {
        final v = evalLang('E330, E300', l);
        expect(v.status, isNot(HalalStatus.halalByIngredients), reason: l);
        expect(v.unknowns, contains(UnknownReason.languageNotSupported), reason: l);
        expect(v.greenConditions[GreenCondition.languageSupported], isFalse, reason: l);
      }
    });

    test('HARAM aus Grund-Erkennung bleibt HARAM (kein Grün, kein Herabstufen)', () {
      final v = evalLang('gula, lemak babi', 'id');
      expect(v.status, HalalStatus.haram);
      expect(v.unknowns, contains(UnknownReason.languageNotSupported));
    });
  });

  group('Bekannte Lücken (ehrlich dokumentiert, nie Grün)', () {
    // Diese Begriffe stehen weder in den Wortlisten noch eindeutig im
    // Open-Food-Facts-Wörterbuch. Sie werden NICHT erfunden.
    const gaps = {
      'ur: Gelatine': ('چینی، جیلاٹن', 'ur'),
      'ur: Schweinefett': ('چینی، سور کی چربی', 'ur'),
      'fa: Schweinefleisch': ('شکر، گوشت خوک', 'fa'),
      'ur: Schweinefleisch': ('چینی، سور کا گوشت', 'ur'),
      'hi: Schweinefleisch': ('चीनी, सूअर का मांस', 'hi'),
      'bn: Schweinefleisch': ('চিনি, শূকরের মাংস', 'bn'),
      'id: „anggur“ (Traube oder Wein – mehrdeutig)': ('air, anggur', 'id'),
    };
    for (final g in gaps.entries) {
      test('${g.key} -> NICHT VERIFIZIERT', () {
        final v = evalLang(g.value.$1, g.value.$2);
        expect(v.status, HalalStatus.notVerified);
        expect(v.unknowns, contains(UnknownReason.languageNotSupported));
      });
    }

    test('Hausa: keine eigenen Begriffe, nur sprachunabhängige Muster', () {
      expect(offTermPatterns['ha'] ?? const {}, isEmpty);
      expect(ingredientSupportFor('ha'), IngredientSupport.basic);
      expect(evalLang('sukari, gishiri, ruwa', 'ha').status, HalalStatus.notVerified);
    });
  });

  group('Mehrdeutige Begriffe lösen keine Regel aus', () {
    test('Arabisch „شراب“ (Sirup/Getränk) gilt nicht als Alkohol', () {
      final v = evalLang('ماء، شراب التوت', 'ar');
      expect(ruleIds(v), isNot(contains('alcoholic_beverage')));
      expect(v.status, HalalStatus.notVerified);
    });

    test('Deutsch „Peperoni“ (Gemüse) ist keine Wurst', () {
      expect(evalLang('Weizenmehl, Peperoni, Salz', 'de').status,
          HalalStatus.halalByIngredients);
    });
  });

  group('Mehrere Sprachfassungen desselben Produkts', () {
    test('Deutsch unkritisch + Arabisch nennt Wein -> Widerspruch, nie Grün', () {
      final v = evalTexts([
        off('Wasser, Zucker, Salz', 'de'),
        off('ماء، سكر، نبيذ', 'ar'),
      ]);
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.conflictingSources));
    });

    test('Beide Fassungen nennen Schwein -> HARAM ohne Widerspruch', () {
      final v = evalTexts([
        off('Zucker, Schweinefett', 'de'),
        off('gula, lemak babi', 'id'),
      ]);
      expect(v.status, HalalStatus.haram);
      expect(v.unknowns, isNot(contains(UnknownReason.conflictingSources)));
    });

    test('Fehlender Treffer in der Grund-Erkennung ist kein Gegenbeleg', () {
      // Urdu kennt „Gelatine“ noch nicht; die deutsche Liste trägt.
      final v = evalTexts([
        off('Zucker, Gelatine', 'de'),
        off('چینی، جیلاٹن', 'ur'),
      ]);
      expect(v.status, HalalStatus.unclear);
      expect(v.unknowns, isNot(contains(UnknownReason.conflictingSources)));
    });

    test('Deutsche Liste unkritisch, Arabisch ohne Fund -> Deutsch trägt', () {
      final v = evalTexts([
        off('Wasser, Zucker, Salz', 'de'),
        off('ماء، سكر، ملح', 'ar'),
      ]);
      expect(v.status, HalalStatus.halalByIngredients);
    });

    test('Reihenfolge der Sprachfassungen ändert das Ergebnis nicht', () {
      final a = evalTexts([off('Wasser, Zucker', 'de'), off('ماء، سكر، نبيذ', 'ar')]);
      final b = evalTexts([off('ماء، سكر، نبيذ', 'ar'), off('Wasser, Zucker', 'de')]);
      expect(a.status, b.status);
      expect(ruleIds(a), ruleIds(b));
    });
  });

  group('Fehlende, unvollständige und unerkannte Daten -> nie Grün', () {
    test('Keine Zutatenliste -> NICHT VERIFIZIERT', () {
      final v = evalTexts(const []);
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.noIngredients));
    });

    test('Als unvollständig markiert -> NICHT VERIFIZIERT', () {
      final v = evalTexts([off('Wasser, Zucker, Salz', 'de', incomplete: true)]);
      expect(v.status, HalalStatus.notVerified);
      expect(v.greenConditions[GreenCondition.listComplete], isFalse);
    });

    test('Möglicherweise abgeschnitten -> NICHT VERIFIZIERT', () {
      final v = evalTexts([off('Wasser, Zucker, Salz', 'de', truncated: true)]);
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.possiblyTruncated));
    });

    test('Überwiegend unerkannte Zutaten (laut Datenbank) -> NICHT VERIFIZIERT', () {
      final v = evalTexts([off('Wasser, Xylofarb, Quorbat', 'de')],
          ingredientsN: 3, unknownN: 2);
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.ingredientsMostlyUnrecognized));
    });

    test('Wurstware ohne Unterzutaten -> NICHT VERIFIZIERT', () {
      final v = evalLang('Weizenmehl, Chorizo', 'de');
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.compositeUnspecified));
    });
  });

  group('Ungeklärte Zutat: Name, Grund und fehlende Information', () {
    test('Gelatine nennt Wortlaut, Regel und offene Fragen', () {
      final v = evalLang('Zucker, Gelatine', 'de');
      final inv = v.investigations.singleWhere((i) => i.ruleId == 'gelatine');
      expect(inv.originalText, 'Gelatine');
      expect(inv.effect, RuleEffect.unclear);
      expect(inv.openQuestions, isNotEmpty);
    });

    test('Gleiche offene Fragen für Gelatine in jeder Sprache', () {
      final de = evalLang(gelatine['de']!, 'de')
          .investigations
          .singleWhere((i) => i.ruleId == 'gelatine');
      for (final e in gelatine.entries) {
        final inv = evalLang(e.value, e.key)
            .investigations
            .singleWhere((i) => i.ruleId == 'gelatine');
        expect(inv.openQuestions, de.openQuestions, reason: e.key);
      }
    });
  });
}
