import 'package:flutter/material.dart';

import '../config.dart';
import '../core/i18n/strings.dart';
import '../data/feedback_store.dart';
import '../data/history_store.dart';
import '../data/off_search.dart';
import '../data/open_food_facts.dart';
import '../data/usda_fdc.dart';
import '../domain/models.dart';
import '../domain/research/research.dart';
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
    OffTaxonomyClient? taxonomy,
    UsdaFdcClient? fdc,
    OffSearchClient? productSearch,
    HistoryStore? history,
    SettingsStore? settings,
    FeedbackStore? feedbackStore,
    HalalEngine? engine,
    DateTime Function()? clock,
  })  : _off = off ?? OpenFoodFactsClient(),
        _taxonomy = taxonomy ?? OffTaxonomyClient(),
        _fdc = fdc ?? UsdaFdcClient(),
        productSearch = productSearch ?? OffSearchClient(),
        _historyStore = history ?? HistoryStore(),
        _settings = settings ?? SettingsStore(),
        _feedbackStore = feedbackStore ?? FeedbackStore(),
        engine = engine ?? HalalEngine(),
        _clock = clock ?? DateTime.now;

  final OpenFoodFactsClient _off;
  final OffTaxonomyClient _taxonomy;
  final UsdaFdcClient _fdc;

  /// Suche nach Produktname/Marke (Open Food Facts).
  final OffSearchClient productSearch;
  final FeedbackStore _feedbackStore;
  List<FeedbackEntry> feedback = [];
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
    feedback = await _feedbackStore.load();
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

  /// Fragt Open Food Facts ab und – nur wenn dort kein Produkt oder keine
  /// Zutatenliste vorliegt – USDA FoodData Central (exakt gleiche GTIN).
  /// Ist Open Food Facts nicht erreichbar, gilt das bisherige Verhalten:
  /// gespeichertes Ergebnis mit Warnhinweis oder Fehlermeldung.
  Future<LookupOutcome> lookup(String barcode) async {
    try {
      var product = await _off.fetch(barcode);
      final checks = <SourceCheck>[
        SourceCheck(SourceKind.openFoodFacts,
            product == null ? SourceCheckStatus.notFound : SourceCheckStatus.found,
            checkedAt: now()),
      ];
      if (product != null && product.ingredientTexts.isNotEmpty) {
        checks.add(const SourceCheck(SourceKind.usdaFdc, SourceCheckStatus.skipped));
      } else if (!_fdc.isConfigured) {
        checks.add(const SourceCheck(SourceKind.usdaFdc, SourceCheckStatus.notConfigured));
      } else {
        try {
          final fdc = await _fdc.fetchByGtin(barcode);
          checks.add(SourceCheck(SourceKind.usdaFdc,
              fdc == null ? SourceCheckStatus.notFound : SourceCheckStatus.found,
              checkedAt: now()));
          product = mergeProductSources(product, fdc);
        } on LookupException {
          checks.add(SourceCheck(SourceKind.usdaFdc, SourceCheckStatus.unavailable,
              checkedAt: now()));
        }
      }
      final verdict = await evaluateWithResearch(
          product: product, scannedBarcode: barcode);
      final entry = ScanEntry(
        id: '${now().microsecondsSinceEpoch}',
        createdAt: now(),
        barcode: barcode,
        product: product,
        verdict: verdict,
        sourceChecks: checks,
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
    final verdict = await evaluateWithResearch(
      product: product,
      scannedBarcode: product == null ? null : barcode,
      overrideTexts: texts,
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

  /// Bewertung in zwei Durchgängen: zuerst offline, dann – falls kritische
  /// Zutaten offen sind – mit allgemeinen Stoffinformationen aus der
  /// Open-Food-Facts-Taxonomie. Ist die Quelle nicht erreichbar, wird das im
  /// Bericht als "nicht erreichbar" ausgewiesen (keine vorgetäuschte Recherche).
  Future<Verdict> evaluateWithResearch({
    required ProductRecord? product,
    String? scannedBarcode,
    List<IngredientText>? overrideTexts,
  }) async {
    final first = engine.evaluate(
      product: product,
      scannedBarcode: scannedBarcode,
      overrideTexts: overrideTexts,
      now: now(),
    );
    final ids = <String>{
      for (final inv in first.investigations)
        for (final step in inv.steps)
          if (step.kind == StepKind.taxonomy && step.detail['id'] != null)
            step.detail['id']!,
    };
    if (ids.isEmpty) return first;
    ResearchContext ctx;
    try {
      final tax = await _taxonomy.fetch(ids);
      ctx = ResearchContext(
          product: product, taxonomy: tax, taxonomyStatus: OnlineSourceStatus.ok);
    } catch (_) {
      // Offline, Zeitüberschreitung, Limit oder fehlerhafte Antwort.
      ctx = ResearchContext(
          product: product, taxonomyStatus: OnlineSourceStatus.unavailable);
    }
    return engine.evaluate(
      product: product,
      scannedBarcode: scannedBarcode,
      overrideTexts: overrideTexts,
      research: ctx,
      now: now(),
    );
  }

  // ------------------------------------------------------------- Feedback --

  Future<FeedbackEntry> addFeedback({
    required FeedbackKind kind,
    required String text,
    String? barcode,
    String? productName,
    String? ingredient,
    String? sourceUrl,
  }) async {
    final e = FeedbackEntry(
      id: '${now().microsecondsSinceEpoch}',
      createdAt: now(),
      kind: kind,
      text: text.trim(),
      barcode: barcode,
      productName: productName,
      ingredient: ingredient,
      sourceUrl: (sourceUrl ?? '').trim().isEmpty ? null : sourceUrl!.trim(),
    );
    feedback = [e, ...feedback];
    await _feedbackStore.save(feedback);
    notifyListeners();
    return e;
  }

  Future<void> removeFeedback(FeedbackEntry e) async {
    feedback = feedback.where((x) => x.id != e.id).toList();
    await _feedbackStore.save(feedback);
    notifyListeners();
  }

  List<FeedbackEntry> feedbackFor(String? barcode) => barcode == null
      ? const []
      : feedback.where((f) => f.barcode == barcode).toList();

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
