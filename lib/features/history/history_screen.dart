import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../home/home_screen.dart';
import '../scanner/scanner_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.favoritesOnly});
  final bool favoritesOnly;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.strings;
    final items = favoritesOnly
        ? state.history.where((e) => e.favorite).toList()
        : state.history;
    final title = s.t(favoritesOnly ? 'nav.favorites' : 'nav.history');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: items.isEmpty
          ? EmptyState(
              icon: favoritesOnly ? Icons.star_outline : Icons.history,
              title: s.t(favoritesOnly ? 'favorites.empty.title' : 'history.empty.title'),
              message: s.t(favoritesOnly ? 'favorites.empty.body' : 'history.empty.body'),
              actions: [
                FilledButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(s.t('home.scan')),
                  onPressed: () => openScanner(context),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(Gap.m),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text(s.t('history.offlineNote'),
                      style: Theme.of(context).textTheme.bodySmall);
                }
                final e = items[i - 1];
                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.l),
                    decoration: BoxDecoration(
                        color: AppColors.haram,
                        borderRadius: BorderRadius.circular(Radii.card)),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) => state.remove(e),
                  child: Semantics(
                    customSemanticsActions: {
                      CustomSemanticsAction(label: s.t('history.delete')): () => state.remove(e),
                    },
                    child: EntryTile(entry: e),
                  ),
                );
              },
            ),
    );
  }
}
