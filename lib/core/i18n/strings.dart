/// Zentrales Übersetzungssystem.
///
/// Alle sichtbaren Texte kommen aus `assets/i18n/SPRACHE.json`.
/// Fehlt ein Schlüssel, wird Englisch verwendet (nie ein leerer Text).
library;

import 'dart:convert';

import 'package:flutter/services.dart';

enum TranslationStatus {
  /// Vollständig und geprüft.
  complete,

  /// Vollständig vorhanden, aber noch nicht von Muttersprachlern/Fachleuten geprüft.
  draft,

  /// Geplant – noch keine Übersetzung.
  planned,
}

class LanguageInfo {
  const LanguageInfo(this.code, this.nativeName, this.status, {this.rtl = false, this.note});
  final String code;
  final String nativeName;
  final TranslationStatus status;
  final bool rtl;
  final String? note;
  bool get selectable => status != TranslationStatus.planned;
}

const List<LanguageInfo> appLanguages = [
  LanguageInfo('de', 'Deutsch', TranslationStatus.complete),
  LanguageInfo('en', 'English', TranslationStatus.complete),
  LanguageInfo('ar', 'العربية', TranslationStatus.draft, rtl: true),
  LanguageInfo('tr', 'Türkçe', TranslationStatus.draft),
  LanguageInfo('fr', 'Français', TranslationStatus.planned),
  LanguageInfo('ur', 'اردو', TranslationStatus.planned, rtl: true),
  LanguageInfo('id', 'Bahasa Indonesia', TranslationStatus.planned),
  LanguageInfo('ms', 'Bahasa Melayu', TranslationStatus.planned),
  LanguageInfo('fa', 'فارسی', TranslationStatus.planned, rtl: true),
  LanguageInfo('bn', 'বাংলা', TranslationStatus.planned),
  LanguageInfo('hi', 'हिन्दी', TranslationStatus.planned),
  LanguageInfo('sw', 'Kiswahili', TranslationStatus.planned),
  LanguageInfo('so', 'Soomaali', TranslationStatus.planned),
  LanguageInfo('ha', 'Hausa', TranslationStatus.planned),
  LanguageInfo('sq', 'Shqip', TranslationStatus.planned),
  LanguageInfo('bs', 'Bosanski', TranslationStatus.planned),
  LanguageInfo('ru', 'Русский', TranslationStatus.planned),
  LanguageInfo('kk', 'Қазақ тілі', TranslationStatus.planned),
  LanguageInfo('uz', 'Oʻzbekcha', TranslationStatus.planned),
  LanguageInfo('az', 'Azərbaycanca', TranslationStatus.planned),
  LanguageInfo('ku', 'Kurdî (Kurmancî)', TranslationStatus.planned,
      note: 'Kurmancî, lateinische Schrift'),
];

LanguageInfo languageInfo(String code) =>
    appLanguages.firstWhere((l) => l.code == code, orElse: () => appLanguages[1]);

class AppStrings {
  AppStrings._(this.code, this._map, this._fallback);

  final String code;
  final Map<String, String> _map;
  final Map<String, String> _fallback;

  bool get isRtl => languageInfo(code).rtl;
  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;

  static Future<Map<String, String>> _loadMap(
      AssetBundle bundle, String code) async {
    final raw = await bundle.loadString('assets/i18n/$code.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return json.map((k, v) => MapEntry(k, v as String));
  }

  static Future<AppStrings> load(String code, {AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    final fallback = await _loadMap(b, 'en');
    Map<String, String> map;
    try {
      map = code == 'en' ? fallback : await _loadMap(b, code);
    } catch (_) {
      return AppStrings._('en', fallback, fallback);
    }
    return AppStrings._(code, map, fallback);
  }

  /// Für Tests ohne Asset-Bundle.
  factory AppStrings.fromMaps(String code, Map<String, String> map,
          Map<String, String> fallback) =>
      AppStrings._(code, map, fallback);

  bool has(String key) => _map.containsKey(key) || _fallback.containsKey(key);

  /// Übersetzung mit Platzhaltern: t('x', {'name': 'Wert'}) ersetzt {name}.
  String t(String key, [Map<String, Object?> params = const {}]) {
    var s = _map[key] ?? _fallback[key] ?? key;
    params.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
    return s;
  }
}

/// Einbettung eines Textes, der immer links-nach-rechts erscheinen muss
/// (Barcodes, E-Nummern), auch in arabischen Sätzen.
String ltr(String s) => '\u2066$s\u2069';
