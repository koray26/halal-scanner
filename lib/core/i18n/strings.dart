/// Zentrales Übersetzungssystem.
///
/// Alle sichtbaren Texte kommen aus `assets/i18n/SPRACHE.json`.
/// Fehlt ein Schlüssel, wird Englisch verwendet (nie ein leerer Text).
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;

enum TranslationStatus {
  /// Vollständig und geprüft.
  complete,

  /// Vollständig vorhanden, aber noch nicht von Muttersprachlern/Fachleuten geprüft.
  draft,

  /// Geplant – noch keine Übersetzung.
  planned,
}

/// Schrift einer Sprache. Die Texterkennung (OCR) liest nur [latin].
enum WritingScript { latin, arabic, bengali, devanagari, hanSimplified, cyrillic }

class LanguageInfo {
  const LanguageInfo(this.code, this.nativeName, this.status,
      {this.rtl = false,
      this.note,
      this.priority = 0,
      this.script = WritingScript.latin,
      this.scriptCode});
  final String code;
  final String nativeName;

  /// Stand der Übersetzung der Benutzeroberfläche (nicht der Zutatenprüfung!).
  final TranslationStatus status;
  final bool rtl;
  final String? note;

  /// Zielgruppen-Priorität (1 = zuerst absichern, 2 = große muslimisch
  /// geprägte Märkte, 3 = weitere Reichweite, 0 = später nach Bedarf).
  final int priority;
  final WritingScript script;

  /// ISO-15924-Schriftcode, falls die Sprache mehrere Schriften hat (zh: Hans).
  final String? scriptCode;
  bool get selectable => status != TranslationStatus.planned;

  /// Die Foto-Texterkennung kann diese Schrift lesen (nur lateinisch).
  bool get ocrCanRead => script == WritingScript.latin;

  Locale get locale =>
      Locale.fromSubtags(languageCode: code, scriptCode: scriptCode);
}

/// Reihenfolge = Zielgruppen-Priorität. Siehe docs/SPRACHEN.md.
/// WICHTIG: Diese Liste beschreibt nur die Benutzeroberfläche. Welche
/// Zutatenlisten geprüft werden, steht in `domain/rules/catalog.dart`
/// (`supportedRuleLanguages`, `greenRuleLanguages`).
const List<LanguageInfo> appLanguages = [
  // Priorität 1 – zuerst absichern
  LanguageInfo('ar', 'العربية', TranslationStatus.draft,
      rtl: true, priority: 1, script: WritingScript.arabic),
  LanguageInfo('en', 'English', TranslationStatus.complete, priority: 1),
  LanguageInfo('de', 'Deutsch', TranslationStatus.complete, priority: 1),
  LanguageInfo('fr', 'Français', TranslationStatus.draft, priority: 1),
  LanguageInfo('tr', 'Türkçe', TranslationStatus.draft, priority: 1),
  // Priorität 2 – große muslimisch geprägte Märkte
  LanguageInfo('id', 'Bahasa Indonesia', TranslationStatus.draft, priority: 2),
  LanguageInfo('ur', 'اردو', TranslationStatus.draft,
      rtl: true, priority: 2, script: WritingScript.arabic),
  LanguageInfo('bn', 'বাংলা', TranslationStatus.draft,
      priority: 2, script: WritingScript.bengali),
  LanguageInfo('hi', 'हिन्दी', TranslationStatus.draft,
      priority: 2, script: WritingScript.devanagari),
  LanguageInfo('ms', 'Bahasa Melayu', TranslationStatus.draft, priority: 2),
  LanguageInfo('fa', 'فارسی', TranslationStatus.draft,
      rtl: true, priority: 2, script: WritingScript.arabic),
  LanguageInfo('ha', 'Hausa', TranslationStatus.draft, priority: 2),
  // Priorität 3 – weitere Reichweite
  LanguageInfo('zh', '简体中文', TranslationStatus.planned,
      priority: 3, script: WritingScript.hanSimplified, scriptCode: 'Hans'),
  // Später nach Bedarf
  LanguageInfo('sw', 'Kiswahili', TranslationStatus.planned),
  LanguageInfo('so', 'Soomaali', TranslationStatus.planned),
  LanguageInfo('sq', 'Shqip', TranslationStatus.planned),
  LanguageInfo('bs', 'Bosanski', TranslationStatus.planned),
  LanguageInfo('ru', 'Русский', TranslationStatus.planned,
      script: WritingScript.cyrillic),
  LanguageInfo('kk', 'Қазақ тілі', TranslationStatus.planned,
      script: WritingScript.cyrillic),
  LanguageInfo('uz', 'Oʻzbekcha', TranslationStatus.planned),
  LanguageInfo('az', 'Azərbaycanca', TranslationStatus.planned),
  LanguageInfo('ku', 'Kurdî (Kurmancî)', TranslationStatus.planned,
      note: 'Kurmancî, lateinische Schrift'),
];

LanguageInfo languageInfo(String code) => appLanguages.firstWhere(
    (l) => l.code == code,
    orElse: () => appLanguages.firstWhere((l) => l.code == 'en'));

class AppStrings {
  AppStrings._(this.code, this._map, this._fallback);

  final String code;
  final Map<String, String> _map;
  final Map<String, String> _fallback;

  bool get isRtl => languageInfo(code).rtl;
  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;

  static Future<Map<String, String>> _loadMap(
      AssetBundle bundle, String code) async {
    // load + utf8 statt loadString: kein Isolate für große Dateien nötig.
    final data = await bundle.load('assets/i18n/$code.json');
    final raw = utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
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
