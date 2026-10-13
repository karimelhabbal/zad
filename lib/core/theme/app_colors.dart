import 'package:flutter/material.dart';

/// "Sanctuary Elegance" palette — extracted from the approved Stitch design
/// system (`sanctuary_elegance/DESIGN.md`).
///
/// Light mode = warm ivory parchment with deep emerald + brushed gold.
/// Dark mode  = nocturnal spruce / obsidian sanctuary with glowing emerald.
class ZadPalette {
  const ZadPalette._();

  // ---------------------------------------------------------------- light ---
  static const Color lightSurface = Color(0xFFFBF9F4);
  static const Color lightSurfaceDim = Color(0xFFDBDAD5);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF5F3EE);
  static const Color lightSurfaceContainer = Color(0xFFF0EEE9);
  static const Color lightSurfaceContainerHigh = Color(0xFFEAE8E3);
  static const Color lightSurfaceContainerHighest = Color(0xFFE4E2DD);
  static const Color lightOnSurface = Color(0xFF1B1C19);
  static const Color lightOnSurfaceVariant = Color(0xFF404944);
  static const Color lightOutline = Color(0xFF707974);
  static const Color lightOutlineVariant = Color(0xFFC0C9C2);
  static const Color lightPrimary = Color(0xFF003626);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFF134E3A);
  static const Color lightOnPrimaryContainer = Color(0xFF85BEA4);
  static const Color lightSecondary = Color(0xFF7B581D);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFFFD089);
  static const Color lightOnSecondaryContainer = Color(0xFF79571C);
  static const Color lightTertiary = Color(0xFF0B3529);
  static const Color lightTertiaryContainer = Color(0xFF254C3F);
  static const Color lightError = Color(0xFFBA1A1A);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFFFDAD6);
  static const Color lightOnErrorContainer = Color(0xFF93000A);
  static const Color lightInverseSurface = Color(0xFF30312E);
  static const Color lightInverseOnSurface = Color(0xFFF2F1EC);

  // ----------------------------------------------------------------- dark ---
  static const Color darkSurface = Color(0xFF0B1914);
  static const Color darkSurfaceDim = Color(0xFF08120E);
  static const Color darkSurfaceContainerLowest = Color(0xFF060F0C);
  static const Color darkSurfaceContainerLow = Color(0xFF0E1E18);
  static const Color darkSurfaceContainer = Color(0xFF12241E);
  static const Color darkSurfaceContainerHigh = Color(0xFF162C24);
  static const Color darkSurfaceContainerHighest = Color(0xFF1B332A);
  static const Color darkOnSurface = Color(0xFFE7EDE9);
  static const Color darkOnSurfaceVariant = Color(0xFFA9BBB2);
  static const Color darkOutline = Color(0xFF5C6B64);
  static const Color darkOutlineVariant = Color(0xFF2C3B34);
  static const Color darkPrimary = Color(0xFF99D3B8);
  static const Color darkOnPrimary = Color(0xFF00382A);
  static const Color darkPrimaryContainer = Color(0xFF134E3A);
  static const Color darkOnPrimaryContainer = Color(0xFFB5EFD3);
  static const Color darkSecondary = Color(0xFFEDBF7A);
  static const Color darkOnSecondary = Color(0xFF3F2E0B);
  static const Color darkSecondaryContainer = Color(0xFF5B431A);
  static const Color darkOnSecondaryContainer = Color(0xFFFFD089);
  static const Color darkTertiary = Color(0xFFA6D0BE);
  static const Color darkTertiaryContainer = Color(0xFF254C3F);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF690005);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);
  static const Color darkInverseSurface = Color(0xFFE7EDE9);
  static const Color darkInverseOnSurface = Color(0xFF12241E);

  /// Brushed gold used for hairline borders and ceremonial accents.
  static const Color goldLight = Color(0xFFC99E5C);
  static const Color goldDark = Color(0xFFEDBF7A);

  /// Ambient chromatic shadow tint (never pure black).
  static const Color shadowTintLight = Color(0x0F0F382C);
  static const Color shadowTintDark = Color(0x33000000);
}

/// Extra tokens that are not part of the Material colour scheme but are used
/// throughout the design (gold hairlines, frosted navigation, etc.).
@immutable
class ZadTokens extends ThemeExtension<ZadTokens> {
  const ZadTokens({
    required this.gold,
    required this.goldSoft,
    required this.cardBorder,
    required this.ambientShadow,
    required this.navigationFill,
    required this.heroGradient,
    required this.parchment,
  });

  final Color gold;
  final Color goldSoft;
  final Color cardBorder;
  final Color ambientShadow;
  final Color navigationFill;
  final List<Color> heroGradient;
  final Color parchment;

  static const ZadTokens light = ZadTokens(
    gold: ZadPalette.goldLight,
    goldSoft: Color(0x33C99E5C),
    cardBorder: Color(0x33C99E5C),
    ambientShadow: Color(0x140F382C),
    navigationFill: Color(0xEBFBF9F4),
    heroGradient: [Color(0xFF134E3A), Color(0xFF0B3529)],
    parchment: Color(0xFFFBF9F4),
  );

  static const ZadTokens dark = ZadTokens(
    gold: ZadPalette.goldDark,
    goldSoft: Color(0x33EDBF7A),
    cardBorder: Color(0x2EEDBF7A),
    ambientShadow: Color(0x4D000000),
    navigationFill: Color(0xEB12241E),
    heroGradient: [Color(0xFF16382C), Color(0xFF0B1914)],
    parchment: Color(0xFF0B1914),
  );

  @override
  ZadTokens copyWith({
    Color? gold,
    Color? goldSoft,
    Color? cardBorder,
    Color? ambientShadow,
    Color? navigationFill,
    List<Color>? heroGradient,
    Color? parchment,
  }) {
    return ZadTokens(
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      cardBorder: cardBorder ?? this.cardBorder,
      ambientShadow: ambientShadow ?? this.ambientShadow,
      navigationFill: navigationFill ?? this.navigationFill,
      heroGradient: heroGradient ?? this.heroGradient,
      parchment: parchment ?? this.parchment,
    );
  }

  @override
  ZadTokens lerp(covariant ZadTokens? other, double t) {
    if (other == null) return this;
    return ZadTokens(
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      ambientShadow: Color.lerp(ambientShadow, other.ambientShadow, t)!,
      navigationFill: Color.lerp(navigationFill, other.navigationFill, t)!,
      heroGradient: <Color>[
        Color.lerp(heroGradient.first, other.heroGradient.first, t)!,
        Color.lerp(heroGradient.last, other.heroGradient.last, t)!,
      ],
      parchment: Color.lerp(parchment, other.parchment, t)!,
    );
  }
}

extension ZadThemeContext on BuildContext {
  ZadTokens get tokens => Theme.of(this).extension<ZadTokens>() ?? ZadTokens.light;
}
