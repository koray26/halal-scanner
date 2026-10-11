// ignore_for_file: invalid_use_of_visible_for_testing_member
// Erzeugt Bildschirmfotos der wichtigsten Seiten (für die Sichtprüfung in CI).
// Ausführen: flutter test test_screens --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/app.dart';
import 'package:halal_scanner/data/history_store.dart';
import 'package:halal_scanner/domain/models.dart';
import 'package:halal_scanner/features/result/result_screen.dart';
import 'package:halal_scanner/features/result/sources_screen.dart';
import 'package:halal_scanner/features/settings/settings_screen.dart';
import 'package:halal_scanner/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final file = File('$dir/$f');
      if (file.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  }

  await family('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  await family('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

ScanEntry entry(AppState s, String name, String brand, String ingredients,
    {String code = '4006381333931', List<String> labels = const []}) {
  final now = DateTime.now();
  final src = SourceRef(
      kind: SourceKind.openFoodFacts,
      retrievedAt: now,
      url: 'https://world.openfoodfacts.org/product/$code',
      version: '1700000000');
  final p = ProductRecord(
    barcode: code,
    source: src,
    name: name,
    brand: brand,
    quantity: '200 g',
    countries: const ['en:germany'],
    labelTags: labels,
    lastModified: DateTime.utc(2025, 3, 1),
    ingredientTexts: [IngredientText(text: ingredients, lang: 'de', source: src)],
  );
  return ScanEntry(
    id: name,
    createdAt: now,
    barcode: code,
    product: p,
    verdict: s.engine.evaluate(product: p, scannedBarcode: code, now: now),
  );
}

void main() {
  late AppState state;
  late List<ScanEntry> samples;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadFonts();
  });

  Future<void> setup(WidgetTester tester, String lang) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'language': lang});
    state = AppState();
    await tester.runAsync(state.init);
    samples = [
      entry(state, 'Fruchtgummi Klassik', 'Beispielmarke',
          'Glukosesirup, Zucker, Schweinegelatine, Säuerungsmittel: Citronensäure, Aroma'),
      entry(state, 'Vollmilch-Schokolade', 'Beispielmarke',
          'Zucker, Kakaobutter, Vollmilchpulver, Kakaomasse, Emulgator: Lecithine (Soja), Aroma'),
      entry(state, 'Weizenbrötchen', 'Bäckerei Test',
          'Weizenmehl, Wasser, Hefe, Salz, Rapsöl, Emulgator (E471 pflanzlich)', code: '96385074'),
      entry(state, 'Gummibärchen Halal', 'Testmarke', 'Glukosesirup, Zucker, Rindergelatine, Citronensäure',
          labels: const ['en:halal']),
    ];
    await tester.runAsync(() async {
      for (final e in samples.reversed) {
        state.history.insert(0, e);
      }
      await HistoryStore().save(state.history);
    });
  }

  Future<void> shot(WidgetTester tester, Widget w, String name) async {
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();
    await expectLater(find.byWidget(w), matchesGoldenFile('screens/$name.png'));
  }

  testWidgets('01 Start', (tester) async {
    await setup(tester, 'de');
    await shot(tester, HalalScannerApp(state: state), '01_start');
  });

  testWidgets('02 Ergebnis HARAM', (tester) async {
    await setup(tester, 'de');
    await shot(tester, themed(state, ResultScreen(entry: samples[0])), '02_haram');
  });

  testWidgets('03 Ergebnis UNKLAR', (tester) async {
    await setup(tester, 'de');
    await shot(tester, themed(state, ResultScreen(entry: samples[1])), '03_unklar');
  });

  testWidgets('04 Ergebnis HALAL NACH ZUTATENPRÜFUNG', (tester) async {
    await setup(tester, 'de');
    await shot(tester, themed(state, ResultScreen(entry: samples[2])), '04_halal_zutaten');
  });

  testWidgets('05 Quellen', (tester) async {
    await setup(tester, 'de');
    await shot(tester, themed(state, SourcesScreen(entry: samples[0])), '05_quellen');
  });

  testWidgets('06 Einstellungen dunkel', (tester) async {
    await setup(tester, 'de');
    await tester.runAsync(() => state.setThemeMode(ThemeMode.dark));
    await shot(tester, themed(state, const SettingsScreen()), '06_einstellungen_dunkel');
  });

  testWidgets('07 Sprachauswahl', (tester) async {
    await setup(tester, 'de');
    await shot(tester, themed(state, const LanguagePickerScreen(firstRun: true)), '07_sprache');
  });

  testWidgets('08 Start Englisch dunkel', (tester) async {
    await setup(tester, 'en');
    await tester.runAsync(() => state.setThemeMode(ThemeMode.dark));
    await shot(tester, HalalScannerApp(state: state), '08_start_en_dunkel');
  });

  // Hinweis: Arabische Schrift erscheint mangels Testschriftart als Kästchen;
  // geprüft wird hier die Spiegelung des Layouts (RTL).
  testWidgets('10 Recherche-Karte Aroma (ganze Seite)', (tester) async {
    await setup(tester, 'de');
    tester.view.physicalSize = const Size(1170, 9000);
    final e = entry(state, 'Kekse', 'Beispielmarke',
        'Weizenmehl, Zucker, Palmfett, Aroma, Salz', );
    await shot(tester, themed(state, ResultScreen(entry: e)), '10_aroma_recherche');
  });

  testWidgets('11 Grün mit Checkliste (ganze Seite)', (tester) async {
    await setup(tester, 'de');
    tester.view.physicalSize = const Size(1170, 6000);
    await shot(tester, themed(state, ResultScreen(entry: samples[2])), '11_gruen_checkliste');
  });

  testWidgets('09 Ergebnis Arabisch (Layout RTL)', (tester) async {
    await setup(tester, 'ar');
    await shot(tester, themed(state, ResultScreen(entry: samples[1])), '09_ar_rtl');
  });

}

Widget themed(AppState state, Widget child) => AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => buildMaterialApp(state, child),
      ),
    );
