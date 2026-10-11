/// Eingabehilfe für Ziffern aus anderen Schriften.
library;

import 'package:flutter/services.dart';

import '../../domain/barcode.dart';

/// Wandelt beim Tippen arabisch-indische, persische/Urdu-, Devanagari- und
/// bengalische Ziffern in 0–9 um. Ohne diese Umwandlung würde ein reiner
/// 0–9-Filter solche Eingaben stillschweigend verwerfen.
class NativeDigitsInputFormatter extends TextInputFormatter {
  const NativeDigitsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final converted = Barcode.asciiDigits(newValue.text);
    if (converted == newValue.text) return newValue;
    // Jede umgewandelte Ziffer ist eine UTF-16-Einheit wie vorher:
    // Auswahl/Cursor bleiben gültig.
    return newValue.copyWith(text: converted);
  }
}
