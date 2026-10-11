import 'package:flutter/material.dart';

import '../../domain/rules/halal_engine.dart';

/// Design-Tokens: Farben, Abstände, Radien.
class AppColors {
  AppColors._();
  static const forest = Color(0xFF1F4D3A);
  static const forestDark = Color(0xFF153728);
  static const forestLight = Color(0xFF7FC4A2);
  static const gold = Color(0xFFB8913A);
  static const goldLight = Color(0xFFD9B865);
  static const warmWhite = Color(0xFFF7F5F0);
  static const ink = Color(0xFF1B1F1D);
  static const inkMuted = Color(0xFF4F5753);
  static const darkBg = Color(0xFF0F1412);
  static const darkSurface = Color(0xFF18201C);

  // Statusfarben – immer zusammen mit Text und Symbol verwenden.
  static const halal = Color(0xFF1E7A46);
  static const haram = Color(0xFFB3261E);
  static const unclear = Color(0xFFB45309);
  static const notVerified = Color(0xFF8A5A00);
  static const neutral = Color(0xFF5F6B66);
}

class Gap {
  Gap._();
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
}

class Radii {
  Radii._();
  static const card = 20.0;
  static const button = 16.0;
}

class StatusStyle {
  const StatusStyle(this.color, this.icon, this.labelKey, this.meaningKey);
  final Color color;
  final IconData icon;
  final String labelKey;
  final String meaningKey;

  static StatusStyle of(HalalStatus s) => switch (s) {
        HalalStatus.halalCertified => const StatusStyle(AppColors.halal,
            Icons.verified, 'status.halalCertified', 'status.halalCertified.meaning'),
        HalalStatus.halalByIngredients => const StatusStyle(AppColors.halal,
            Icons.check_circle, 'status.halalByIngredients',
            'status.halalByIngredients.meaning'),
        HalalStatus.haram => const StatusStyle(AppColors.haram, Icons.block,
            'status.haram', 'status.haram.meaning'),
        HalalStatus.unclear => const StatusStyle(AppColors.unclear,
            Icons.help, 'status.unclear', 'status.unclear.meaning'),
        HalalStatus.notVerified => const StatusStyle(AppColors.notVerified,
            Icons.gpp_maybe, 'status.notVerified', 'status.notVerified.meaning'),
      };

  static const loading = StatusStyle(AppColors.neutral, Icons.hourglass_top,
      'status.loading', 'status.loading.meaning');
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      brightness: b,
    ).copyWith(
      primary: dark ? AppColors.forestLight : AppColors.forest,
      onPrimary: dark ? AppColors.darkBg : Colors.white,
      secondary: dark ? AppColors.goldLight : AppColors.gold,
      surface: dark ? AppColors.darkSurface : Colors.white,
      onSurface: dark ? const Color(0xFFE8ECEA) : AppColors.ink,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      scaffoldBackgroundColor: dark ? AppColors.darkBg : AppColors.warmWhite,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? AppColors.darkBg : AppColors.warmWhite,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(
              color: dark ? const Color(0xFF26302B) : const Color(0xFFE6E1D6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.button)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          side: BorderSide(color: scheme.primary, width: 1.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.button)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
            base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1F2924) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
          color: dark ? const Color(0xFF26302B) : const Color(0xFFE6E1D6)),
    );
  }
}
