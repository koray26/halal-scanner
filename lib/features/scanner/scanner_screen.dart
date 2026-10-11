import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/barcode.dart';
import '../../state/app_state.dart';
import '../result/lookup_screen.dart';

void openScanner(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true, builder: (_) => const ScannerScreen()));
}

/// Barcode manuell eingeben (Fallback, wenn Kamera nicht funktioniert).
Future<void> showManualEntry(BuildContext context, {bool replace = false}) async {
  final s = AppScope.read(context).strings;
  final controller = TextEditingController();
  String? error;
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(s.t('manual.title')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(s.t('manual.hint')),
          const SizedBox(height: Gap.m),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
              decoration: InputDecoration(
                labelText: s.t('manual.label'),
                errorText: error,
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.t('common.cancel'))),
          FilledButton(
            onPressed: () {
              final check = Barcode.check(controller.text);
              if (!check.isValid) {
                setState(() => error = s.t('barcode.problem.${check.problem!.name}'));
                return;
              }
              Navigator.pop(ctx, check.normalized);
            },
            child: Text(s.t('manual.submit')),
          ),
        ],
      ),
    ),
  );
  if (code == null || !context.mounted) return;
  final route = MaterialPageRoute(builder: (_) => LookupScreen(barcode: code));
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.normal,
  );

  String? _lastCode;
  DateTime _lastTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _handling = false;
  String? _hint;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    for (final b in capture.barcodes) {
      var raw = b.rawValue;
      if (raw == null) continue;
      if (b.format == BarcodeFormat.upcE && raw.length == 8) {
        raw = Barcode.upcEToUpcA(raw) ?? raw;
      }
      // Schutz vor wiederholtem Scannen desselben Codes (3 Sekunden).
      final now = DateTime.now();
      if (raw == _lastCode && now.difference(_lastTime) < const Duration(seconds: 3)) {
        return;
      }
      _lastCode = raw;
      _lastTime = now;

      final check = Barcode.check(raw);
      if (!check.isValid) {
        setState(() => _hint = AppScope.read(context).strings.t('scanner.unreadable'));
        continue;
      }
      _handling = true;
      HapticFeedback.mediumImpact();
      await controller.stop();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => LookupScreen(barcode: check.normalized)));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth * 0.8).clamp(200.0, 380.0).toDouble();
        final h = w * 0.55;
        final window = Rect.fromCenter(
            center: Offset(c.maxWidth / 2, c.maxHeight * 0.42), width: w, height: h);
        return Stack(children: [
          Positioned.fill(
            child: MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraError(error: error, strings: s),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _FramePainter(window)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Gap.s),
              child: Row(children: [
                _RoundButton(
                  icon: Icons.close,
                  label: s.t('scanner.close'),
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: controller,
                  builder: (context, st, _) {
                    final on = st.torchState == TorchState.on;
                    return _RoundButton(
                      icon: on ? Icons.flashlight_off : Icons.flashlight_on,
                      label: s.t(on ? 'scanner.torch.off' : 'scanner.torch.on'),
                      onTap: st.torchState == TorchState.unavailable
                          ? null
                          : () => controller.toggleTorch(),
                    );
                  },
                ),
              ]),
            ),
          ),
          Positioned(
            left: Gap.l,
            right: Gap.l,
            top: window.bottom + Gap.l,
            child: Column(children: [
              Text(
                _hint ?? s.t('scanner.instruction'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Gap.l),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                icon: const Icon(Icons.keyboard),
                label: Text(s.t('scanner.manual')),
                onPressed: () => showManualEntry(context, replace: true),
              ),
            ]),
          ),
        ]);
      }),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(icon, color: onTap == null ? Colors.white38 : Colors.white, size: 26),
              ),
            ),
          ),
        ),
      );
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.window);
  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(window, const Radius.circular(18));
    final bg = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(r)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(bg, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRRect(
        r,
        Paint()
          ..color = AppColors.goldLight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.window != window;
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.strings});
  final MobileScannerException error;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.l),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white, size: 56),
            const SizedBox(height: Gap.m),
            Text(
              strings.t(denied ? 'scanner.permission.title' : 'scanner.error.title'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Gap.s),
            Text(
              strings.t(denied ? 'scanner.permission.body' : 'scanner.error.body'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ]),
        ),
      ),
    );
  }
}
