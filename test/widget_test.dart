import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/app.dart';
import 'package:halal_scanner/core/i18n/strings.dart';
import 'package:halal_scanner/core/widgets/widgets.dart';
import 'package:halal_scanner/data/history_store.dart';
import 'package:halal_scanner/domain/models.dart';
import 'package:halal_scanner/domain/rules/halal_engine.dart';
import 'package:halal_scanner/features/result/investigation_widgets.dart';
import 'package:halal_scanner/features/result/result_screen.dart';
import 'package:halal_scanner/features/settings/settings_screen.dart';
import 'package:halal_scanner/features/settings/usda_key_screen.dart';
import 'package:halal_scanner/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> makeState(String lang) async {
  SharedPreferences.setMockInitialValues({'language': lang});
  FlutterSecureStorage.setMockInitialValues({});
  final s = AppState();
  await s.init();
  return s;
}

/// Echte asynchrone Arbeit (Asset-Laden) außerhalb der Fake-Zeit ausführen.
Future<AppState> makeStateIn(WidgetTester tester, String lang) async =>
    (await tester.runAsync(() => makeState(lang)))!;

ScanEntry entryFor(String ingredients, AppState state) {
  final now = DateTime.now();
  final src = SourceRef(kind: SourceKind.openFoodFacts, retrievedAt: now);
  final p = ProductRecord(
    barcode: '4006381333931',
    source: src,
    name: 'Testgummi',
    brand: 'Testmarke',
    ingredientTexts: [IngredientText(text: ingredients, lang: 'de', source: src)],
  );
  return ScanEntry(
    id: '1',
    createdAt: now,
    barcode: p.barcode,
    product: p,
    verdict: state.engine.evaluate(product: p, scannedBarcode: p.barcode, now: now),
  );
}

