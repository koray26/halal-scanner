import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/history_store.dart';
import '../../domain/models.dart';
import '../../domain/rules/halal_engine.dart';
import '../../state/app_state.dart';
import 'result_screen.dart';

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key, required this.entry});
  final ScanEntry entry;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    final v = entry.verdict;
    final r = Report(v, s);
    final sources = <SourceRef>[
      if (entry.product != null) entry.product!.source,
      ...entry.analyzedTexts.map((t) => t.source),
      if (v.validCertification != null) v.validCertification!.source,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.t('result.sources'))),
      body: ListView(
        padding: const EdgeInsets.all(Gap.m),
        children: [
          SectionCard(
            title: s.t('sources.used'),
            icon: Icons.source_outlined,
            child: sources.isEmpty
                ? Text(s.t('evidence.none'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sources.map((src) => Padding(
                          padding: const EdgeInsets.only(bottom: Gap.m),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.t('ingredients.source.${src.kind.name}'),
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(s.t('sources.retrieved', {'date': formatDateTime(src.retrievedAt)})),
                            if (src.version != null)
                              Text(s.t('sources.version', {'version': _version(src.version!)})),
                            if (src.kind == SourceKind.openFoodFacts) Text(s.t('sources.offLicense')),
                            if (src.url != null)
                              TextButton.icon(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: Text(s.t('sources.open')),
                                onPressed: () => launchUrl(Uri.parse(src.url!),
                                    mode: LaunchMode.externalApplication),
                              ),
                          ]),
                        )).toList(),
                  ),
          ),
          const SizedBox(height: Gap.m),
          SectionCard(
            title: s.t('sources.reasoning'),
            icon: Icons.rule,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.t('sources.decision.${v.status.name}')),
              const SizedBox(height: Gap.s),
              ...v.findings.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: Gap.s),
                    child: Text(
                      '• ${r.findingName(f)}: „${f.matchedText}“ – '
                      '${f.isResolved ? s.t('effect.resolved') : s.t('effect.${f.effect.name}')}'
                      '${f.isResolved ? ' (${resolutionText(s, f)})' : ''}',
                    ),
                  )),
            ]),
          ),
          const SizedBox(height: Gap.m),
          SectionCard(
            title: s.t('sources.rules'),
            icon: Icons.gavel_outlined,
            child: Text(s.t('sources.rulesBody', {
              'version': ltr(v.rulesetVersion),
              'date': formatDateTime(v.evaluatedAt),
            })),
          ),
          const SizedBox(height: Gap.m),
          SectionCard(
            title: s.t('sources.limits'),
            icon: Icons.warning_amber_outlined,
            child: Text(s.t('sources.limitsBody')),
          ),
        ],
      ),
    );
  }
}

/// Open Food Facts liefert den Datenstand als Unix-Zeitstempel.
String _version(String v) {
  final secs = int.tryParse(v);
  if (secs == null || secs < 1000000000) return ltr(v);
  return formatDateTime(DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true));
}

/// Lesbarer Grund, warum eine Unklarheit aufgelöst wurde.
String resolutionText(AppStrings s, Finding f) {
  final keys = f.resolutionKeys.isNotEmpty
      ? f.resolutionKeys
      : [if (f.resolvedBy != null) 'qualifier.${f.resolvedBy!.name}'];
  return keys.map((k) => s.t('resolution.$k')).join('; ');
}
