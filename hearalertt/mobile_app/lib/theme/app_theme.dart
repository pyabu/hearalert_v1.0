import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ══════════════════════════════════════════════════════════════════════
/// Aurora Dusk Design System — HearAlert 2.0
///
/// Palette: Deep Indigo + Vivid Violet + Rose Pink + Warm Amber
/// Philosophy: Violet = active/alive, rose = confirmed/safe,
///   amber = alert, red = emergency.
/// ══════════════════════════════════════════════════════════════════════
class AppTheme {

  // ─────────────────────────────────────────────────────────────────────
  // AURORA DUSK BACKGROUNDS
  // ─────────────────────────────────────────────────────────────────────
  static const Color void_            = Color(0xFF080612); // Absolute deep indigo-black
  static const Color surface          = Color(0xFF0F0C22); // Primary surface
  static const Color surfaceElevated  = Color(0xFF16122E); // Elevated cards
  static const Color glassLow         = Color(0xFF1C1840); // Subtle glass tint
  static const Color glassHigh        = Color(0xFF252050); // Stronger glass

  // ─────────────────────────────────────────────────────────────────────
  // PRIMARY — Vivid Violet  (active signal, listening, life)
  // ─────────────────────────────────────────────────────────────────────
  static const Color primary          = Color(0xFFA855F7); // Vivid Violet
  static const Color primaryLight     = Color(0xFFC084FC); // Light Violet / Glow
  static const Color primaryDark      = Color(0xFF7C3AED); // Deep Violet
  static const Color primaryMuted     = Color(0xFF3B0764); // Muted Violet

  // ─────────────────────────────────────────────────────────────────────
  // SECONDARY — Rose Pink  (confirmed detection, safe)
  // ─────────────────────────────────────────────────────────────────────
  static const Color secondary        = Color(0xFFF472B6); // Rose Pink
  static const Color secondaryLight   = Color(0xFFFBBDD5); // Light Rose
  static const Color secondaryDark    = Color(0xFFDB2777); // Deep Rose
  static const Color secondaryMuted   = Color(0xFF500724); // Muted Rose

  // ─────────────────────────────────────────────────────────────────────
  // ACCENTS — Amber & Sky
  // ─────────────────────────────────────────────────────────────────────
  static const Color accentOrange     = Color(0xFFFB923C); // Warm Amber (alert)
  static const Color accentYellow     = Color(0xFFFBBF24); // Golden Yellow
  static const Color accentPink       = Color(0xFFEC4899); // Hot Pink
  static const Color accentViolet     = Color(0xFF818CF8); // Periwinkle

  // ─────────────────────────────────────────────────────────────────────
  // SEMANTIC
  // ─────────────────────────────────────────────────────────────────────
  static const Color danger           = Color(0xFFEF4444); // Vivid Red Emergency
  static const Color warning          = Color(0xFFFB923C); // Amber Warning
  static const Color success          = Color(0xFFA855F7); // Violet Success (matches primary)
  static const Color info             = Color(0xFF60A5FA); // Sky Blue Info

  // ─────────────────────────────────────────────────────────────────────
  // TEXT
  // ─────────────────────────────────────────────────────────────────────
  static const Color textPrimary      = Color(0xFFF5F0FF); // Warm white-violet
  static const Color textSecondary    = Color(0xFFB8A8D8); // Mid violet-gray
  static const Color textMuted        = Color(0xFF6B5E8A); // Muted violet-gray
  static const Color textDisabled     = Color(0xFF352D4D); // Disabled

  // ─────────────────────────────────────────────────────────────────────
  // AURORA DUSK GRADIENTS
  // ─────────────────────────────────────────────────────────────────────

