import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/open_food_facts.dart';
import '../../state/app_state.dart';
import '../ocr/ocr_screen.dart';
import '../scanner/scanner_screen.dart';
import 'result_screen.dart';

/// Lädt das Produkt und zeigt danach das Ergebnis.
class LookupScreen extends StatefulWidget {
  const LookupScreen({super.key, required this.barcode});
  final String barcode;

  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  LookupOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _outcome = null);
    final o = await AppScope.read(context).lookup(widget.barcode);
    if (mounted) setState(() => _outcome = o);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    final o = _outcome;
    if (o == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.t('lookup.title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.l),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              StatusBadge(style: StatusStyle.loading, strings: s, large: true),
              const SizedBox(height: Gap.l),
              const CircularProgressIndicator(),
              const SizedBox(height: Gap.m),
              Text(s.t('lookup.loading', {'code': ltr(widget.barcode)}),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
    }
    if (o.entry != null) {
      return ResultScreen(entry: o.entry!, offlineError: o.fromCache ? o.error : null);
    }
    final err = o.error ?? LookupError.network;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('lookup.title'))),
      body: EmptyState(
        icon: err == LookupError.network || err == LookupError.timeout
            ? Icons.wifi_off
            : Icons.error_outline,
        title: s.t('lookup.error.title'),
        message: s.t('lookup.error.${err.name}'),
        actions: [
          FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(s.t('common.retry'))),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => OcrScreen(barcode: widget.barcode))),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(s.t('home.photo')),
          ),
          TextButton(
            onPressed: () => showManualEntry(context, replace: true),
            child: Text(s.t('scanner.manual')),
          ),
        ],
      ),
    );
  }
}
