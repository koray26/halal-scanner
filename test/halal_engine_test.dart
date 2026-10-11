// Feste Testfälle für die Halal-Regeln. Diese Ergebnisse dürfen sich nur
// durch eine bewusste, dokumentierte Regeländerung ändern.
import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/domain/models.dart';
import 'package:halal_scanner/domain/rules/catalog.dart';
import 'package:halal_scanner/domain/rules/halal_engine.dart';

final now = DateTime.utc(2026, 10, 11);
final offSource = SourceRef(
  kind: SourceKind.openFoodFacts,
  retrievedAt: now,
  url: 'https://world.openfoodfacts.org/product/4000000000000',
);

const code = '4006381333931'; // gültige EAN-13

ProductRecord product(
  String? ingredients, {
  String barcode = code,
  String? name = 'Testprodukt',
  bool incomplete = false,
  List<String> labels = const [],
  List<String> additives = const [],
  List<Certification> certs = const [],
  List<IngredientText>? texts,
  DateTime? lastModified,
}) =>
    ProductRecord(
      barcode: barcode,
      source: offSource,
      name: name,
      lastModified: lastModified,
      labelTags: labels,
      additiveTags: additives,
      certifications: certs,
      ingredientTexts: texts ??
          (ingredients == null
              ? const []
              : [
                  IngredientText(
                      text: ingredients,
                      lang: 'de',
                      source: offSource,
                      markedIncomplete: incomplete)
                ]),
    );

Verdict eval(String? ingredients, {String scanned = code}) => HalalEngine()
    .evaluate(product: product(ingredients), scannedBarcode: scanned, now: now);

Set<String> ruleIds(Verdict v) => v.findings
    .where((f) => !f.isResolved && f.effect != RuleEffect.info)
    .map((f) => f.ruleId)
    .toSet();

