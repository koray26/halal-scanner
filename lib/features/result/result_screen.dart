import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/history_store.dart';
import '../../data/open_food_facts.dart';
import '../../domain/models.dart';
import '../../domain/research/research.dart';
import '../../domain/rules/catalog.dart';
import '../../domain/rules/halal_engine.dart';
import '../../state/app_state.dart';
import '../feedback/feedback_screen.dart';
import '../ocr/ocr_screen.dart';
import 'dimensions_card.dart';
import 'ingredients_screen.dart';
import 'investigation_widgets.dart';
import 'sources_screen.dart';

/// Bausteine des Berichts – beantwortet die fünf Pflichtfragen.
class Report {
  Report(this.v, this.s);
  final Verdict v;
  final AppStrings s;

  String findingName(Finding f) => f.escalatedByPork
      ? s.t('rule.porkDerived.name', {'item': s.t('rule.${f.ruleId}.name')})
      : s.t('rule.${f.ruleId}.name');

  String _items(List<Finding> fs) {
    final names = <String>[];
    for (final f in fs) {
      final n = '„${f.matchedText}“';
      if (!names.contains(n)) names.add(n);
    }
    return names.take(4).join(', ');
  }

  String summary() {
    final body = switch (v.status) {
      HalalStatus.haram => s.t('report.summary.haram', {'items': _items(v.haramFindings)}),
      HalalStatus.unclear =>
        s.t('report.summary.unclear', {'items': _items(v.unclearFindings)}),
      HalalStatus.halalByIngredients =>
        s.t('report.summary.halalByIngredients', {'count': v.checkedIngredientCount}),
      HalalStatus.halalCertified => s.t('report.summary.halalCertified',
          {'certifier': v.validCertification?.certifier ?? '-'}),
      HalalStatus.notVerified => s.t('report.summary.notVerified', {
          'reason': v.unknowns.isEmpty
              ? ''
              : s.t('unknown.${_primaryUnknown().name}'),
        }),
    };
    return body;
  }

  UnknownReason _primaryUnknown() {
    const order = [
      UnknownReason.productNotFound,
      UnknownReason.identityMismatch,
      UnknownReason.conflictingSources,
      UnknownReason.languageNotSupported,
      UnknownReason.languageLimited,
      UnknownReason.noIngredients,
      UnknownReason.notIdentifiedPhotoOnly,
      UnknownReason.possiblyTruncated,
      UnknownReason.compositeUnspecified,
      UnknownReason.uncertainOcrText,
      UnknownReason.ingredientsIncomplete,
      UnknownReason.userEditedText,
      UnknownReason.identityWeak,
    ];
    for (final r in order) {
      if (v.unknowns.contains(r)) return r;
    }
    return v.unknowns.first;
  }

  List<Finding> get relevant => [...v.haramFindings, ...v.unclearFindings];

  List<String> whyTexts() {
    final out = <String>[];
    for (final f in relevant) {
      final t = f.escalatedByPork
          ? s.t('rule.porkDerived.why')
          : s.t('rule.${f.ruleId}.why');
      if (!out.contains(t)) out.add(t);
    }
    return out;
  }

