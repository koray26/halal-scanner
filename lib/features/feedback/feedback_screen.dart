import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/feedback_store.dart';
import '../../state/app_state.dart';

/// Formular "Weißt du mehr?" – speichert einen unbestätigten Hinweis lokal.
Future<void> showFeedbackSheet(
  BuildContext context, {
  String? barcode,
  String? productName,
  String? ingredient,
  FeedbackKind initialKind = FeedbackKind.ingredientInfo,
}) async {
  final state = AppScope.read(context);
  final s = state.strings;
  final text = TextEditingController();
  final url = TextEditingController();
  var kind = initialKind;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
            Gap.m, 0, Gap.m, MediaQuery.of(ctx).viewInsets.bottom + Gap.m),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.t('feedback.title'), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: Gap.xs),
              Text(s.t('feedback.intro')),
              if (ingredient != null) ...[
                const SizedBox(height: Gap.s),
                Text(s.t('feedback.forIngredient', {'ingredient': ingredient}),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: Gap.s),
              Wrap(
                spacing: Gap.s,
                runSpacing: Gap.xs,
                children: FeedbackKind.values
                    .map((k) => ChoiceChip(
                          label: Text(s.t('feedback.kind.${k.name}')),
                          selected: kind == k,
                          onSelected: (_) => setState(() => kind = k),
                        ))
                    .toList(),
              ),
              const SizedBox(height: Gap.s),
              TextField(
                controller: text,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(labelText: s.t('feedback.text')),
              ),
              const SizedBox(height: Gap.s),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: s.t('feedback.url')),
              ),
              const SizedBox(height: Gap.s),
              Text(s.t('feedback.rules'), style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: Gap.m),
              FilledButton(
                onPressed: () {
                  if (text.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: Text(s.t('feedback.save')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (saved != true) return;
  await state.addFeedback(
    kind: kind,
    text: text.text,
    barcode: barcode,
    productName: productName,
    ingredient: ingredient,
    sourceUrl: url.text,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.t('feedback.saved'))));
  }
}

/// Liste der eigenen (unbestätigten) Hinweise mit Export.
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.strings;
    final items = state.feedback;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('feedback.list.title'))),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.lightbulb_outline,
              title: s.t('feedback.list.empty.title'),
              message: s.t('feedback.list.empty.body'),
            )
          : ListView(
              padding: const EdgeInsets.all(Gap.m),
              children: [
                Text(s.t('feedback.list.note'),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Gap.m),
                for (final f in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.s),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.pending_outlined),
                        title: Text(s.t('feedback.kind.${f.kind.name}'),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text([
                          if (f.productName != null || f.barcode != null)
                            '${f.productName ?? ''} ${f.barcode != null ? ltr(f.barcode!) : ''}'.trim(),
                          if (f.ingredient != null) '„${f.ingredient}“',
                          f.text,
                          if (f.sourceUrl != null) f.sourceUrl!,
                          '${formatDateTime(f.createdAt)} · ${s.t('feedback.unconfirmed')}',
                        ].join('\n')),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: s.t('common.delete'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => state.removeFeedback(f),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: Gap.m),
                FilledButton.icon(
                  icon: const Icon(Icons.copy),
                  label: Text(s.t('feedback.export.copy')),
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: FeedbackStore.exportJson(items)));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.t('feedback.export.copied'))));
                    }
                  },
                ),
                const SizedBox(height: Gap.s),
                OutlinedButton.icon(
                  icon: const Icon(Icons.mail_outline),
                  label: Text(s.t('feedback.export.mail')),
                  onPressed: () => _mail(context, s, items),
                ),
                const SizedBox(height: Gap.s),
                Text(s.t('feedback.export.privacy'),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
    );
  }

  Future<void> _mail(BuildContext context, AppStrings s, List<FeedbackEntry> items) async {
    final lines = items.map((f) => '- [${f.kind.name}] ${f.barcode ?? ''} '
        '${f.ingredient != null ? '„${f.ingredient}“ ' : ''}${f.text}'
        '${f.sourceUrl != null ? ' (${f.sourceUrl})' : ''} – '
        '${f.createdAt.toUtc().toIso8601String()}');
    var body = '${s.t('feedback.export.mailIntro')}\n\n${lines.join('\n')}';
    if (body.length > 1800) body = '${body.substring(0, 1800)}…';
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.hasContactEmail ? AppConfig.contactEmail : '',
      query: 'subject=${Uri.encodeComponent(s.t('feedback.export.mailSubject'))}'
          '&body=${Uri.encodeComponent(body)}',
    );
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.t('inquiry.noMailApp'))));
    }
  }
}

/// Anzeige der eigenen Hinweise zu einem Produkt (immer als unbestätigt).
class ProductFeedbackSection extends StatelessWidget {
  const ProductFeedbackSection({super.key, required this.barcode, this.productName});
  final String? barcode;
  final String? productName;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.strings;
    final items = state.feedbackFor(barcode);
    return SectionCard(
      title: s.t('feedback.section.title'),
      icon: Icons.lightbulb_outline,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.t('feedback.section.intro')),
        for (final f in items) ...[
          const SizedBox(height: Gap.s),
          Text('• ${s.t('feedback.kind.${f.kind.name}')}'
              '${f.ingredient != null ? ' („${f.ingredient}“)' : ''}: ${f.text} '
              '– ${s.t('feedback.unconfirmed')}'),
        ],
        const SizedBox(height: Gap.s),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add_comment_outlined),
            label: Text(s.t('feedback.add')),
            onPressed: () => showFeedbackSheet(context,
                barcode: barcode, productName: productName),
          ),
        ),
      ]),
    );
  }
}
