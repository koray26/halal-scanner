import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/domain/barcode.dart';
import 'package:halal_scanner/domain/rules/ingredient_parser.dart';

void main() {
  group('Barcode', () {
    test('gültige Codes', () {
      expect(Barcode.check('4006381333931').isValid, isTrue); // EAN-13
      expect(Barcode.check('96385074').isValid, isTrue); // EAN-8
      expect(Barcode.check('012345678905').isValid, isTrue); // UPC-A
      expect(Barcode.check(' 4006381 333931 ').normalized, '4006381333931');
    });

    test('UPC-E wird zu UPC-A erweitert', () {
      expect(Barcode.upcEToUpcA('04252614'), '042100005264');
      expect(Barcode.check('042100005264').isValid, isTrue);
      expect(Barcode.upcEToUpcA('123'), isNull);
    });

    test('ungültige Codes', () {
      expect(Barcode.check('').problem, BarcodeProblem.empty);
      expect(Barcode.check('40063813339x1').problem, BarcodeProblem.notNumeric);
      expect(Barcode.check('12345').problem, BarcodeProblem.wrongLength);
      expect(Barcode.check('4006381333932').problem, BarcodeProblem.badCheckDigit);
    });
  });

  group('IngredientParser', () {
    test('verschachtelte Klammern', () {
      final p = IngredientParser.parse(
          'Zutaten: Zucker, Füllung (Rindergelatine, Fett (pflanzlich)), Salz.');
      expect(p.roots.map((n) => n.head.trim()), ['Zucker', 'Füllung', 'Salz']);
      final fuellung = p.roots[1];
      expect(fuellung.children.map((c) => c.head.trim()),
          ['Rindergelatine', 'Fett']);
      expect(fuellung.children[1].children.single.head.trim(), 'pflanzlich');
    });

    test('Dezimalpunkt trennt nicht', () {
      final p = IngredientParser.parse('Kakao 2.5%, Zucker');
      expect(p.roots.length, 2);
    });

    test('OFF-Allergenmarkierung wird entfernt', () {
      final p = IngredientParser.parse('_Milch_, Zucker');
      expect(p.roots.first.head, 'Milch');
    });

    test('Spurenhinweis wird abgetrennt', () {
      final p = IngredientParser.parse('Zucker. May contain traces of nuts.');
      expect(p.roots.single.head, 'Zucker');
      expect(p.tracesText, startsWith('May contain'));
    });

    test('Unbalancierte Klammer bricht nicht ab', () {
      final p = IngredientParser.parse('Zucker, Gelatine (Schwein');
      expect(p.allNodes.map((n) => n.head.trim()), contains('Schwein'));
    });
  });
}
