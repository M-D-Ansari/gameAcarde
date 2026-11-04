import 'package:flutter/material.dart';

/// Skeuomorphic & Tactile Arcade Theme Tokens
class AppColors {
  // Rich Arcade Cabinet Tones (Physical Materials)
  static const Color darkSlate = Color(0xFF0D1117);
  static const Color chassisBlack = Color(0xFF161B22);
  static const Color consoleBevel = Color(0xFF21262D);
  static const Color brushedMetal = Color(0xFF30363D);
  static const Color tactileSurface = Color(0xFF1F242C);
  static const Color recessedSlot = Color(0xFF080B0F);

  // Vibrant Physical LED & Neon Pigments
  static const Color electricCyan = Color(0xFF00E5FF);
  static const Color arcadeMagenta = Color(0xFFFF2A85);
  static const Color arcadeAmber = Color(0xFFFFB300);
  static const Color laserGreen = Color(0xFF00E676);
  static const Color warningRed = Color(0xFFFF1744);

  // Legacy mappings for backwards-compatibility
  static const Color voidSlate = darkSlate;
  static const Color onyxNavy = chassisBlack;
  static const Color carbonCard = tactileSurface;
  static const Color mutedSilver = brushedMetal;
  static const Color neonCyan = electricCyan;
  static const Color neonBlue = Color(0xFF4FACFE);
  static const Color cyberMagenta = arcadeMagenta;
  static const Color cyberPurple = Color(0xFF7000FF);
  static const Color solGold = arcadeAmber;
  static const Color emeraldGreen = laserGreen;
  static const Color crimsonFlare = warningRed;

  static const LinearGradient brandGradient = LinearGradient(
    colors: [electricCyan, Color(0xFF0091EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [arcadeMagenta, Color(0xFFC2185B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [arcadeAmber, Color(0xFFE65100)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkSlate,
      primaryColor: AppColors.electricCyan,
      cardColor: AppColors.tactileSurface,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.electricCyan,
        secondary: AppColors.arcadeMagenta,
        surface: AppColors.chassisBlack,
        background: AppColors.darkSlate,
        error: AppColors.warningRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.chassisBlack,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class SkeuomorphicDecorations {
  /// Realistic 3D arcade push button with tactile relief & bevel
  static BoxDecoration arcadeButton({
    required Color baseColor,
    bool isPressed = false,
    double radius = 16.0,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isPressed
            ? [
                baseColor.withOpacity(0.8),
                baseColor,
              ]
            : [
                baseColor,
                HSLColor.fromColor(baseColor)
                    .withLightness((HSLColor.fromColor(baseColor).lightness - 0.15).clamp(0.0, 1.0))
                    .toColor(),
              ],
      ),
      boxShadow: isPressed
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                offset: const Offset(0, 5),
                blurRadius: 4,
              ),
              BoxShadow(
                color: baseColor.withOpacity(0.35),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
      border: Border(
        top: BorderSide(
          color: isPressed ? Colors.transparent : Colors.white.withOpacity(0.4),
          width: 1.5,
        ),
        bottom: BorderSide(
          color: Colors.black.withOpacity(0.5),
          width: 2.5,
        ),
      ),
    );
  }

  /// Recessed inset tray for display panels & boards
  static BoxDecoration recessedSlot({double radius = 16.0}) {
    return BoxDecoration(
      color: AppColors.recessedSlot,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.9),
          offset: const Offset(2, 2),
          blurRadius: 4,
          spreadRadius: -1,
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.05),
          offset: const Offset(-1, -1),
          blurRadius: 2,
        ),
      ],
      border: Border.all(
        color: AppColors.consoleBevel,
        width: 1.2,
      ),
    );
  }

  /// Bento card with tactile depth and acrylic bevel
  static BoxDecoration bentoCard({
    Color? surfaceColor,
    Color? accentColor,
    double radius = 22.0,
  }) {
    final bg = surfaceColor ?? AppColors.tactileSurface;
    final accent = accentColor ?? AppColors.electricCyan;

    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          bg.withRed((bg.red + 8).clamp(0, 255)),
          bg,
        ],
      ),
      border: Border.all(
        color: accent.withOpacity(0.25),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.6),
          offset: const Offset(0, 6),
          blurRadius: 16,
          spreadRadius: -2,
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.04),
          offset: const Offset(0, 1),
          blurRadius: 0,
        ),
      ],
    );
  }
}
