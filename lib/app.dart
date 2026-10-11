import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
        builder: (context, _) {
          final s = state.strings;
          return MaterialApp(
            title: s.t('app.name'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: state.themeMode,
            locale: Locale(s.code),
            supportedLocales: const [
              Locale('de'),
              Locale('en'),
              Locale('ar'),
              Locale('tr'),
            ],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            // Schreibrichtung kommt aus unserem Sprachsystem (RTL für ar/ur/fa).
            builder: (context, child) => Directionality(
              textDirection: s.direction,
              child: child!,
            ),
            home: state.languageChosen
                ? const HomeShell()
                : const LanguagePickerScreen(firstRun: true),
          );
        },
      ),
    );
  }
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
              label: s.t('nav.settings')),
        ],
      ),
    );
  }
}