  /// Vivid violet sweep
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  /// Aurora pulse — violet → rose
  static const LinearGradient biosonicGradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFFF472B6)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  /// Signal waveform gradient for waveform painter
  static const LinearGradient signalPulseGradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFFC084FC), Color(0xFFF472B6)],
    begin: Alignment.centerLeft, end: Alignment.centerRight,
    stops: [0.0, 0.5, 1.0],
  );

  /// Emergency alert gradient
  static const LinearGradient emergencyGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFFB923C)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  /// Amber / warm alert
  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFB923C), Color(0xFFFBBF24)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  /// Full spectrum aurora for decorative elements
  static const LinearGradient auroraGradient = LinearGradient(
    colors: [
      Color(0xFF818CF8), // Periwinkle
      Color(0xFFA855F7), // Violet
      Color(0xFFEC4899), // Pink
      Color(0xFFFB923C), // Amber
    ],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    stops: [0.0, 0.33, 0.66, 1.0],
  );

  /// Deep surface background gradient
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [void_, surface],
  );

  /// Accent gradient for action buttons
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFB923C), Color(0xFFEC4899)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  /// Glass border highlight
  static const LinearGradient glassBorderGradient = LinearGradient(
    colors: [
      Color.fromRGBO(168, 85, 247, 0.30),
      Color.fromRGBO(255, 255, 255, 0.08),
      Color.fromRGBO(255, 255, 255, 0.02),
      Color.fromRGBO(168, 85, 247, 0.12),
    ],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    stops: [0.0, 0.35, 0.65, 1.0],
  );

  // ─────────────────────────────────────────────────────────────────────
  // GLASS DESIGN TOKENS
  // ─────────────────────────────────────────────────────────────────────
  static const double blurSubtle    = 8.0;
  static const double blurStandard  = 16.0;
  static const double blurHeavy     = 28.0;
  static const double blurExtreme   = 48.0;

  static const double opacityGlassLow    = 0.04;
  static const double opacityGlassMedium = 0.08;
  static const double opacityGlassHigh   = 0.14;

  // Border Radii
  static const double radiusXS   = 8.0;
  static const double radiusSM   = 12.0;
  static const double radiusMD   = 16.0;
  static const double radiusLG   = 24.0;
  static const double radiusXL   = 32.0;
  static const double radiusFull = 999.0;

  // Spacing (4px grid)
  static const double spaceXS  = 4.0;
  static const double spaceSM  = 8.0;
  static const double spaceMD  = 16.0;
  static const double spaceLG  = 24.0;
  static const double spaceXL  = 32.0;
  static const double space2XL = 48.0;
  static const double space3XL = 64.0;

  // ─────────────────────────────────────────────────────────────────────
  // ANIMATION TOKENS
  // ─────────────────────────────────────────────────────────────────────
  static const Duration liquidFast      = Duration(milliseconds: 180);
  static const Duration liquidMedium    = Duration(milliseconds: 350);
  static const Duration liquidSlow      = Duration(milliseconds: 700);
  static const Duration liquidSlowExtra = Duration(milliseconds: 1100);

  // ─────────────────────────────────────────────────────────────────────
  // GLOW & SHADOW SYSTEM
  // ─────────────────────────────────────────────────────────────────────

  /// Multi-layer violet primary glow
  static List<BoxShadow> glow(Color color, {double intensity = 1.0}) => [
    BoxShadow(
      color: color.withOpacity(0.40 * intensity),
      blurRadius: 14, spreadRadius: -4,
    ),
    BoxShadow(
      color: color.withOpacity(0.22 * intensity),
      blurRadius: 30, spreadRadius: -2,
    ),
    BoxShadow(
      color: color.withOpacity(0.10 * intensity),
      blurRadius: 50, spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get neonGlow => [
    BoxShadow(color: primary.withOpacity(0.45), blurRadius: 20, spreadRadius: 0),
    BoxShadow(color: secondary.withOpacity(0.20), blurRadius: 40, spreadRadius: -8),
  ];

  static List<BoxShadow> elevation({double level = 1.0}) => [
    BoxShadow(
      color: Colors.black.withOpacity(0.20 * level),
      blurRadius: 8 * level, offset: Offset(0, 2 * level),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.10 * level),
      blurRadius: 16 * level, offset: Offset(0, 4 * level),
    ),
  ];

  // ─────────────────────────────────────────────────────────────────────
  // THEME DATA FACTORY
  // ─────────────────────────────────────────────────────────────────────
  static ThemeData create(Color seedColor, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: void_,

      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: accentOrange,
        surface: surface,
        onSurface: textPrimary,
        error: danger,
      ),

      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 36, fontWeight: FontWeight.bold,
          letterSpacing: -1.5, color: textPrimary, height: 1.1,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          fontSize: 28, fontWeight: FontWeight.bold,
          letterSpacing: -1.0, color: textPrimary, height: 1.2,
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary, height: 1.2,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary, height: 1.3,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary, height: 1.4,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary, height: 1.4,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400, color: textSecondary, height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary, height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w400, color: textMuted, height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: 0.5,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary, letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w500, color: textMuted, letterSpacing: 1.0,
        ),
      ),

      cardTheme: CardThemeData(
        color: glassLow,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMD)),
        margin: EdgeInsets.zero,
      ),

      iconTheme: const IconThemeData(color: textSecondary, size: 24),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceSM),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: spaceLG, vertical: spaceMD),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSM)),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary.withOpacity(0.28);
          return glassHigh;
        }),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: glassHigh,
        thumbColor: primary,
        overlayColor: primary.withOpacity(0.20),
        trackHeight: 4,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // LEGACY COMPATIBILITY ALIASES
  // ─────────────────────────────────────────────────────────────────────
  static const Color tectonicVoid    = void_;
  static const Color tectonicSurface = surface;
  static const Color tectonicGlass   = glassLow;
  static const Color tectonicBlue    = secondary;
  static const Color tectonicPurple  = accentViolet;
  static const Color primaryNeon     = primaryLight;
  static const Color secondaryNeon   = secondaryLight;
  static const Color errorNeon       = danger;
  static const Color successNeon     = success;
  static const Color subtle          = Color(0x14A855F7); // violet-tinted subtle
  static const Color error           = danger;
  static const Color accent          = accentOrange;
  static const Color elevated        = surfaceElevated;
  static const Color tertiary        = accentYellow;
  static const double blurStrong     = blurHeavy;

  static List<BoxShadow> glowShadow(Color color, {double intensity = 1.0}) =>
      glow(color, intensity: intensity);

  static List<BoxShadow> softGlow(Color color) => glow(color, intensity: 0.3);

  // Responsive blur utility
  static double responsiveBlur(BuildContext context, double baseBlur) {
    double width = MediaQuery.of(context).size.width;
    if (width < 400) return baseBlur * 0.5;
    if (width < 600) return baseBlur * 0.7;
    return baseBlur;
  }

  static LinearGradient liquidFlow({required Color start, required Color end}) {
    return LinearGradient(
      colors: [start, end],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    );
  }
}
