import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color cardSurface = Color(0xFF1E293B); // Slate 800
  static const Color cardBorder = Color(0xFF334155); // Slate 700

  static const Color primaryCyan = Color(0xFF06B6D4); // Cyan 500
  static const Color secondaryViolet = Color(0xFF8B5CF6); // Violet 500
  static const Color accentEmerald = Color(0xFF10B981); // Emerald 500
  static const Color warningAmber = Color(0xFFF59E0B); // Amber 500
  static const Color errorRose = Color(0xFFF43F5E); // Rose 500

  // Graph axis colors
  static const Color axisX = Color(0xFFEF4444); // Red
  static const Color axisY = Color(0xFF10B981); // Green
  static const Color axisZ = Color(0xFF3B82F6); // Blue

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: secondaryViolet,
        surface: cardSurface,
        error: errorRose,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
