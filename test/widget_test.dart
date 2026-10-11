import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/app.dart';
import 'package:halal_scanner/core/i18n/strings.dart';
import 'package:halal_scanner/core/widgets/widgets.dart';
import 'package:halal_scanner/data/history_store.dart';
import 'package:halal_scanner/domain/models.dart';
import 'package:halal_scanner/domain/rules/halal_engine.dart';
import 'package:halal_scanner/features/result/result_screen.dart';
import 'package:halal_scanner/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> makeState(String lang) async {
  SharedPreferences.setMockInitialValues({'language': lang});
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

  testWidgets('Arabisch wird rechts-nach-links dargestellt', (tester) async {
    final state = await makeStateIn(tester, 'ar');
    await tester.pumpWidget(HalalScannerApp(state: state));
    await tester.pumpAndSettle();
    final finder = find.text('مسح منتج');
    expect(finder, findsOneWidget);
    expect(Directionality.of(tester.element(finder)), TextDirection.rtl);
  });

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
    final state = AppState();
    await tester.runAsync(state.init);
    await tester.pumpWidget(HalalScannerApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('Deutsch'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('اردو'), 200);
    final urdu = tester.widget<ListTile>(
        find.ancestor(of: find.text('اردو'), matching: find.byType(ListTile)));
    expect(urdu.enabled, isFalse);
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
}
