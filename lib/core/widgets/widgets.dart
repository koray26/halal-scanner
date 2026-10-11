import 'package:flutter/material.dart';

import '../../domain/rules/halal_engine.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';

/// Eigenes Logo: Scanner-Rahmen mit Schutzschild und Haken.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(size: Size.square(size), painter: LogoPainter()),
      );
}

class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final bg = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(s * 0.24));
    canvas.drawRRect(bg, Paint()..color = AppColors.forest);

    // Scanner-Ecken
    final corner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round;
    final m = s * 0.2, l = s * 0.16;
    for (final (x, y, dx, dy) in [
      (m, m, 1.0, 1.0),
      (s - m, m, -1.0, 1.0),
      (m, s - m, 1.0, -1.0),
      (s - m, s - m, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * l, y), corner);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * l), corner);
    }

    // Schild
    final cx = s / 2;
    final shield = Path()
      ..moveTo(cx, s * 0.31)
      ..lineTo(s * 0.66, s * 0.37)
      ..quadraticBezierTo(s * 0.66, s * 0.6, cx, s * 0.7)
      ..quadraticBezierTo(s * 0.34, s * 0.6, s * 0.34, s * 0.37)
      ..close();
    canvas.drawPath(shield, Paint()..color = AppColors.gold);

    // Haken
    final check = Path()
      ..moveTo(s * 0.43, s * 0.5)
      ..lineTo(s * 0.485, s * 0.555)
      ..lineTo(s * 0.58, s * 0.45);
    canvas.drawPath(
        check,
        Paint()
          ..color = AppColors.forest
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Statusanzeige: immer Farbe + Symbol + Text (nie nur Farbe).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.style, required this.strings, this.large = false});

  factory StatusBadge.forStatus(HalalStatus s, AppStrings strings, {bool large = false}) =>
      StatusBadge(style: StatusStyle.of(s), strings: strings, large: large);

  final StatusStyle style;
  final AppStrings strings;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final label = strings.t(style.labelKey);
    final textStyle = (large
            ? Theme.of(context).textTheme.titleLarge
            : Theme.of(context).textTheme.labelLarge)
        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.4);
    return Semantics(
      label: '${strings.t('a11y.status')}: $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: large ? Gap.m : 10, vertical: large ? 12 : 6),
        decoration: BoxDecoration(
          color: style.color,
          borderRadius: BorderRadius.circular(large ? 14 : 10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, color: Colors.white, size: large ? 28 : 18),
            SizedBox(width: large ? 10 : 6),
            Flexible(child: Text(label, style: textStyle)),
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.icon, required this.child, this.padding});
  final String? title;
  final IconData? icon;
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(Gap.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: Gap.s),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title!,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
              const SizedBox(height: Gap.s),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actions = const []});
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: Gap.m),
            Text(title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Gap.s),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            const SizedBox(height: Gap.l),
            ...actions.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: SizedBox(width: double.infinity, child: a))),
          ],
        ),
      ),
    );
  }
}

String formatDate(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return ltr('${l.year}-${two(l.month)}-${two(l.day)}');
}

String formatDateTime(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return ltr('${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}');
}