void main() {
  group('Regel A – belegtes HARAM', () {
    test('Schweinegelatine -> HARAM mit Beleg', () {
      final v = eval('Zucker, Glukosesirup, Schweinegelatine, Säuerungsmittel: Citronensäure');
      expect(v.status, HalalStatus.haram);
      expect(v.certainty, Certainty.documented);
      final f = v.haramFindings.single;
      expect(f.ruleId, 'gelatine');
      expect(f.escalatedByPork, isTrue);
      expect(f.ingredient, contains('schweinegelatine'));
    });

    test('Gelatine (Schwein) in Klammern -> HARAM', () {
      final v = eval('Zucker, Gelatine (Schwein), Farbstoff');
      expect(v.status, HalalStatus.haram);
    });

    test('Englisch: pork gelatin -> HARAM', () {
      expect(eval('sugar, pork gelatin, citric acid').status, HalalStatus.haram);
    });

    test('Schweinefleisch -> HARAM', () {
      expect(eval('Schweinefleisch 80%, Salz, Gewürze').status, HalalStatus.haram);
    });

    test('Rotwein als Zutat -> HARAM', () {
      final v = eval('Rindfleisch, Rotwein 10%, Zwiebeln');
      expect(v.status, HalalStatus.haram);
      expect(ruleIds(v), contains('alcoholic_beverage'));
    });

    test('Alkohol deklariert -> HARAM', () {
      final v = eval('Zucker, Kakaobutter, Alkohol 2%, Vollmilchpulver');
      expect(v.status, HalalStatus.haram);
      expect(ruleIds(v), contains('alcohol_declared'));
    });

    test('Blut -> HARAM, Blutorange nicht', () {
      expect(eval('Schweineblut, Grütze').status, HalalStatus.haram);
      expect(ruleIds(eval('Wasser, Blutorangensaft, Zucker')), isNot(contains('blood')));
    });

    test('Schmalz vom Schwein (lard) -> HARAM', () {
      expect(eval('flour, lard, salt').status, HalalStatus.haram);
    });
  });

  group('Regel D – UNKLAR', () {
    test('Gelatine ohne Herkunft -> UNKLAR', () {
      final v = eval('Zucker, Glukosesirup, Gelatine, Citronensäure');
      expect(v.status, HalalStatus.unclear);
      expect(v.unclearFindings.single.ruleId, 'gelatine');
    });

    test('Rindergelatine -> UNKLAR (Schlachtung unbekannt)', () {
      expect(eval('Zucker, Rindergelatine').status, HalalStatus.unclear);
    });

    test('Aroma -> UNKLAR', () {
      expect(eval('Zucker, Kakaobutter, Aroma').status, HalalStatus.unclear);
    });

    test('E471 ohne Herkunft -> UNKLAR, pflanzlich -> aufgelöst', () {
      expect(eval('Weizenmehl, Emulgator: E471, Salz').status, HalalStatus.unclear);
      final v = eval('Weizenmehl, Emulgator (E471 pflanzlich), Salz');
      expect(v.status, HalalStatus.halalByIngredients);
      expect(v.resolvedFindings.single.resolvedBy, Qualifier.plant);
    });

    test('Pflanzliche Emulgatoren als Überbegriff gilt für alle Kinder', () {
      final v = eval('Zucker, pflanzliche Emulgatoren (Mono- und Diglyceride von Speisefettsäuren, E472e)');
      expect(v.status, HalalStatus.halalByIngredients);
    });

    test('Überbegriff "pflanzlich" darf Geschwister nicht freisprechen', () {
      final v = eval('Füllung (Rindergelatine, pflanzliches Fett), Zucker');
      expect(v.status, HalalStatus.unclear);
      expect(ruleIds(v), contains('gelatine'));
    });

    test('Lab / Käse ohne Angabe -> UNKLAR, mikrobielles Lab -> ok', () {
      expect(eval('Milch, Salz, Lab').status, HalalStatus.unclear);
      expect(eval('Milch, Salz, mikrobielles Lab').status, HalalStatus.halalByIngredients);
    });

    test('Weinessig -> UNKLAR (nicht HARAM)', () {
      final v = eval('Gurken, Wasser, Weinessig, Salz');
      expect(v.status, HalalStatus.unclear);
      expect(ruleIds(v), {'wine_vinegar'});
    });

    test('vinaigre de vin -> UNKLAR, nicht Wein', () {
      final v = eval('eau, vinaigre de vin, sel');
      expect(ruleIds(v), {'wine_vinegar'});
    });

    test('Karmin E120 -> UNKLAR (strittig)', () {
      expect(eval('Zucker, Farbstoff: E120').status, HalalStatus.unclear);
    });

    test('Hähnchenfleisch ohne Halal-Angabe -> UNKLAR', () {
      expect(eval('Hähnchenfleisch 70%, Wasser, Salz').status, HalalStatus.unclear);
    });

    test('Garnelen -> UNKLAR (Lehrmeinungen unterschiedlich)', () {
      expect(eval('Reis, Garnelen, Salz').status, HalalStatus.unclear);
    });
  });

  group('Keine Fehlalarme', () {
    test('Einfache pflanzliche Liste -> HALAL NACH ZUTATENPRÜFUNG', () {
      final v = eval('Zutaten: Weizenmehl, Zucker, Sonnenblumenöl, Salz, Hefe.');
      expect(v.status, HalalStatus.halalByIngredients);
      expect(v.certainty, Certainty.limited);
      expect(v.unknowns, contains(UnknownReason.manufacturingNotVerified));
      expect(v.validCertification, isNull);
    });

    test('Zuckeralkohole, Weinsäure, Hühnerei, Fruchtfleisch sind unkritisch', () {
      final v = eval('Süßungsmittel (Zuckeralkohole), Säuerungsmittel: Weinsäure, '
          'Hühnereiweiß, Mangofruchtfleisch, Butterschmalz, Malzextrakt');
      expect(ruleIds(v), isEmpty, reason: ruleIds(v).toString());
      expect(v.status, HalalStatus.halalByIngredients);
    });

    test('Kann Spuren von … wird separat ausgewiesen', () {
      final v = eval('Zucker, Kakaomasse. Kann Spuren von Milch und Nüssen enthalten.');
      expect(v.tracesText, contains('spuren'));
      expect(v.status, HalalStatus.halalByIngredients);
    });

    test('Molke ist nur Hinweis', () {
      final v = eval('Zucker, Süßmolkenpulver, Kakao');
      expect(v.status, HalalStatus.halalByIngredients);
      expect(v.infoFindings.single.ruleId, 'whey');
    });

    test('Fischgelatine und Halal-Rindergelatine -> aufgelöst', () {
      expect(eval('Zucker, Fischgelatine').status, HalalStatus.halalByIngredients);
      expect(eval('Zucker, Rindergelatine (halal)').status,
          HalalStatus.halalByIngredients);
    });

    test('Austernpilze sind keine Austern', () {
      expect(eval('Austernpilze, Salz').status, HalalStatus.halalByIngredients);
    });
  });

  group('Regel E – NICHT VERIFIZIERT', () {
    test('Unbekannter Barcode', () {
      final v = HalalEngine()
          .evaluate(product: null, scannedBarcode: code, now: now);
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.productNotFound));
    });

    test('Quelle liefert anderes Produkt -> keine Übernahme der Zutaten', () {
      final v = HalalEngine().evaluate(
          product: product('Schweinegelatine', barcode: '4006381333948'),
          scannedBarcode: code,
          now: now);
      expect(v.status, HalalStatus.notVerified);
      expect(v.identity, IdentityStatus.mismatch);
      expect(v.findings, isEmpty);
    });

    test('Fehlende Zutatenliste -> nie HALAL', () {
      final v = eval(null);
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.noIngredients));
    });

    test('Zutatenliste in nicht unterstützter Sprache -> NICHT VERIFIZIERT', () {
      final v = HalalEngine().evaluate(
          product: product(null, texts: [
            IngredientText(
                text: 'cukier, żelatyna wieprzowa', lang: 'pl', source: offSource),
          ]),
          scannedBarcode: code,
          now: now);
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.languageNotSupported));
    });

    test('Leere Zutatenliste -> nie HALAL', () {
      expect(eval('  ').status, HalalStatus.notVerified);
    });

    test('Als unvollständig markierte Liste ohne Befund -> NICHT VERIFIZIERT', () {
      final v = HalalEngine().evaluate(
          product: product('Zucker, Salz', incomplete: true),
          scannedBarcode: code,
          now: now);
      expect(v.status, HalalStatus.notVerified);
    });

    test('Unvollständig, aber Schweinegelatine erkannt -> HARAM bleibt belegt', () {
      final v = HalalEngine().evaluate(
          product: product('Zucker, Schweinegelatine', incomplete: true),
          scannedBarcode: code,
          now: now);
      expect(v.status, HalalStatus.haram);
    });

    test('Produktname fehlt -> schwache Zuordnung -> keine Halal-Freigabe', () {
      final v = HalalEngine().evaluate(
          product: product('Zucker, Salz', name: null),
          scannedBarcode: code,
          now: now);
      expect(v.status, HalalStatus.notVerified);
      expect(v.identity, IdentityStatus.weak);
    });

    test('Widersprüchliche Quellen -> NICHT VERIFIZIERT', () {
      final v = HalalEngine().evaluate(
          product: product(null, texts: [
            IngredientText(text: 'Zucker, Schweinegelatine', lang: 'de', source: offSource),
            IngredientText(text: 'sugar, beef gelatin', lang: 'en', source: offSource),
          ]),
          scannedBarcode: code,
          now: now);
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.conflictingSources));
    });

    test('Fotografierte Liste ohne Befund -> NICHT VERIFIZIERT (kein Produktbezug)', () {
      final v = HalalEngine().evaluate(
        product: null,
        overrideTexts: [
          IngredientText(
              text: 'Zucker, Salz',
              source: SourceRef(kind: SourceKind.ocrPhoto, retrievedAt: now)),
        ],
        now: now,
      );
      expect(v.status, HalalStatus.notVerified);
      expect(v.identity, IdentityStatus.notApplicable);
    });

    test('Unleserliches Foto (abgeschnitten) -> keine Halal-Freigabe', () {
      final v = HalalEngine().evaluate(
        product: product('x'),
        scannedBarcode: code,
        overrideTexts: [
          IngredientText(
              text: 'Zucker, Weizenm',
              possiblyTruncated: true,
              uncertainFragments: const ['Weizenm'],
              source: SourceRef(kind: SourceKind.ocrPhoto, retrievedAt: now)),
        ],
        now: now,
      );
      expect(v.status, HalalStatus.notVerified);
      expect(v.unknowns, contains(UnknownReason.possiblyTruncated));
    });

    test('Fotografierte Liste mit Gelatine -> UNKLAR', () {
      final v = HalalEngine().evaluate(
        product: null,
        overrideTexts: [
          IngredientText(
              text: 'Zucker, Gelatine',
              source: SourceRef(kind: SourceKind.ocrPhoto, retrievedAt: now)),
        ],
        now: now,
      );
      expect(v.status, HalalStatus.unclear);
    });

    test('Nutzerkorrigierter Text kann keine Halal-Freigabe erzeugen', () {
      final v = HalalEngine().evaluate(
        product: product('Zucker, Salz'),
        scannedBarcode: code,
        overrideTexts: [
          IngredientText(
              text: 'Zucker, Salz',
              source: SourceRef(kind: SourceKind.userEdited, retrievedAt: now)),
        ],
        now: now,
      );
      expect(v.status, HalalStatus.notVerified);
    });
  });

  group('Regel B – Zertifizierung', () {
    Certification cert({
      bool verified = true,
      List<String> gtins = const [code],
      DateTime? until,
    }) =>
        Certification(
          certifier: 'Testzertifizierer',
          gtins: gtins,
          verified: verified,
          validFrom: DateTime.utc(2025, 1, 1),
          validUntil: until ?? DateTime.utc(2027, 1, 1),
          source: SourceRef(kind: SourceKind.certificationRegistry, retrievedAt: now),
        );

    Verdict withCert(Certification c, [String ingredients = 'Zucker, Aroma']) =>
        HalalEngine().evaluate(
            product: product(ingredients, certs: [c]),
            scannedBarcode: code,
            now: now);

    test('Gültiges, passendes Zertifikat -> HALAL-ZERTIFIZIERT', () {
      final v = withCert(cert());
      expect(v.status, HalalStatus.halalCertified);
      expect(v.validCertification, isNotNull);
    });

    test('Abgelaufenes Zertifikat -> nicht zertifiziert', () {
      final v = withCert(cert(until: DateTime.utc(2026, 1, 1)));
      expect(v.status, isNot(HalalStatus.halalCertified));
      expect(v.unknowns, contains(UnknownReason.certificationExpired));
    });

    test('Zertifikat für anderes Produkt -> nicht zertifiziert', () {
      final v = withCert(cert(gtins: const ['4006381333948']));
      expect(v.status, isNot(HalalStatus.halalCertified));
      expect(v.unknowns, contains(UnknownReason.certificationNotApplicable));
    });

    test('Unverifiziertes Zertifikat -> nicht zertifiziert', () {
      final v = withCert(cert(verified: false));
      expect(v.status, isNot(HalalStatus.halalCertified));
    });

    test('Zertifikat + Schweinegelatine -> Widerspruch -> NICHT VERIFIZIERT', () {
      final v = withCert(cert(), 'Zucker, Schweinegelatine');
      expect(v.status, HalalStatus.notVerified);
    });

    test('Halal-Label aus Open Food Facts ist kein Zertifikat', () {
      final v = HalalEngine().evaluate(
          product: product('Zucker, Gelatine', labels: const ['en:halal']),
          scannedBarcode: code,
          now: now);
      expect(v.status, HalalStatus.unclear);
      expect(v.labelHalalUnverified, isTrue);
    });
  });

  group('Sonstiges', () {
    test('Zusatzstoff-Tags ergänzen fehlende Treffer', () {
      final v = HalalEngine().evaluate(
          product: product('Zucker, Emulgator', additives: const ['en:e471']),
          scannedBarcode: code,
          now: now);
      expect(v.status, HalalStatus.unclear);
      expect(v.unclearFindings.single.fromAdditiveTag, isTrue);
    });

    test('Alte Daten werden gekennzeichnet', () {
      final v = HalalEngine().evaluate(
          product: product('Zucker', lastModified: DateTime.utc(2019, 1, 1)),
          scannedBarcode: code,
          now: now);
      expect(v.unknowns, contains(UnknownReason.dataOld));
    });

    test('UPC-A und EAN-13 mit führender Null sind dasselbe Produkt', () {
      final v = HalalEngine().evaluate(
          product: product('Zucker', barcode: '0012345678905'),
          scannedBarcode: '012345678905',
          now: now);
      expect(v.identity, IdentityStatus.confirmed);
    });

    test('Ergebnis ist deterministisch und serialisierbar', () {
      final a = eval('Zucker, Gelatine, Aroma');
      final b = Verdict.fromJson(a.toJson());
      expect(b.toJson(), a.toJson());
      expect(eval('Zucker, Gelatine, Aroma').toJson(), a.toJson());
    });

    test('Regelversion ist gesetzt', () {
      expect(eval('Zucker').rulesetVersion, rulesetVersion);
    });
  });
}
