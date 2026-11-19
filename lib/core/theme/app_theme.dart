import 'package:flutter/material.dart';

class AppTheme {
  // Brand & Action
  static const Color primary = Color(0xFF0F172A); // Slate 900 / Graphite
  static const Color accent = Color(0xFF0F4C3A); // ABC Retail Signature Forest Green
  static const Color accentBg = Color(0xFFECFDF5); // Emerald 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color muted = Color(0xFF64748B); // Slate 500
  static const Color subtle = Color(0xFF94A3B8); // Slate 400

  // Semantic Status
  static const Color success = Color(0xFF047857); // Emerald 700
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFB45309); // Amber 700
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFC1121F); // Red 700
  static const Color dangerBg = Color(0xFFFEF2F2);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: danger,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: primary, size: 20),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: subtle, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
    );
  }
}
