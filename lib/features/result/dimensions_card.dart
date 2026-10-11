import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/rules/dimensions.dart';
import '../../domain/rules/halal_engine.dart';

/// Getrennte Sachaussagen: Schweinebestandteile und Alkohol.
/// Der Halal-Status steht darüber in der Statuskarte.
class DimensionsCard extends StatelessWidget {
  const DimensionsCard(
      {super.key, required this.verdict, required this.strings, this.showTitle = true});
  final Verdict verdict;
  final AppStrings strings;

  /// false: ohne eigene Karte/Überschrift (in einem aufklappbaren Abschnitt).
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final d = assessDimensions(verdict);
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Row(label: s.t('dimension.pork'), result: d.pork, strings: s),
      const SizedBox(height: Gap.m),
      _Row(label: s.t('dimension.alcohol'), result: d.alcohol, strings: s),
      const SizedBox(height: Gap.m),
      Text(s.t('dimension.note'), style: Theme.of(context).textTheme.bodySmall),
    ]);
    if (!showTitle) return body;
    return SectionCard(
      title: s.t('dimension.title'),
      icon: Icons.science_outlined,
      child: body,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.result, required this.strings});
  final String label;
  final DimensionResult result;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final (color, icon) = switch (result.state) {
      DimensionState.detected => (AppColors.haram, Icons.error),
      DimensionState.notDetected => (AppColors.neutral, Icons.search_off),
      DimensionState.unresolved => (AppColors.unclear, Icons.help),
    };
    final details = <String>[
      if (result.ingredients.isNotEmpty)
        s.t('dimension.items', {
          'items': result.ingredients.take(4).map((i) => '„$i“').join(', '),
        }),
      for (final r in result.reasons) s.t('dimension.reason.${r.name}'),
    ];
    return Semantics(
      container: true,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: Gap.s),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.titleSmall),
            Text(s.t('dimension.state.${result.state.name}'),
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w800)),
            for (final t in details) Text(t, style: theme.textTheme.bodyMedium),
          ]),
        ),
      ]),
    );
  }
}
