import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/core/i18n/fallback_localizations.dart';
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
    expect(ltr('4006381333931'), '\u20664006381333931\u2069');
  });

  test('Keine absoluten Aussagen wie "100 % halal" oder "garantiert halal"', () {
    // Je Sprache die naheliegenden Formulierungen für „garantiert/sicher halal“.
    final banned = RegExp(
        r'100\s?%|%\s?100|٪\s?100|100\s?٪|۱۰۰|'
        r'garantiert\s+halal|guaranteed\s+halal|'
        r'helal\s+garanti|garantili\s+helal|حلال\s+مضمون|مضمون|'
        r'halal\s+garanti|garanti\s+halal|certainement\s+halal|'
        r'dijamin\s+halal|pasti\s+halal|halal\s+terjamin|terjamin\s+halal|'
        r'گارنٹی\s*شدہ\s+حلال|یقینی\s+طور\s+پر\s+حلال|'
        r'تضمین\s*شده\s+حلال|حلال\s+تضمینی|قطعاً\s+حلال|'
        r'নিশ্চিতভাবে\s+হালাল|গ্যারান্টিযুক্ত\s+হালাল|'
        r'गारंटीड\s+हलाल|निश्चित\s+रूप\s+से\s+हलाल|'
        r'tabbataccen\s+halal|halal\s+ne\s+tabbas',
        caseSensitive: false,
        unicode: true);
    expect(banned.hasMatch('100 % halal'), isTrue);
    expect(banned.hasMatch('dijamin halal'), isTrue);
    for (final lang in appLanguages.where((l) => l.selectable)) {
      final map = load(lang.code);
      final hits = map.entries.where((e) => banned.hasMatch(e.value)).map((e) => e.key);
      expect(hits, isEmpty, reason: '${lang.code}: $hits');
    }
  });

  test('Grün ist überall als keine Zertifizierung gekennzeichnet', () {
    for (final lang in appLanguages.where((l) => l.selectable)) {
      final map = load(lang.code);
      expect(map['status.halalByIngredients.meaning'], isNotEmpty);
      expect(map['green.notGuarantee'], isNotEmpty);
    }
    expect(load('de')['status.halalByIngredients'],
        'HALAL NACH VOLLSTÄNDIGER ZUTATENPRÜFUNG');
  });

  group('Sprachstrategie (Prioritäten)', () {
    const prio1 = ['ar', 'en', 'de', 'fr', 'tr'];
    const prio2 = ['id', 'ur', 'bn', 'hi', 'ms', 'fa', 'ha'];

    test('Priorität 1 steht zuerst, Priorität 1 und 2 sind wählbar', () {
      expect(appLanguages.take(5).map((l) => l.code), prio1);
      for (final c in [...prio1, ...prio2]) {
        final l = languageInfo(c);
        expect(l.code, c);
        expect(l.selectable, isTrue, reason: c);
      }
      expect(prio2.map((c) => languageInfo(c).priority).toSet(), {2});
    });

    test('Vereinfachtes Chinesisch ist Priorität 3, noch in Vorbereitung', () {
      final zh = languageInfo('zh');
      expect(zh.priority, 3);
      expect(zh.selectable, isFalse);
      expect(zh.locale.scriptCode, 'Hans');
    });

    test('Nur Deutsch und Englisch gelten als vollständig übersetzt', () {
      final complete = appLanguages
          .where((l) => l.status == TranslationStatus.complete)
          .map((l) => l.code)
          .toSet();
      expect(complete, {'de', 'en'});
    });
  });

  group('Rechts-nach-links', () {
    test('Genau Arabisch, Urdu und Persisch sind RTL', () {
      final rtl = appLanguages.where((l) => l.rtl).map((l) => l.code).toSet();
      expect(rtl, {'ar', 'ur', 'fa'});
      for (final c in rtl) {
        final s = AppStrings.fromMaps(c, load(c), load('en'));
        expect(s.direction, TextDirection.rtl, reason: c);
        expect(s.isRtl, isTrue);
      }
      for (final c in ['bn', 'hi', 'id', 'ms', 'ha', 'fr', 'tr']) {
        expect(AppStrings.fromMaps(c, load(c), load('en')).direction,
            TextDirection.ltr, reason: c);
      }
    });

    test('RTL-Texte sind tatsächlich in arabischer Schrift', () {
      final arabicLetter = RegExp(r'\p{Script=Arabic}', unicode: true);
      for (final c in ['ar', 'ur', 'fa']) {
        final m = load(c);
        for (final k in ['status.haram', 'status.unclear', 'status.notVerified',
            'home.scan', 'nav.settings']) {
          expect(arabicLetter.hasMatch(m[k]!), isTrue, reason: '$c: $k');
        }
      }
    });

    test('Platzhalter für Barcodes/E-Nummern bleiben in RTL-Texten erhalten', () {
      for (final c in ['ar', 'ur', 'fa']) {
        expect(load(c)['lookup.loading'], contains('{code}'));
        expect(load(c)['finding.fromTag'], contains('{code}'));
      }
    });
  });

  test('Die fünf Ergebnis-Bezeichnungen sind in jeder Sprache verschieden', () {
    const keys = [
      'status.halalCertified',
      'status.halalByIngredients',
      'status.haram',
      'status.unclear',
      'status.notVerified',
    ];
    for (final lang in appLanguages.where((l) => l.selectable)) {
      final m = load(lang.code);
      final labels = keys.map((k) => m[k]!.trim().toLowerCase()).toSet();
      expect(labels, hasLength(keys.length), reason: lang.code);
    }
  });

  test('Jede Sprache erklärt die Zutaten-Erkennung getrennt von der Oberfläche', () {
    for (final lang in appLanguages.where((l) => l.selectable)) {
      final m = load(lang.code);
      for (final k in [
        'language.ingredients.full',
        'language.ingredients.limited',
        'language.ingredients.none',
        'unknown.languageLimited',
        'unknown.languageNotSupported',
        'unknown.unsupportedScript',
      ]) {
        expect(m[k], isNotEmpty, reason: '${lang.code}: $k');
      }
    }
  });

  group('Flutter-Standardtexte (Bedienelemente)', () {
    test('Alle wählbaren Sprachen außer Hausa bringt Flutter selbst mit', () {
      for (final lang in appLanguages.where((l) => l.selectable)) {
        final builtIn = kMaterialSupportedLanguages.contains(lang.code);
        expect(builtIn, lang.code != 'ha', reason: lang.code);
      }
    });

    test('Ersatz greift nur, wo Flutter nichts mitbringt', () {
      const material = FallbackMaterialLocalizationsDelegate();
      const cupertino = FallbackCupertinoLocalizationsDelegate();
      const widgets = FallbackWidgetsLocalizationsDelegate();
      expect(material.isSupported(const Locale('ha')), isTrue);
      expect(cupertino.isSupported(const Locale('ha')), isTrue);
      expect(widgets.isSupported(const Locale('ha')), isTrue);
      for (final c in ['ar', 'ur', 'fa', 'de', 'en', 'id', 'bn', 'hi', 'ms', 'fr', 'tr']) {
        expect(material.isSupported(Locale(c)), isFalse, reason: c);
      }
    });
  });
}
