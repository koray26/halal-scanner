import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/history_store.dart';
import '../../state/app_state.dart';
import '../ocr/ocr_screen.dart';
import '../result/result_screen.dart';
import '../scanner/scanner_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onShowHistory});
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.strings;
    final theme = Theme.of(context);
    final recent = state.history.take(4).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Gap.m,
        title: Row(children: [
          const AppLogo(size: 36),
          const SizedBox(width: Gap.s + 2),
          Flexible(child: Text(s.t('app.name'), overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            tooltip: s.t('settings.language'),
            icon: const Icon(Icons.translate),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LanguagePickerScreen(firstRun: false))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, Gap.xl),
        children: [
          Text(s.t('home.greeting'),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: Gap.xs),
          Text(s.t('home.intro'), style: theme.textTheme.bodyLarge),
          const SizedBox(height: Gap.l),
          _ScanHero(onTap: () => openScanner(context), label: s.t('home.scan')),
          const SizedBox(height: Gap.m),
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(s.t('home.photo')),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const OcrScreen())),
          ),
          const SizedBox(height: Gap.xs),
          TextButton.icon(
            icon: const Icon(Icons.keyboard_outlined),
            label: Text(s.t('home.manual')),
            onPressed: () => showManualEntry(context),
          ),
          const SizedBox(height: Gap.l),
          if (recent.isEmpty)
            SectionCard(
              title: s.t('home.recent'),
              icon: Icons.history,
              child: Text(s.t('home.recent.empty')),
            )
          else ...[
            Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(s.t('home.lastScan'),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
              TextButton(onPressed: onShowHistory, child: Text(s.t('home.showAll'))),
            ]),
            const SizedBox(height: Gap.s),
            ...recent.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: Gap.s),
                  child: EntryTile(entry: e),
                )),
          ],
          const SizedBox(height: Gap.m),
          Text(s.t('home.disclaimer'),
              style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.onTap, required this.label});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: dark ? AppColors.forestDark : AppColors.forest,
        borderRadius: BorderRadius.circular(Radii.card + 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card + 4),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xl, horizontal: Gap.l),
            child: Column(children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.goldLight, width: 2),
                ),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 44),
              ),
              const SizedBox(height: Gap.m),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }
}

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry});
  final ScanEntry entry;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.strings;
    final style = StatusStyle.of(entry.verdict.status);
    final title = entry.product?.name ??
        (entry.barcode != null ? ltr(entry.barcode!) : s.t('history.photoEntry'));
    final subtitle = [
      if (entry.product?.brand != null) entry.product!.brand!,
      formatDate(entry.createdAt),
    ].join(' · ');
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.xs),
        leading: Icon(style.icon, color: style.color, size: 30),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${s.t(style.labelKey)}\n$subtitle'),
        isThreeLine: true,
        trailing: entry.favorite
            ? Icon(Icons.star, color: Theme.of(context).colorScheme.secondary,
                semanticLabel: s.t('result.favorite.on'))
            : null,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ResultScreen(entry: entry, fromHistory: true))),
      ),
    );
  }
}
