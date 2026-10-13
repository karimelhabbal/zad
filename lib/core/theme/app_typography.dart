import 'package:flutter/material.dart';

/// Font families bundled with the app (see `pubspec.yaml`).
class ZadFonts {
  const ZadFonts._();

  /// Classical / Quranic script — used for Quran text and devotional passages.
  static const String classical = 'Amiri';

  /// Arabic UI face.
  static const String arabicUi = 'NotoNaskhArabic';

  /// Latin body face.
  static const String latinUi = 'IBMPlexSans';

  /// Latin display face (headings).
  static const String latinDisplay = 'NotoSerif';
}

/// Builds a [TextStyle] that works correctly with **variable** fonts.
///
/// `IBMPlexSans`, `NotoSerif` and `NotoNaskhArabic` ship as variable fonts, and
/// Flutter does not derive the `wght` axis from [TextStyle.fontWeight] on its
/// own — so every weight is applied explicitly through [FontVariation].
TextStyle zadText({
  required double size,
  int weight = 400,
  double? height,
  double? letterSpacing,
  String? family,
  Color? color,
  FontStyle? fontStyle,
  TextDecoration? decoration,
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontStyle: fontStyle,
    decoration: decoration,
    fontWeight: _nearestWeight(weight),
    fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
  );
}

FontWeight _nearestWeight(int weight) {
  const weights = <int, FontWeight>{
    100: FontWeight.w100,
    200: FontWeight.w200,
    300: FontWeight.w300,
    400: FontWeight.w400,
    500: FontWeight.w500,
    600: FontWeight.w600,
    700: FontWeight.w700,
    800: FontWeight.w800,
    900: FontWeight.w900,
  };
  final key = (weight ~/ 100) * 100;
  return weights[key.clamp(100, 900)] ?? FontWeight.w400;
}

/// The typographic scale from `DESIGN.md`, mapped onto Flutter's [TextTheme].
///
/// Headings use a serif display face and body text uses a grotesque UI face.
/// For Arabic the UI face is Noto Naskh Arabic so that diacritics and
/// ligatures render correctly; for Latin the design's IBM Plex Sans is used.
TextTheme zadTextTheme({
  required Color onSurface,
  required Color onSurfaceVariant,
  required bool isArabic,
}) {
  final display = isArabic ? ZadFonts.arabicUi : ZadFonts.latinDisplay;
  final ui = isArabic ? ZadFonts.arabicUi : ZadFonts.latinUi;

  return TextTheme(
    // headline-lg — 32 / 600 / 1.5
    displaySmall: zadText(
      size: 32,
      weight: 600,
      height: 1.5,
      family: display,
      color: onSurface,
    ),
    // headline-lg-mobile — 26 / 600
    headlineLarge: zadText(
      size: 26,
      weight: 600,
      height: 1.46,
      family: display,
      color: onSurface,
    ),
    // headline-md — 22 / 600
    headlineMedium: zadText(
      size: 22,
      weight: 600,
      height: 1.55,
      family: display,
      color: onSurface,
    ),
    // headline-sm — 18 / 600
    headlineSmall: zadText(
      size: 18,
      weight: 600,
      height: 1.55,
      family: display,
      color: onSurface,
    ),
    // body-lg — 18 / 400
    titleLarge: zadText(
      size: 18,
      weight: 600,
      height: 1.5,
      family: ui,
      color: onSurface,
    ),
    titleMedium: zadText(
      size: 16,
      weight: 600,
      height: 1.5,
      family: ui,
      color: onSurface,
    ),
    titleSmall: zadText(
      size: 14,
      weight: 600,
      height: 1.45,
      family: ui,
      color: onSurface,
    ),
    bodyLarge: zadText(
      size: 18,
      weight: 400,
      height: 1.67,
      family: ui,
      color: onSurface,
    ),
    // body-md — 15 / 400
    bodyMedium: zadText(
      size: 15,
      weight: 400,
      height: 1.6,
      family: ui,
      color: onSurface,
    ),
    // body-sm — 13 / 400
    bodySmall: zadText(
      size: 13,
      weight: 400,
      height: 1.54,
      family: ui,
      color: onSurfaceVariant,
    ),
    // label-lg — 14 / 500
    labelLarge: zadText(
      size: 14,
      weight: 500,
      height: 1.43,
      letterSpacing: 0.14,
      family: ui,
      color: onSurface,
    ),
    // label-md — 12 / 500
    labelMedium: zadText(
      size: 12,
      weight: 500,
      height: 1.33,
      letterSpacing: 0.12,
      family: ui,
      color: onSurfaceVariant,
    ),
    // label-sm — 10 / 500
    labelSmall: zadText(
      size: 10,
      weight: 500,
      height: 1.4,
      letterSpacing: 0.1,
      family: ui,
      color: onSurfaceVariant,
    ),
  );
}

/// Style used for Quranic verses and dhikr passages.
TextStyle quranVerseStyle({
  required Color color,
  double size = 26,
  double height = 2.05,
}) {
  return zadText(
    size: size,
    weight: 400,
    height: height,
    family: ZadFonts.classical,
    color: color,
  );
}

/// Design-system radii (`rounded` scale from DESIGN.md).
class ZadRadius {
  const ZadRadius._();
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 24;
  static const double full = 999;
}

/// 8dp base-unit spacing scale.
class ZadSpacing {
  const ZadSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 36;
  static const double gutter = 16;
  static const double margin = 20;
}
