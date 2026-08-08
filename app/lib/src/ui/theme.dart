import 'package:flutter/material.dart';

import 'brand.dart';

/// Vahid vizual sistem — Duolingo tipli oyunvari, LachinGo səyahət unikallığı.
///
/// Ekranlar sabit rəng/radius/boşluq yazmır, buradan gələn tokenləri işlədir.
class AppSpacing {
  const AppSpacing._();

  static const double screen = 20;
  static const double card = 12;
  static const double section = 24;

  /// Standart kart radiusu.
  static const double radiusCard = 16;

  /// Oyunvari 3D kartlar — daha yumraq (Duolingo ~18–20px).
  static const double radiusPlayful = 20;

  static const double radiusControl = 14;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.navy,
    brightness: Brightness.light,
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF5F9FD),
    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF5F9FD),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPlayful),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: BrandColors.gold.withValues(alpha: 0.22),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 26,
          color: selected ? BrandColors.navy : scheme.onSurfaceVariant,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return base.textTheme.labelSmall?.copyWith(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          color: selected ? BrandColors.navy : scheme.onSurfaceVariant,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        ),
        textStyle: base.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        ),
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        textStyle: base.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: BrandColors.navy,
        selectedForegroundColor: Colors.white,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      space: 1,
      thickness: 1,
    ),
  );
}
