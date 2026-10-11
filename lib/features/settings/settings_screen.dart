import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/rules/catalog.dart';
import '../../state/app_state.dart';
import '../feedback/feedback_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.strings;
    final lang = languageInfo(s.code);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('nav.settings'))),
      body: ListView(
        padding: const EdgeInsets.all(Gap.m),
        children: [
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: Gap.s),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(s.t('settings.language')),
                subtitle: Text(lang.nativeName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LanguagePickerScreen(firstRun: false))),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(s.t('settings.theme')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.s),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: ThemeMode.system, label: Text(s.t('settings.theme.system'))),
                      ButtonSegment(value: ThemeMode.light, label: Text(s.t('settings.theme.light'))),
                      ButtonSegment(value: ThemeMode.dark, label: Text(s.t('settings.theme.dark'))),
                    ],
                    selected: {state.themeMode},
                    onSelectionChanged: (v) => state.setThemeMode(v.first),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: Gap.m),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: Gap.s),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.rule),
                title: Text(s.t('settings.rules')),
                subtitle: Text(s.t('settings.rules.sub', {'version': ltr(rulesetVersion)})),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openInfo(context, 'info.rules'),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(s.t('settings.privacy')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openInfo(context, 'info.privacy'),
              ),
              ListTile(
                leading: const Icon(Icons.dataset_outlined),
                title: Text(s.t('settings.sources')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openInfo(context, 'info.sources'),
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(s.t('feedback.list.title')),
                subtitle: Text(s.t('feedback.list.sub', {'count': state.feedback.length})),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FeedbackScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: Text(s.t('settings.feedback')),
                subtitle: Text(s.t('settings.feedback.sub')),
                onTap: () => launchUrl(
                    Uri.parse('https://github.com/koray26/halal-scanner/issues/new'),
                    mode: LaunchMode.externalApplication),
              ),
              if (AppConfig.hasContactEmail)
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(s.t('settings.contact')),
                  subtitle: const Text(AppConfig.contactEmail),
                  onTap: () => launchUrl(Uri(scheme: 'mailto', path: AppConfig.contactEmail)),
                ),
            ]),
          ),
          const SizedBox(height: Gap.m),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: Gap.s),
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.haram),
              title: Text(s.t('settings.clearHistory')),
              subtitle: Text(s.t('settings.clearHistory.sub')),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(s.t('settings.clearHistory')),
                    content: Text(s.t('settings.clearHistory.confirm')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('common.cancel'))),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('common.delete'))),
                    ],
                  ),
                );
                if (ok == true) await state.clearHistory();
              },
            ),
          ),
          const SizedBox(height: Gap.l),
          Center(child: Text('${s.t('app.name')} ${ltr(AppConfig.appVersion)}',
              style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }

  void _openInfo(BuildContext context, String key) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => InfoScreen(keyPrefix: key)));
  }
}

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.keyPrefix});
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('$keyPrefix.title'))),
      body: ListView(
        padding: const EdgeInsets.all(Gap.m),
        children: [
          SelectableText(s.t('$keyPrefix.body'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class LanguagePickerScreen extends StatelessWidget {
  const LanguagePickerScreen({super.key, required this.firstRun});
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.strings;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: firstRun ? null : AppBar(title: Text(s.t('settings.language'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            if (firstRun) ...[
              const SizedBox(height: Gap.l),
              const Center(child: AppLogo(size: 72)),
              const SizedBox(height: Gap.m),
              Text(s.t('app.name'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: Gap.s),
              Text(s.t('language.choose'), textAlign: TextAlign.center),
              const SizedBox(height: Gap.l),
            ],
            for (final l in appLanguages)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.xs),
                child: Card(
                  child: ListTile(
                    enabled: l.selectable,
                    title: Text(l.nativeName,
                        textDirection: l.rtl ? TextDirection.rtl : TextDirection.ltr,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(s.t('language.status.${l.status.name}') +
                        (l.note != null ? ' · ${l.note}' : '')),
                    trailing: l.code == s.code && !firstRun
                        ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                        : null,
                    onTap: !l.selectable
                        ? null
                        : () async {
                            await state.setLanguage(l.code);
                            if (!firstRun && context.mounted) Navigator.of(context).pop();
                          },
                  ),
                ),
              ),
            const SizedBox(height: Gap.s),
            Text(s.t('language.note'), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
