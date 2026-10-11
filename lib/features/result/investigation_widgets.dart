import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/history_store.dart';
import '../../domain/knowledge/substances.dart';
import '../../domain/research/research.dart';
import '../../domain/rules/catalog.dart';
import '../../domain/rules/halal_engine.dart';
import '../../state/app_state.dart';
import '../feedback/feedback_screen.dart';

/// Checkliste der Freigabebedingungen ("Warum dieses Ergebnis?").
class GreenChecklist extends StatelessWidget {
  const GreenChecklist({super.key, required this.verdict, required this.strings});
  final Verdict verdict;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final conds = verdict.greenConditions;
    if (conds.isEmpty) return const SizedBox.shrink();
    final green = verdict.status == HalalStatus.halalByIngredients;
    final unmet = conds.entries.where((e) => !e.value).map((e) => e.key).toList();
    return SectionCard(
      title: s.t(green ? 'green.title.met' : 'green.title.unmet'),
      icon: Icons.checklist,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.t(green ? 'green.intro.met' : 'green.intro.unmet')),
        const SizedBox(height: Gap.s),
        for (final c in (green ? conds.keys.toList() : unmet))
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(conds[c]! ? Icons.check_circle : Icons.cancel,
                  size: 20,
                  color: conds[c]! ? AppColors.halal : AppColors.notVerified,
                  semanticLabel: s.t(conds[c]! ? 'green.met' : 'green.unmet')),
              const SizedBox(width: Gap.s),
              Expanded(child: Text(s.t('green.cond.${c.name}'))),
            ]),
          ),
        if (green) ...[
          const SizedBox(height: Gap.s),
          Text(s.t('green.notGuarantee'),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

/// Detailkarte je kritischer Zutat mit Rechercheergebnis.
class InvestigationCard extends StatelessWidget {
  const InvestigationCard({
    super.key,
    required this.inv,
    required this.entry,
    required this.strings,
    this.initiallyExpanded = false,
  });

  final Investigation inv;
  final ScanEntry entry;
  final AppStrings strings;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final haram = inv.effect == RuleEffect.haram;
    final resolved = inv.resolved;
    final color = haram
        ? AppColors.haram
        : resolved
            ? AppColors.halal
            : AppColors.unclear;
    final icon = haram
        ? Icons.block
        : resolved
            ? Icons.check_circle
            : Icons.help;
    final stateKey = haram
        ? 'inv.state.haram'
        : resolved
            ? 'inv.state.resolved'
            : inv.disputed
                ? 'inv.state.disputed'
                : 'inv.state.open';

    final productEvidence =
        inv.evidence.where((e) => e.strength == EvidenceStrength.productSpecific).toList();
    final generalEvidence =
        inv.evidence.where((e) => e.strength == EvidenceStrength.general).toList();
    final ruleName = s.t('rule.${inv.ruleId}.name');

    Widget label(String k) => Padding(
          padding: const EdgeInsets.only(top: Gap.m, bottom: Gap.xs),
          child: Text(s.t(k),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: color, size: 28),
          title: Text('„${inv.originalText}“ – ${s.t(stateKey)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text([
            ruleName,
            if (inv.additiveCode != null) ltr(inv.additiveCode!),
          ].join(' · ')),
          childrenPadding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.m),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv(s.t('inv.original'), inv.ingredient),
            _kv(s.t('inv.normalized'), [
              if (inv.additiveCode != null) '${ltr(inv.additiveCode!)} – ${inv.additiveName}',
              if (inv.additiveCode == null) ruleName,
            ].join()),
            if (inv.functionClass != null)
              _kv(s.t('inv.class'), s.t('class.${inv.functionClass}')),
            label('inv.q.known'),
            Text(s.t('substance.${inv.ruleId}.identity')),
            if (inv.possibleOrigins.isNotEmpty) ...[
              const SizedBox(height: Gap.xs),
              Text(s.t('inv.possibleOrigins', {
                'list': inv.possibleOrigins.map((o) => s.t('origin.${o.name}')).join(', '),
              })),
            ],
            if (inv.questions.isNotEmpty) ...[
              label('inv.q.originCheck'),
              for (final q in inv.questions.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.xs),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(
                      q.value == QuestionState.open ? Icons.help_outline : Icons.check,
                      size: 18,
                      color: q.value == QuestionState.open ? AppColors.unclear : AppColors.halal,
                    ),
                    const SizedBox(width: Gap.s),
                    Expanded(
                        child: Text('${s.t('question.${q.key.name}')} – '
                            '${s.t('qstate.${q.value.name}')}')),
                  ]),
                ),
            ],
            label('inv.q.productEvidence'),
            if (productEvidence.isEmpty)
              Text(s.t('inv.noProductEvidence'))
            else
              ...productEvidence.map((e) => _evidenceRow(context, e)),
            if (generalEvidence.isNotEmpty) ...[
              label('inv.q.general'),
              Text(s.t('inv.generalNote'), style: theme.textTheme.bodySmall),
              const SizedBox(height: Gap.xs),
              ...generalEvidence.map((e) => _evidenceRow(context, e)),
            ],
            label('inv.q.sources'),
            ...inv.steps.map((st) => Padding(
                  padding: const EdgeInsets.only(bottom: Gap.xs),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(_stepIcon(st.outcome), size: 18, color: _stepColor(st.outcome)),
                    const SizedBox(width: Gap.s),
                    Expanded(
                        child: Text('${s.t('step.${st.kind.name}')}: '
                            '${s.t('outcome.${st.outcome.name}')}')),
                  ]),
                )),
            label('inv.q.assessment'),
            Text(inv.effect == RuleEffect.haram
                ? s.t(entry.verdict.findings
                        .any((f) => f.escalatedByPork && f.matchedText == inv.originalText)
                    ? 'rule.porkDerived.why'
                    : 'rule.${inv.ruleId}.why')
                : s.t('rule.${inv.ruleId}.why')),
            if (inv.disputed) ...[
              const SizedBox(height: Gap.xs),
              Text(s.t('inv.disputedNote'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            if (inv.labelContradiction) ...[
              const SizedBox(height: Gap.xs),
              Text(s.t('unknown.labelContradiction'),
                  style: const TextStyle(color: AppColors.notVerified, fontWeight: FontWeight.w600)),
            ],
            if (!haram && !resolved) ...[
              label('inv.q.unknown'),
              for (final q in inv.openQuestions) Text('• ${s.t('question.${q.name}')}'),
              label('inv.q.clarify'),
              for (final q in inv.openQuestions) Text('• ${s.t('clarify.${q.name}')}'),
            ],
            const SizedBox(height: Gap.s),
            Text(s.t('inv.checkedAt', {'date': formatDateTime(entry.verdict.evaluatedAt)}),
                style: theme.textTheme.bodySmall),
            const SizedBox(height: Gap.s),
            Wrap(spacing: Gap.s, runSpacing: Gap.xs, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.lightbulb_outline),
                label: Text(s.t('feedback.knowMore')),
                onPressed: () => showFeedbackSheet(context,
                    barcode: entry.barcode,
                    productName: entry.product?.name,
                    ingredient: inv.originalText),
              ),
              if (!haram && !resolved && entry.product != null)
                TextButton.icon(
                  icon: const Icon(Icons.mail_outline),
                  label: Text(s.t('inquiry.button')),
                  onPressed: () => openManufacturerInquiry(context, entry, [inv]),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.xs),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: v),
        ])),
      );

  Widget _evidenceRow(BuildContext context, Evidence e) {
    final text = strings.t('evidence.${e.key}', e.params);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('• $text'),
        if (e.url != null)
          TextButton.icon(
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, alignment: AlignmentDirectional.centerStart),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(strings.t('sources.open')),
            onPressed: () =>
                launchUrl(Uri.parse(e.url!), mode: LaunchMode.externalApplication),
          ),
      ]),
    );
  }

  static IconData _stepIcon(StepOutcome o) => switch (o) {
        StepOutcome.found => Icons.check_circle_outline,
        StepOutcome.nothingFound => Icons.radio_button_unchecked,
        StepOutcome.unavailable => Icons.cloud_off,
        StepOutcome.notPossible => Icons.remove_circle_outline,
      };

  static Color _stepColor(StepOutcome o) => switch (o) {
        StepOutcome.found => AppColors.halal,
        StepOutcome.unavailable => AppColors.unclear,
        _ => AppColors.neutral,
      };
}

