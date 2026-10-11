/// GTIN-Hilfsfunktionen (EAN-8, UPC-A, EAN-13, GTIN-14).
///
/// Ein Barcode identifiziert ein Produkt, er enthält keine Zutaten.
library;

enum BarcodeProblem { empty, notNumeric, wrongLength, badCheckDigit }

class BarcodeCheck {
  const BarcodeCheck._(this.normalized, this.problem);
  final String normalized;
  final BarcodeProblem? problem;
  bool get isValid => problem == null;
}

class Barcode {
  Barcode._();

  static const validLengths = {8, 12, 13, 14};

  /// Entfernt Leerzeichen/Bindestriche und prüft Länge sowie Prüfziffer.
  static BarcodeCheck check(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.isEmpty) return BarcodeCheck._(cleaned, BarcodeProblem.empty);
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return BarcodeCheck._(cleaned, BarcodeProblem.notNumeric);
    }
    if (!validLengths.contains(cleaned.length)) {
      return BarcodeCheck._(cleaned, BarcodeProblem.wrongLength);
    }
    if (!hasValidCheckDigit(cleaned)) {
      return BarcodeCheck._(cleaned, BarcodeProblem.badCheckDigit);
    }
    return BarcodeCheck._(cleaned, null);
  }

  /// GS1-Prüfziffer (Modulo 10, Gewichtung 3/1 von rechts).
  static bool hasValidCheckDigit(String digits) {
    var sum = 0;
    final body = digits.substring(0, digits.length - 1);
    for (var i = 0; i < body.length; i++) {
      final d = body.codeUnitAt(body.length - 1 - i) - 48;
      sum += (i % 2 == 0) ? d * 3 : d;
    }
    final check = (10 - (sum % 10)) % 10;
    return check == digits.codeUnitAt(digits.length - 1) - 48;
  }

  /// Vergleichsschlüssel: GTIN ohne führende Nullen
  /// (UPC-A 012345678905 == EAN-13 0012345678905).
  static String key(String code) {
    final k = code.replaceFirst(RegExp(r'^0+'), '');
    return k.isEmpty ? '0' : k;
  }

  static bool sameProduct(String a, String b) => key(a) == key(b);

  /// Wandelt einen 8-stelligen UPC-E-Code in UPC-A (12 Stellen) um.
  static String? upcEToUpcA(String upce) {
    if (!RegExp(r'^[01]\d{7}$').hasMatch(upce)) return null;
    final sys = upce[0];
    final d = upce.substring(1, 7);
    final check = upce[7];
    final last = d[5];
    String body;
    switch (last) {
      case '0':
      case '1':
      case '2':
        body = '${d.substring(0, 2)}${last}0000${d.substring(2, 5)}';
      case '3':
        body = '${d.substring(0, 3)}00000${d.substring(3, 5)}';
      case '4':
        body = '${d.substring(0, 4)}00000${d[4]}';
      default:
        body = '${d.substring(0, 5)}0000$last';
    }
    return '$sys$body$check';
  }
}
