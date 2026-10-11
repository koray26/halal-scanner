import 'package:flutter/material.dart';

import '../config.dart';
import '../core/i18n/strings.dart';
import '../data/history_store.dart';
import '../data/open_food_facts.dart';
import '../domain/models.dart';
import '../domain/rules/halal_engine.dart';

class LookupOutcome {
  LookupOutcome({this.entry, this.error, this.fromCache = false});
  final ScanEntry? entry;
  final LookupError? error;

  /// Ergebnis stammt aus dem Gerätespeicher, weil keine Verbindung bestand.
  final bool fromCache;
}

class AppState extends ChangeNotifier {
  AppState({
    OpenFoodFactsClient? off,
    HistoryStore? history,
    SettingsStore? settings,
    HalalEngine? engine,
    DateTime Function()? clock,
  })  : _off = off ?? OpenFoodFactsClient(),
        _historyStore = history ?? HistoryStore(),
        _settings = settings ?? SettingsStore(),
        engine = engine ?? HalalEngine(),
        _clock = clock ?? DateTime.now;

  final OpenFoodFactsClient _off;
  final HistoryStore _historyStore;
  final SettingsStore _settings;
  final HalalEngine engine;
  final DateTime Function() _clock;

  AppStrings? _strings;
  AppStrings get strings => _strings!;
  bool get ready => _strings != null;

  bool languageChosen = false;
  ThemeMode themeMode = ThemeMode.system;
  List<ScanEntry> history = [];

  DateTime now() => _clock();

  Future<void> init() async {
    final saved = await _settings.loadLanguage();
    languageChosen = saved != null;
    _strings = await AppStrings.load(saved ?? _deviceLanguage());
    themeMode = switch (await _settings.loadTheme()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    history = await _historyStore.load();
    notifyListeners();
  }

  String _deviceLanguage() {
    final code =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final info = appLanguages.where((l) => l.code == code && l.selectable);
    return info.isEmpty ? 'en' : code;
  }

  Future<void> setLanguage(String code) async {
    _strings = await AppStrings.load(code);
    languageChosen = true;
    await _settings.saveLanguage(code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _settings.saveTheme(mode.name);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Scans --

  ScanEntry? cachedFor(String barcode) {
    for (final e in history) {
      if (e.barcode == barcode && e.product != null) return e;
    }
    return null;
  }

  Future<LookupOutcome> lookup(String barcode) async {
    try {
      final product = await _off.fetch(barcode);
      final verdict = engine.evaluate(
          product: product, scannedBarcode: barcode, now: now());
      final entry = ScanEntry(
        id: '${now().microsecondsSinceEpoch}',
        createdAt: now(),
        barcode: barcode,
        product: product,
        verdict: verdict,
        favorite: history.any((e) => e.barcode == barcode && e.favorite),
      );
      await _upsert(entry);
      return LookupOutcome(entry: entry);
    } on LookupException catch (e) {
      final cached = cachedFor(barcode);
      if (cached != null) {
        return LookupOutcome(entry: cached, error: e.error, fromCache: true);
      }
      return LookupOutcome(error: e.error);
    }
  }

  /// Bewertet eine fotografierte oder korrigierte Zutatenliste.
  /// Der Originaldatensatz (z. B. aus Open Food Facts) bleibt unverändert.
  Future<ScanEntry> analyzeTexts(List<IngredientText> texts,
      {String? barcode, ProductRecord? product}) async {
    final verdict = engine.evaluate(
      product: product,
      scannedBarcode: product == null ? null : barcode,
      overrideTexts: texts,
      now: now(),
    );
    final entry = ScanEntry(
      id: '${now().microsecondsSinceEpoch}',
      createdAt: now(),
      barcode: barcode,
      product: product,
      analyzedTexts: texts,
      verdict: verdict,
    );
    await _upsert(entry, replaceSameBarcode: false);
    return entry;
  }

  Future<void> _upsert(ScanEntry entry, {bool replaceSameBarcode = true}) async {
    if (replaceSameBarcode && entry.barcode != null) {
      history.removeWhere(
          (e) => e.barcode == entry.barcode && e.analyzedTexts.isEmpty);
    }
    history.insert(0, entry);
    await _historyStore.save(history);
    notifyListeners();
  }

  bool isStale(ScanEntry e) =>
      now().difference(e.verdict.evaluatedAt) > AppConfig.cacheFreshFor;

  Future<void> toggleFavorite(ScanEntry e) async {
    e.favorite = !e.favorite;
    await _historyStore.save(history);
    notifyListeners();
  }

  Future<void> remove(ScanEntry e) async {
    history.removeWhere((x) => x.id == e.id);
    await _historyStore.save(history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history = history.where((e) => e.favorite).toList();
    await _historyStore.save(history);
    notifyListeners();
  }
}

/// Stellt den AppState im Widget-Baum bereit.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