  List<String> unknownTexts() {
    final out = v.unknowns.map((u) => s.t('unknown.${u.name}')).toList();
    if (v.labelHalalUnverified) out.add(s.t('report.labelUnverified'));
    if (v.tracesText != null) out.add(s.t('report.traces', {'text': v.tracesText}));
    return out;
  }
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.entry, this.offlineError, this.fromHistory = false});
  final ScanEntry entry;
  final LookupError? offlineError;
  final bool fromHistory;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late ScanEntry entry = widget.entry;
  late LookupError? offlineError = widget.offlineError;
  bool _revalidating = false;

  Future<void> _revalidate() async {
    final code = entry.barcode;
    if (code == null) return;
    setState(() => _revalidating = true);
    final o = await AppScope.read(context).lookup(code);
    if (!mounted) return;
    setState(() {
      _revalidating = false;
      if (o.entry != null && !o.fromCache) {
        entry = o.entry!;
        offlineError = null;
      } else {
        offlineError = o.error;
      }
    });
    if (o.fromCache || o.entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppScope.read(context).strings.t('result.revalidate.failed'))));
    }
  }

  Future<void> _report() async {
    final s = AppScope.read(context).strings;
    final code = entry.barcode;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.m),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.t('report.issue.title'), style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: Gap.s),
            Text(s.t('report.issue.body')),
            const SizedBox(height: Gap.m),
            if (code != null)
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: Text(s.t('report.issue.off')),
                onPressed: () => launchUrl(
                    Uri.parse('${AppConfig.offBaseUrl}/product/$code'),
                    mode: LaunchMode.externalApplication),
              ),
            const SizedBox(height: Gap.s),
            OutlinedButton.icon(
              icon: const Icon(Icons.bug_report_outlined),
              label: Text(s.t('report.issue.app')),
              onPressed: () => launchUrl(
                  Uri.parse('https://github.com/koray26/halal-scanner/issues/new'
                      '?title=${Uri.encodeComponent('Produktdaten ${code ?? ''}')}'
                      '&body=${Uri.encodeComponent('Barcode: ${code ?? '-'}\nRegelversion: ${entry.verdict.rulesetVersion}\nErgebnis: ${entry.verdict.status.name}\n\nWas ist falsch?\n')}'),
                  mode: LaunchMode.externalApplication),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.strings;
    final theme = Theme.of(context);
    final v = entry.verdict;
    final p = entry.product;
    final r = Report(v, s);
    final style = StatusStyle.of(v.status);
    final stale = offlineError != null || state.isStale(entry);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('result.title')),
        actions: [
          IconButton(
            tooltip: s.t(entry.favorite ? 'result.favorite.on' : 'result.favorite.off'),
            icon: Icon(entry.favorite ? Icons.star : Icons.star_outline),
            onPressed: () async {
              await state.toggleFavorite(entry);
              setState(() {});
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, Gap.xl),
        children: [
          if (stale)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.m),
              child: MaterialBanner(
                padding: const EdgeInsets.all(Gap.m),
                leading: const Icon(Icons.cloud_off),
                content: Text(s.t('result.stale', {'date': formatDateTime(v.evaluatedAt)})),
                actions: [
                  if (entry.barcode != null)
                    TextButton(
                        onPressed: _revalidating ? null : _revalidate,
                        child: Text(s.t('result.revalidate'))),
                ],
              ),
            ),
          _ProductHeader(entry: entry, strings: s),
          const SizedBox(height: Gap.m),
          Card(
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 6, color: style.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.m),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      StatusBadge(style: style, strings: s, large: true),
                      const SizedBox(height: Gap.m),
                      Text(r.summary(),
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: Gap.s),
                      Text(s.t(style.meaningKey), style: theme.textTheme.bodyMedium),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: Gap.m),
          GreenChecklist(verdict: v, strings: s),
          const SizedBox(height: Gap.m),
          Semantics(
            header: true,
            child: Text(s.t('report.q.found'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: Gap.xs),
          if (v.investigations.isEmpty)
            Text(s.t(v.findings.isEmpty && v.checkedIngredientCount == 0
                ? 'report.found.nothingChecked'
                : 'report.found.none'))
          else ...[
            Text(s.t('inv.intro'), style: theme.textTheme.bodySmall),
            const SizedBox(height: Gap.s),
            for (final inv in _sorted(v.investigations))
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: InvestigationCard(
                  inv: inv,
                  entry: entry,
                  strings: s,
                  initiallyExpanded: v.investigations.length == 1,
                ),
              ),
          ],
          if (v.investigations.any((i) => i.effect == RuleEffect.unclear && !i.resolved && !i.disputed) &&
              entry.product != null) ...[
            const SizedBox(height: Gap.xs),
            OutlinedButton.icon(
              icon: const Icon(Icons.mail_outline),
              label: Text(s.t('inquiry.buttonAll')),
              onPressed: () => openManufacturerInquiry(context, entry,
                  v.investigations.where((i) => i.effect == RuleEffect.unclear && !i.resolved).toList()),
            ),
          ],
          const SizedBox(height: Gap.m),
          DimensionsCard(verdict: v, strings: s),
          const SizedBox(height: Gap.l),
          Semantics(
            header: true,
            child: Text(s.t('report.details'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: Gap.s),
          if (r.whyTexts().isNotEmpty) ...[
            const SizedBox(height: Gap.m),
            SectionCard(
              title: s.t('report.q.why'),
              icon: Icons.lightbulb_outline,
              child: _Bullets(r.whyTexts()),
            ),
          ],
          const SizedBox(height: Gap.m),
          SectionCard(
            title: s.t('report.q.evidence'),
            icon: Icons.fact_check_outlined,
            child: Text(_evidenceText(s, entry)),
          ),
          if (r.unknownTexts().isNotEmpty) ...[
            const SizedBox(height: Gap.m),
            SectionCard(
              title: s.t('report.q.unknown'),
              icon: Icons.help_outline,
              child: _Bullets(r.unknownTexts()),
            ),
          ],
          if (v.infoFindings.isNotEmpty) ...[
            const SizedBox(height: Gap.m),
            SectionCard(
              title: s.t('report.resolved'),
              icon: Icons.info_outline,
              child: _Bullets([
                ...v.infoFindings.map((f) =>
                    '„${f.matchedText}“: ${s.t('rule.${f.ruleId}.why')}'),
              ]),
            ),
          ],
          const SizedBox(height: Gap.m),
          SectionCard(
            title: s.t('report.q.certainty'),
            icon: Icons.balance,
            child: Text(s.t('certainty.${v.certainty.name}')),
          ),
          const SizedBox(height: Gap.m),
          ProductFeedbackSection(barcode: entry.barcode, productName: p?.name),
          const SizedBox(height: Gap.l),
          FilledButton.icon(
            icon: const Icon(Icons.list_alt),
            label: Text(s.t('result.showIngredients')),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => IngredientsScreen(entry: entry))),
          ),
          const SizedBox(height: Gap.s),
          OutlinedButton.icon(
            icon: const Icon(Icons.source_outlined),
            label: Text(s.t('result.sources')),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SourcesScreen(entry: entry))),
          ),
          if (v.status == HalalStatus.notVerified || v.status == HalalStatus.unclear) ...[
            const SizedBox(height: Gap.s),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(s.t('home.photo')),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OcrScreen(barcode: entry.barcode, product: p))),
            ),
          ],
          if (entry.barcode != null) ...[
            const SizedBox(height: Gap.s),
            OutlinedButton.icon(
              icon: _revalidating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(s.t('result.revalidate')),
              onPressed: _revalidating ? null : _revalidate,
            ),
          ],
          const SizedBox(height: Gap.s),
          TextButton.icon(
            icon: const Icon(Icons.flag_outlined),
            label: Text(s.t('result.reportIssue')),
            onPressed: _report,
          ),
          const SizedBox(height: Gap.m),
          Text(s.t('result.disclaimer', {'version': ltr(rulesetVersion)}),
              style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  static List<Investigation> _sorted(List<Investigation> list) {
    int rank(Investigation i) => i.effect == RuleEffect.haram
        ? 0
        : i.resolved
            ? 2
            : 1;
    final out = [...list]..sort((a, b) => rank(a).compareTo(rank(b)));
    return out;
  }

  String _evidenceText(AppStrings s, ScanEntry e) {
    final v = e.verdict;
    final parts = <String>[];
    final p = e.product;
    if (p != null) {
      if (p.source.kind == SourceKind.usdaFdc) {
        parts.add(s.t('evidence.fdc', {
          'date': formatDate(p.source.retrievedAt),
          'published': p.source.version ?? '-',
        }));
      } else {
        parts.add(s.t('evidence.off', {
          'date': formatDate(p.source.retrievedAt),
          'modified': p.lastModified == null ? '-' : formatDate(p.lastModified!),
        }));
        final fdc = p.ingredientTexts
            .where((t) => t.source.kind == SourceKind.usdaFdc)
            .firstOrNull;
        if (fdc != null) {
          parts.add(s.t('evidence.fdcIngredients', {
            'date': formatDate(fdc.source.retrievedAt),
            'published': fdc.source.version ?? '-',
          }));
        }
      }
    }
    if (e.analyzedTexts.isNotEmpty) {
      final kind = e.analyzedTexts.first.source.kind;
      parts.add(s.t(kind == SourceKind.userEdited ? 'evidence.userEdited' : 'evidence.ocr'));
    }
    if (v.validCertification != null) {
      parts.add(s.t('evidence.cert', {'certifier': v.validCertification!.certifier}));
    }
    if (parts.isEmpty) parts.add(s.t('evidence.none'));
    parts.add(s.t('evidence.rules', {
      'version': ltr(v.rulesetVersion),
      'date': formatDateTime(v.evaluatedAt),
    }));
    return parts.join('\n\n');
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.entry, required this.strings});
  final ScanEntry entry;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final p = entry.product;
    final theme = Theme.of(context);
    final s = strings;
    final name = p?.nameFor(s.code);
    // Die Marke ersetzt den fehlenden Namen nur in der Anzeige.
    final brandAsTitle = p != null && name == null && p.brand != null;
    final title = name ??
        (p == null
            ? s.t(entry.barcode == null ? 'history.photoEntry' : 'result.unknownProduct')
            : p.brand ?? s.t('result.unnamedProduct'));
    final subtitle = [if (!brandAsTitle) p?.brand, p?.quantity].whereType<String>();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 88,
          height: 88,
          color: theme.colorScheme.surfaceContainerHighest,
          child: p?.imageUrl != null
              ? Image.network(
                  p!.imageUrl!,
                  fit: BoxFit.cover,
                  semanticLabel: s.t('result.image'),
                  errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined),
                )
              : Icon(entry.barcode == null ? Icons.photo_camera_outlined : Icons.inventory_2_outlined, size: 36),
        ),
      ),
      const SizedBox(width: Gap.m),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (p != null && name == null)
            Text(s.t('result.nameMissing'), style: theme.textTheme.bodyMedium),
          if (subtitle.isNotEmpty)
            Text(subtitle.join(' · '), style: theme.textTheme.bodyLarge),
          if (entry.barcode != null) ...[
            const SizedBox(height: Gap.xs),
            Text('${s.t('result.barcode')}: ${ltr(entry.barcode!)}',
                style: theme.textTheme.bodyMedium),
          ],
          if (p != null && p.countries.isNotEmpty)
            Text('${s.t('result.countries')}: ${p.countries.map(_country).take(4).join(', ')}',
                style: theme.textTheme.bodySmall),
        ]),
      ),
    ]);
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);
  final List<String> items;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: Gap.xs + 2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('•  '),
                    Expanded(child: Text(t)),
                  ]),
                ))
            .toList(),
      );
}

String _country(String tag) {
  final c = tag.split(':').last.replaceAll('-', ' ');
  return c.isEmpty ? c : c[0].toUpperCase() + c.substring(1);
}
