import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Builds the Material themes for the approved "Sanctuary Elegance" design.
class ZadTheme {
  const ZadTheme._();

  static ThemeData light({bool isArabic = true}) => _build(
    brightness: Brightness.light,
    isArabic: isArabic,
    scheme: const ColorScheme(
      brightness: Brightness.light,
      primary: ZadPalette.lightPrimary,
      onPrimary: ZadPalette.lightOnPrimary,
      primaryContainer: ZadPalette.lightPrimaryContainer,
      onPrimaryContainer: ZadPalette.lightOnPrimaryContainer,
      secondary: ZadPalette.lightSecondary,
      onSecondary: ZadPalette.lightOnSecondary,
      secondaryContainer: ZadPalette.lightSecondaryContainer,
      onSecondaryContainer: ZadPalette.lightOnSecondaryContainer,
      tertiary: ZadPalette.lightTertiary,
      onTertiary: Colors.white,
      tertiaryContainer: ZadPalette.lightTertiaryContainer,
      onTertiaryContainer: Color(0xFF92BBAB),
      error: ZadPalette.lightError,
      onError: ZadPalette.lightOnError,
      errorContainer: ZadPalette.lightErrorContainer,
      onErrorContainer: ZadPalette.lightOnErrorContainer,
      surface: ZadPalette.lightSurface,
      onSurface: ZadPalette.lightOnSurface,
      onSurfaceVariant: ZadPalette.lightOnSurfaceVariant,
      surfaceContainerLowest: ZadPalette.lightSurfaceContainerLowest,
      surfaceContainerLow: ZadPalette.lightSurfaceContainerLow,
      surfaceContainer: ZadPalette.lightSurfaceContainer,
      surfaceContainerHigh: ZadPalette.lightSurfaceContainerHigh,
      surfaceContainerHighest: ZadPalette.lightSurfaceContainerHighest,
      outline: ZadPalette.lightOutline,
      outlineVariant: ZadPalette.lightOutlineVariant,
      inverseSurface: ZadPalette.lightInverseSurface,
      onInverseSurface: ZadPalette.lightInverseOnSurface,
      shadow: Color(0x140F382C),
      scrim: Color(0x660F382C),
    ),
    tokens: ZadTokens.light,
  );

  static ThemeData dark({bool isArabic = true}) => _build(
    brightness: Brightness.dark,
    isArabic: isArabic,
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: ZadPalette.darkPrimary,
      onPrimary: ZadPalette.darkOnPrimary,
      primaryContainer: ZadPalette.darkPrimaryContainer,
      onPrimaryContainer: ZadPalette.darkOnPrimaryContainer,
      secondary: ZadPalette.darkSecondary,
      onSecondary: ZadPalette.darkOnSecondary,
      secondaryContainer: ZadPalette.darkSecondaryContainer,
      onSecondaryContainer: ZadPalette.darkOnSecondaryContainer,
      tertiary: ZadPalette.darkTertiary,
      onTertiary: Color(0xFF003828),
      tertiaryContainer: ZadPalette.darkTertiaryContainer,
      onTertiaryContainer: Color(0xFFC1ECDA),
      error: ZadPalette.darkError,
      onError: ZadPalette.darkOnError,
      errorContainer: ZadPalette.darkErrorContainer,
      onErrorContainer: ZadPalette.darkOnErrorContainer,
      surface: ZadPalette.darkSurface,
      onSurface: ZadPalette.darkOnSurface,
      onSurfaceVariant: ZadPalette.darkOnSurfaceVariant,
      surfaceContainerLowest: ZadPalette.darkSurfaceContainerLowest,
      surfaceContainerLow: ZadPalette.darkSurfaceContainerLow,
      surfaceContainer: ZadPalette.darkSurfaceContainer,
      surfaceContainerHigh: ZadPalette.darkSurfaceContainerHigh,
      surfaceContainerHighest: ZadPalette.darkSurfaceContainerHighest,
      outline: ZadPalette.darkOutline,
      outlineVariant: ZadPalette.darkOutlineVariant,
      inverseSurface: ZadPalette.darkInverseSurface,
      onInverseSurface: ZadPalette.darkInverseOnSurface,
      shadow: Color(0x66000000),
      scrim: Color(0x99000000),
    ),
    tokens: ZadTokens.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required bool isArabic,
    required ColorScheme scheme,
    required ZadTokens tokens,
  }) {
    final isLight = brightness == Brightness.light;
    final textTheme = zadTextTheme(
      onSurface: scheme.onSurface,
      onSurfaceVariant: scheme.onSurfaceVariant,
      isArabic: isArabic,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      ),
      cardTheme: CardThemeData(
        color: isLight
            ? scheme.surfaceContainerLowest
            : scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZadRadius.xl),
          side: BorderSide(color: tokens.cardBorder, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZadRadius.md),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: scheme.primary,
          side: BorderSide(color: tokens.gold, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZadRadius.md),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainer,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZadRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZadRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZadRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZadRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZadRadius.full),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.md,
          vertical: ZadSpacing.sm,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ZadRadius.xxl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight
            ? scheme.surfaceContainerLowest
            : scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZadRadius.xl),
          side: BorderSide(color: tokens.cardBorder),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZadRadius.lg),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZadRadius.lg),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onPrimaryContainer,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(ZadRadius.full),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(ZadRadius.md),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
