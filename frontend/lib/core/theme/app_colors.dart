import 'package:flutter/material.dart';

class AppColors {
  // ─── Brand ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF5C1D24); // Deep Maroon
  static const Color secondary = Color(0xFFDEB059); // Gold/Yellow

  // ─── Backgrounds ────────────────────────────────────────────────────
  static const Color bgDark =
      Color(0xFFFDECD4); // Peach gradient background base
  static const Color bgCard = Color(0xFFFFFFFF); // White cards where applicable
  static const Color bgSurface = Color(0xFFFDECD4);
  static const Color bgElevated = Color(0xFFF9DCBA);

  // ─── Semantic ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFDEB059);
  static const Color info = Color(0xFF0EA5E9);

  // ─── Text ───────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF2E1A1D); // Dark text on light bg
  static const Color textSecondary = Color(0xFF6B4D51);
  static const Color textMuted = Color(0xFFA68B8E);
  static const Color textOnPrimary = Color(0xFFFDECD4); // Light text on maroon

  // ─── Borders / Dividers ─────────────────────────────────────────────
  static const Color border = Color(0xFFE5C8B0);
  static const Color divider = Color(0xFFE5C8B0);

  // ─── Gradients ──────────────────────────────────────────────────────
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [Color(0xFF5C1D24), Color(0xFF7D2731)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientSecondary = LinearGradient(
    colors: [Color(0xFFEAB308), Color(0xFFD97706)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient gradientBackground = LinearGradient(
    colors: [Color(0xFF5C1D24), Color(0xFFF3A183), Color(0xFFFDECD4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.4, 1.0],
  );

  static const LinearGradient gradientSuccess = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientError = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Utility methods ────────────────────────────────────────────────
  /// Returns a color representing the integrity score level.
  static Color integrityScoreColor(int score) {
    if (score >= 90) return success;
    if (score >= 70) return warning;
    return error;
  }

  /// Returns a color based on internship mode.
  static Color modeColor(String mode) => switch (mode.toLowerCase()) {
        'remote' => success,
        'onsite' => info,
        _ => warning,
      };
}