void main() {
  testWidgets('Startbildschirm: Deutsch, Scan-Button, Navigation', (tester) async {
    final state = await makeStateIn(tester, 'de');
    await tester.pumpWidget(HalalScannerApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('Produkt scannen'), findsOneWidget);
    expect(find.text('Zutaten fotografieren'), findsOneWidget);
    expect(find.text('Verlauf'), findsWidgets);
    expect(Directionality.of(tester.element(find.text('Produkt scannen'))),
        TextDirection.ltr);

    await tester.tap(find.text('Mehr'));
    await tester.pumpAndSettle();
    expect(find.text('Sprache'), findsOneWidget);
  });

  // Startbildschirm in jeder RTL-Sprache: Text sichtbar, Richtung rechts-nach-links.
  for (final e in const {
    'ar': 'مسح منتج',
    'ur': 'پروڈکٹ اسکین کریں',
    'fa': 'اسکن محصول',
  }.entries) {
    testWidgets('${e.key} wird rechts-nach-links dargestellt', (tester) async {
      final state = await makeStateIn(tester, e.key);
      await tester.pumpWidget(HalalScannerApp(state: state));
      await tester.pumpAndSettle();
      final finder = find.text(e.value);
      expect(finder, findsOneWidget);
      expect(Directionality.of(tester.element(finder)), TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });
  }

  // Links-nach-rechts-Sprachen der Priorität 2 starten ohne Fehler.
  for (final e in const {
    'id': 'Pindai produk',
    'ms': 'Imbas produk',
    'bn': 'পণ্য স্ক্যান করুন',
    'hi': 'उत्पाद स्कैन करें',
    'ha': 'Duba kaya', // Flutter-Standardtexte über den englischen Ersatz
    'fr': 'Scanner un produit',
  }.entries) {
    testWidgets('${e.key}: Startbildschirm', (tester) async {
      final state = await makeStateIn(tester, e.key);
      await tester.pumpWidget(HalalScannerApp(state: state));
      await tester.pumpAndSettle();
      final finder = find.text(e.value);
      expect(finder, findsOneWidget);
      expect(Directionality.of(tester.element(finder)), TextDirection.ltr);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Sprachwechsel zur Laufzeit', (tester) async {
    final state = await makeStateIn(tester, 'de');
    await tester.pumpWidget(HalalScannerApp(state: state));
    await tester.pumpAndSettle();
    await tester.runAsync(() => state.setLanguage('en'));
    await tester.pumpAndSettle();
    expect(find.text('Scan product'), findsOneWidget);
  });

  testWidgets('Erster Start zeigt Sprachauswahl, geplante Sprachen gesperrt',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final state = AppState();
    await tester.runAsync(state.init);
    await tester.pumpWidget(HalalScannerApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('Deutsch'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('اردو'), 200);
    final urdu = tester.widget<ListTile>(
        find.ancestor(of: find.text('اردو'), matching: find.byType(ListTile)));
    expect(urdu.enabled, isTrue); // Priorität 2: als Entwurf wählbar
    await tester.scrollUntilVisible(find.text('简体中文'), 200);
    final zh = tester.widget<ListTile>(
        find.ancestor(of: find.text('简体中文'), matching: find.byType(ListTile)));
    expect(zh.enabled, isFalse); // Priorität 3: in Vorbereitung
  });

  testWidgets('Sprachauswahl zeigt Oberfläche und Zutatenprüfung getrennt', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'de'});
    FlutterSecureStorage.setMockInitialValues({});
    final state = AppState();
    await tester.runAsync(state.init);
    await tester.pumpWidget(AppScope(
      state: state,
      child: const MaterialApp(home: LanguagePickerScreen(firstRun: false)),
    ));
    await tester.pumpAndSettle();
    // Deutsch: vollständig übersetzt, Zutaten vollständig geprüft.
    expect(find.textContaining('werden vollständig geprüft'), findsWidgets);
    // Französisch: eingeschränkt.
    await tester.scrollUntilVisible(find.text('Français'), 200);
    expect(find.textContaining('eingeschränkt geprüft'), findsWidgets);
    // Urdu: Oberfläche als Entwurf, Zutaten nur mit Grund-Erkennung (nie Grün).
    await tester.scrollUntilVisible(find.text('اردو'), 200);
    expect(find.textContaining('nie grünes Ergebnis'), findsWidgets);
  });

  testWidgets('Statusanzeige hat Text, Symbol und Screenreader-Label', (tester) async {
    final state = await makeStateIn(tester, 'de');
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatusBadge.forStatus(HalalStatus.unclear, state.strings))));
    expect(find.text('UNKLAR'), findsOneWidget);
    expect(find.byIcon(Icons.help), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('UNKLAR')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Ergebnis HARAM zeigt Zutat, Begründung und Buttons', (tester) async {
    final state = await makeStateIn(tester, 'de');
    final entry = entryFor('Zucker, Schweinegelatine', state);
    expect(entry.verdict.status, HalalStatus.haram);
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(home: ResultScreen(entry: entry)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('HARAM'), findsOneWidget);
    expect(find.textContaining('Schweinegelatine'), findsWidgets);
    expect(find.text('Was wurde gefunden?'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Quellen und Begründung'), 200);
    expect(find.text('Zutaten anzeigen'), findsOneWidget);
  });

  testWidgets('Ergebnis UNKLAR bei Gelatine unbekannter Herkunft', (tester) async {
    final state = await makeStateIn(tester, 'de');
    final entry = entryFor('Zucker, Gelatine', state);
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(home: ResultScreen(entry: entry)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('UNKLAR'), findsOneWidget);
    expect(find.text('HALAL NACH ZUTATENPRÜFUNG'), findsNothing);
  });

  testWidgets('Barrierefreiheit: Startseite erfüllt Tap-Target-Richtlinien',
      (tester) async {
    final state = await makeStateIn(tester, 'de');
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(HalalScannerApp(state: state));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('Große Schrift (200 %) ohne Layout-Fehler', (tester) async {
    final state = await makeStateIn(tester, 'de');
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0), size: Size(360, 640)),
      child: HalalScannerApp(state: state),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('Verlauf: Speichern und Laden (offline verfügbar)', () async {
    final state = await makeState('de');
    final e = entryFor('Zucker, Aroma', state);
    final store = HistoryStore();
    await store.save([e]);
    final loaded = await store.load();
    expect(loaded.single.verdict.status, HalalStatus.unclear);
    expect(loaded.single.product!.name, 'Testgummi');
  });

  test('Sprachdateien laden über das Asset-System', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final ar = await AppStrings.load('ar');
    expect(ar.isRtl, isTrue);
    expect(ar.t('status.haram'), 'حرام');
  });

  testWidgets('Kurze Ergebnisseite: Status, Zusammenfassung und Zutat ohne Scrollen',
      (tester) async {
    final state = await makeStateIn(tester, 'de');
    // Kleines Smartphone (360 × 640 logische Pixel).
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final entry = entryFor('Zucker, Gelatine', state);
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(home: ResultScreen(entry: entry)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Testgummi'), findsOneWidget);
    expect(find.textContaining('4006381333931'), findsOneWidget);
    // Status: Farbe UND Symbol UND Text.
    expect(find.text('UNKLAR'), findsOneWidget);
    expect(find.byIcon(Icons.help), findsWidgets);
    // Wichtigste Zutat mit Begriff, Wortlaut, Einstufung und fehlender Angabe.
    expect(find.text('Das Wichtigste'), findsOneWidget);
    expect(find.text('Gelatine/Kollagen: „Gelatine“'), findsOneWidget);
    expect(find.text('noch nicht abschließend geklärt'), findsOneWidget);
    expect(find.textContaining('Es fehlt:'), findsOneWidget);
    // Status und Zusammenfassung liegen vollständig im ersten Bildschirm,
    // die wichtigsten Zutaten beginnen dort (Testschrift ist breiter als
    // echte Schriften, auf Geräten passt mehr auf den Bildschirm).
    for (final k in ['result.status', 'result.summary']) {
      expect(tester.getRect(find.byKey(ValueKey(k))).bottom, lessThanOrEqualTo(640),
          reason: k);
    }
    expect(tester.getRect(find.byKey(const ValueKey('result.keyPoints'))).top,
        lessThan(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Details sind eingeklappt und lassen sich per Antippen öffnen', (tester) async {
    final state = await makeStateIn(tester, 'de');
    final entry = entryFor('Zucker, Aroma', state);
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(home: ResultScreen(entry: entry)),
    ));
    await tester.pumpAndSettle();
    // Überschriften der Abschnitte sind sichtbar, ihr Inhalt nicht.
    expect(find.text('Details (zum Öffnen antippen)'), findsOneWidget);
    expect(find.text('Warum kein grünes Ergebnis?'), findsOneWidget);
    expect(find.text('Was wurde gefunden?'), findsOneWidget);
    expect(find.byType(InvestigationCard), findsNothing);
    expect(find.text('Was bedeutet dieses Ergebnis?'), findsNothing);
    expect(find.text('Weißt du mehr?'), findsNothing);

    // „Ausführliche Analyse“ öffnen.
    await tester.scrollUntilVisible(find.text('Ausführliche Analyse'), 200);
    await tester.tap(find.text('Ausführliche Analyse'));
    await tester.pumpAndSettle();
    expect(find.text('Was bedeutet dieses Ergebnis?'), findsOneWidget);
    // Wieder schließen.
    await tester.tap(find.text('Ausführliche Analyse'));
    await tester.pumpAndSettle();
    expect(find.text('Was bedeutet dieses Ergebnis?'), findsNothing);

    // „Was wurde gefunden?“ öffnen: Recherche-Karte und Feedback-Formular.
    await tester.scrollUntilVisible(find.text('Was wurde gefunden?'), -200);
    await tester.tap(find.text('Was wurde gefunden?'));
    await tester.pumpAndSettle();
    expect(find.byType(InvestigationCard), findsOneWidget);
    // Einzige Karte ist bereits aufgeklappt.
    await tester.scrollUntilVisible(find.text('Weißt du mehr?'), 200);
    expect(find.text('Welche Information würde die Einstufung klären?'), findsOneWidget);
    await tester.ensureVisible(find.text('Weißt du mehr?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weißt du mehr?'));
    await tester.pumpAndSettle();
    expect(find.text('Information ergänzen'), findsOneWidget);
    expect(find.text('Herstellerangabe oder Quelle einreichen'), findsOneWidget);
  });

  testWidgets('Gleiches Produkt, andere App-Sprache: gleiche Bewertung, übersetzter Begriff',
      (tester) async {
    for (final (lang, keyPoints, concept, status) in const [
      ('de', 'Das Wichtigste', 'Gelatine/Kollagen', 'UNKLAR'),
      ('en', 'Key points', 'Gelatine/collagen', 'UNCLEAR'),
    ]) {
      final state = await makeStateIn(tester, lang);
      final entry = entryFor('Zucker, Gelatine', state);
      expect(entry.verdict.status, HalalStatus.unclear, reason: lang);
      await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
            key: ValueKey(lang), home: ResultScreen(entry: entry)),
      ));
      await tester.pumpAndSettle();
      expect(find.text(status), findsOneWidget, reason: lang);
      expect(find.text(keyPoints), findsOneWidget, reason: lang);
      // Begriff in der App-Sprache, Wortlaut der Quelle unverändert.
      expect(find.text('$concept: „Gelatine“'), findsOneWidget, reason: lang);
    }
  });

  testWidgets('HARAM: verbotene Zutat steht oben, ohne Aufklappen', (tester) async {
    final state = await makeStateIn(tester, 'de');
    final entry = entryFor('Wasser, Zucker, Rotwein', state);
    expect(entry.verdict.status, HalalStatus.haram);
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(home: ResultScreen(entry: entry)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('HARAM'), findsOneWidget);
    expect(find.byIcon(Icons.block), findsWidgets);
    expect(find.textContaining('„Rotwein“'), findsWidgets);
    expect(find.text('haram'), findsOneWidget);
    expect(find.textContaining('Es fehlt:'), findsNothing);
  });

  testWidgets('NICHT VERIFIZIERT ohne Funde: kein Kasten „Das Wichtigste“', (tester) async {
    final state = await makeStateIn(tester, 'de');
    final now = DateTime.now();
    final src = SourceRef(kind: SourceKind.openFoodFacts, retrievedAt: now);
    final p = ProductRecord(barcode: '4006381333931', source: src, name: 'Ohne Zutaten');
    final entry = ScanEntry(
      id: '2',
      createdAt: now,
      barcode: p.barcode,
      product: p,
      verdict: state.engine.evaluate(product: p, scannedBarcode: p.barcode, now: now),
    );
    expect(entry.verdict.status, HalalStatus.notVerified);
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(home: ResultScreen(entry: entry)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('NICHT VERIFIZIERT'), findsOneWidget);
    expect(find.byKey(const ValueKey('result.keyPoints')), findsNothing);
    expect(find.textContaining('Keine Bewertung möglich'), findsOneWidget);
  });

  testWidgets('USDA-Schlüssel: verdeckte Eingabe, speichern, löschen', (tester) async {
    final state = await makeStateIn(tester, 'de');
    await tester.pumpWidget(AppScope(
      state: state,
      child: const MaterialApp(home: UsdaKeyScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Nicht eingerichtet – die App funktioniert auch ohne.'), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const ValueKey('usdaKey.input')));
    expect(field.obscureText, isTrue);
    expect(find.byKey(const ValueKey('usdaKey.remove')), findsNothing);

    // Ungültig
    await tester.enterText(find.byKey(const ValueKey('usdaKey.input')), 'zu kurz');
    await tester.tap(find.byKey(const ValueKey('usdaKey.save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('nicht wie ein gültiger Schlüssel'), findsOneWidget);
    expect(state.hasUsdaKey, isFalse);

    // Gültig
    await tester.enterText(
        find.byKey(const ValueKey('usdaKey.input')), 'AbCdEf0123456789AbCdEf0123456789AbCdEf01');
    await tester.tap(find.byKey(const ValueKey('usdaKey.save')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(state.hasUsdaKey, isTrue);
    expect(find.text('Eingerichtet – nur auf diesem Gerät gespeichert.'), findsOneWidget);
    // Der gespeicherte Wert wird nie angezeigt.
    expect(find.textContaining('AbCdEf0123'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('usdaKey.remove')));
    await tester.tap(find.byKey(const ValueKey('usdaKey.remove')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(state.hasUsdaKey, isFalse);
    expect(find.text('Nicht eingerichtet – die App funktioniert auch ohne.'), findsOneWidget);
  });
}
