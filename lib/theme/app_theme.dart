import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Corner radii used across the app.
class AppRadius {
  static const double small = 10;
  static const double medium = 16;
  static const double large = 24;
}

/// Builds the app's Material 3 theme from a colour scheme. All component
/// styling lives here so screens only use semantic colours.
ThemeData buildAppTheme(ColorScheme scheme) {
  final isDark = scheme.brightness == Brightness.dark;

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: scheme.brightness,
  );

  final text = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineSmall: base.textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleLarge: base.textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleMedium:
        base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall:
        base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge:
        base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  final roundedMedium = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.medium),
  );

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      systemOverlayStyle: (isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small + 4),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small + 4),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small + 4),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small + 4),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small + 4),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        shape: const StadiumBorder(),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.standard,
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: text.labelLarge,
    ),
    listTileTheme: ListTileThemeData(
      shape: roundedMedium,
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.bodyLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle:
          text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
      space: 1,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.large + 4)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large + 4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.small + 2),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      labelStyle: text.titleSmall,
      unselectedLabelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      indicatorSize: TabBarIndicatorSize.label,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
  );
}

/// Semantic status colours (attendance, grades) that stay readable in both
/// light and dark mode.
class StatusColors {
  const StatusColors._(this.good, this.warning, this.bad, this.none);

  final Color good;
  final Color warning;
  final Color bad;
  final Color none;

  factory StatusColors.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return StatusColors._(
      dark ? const Color(0xFF7BD88F) : const Color(0xFF2E7D32),
      dark ? const Color(0xFFFFC266) : const Color(0xFFB26A00),
      dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
      scheme.outline,
    );
  }

  Color forPercentage(int percentage) {
    if (percentage >= 75) return good;
    if (percentage >= 50) return warning;
    if (percentage > 0) return bad;
    return none;
  }
}
