import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/history_store.dart';
import '../../domain/models.dart';
import '../../domain/rules/catalog.dart';
import '../../state/app_state.dart';
import 'result_screen.dart';

class IngredientsScreen extends StatelessWidget {
  const IngredientsScreen({super.key, required this.entry});
  final ScanEntry entry;

  List<IngredientText> get _texts => entry.analyzedTexts.isNotEmpty
      ? entry.analyzedTexts
      : (entry.product?.ingredientTexts ?? const []);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    final theme = Theme.of(context);
    // Die Fassung in der Sprache der App zuerst; weitere Sprachfassungen
    // (alle werden mit denselben Regeln geprüft) eingeklappt darunter.
    final texts = [..._texts]..sort((a, b) =>
        (a.lang == s.code ? 0 : 1).compareTo(b.lang == s.code ? 0 : 1));
    final highlights = entry.verdict.findings
        .where((f) => !f.fromAdditiveTag)
        .map((f) => (f.matchedText.toLowerCase(), f.effect, f.isResolved))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(s.t('ingredients.title'))),
      body: texts.isEmpty
          ? EmptyState(
              icon: Icons.list_alt,
              title: s.t('ingredients.none.title'),
              message: s.t('ingredients.none.body'),
              actions: [
                FilledButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: Text(s.t('ingredients.edit')),
                  onPressed: () => _edit(context, ''),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(Gap.m),
              children: [
                for (final (i, t) in texts.indexed) ...[
                  if (i == 0)
                    SectionCard(
                      title: _title(s, t),
                      icon: Icons.notes,
                      child: _textBody(s, t, highlights, theme),
                    )
                  else
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          key: ValueKey('ingredients.text.$i'),
                          leading: const Icon(Icons.translate),
                          title: Text(_title(s, t),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          childrenPadding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.m),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: [_textBody(s, t, highlights, theme)],
                        ),
                      ),
                    ),
                  const SizedBox(height: Gap.m),
                ],
                _Legend(strings: s),
                const SizedBox(height: Gap.l),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: Text(s.t('ingredients.edit')),
                  onPressed: () => _edit(context, texts.first.text),
                ),
                const SizedBox(height: Gap.s),
                Text(s.t('ingredients.edit.note'), style: theme.textTheme.bodySmall),
              ],
            ),
    );
  }

  String _title(AppStrings s, IngredientText t) =>
      s.t('ingredients.source.${t.source.kind.name}') +
      (t.lang != null ? ' · ${t.lang!.toUpperCase()}' : '');

  Widget _textBody(AppStrings s, IngredientText t,
          List<(String, RuleEffect, bool)> highlights, ThemeData theme) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText.rich(_highlight(t.text, highlights, theme)),
        if (t.lang != null &&
            t.source.kind == SourceKind.openFoodFacts &&
            !greenRuleLanguages.contains(t.lang)) ...[
          const SizedBox(height: Gap.s),
          Text(s.t('language.ingredients.${ingredientSupportFor(t.lang!).name}'),
              style: const TextStyle(color: AppColors.unclear)),
        ],
        if (t.uncertainFragments.isNotEmpty) ...[
          const SizedBox(height: Gap.s),
          Text(s.t('ocr.uncertain', {'items': t.uncertainFragments.join(' | ')}),
              style: const TextStyle(color: AppColors.unclear)),
        ],
      ]);

  TextSpan _highlight(String text, List<(String, RuleEffect, bool)> hs, ThemeData theme) {
    final lower = text.toLowerCase();
    final marks = List<Color?>.filled(text.length, null);
    for (final (needle, effect, resolved) in hs) {
      if (needle.isEmpty) continue;
      final color = resolved || effect == RuleEffect.info
          ? AppColors.neutral
          : effect == RuleEffect.haram
              ? AppColors.haram
              : AppColors.unclear;
      var i = lower.indexOf(needle);
      while (i >= 0) {
        for (var k = i; k < i + needle.length && k < marks.length; k++) {
          marks[k] ??= color;
        }
        i = lower.indexOf(needle, i + needle.length);
      }
    }
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || marks[i] != marks[start]) {
        final c = marks[start];
        spans.add(TextSpan(
          text: text.substring(start, i),
          style: c == null
              ? null
              : TextStyle(
                  color: c,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                  decorationColor: c),
        ));
        start = i;
      }
    }
    return TextSpan(style: theme.textTheme.bodyLarge, children: spans);
  }

  Future<void> _edit(BuildContext context, String initial) async {
    final state = AppScope.read(context);
    final s = state.strings;
    final controller = TextEditingController(text: initial);
    final text = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: Text(s.t('ingredients.edit'))),
        body: Padding(
          padding: const EdgeInsets.all(Gap.m),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.t('ingredients.edit.note')),
            const SizedBox(height: Gap.m),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(hintText: s.t('ingredients.edit.hint')),
              ),
            ),
            const SizedBox(height: Gap.m),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(s.t('ocr.analyze')),
            ),
          ]),
        ),
      ),
    ));
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    final newEntry = await state.analyzeTexts(
      [
        IngredientText(
          text: text.trim(),
          source: SourceRef(kind: SourceKind.userEdited, retrievedAt: state.now()),
        ),
      ],
      barcode: entry.barcode,
      product: entry.product,
    );
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultScreen(entry: newEntry)));
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.strings});
  final AppStrings strings;
  @override
  Widget build(BuildContext context) {
    Widget item(Color c, IconData i, String k) => Padding(
          padding: const EdgeInsets.only(bottom: Gap.xs),
          child: Row(children: [
            Icon(i, color: c, size: 18),
            const SizedBox(width: Gap.s),
            Expanded(child: Text(strings.t(k))),
          ]),
        );
    return Column(children: [
      item(AppColors.haram, Icons.block, 'ingredients.legend.haram'),
      item(AppColors.unclear, Icons.help, 'ingredients.legend.unclear'),
      item(AppColors.neutral, Icons.info_outline, 'ingredients.legend.info'),
    ]);
  }
}
