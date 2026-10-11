import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/i18n/fallback_localizations.dart';
import 'core/i18n/strings.dart';
import 'core/theme/app_theme.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/scanner/scanner_screen.dart';
import 'features/settings/settings_screen.dart';
import 'state/app_state.dart';

class HalalScannerApp extends StatelessWidget {
  const HalalScannerApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => buildMaterialApp(
          state,
          state.languageChosen
              ? const HomeShell()
              : const LanguagePickerScreen(firstRun: true),
        ),
      ),
    );
  }
}

/// MaterialApp mit Thema, Sprache und Schreibrichtung aus dem AppState.
Widget buildMaterialApp(AppState state, Widget home) {
  final s = state.strings;
  return MaterialApp(
    title: s.t('app.name'),
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: state.themeMode,
    locale: languageInfo(s.code).locale,
    supportedLocales: [
      for (final l in appLanguages.where((l) => l.selectable)) l.locale,
    ],
    // Für Sprachen ohne eingebaute Flutter-Texte (z. B. Hausa) liefern die
    // Ersatz-Delegates englische Standardtexte für Bedienelemente
    // (Tooltips wie „Zurück“). Alle sichtbaren App-Texte kommen weiterhin
    // aus assets/i18n.
    localizationsDelegates: const [
      ...GlobalMaterialLocalizations.delegates,
      FallbackMaterialLocalizationsDelegate(),
      FallbackCupertinoLocalizationsDelegate(),
      FallbackWidgetsLocalizationsDelegate(),
    ],
    // Schreibrichtung kommt aus unserem Sprachsystem (RTL für ar/ur/fa).
    builder: (context, child) => Directionality(
      textDirection: s.direction,
      child: child!,
    ),
    home: home,
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int i) {
    if (i == 1) {
      openScanner(context);
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    final pages = [
      HomeScreen(onShowHistory: () => setState(() => _index = 2)),
      const SizedBox.shrink(),
      const HistoryScreen(favoritesOnly: false),
      const HistoryScreen(favoritesOnly: true),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: s.t('nav.home')),
          NavigationDestination(
              icon: const Icon(Icons.qr_code_scanner),
              label: s.t('nav.scan')),
          NavigationDestination(
              icon: const Icon(Icons.history),
              label: s.t('nav.history')),
          NavigationDestination(
              icon: const Icon(Icons.star_outline),
              selectedIcon: const Icon(Icons.star),
              label: s.t('nav.favorites')),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: s.t('nav.more'),
              tooltip: s.t('nav.settings')),
        ],
      ),
    );
  }
}
