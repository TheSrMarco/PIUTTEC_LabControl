import 'package:flutter/material.dart';

class PiuttecTheme {
  static const Color primaryDark = Color(0xFF0A4336);
  static const Color primaryGreen = Color(0xFF14745E);
  static const Color accentMint = Color(0xFFE6F2EF);
  static const Color background = Color(0xFFF3F6F5);
  static const Color cardSurface = Colors.white;
  static const Color warningAmber = Color(0xFFD97706);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: primaryDark,
        surface: cardSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
    );
  }
}