final _emailRe = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');

/// Bereitet eine Anfrage an den Hersteller vor. Der Nutzer versendet sie
/// selbst aus seinem E-Mail-Programm – die App sendet nichts automatisch.
Future<void> openManufacturerInquiry(
    BuildContext context, ScanEntry entry, List<Investigation> invs) async {
  final s = AppScope.read(context).strings;
  final p = entry.product;
  final to = _emailRe.firstMatch(p?.customerService ?? '')?.group(0) ?? '';
  final questions = <String>[];
  for (final inv in invs) {
    for (final q in inv.openQuestions) {
      if (q == OriginQuestion.scholarlyDispute) continue;
      questions.add('- „${inv.originalText}“: ${s.t('inquiry.q.${q.name}')}');
    }
  }
  final body = s.t('inquiry.body', {
    'product': p?.name ?? '-',
    'brand': p?.brand ?? '-',
    'barcode': entry.barcode ?? '-',
    'questions': questions.isEmpty ? '-' : questions.join('\n'),
  });
  final uri = Uri(
    scheme: 'mailto',
    path: to,
    query: 'subject=${Uri.encodeComponent(s.t('inquiry.subject', {'product': p?.name ?? entry.barcode ?? ''}))}'
        '&body=${Uri.encodeComponent(body)}',
  );
  final ok = await launchUrl(uri);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.t('inquiry.noMailApp'))));
  }
}
