import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/off_search.dart';
import '../../data/open_food_facts.dart';
import '../../state/app_state.dart';
import '../result/lookup_screen.dart';

/// Suche nach Produktname, Marke oder Hersteller.
/// Ein Treffer öffnet die normale Prüfung für genau diesen Barcode.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<ProductSearchHit>? _hits;
  LookupError? _error;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final state = AppScope.read(context);
    final q = _controller.text;
    if (q.trim().length < OffSearchClient.minQueryLength) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hits = await state.productSearch.search(q, lang: state.strings.code);
      if (mounted) setState(() => _hits = hits);
    } on LookupException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    final hits = _hits;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('search.title'))),
      body: ListView(
        padding: const EdgeInsets.all(Gap.m),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: s.t('search.label'),
              helperText: s.t('search.hint'),
              helperMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: s.t('search.submit'),
                icon: const Icon(Icons.search),
                onPressed: _loading ? null : _search,
              ),
            ),
          ),
          const SizedBox(height: Gap.m),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(s.t('lookup.error.${_error!.name}'),
                style: const TextStyle(color: AppColors.unclear))
          else if (hits != null && hits.isEmpty)
            Text(s.t('search.empty'))
          else if (hits != null) ...[
            Text(s.t('search.disclaimer'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Gap.s),
            for (final h in hits)
              Card(
                child: ListTile(
                  leading: h.imageUrl == null
                      ? const Icon(Icons.inventory_2_outlined)
                      : Image.network(h.imageUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined)),
                  title: Text(h.name ?? s.t('result.unnamedProduct')),
                  subtitle: Text([
                    if (h.brand != null) h.brand!,
                    '${s.t('result.barcode')}: ${ltr(h.code)}',
                  ].join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LookupScreen(barcode: h.code))),
                ),
              ),
          ],
          const SizedBox(height: Gap.m),
          Text(s.t('search.source'), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
