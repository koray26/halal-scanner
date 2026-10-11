import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/core/i18n/strings.dart';

Map<String, String> load(String code) =>
    (jsonDecode(File('assets/i18n/$code.json').readAsStringSync())
            as Map<String, dynamic>)
        .cast<String, String>();

final _placeholder = RegExp(r'\{[a-zA-Z]+\}');

void main() {
  final en = load('en');

  test('Alle wählbaren Sprachen haben eine Datei mit allen Schlüsseln', () {
    for (final lang in appLanguages.where((l) => l.selectable)) {
      final map = load(lang.code);
      final missing = en.keys.where((k) => !map.containsKey(k)).toList();
      expect(missing, isEmpty, reason: '${lang.code} fehlt: $missing');
      final empty = map.entries.where((e) => e.value.trim().isEmpty).map((e) => e.key);
      expect(empty, isEmpty, reason: '${lang.code} leer: $empty');
    }
  });

  test('Platzhalter sind in allen Sprachen identisch', () {
    for (final lang in appLanguages.where((l) => l.selectable)) {
      final map = load(lang.code);
      for (final k in en.keys) {
        final a = _placeholder.allMatches(en[k]!).map((m) => m.group(0)).toSet();
        final b = _placeholder.allMatches(map[k]!).map((m) => m.group(0)).toSet();
        expect(b, a, reason: '${lang.code}: $k');
      }
    }
  });

  test('Nur Sprachen mit Datei sind wählbar', () {
    for (final lang in appLanguages) {
      final exists = File('assets/i18n/${lang.code}.json').existsSync();
      expect(lang.selectable, exists, reason: lang.code);
    }
  });

  test('RTL für Arabisch, Urdu, Persisch', () {
    for (final c in ['ar', 'ur', 'fa']) {
      expect(languageInfo(c).rtl, isTrue);
    }
    final ar = AppStrings.fromMaps('ar', load('ar'), en);
    expect(ar.direction, TextDirection.rtl);
    expect(AppStrings.fromMaps('de', load('de'), en).direction, TextDirection.ltr);
  });

  test('Platzhalter-Ersetzung und Fallback', () {
    final s = AppStrings.fromMaps('de', {'a': 'Hallo {name}'}, {'b': 'fallback'});
    expect(s.t('a', {'name': 'Welt'}), 'Hallo Welt');
    expect(s.t('b'), 'fallback');
    expect(s.t('unbekannt'), 'unbekannt');
  });

  test('Barcodes bleiben in RTL-Texten links-nach-rechts', () {
    expect(ltr('4006381333931'), '⁦4006381333931⁩');
  });
}
