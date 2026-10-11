import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';

/// Optionaler, persönlicher USDA-Schlüssel. Der gespeicherte Wert wird nie
/// wieder angezeigt; er kann nur ersetzt oder gelöscht werden.
class UsdaKeyScreen extends StatefulWidget {
  const UsdaKeyScreen({super.key});

  @override
  State<UsdaKeyScreen> createState() => _UsdaKeyScreenState();
}

class _UsdaKeyScreenState extends State<UsdaKeyScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = AppScope.of(context);
    final s = state.strings;
    setState(() => _busy = true);
    final result = await state.saveUsdaKey(_controller.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = switch (result) {
        UsdaKeyResult.saved => null,
        UsdaKeyResult.invalidFormat => s.t('usdaKey.error.format'),
        UsdaKeyResult.storageFailed => s.t('usdaKey.error.storage'),
      };
    });
    if (result == UsdaKeyResult.saved) {
      _controller.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.t('usdaKey.saved'))));
    }
  }

  Future<void> _remove() async {
    final state = AppScope.of(context);
    final s = state.strings;
    await state.removeUsdaKey();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.t('usdaKey.removed'))));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.strings;
    final theme = Theme.of(context);
    final status = !state.hasUsdaKey
        ? s.t('usdaKey.status.none')
        : state.usdaKeyRejected
            ? s.t('usdaKey.status.rejected')
            : s.t('usdaKey.status.set');

    return Scaffold(
      appBar: AppBar(title: Text(s.t('usdaKey.title'))),
      body: ListView(
        padding: const EdgeInsets.all(Gap.m),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status,
                    key: const ValueKey('usdaKey.status'),
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: state.usdaKeyRejected && state.hasUsdaKey
                            ? AppColors.haram
                            : null)),
                const SizedBox(height: Gap.s),
                Text(s.t('usdaKey.body'), style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: Gap.m),
          TextField(
            key: const ValueKey('usdaKey.input'),
            controller: _controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: s.t(state.hasUsdaKey ? 'usdaKey.replace' : 'usdaKey.label'),
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: Gap.s),
          FilledButton(
            key: const ValueKey('usdaKey.save'),
            onPressed: _busy ? null : _save,
            child: Text(s.t('usdaKey.save')),
          ),
          if (state.hasUsdaKey) ...[
            const SizedBox(height: Gap.s),
            OutlinedButton(
              key: const ValueKey('usdaKey.remove'),
              onPressed: _busy ? null : _remove,
              child: Text(s.t('usdaKey.remove')),
            ),
          ],
          const SizedBox(height: Gap.m),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: Text(s.t('usdaKey.signup')),
            onPressed: () => launchUrl(Uri.parse(AppConfig.fdcSignupUrl),
                mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: Gap.s),
          Text(s.t('usdaKey.privacy'), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
