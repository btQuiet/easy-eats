import 'package:flutter/material.dart';

class EatsColors {
  static const cream = Color(0xFFF8F6F1);
  static const forest = Color(0xFF183D33);
  static const coral = Color(0xFFE7654E);
  static const sage = Color(0xFFD9E9DA);
  static const ink = Color(0xFF22302C);
}

ThemeData easyEatsTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: EatsColors.forest,
    primary: EatsColors.forest,
    secondary: EatsColors.coral,
    surface: EatsColors.cream,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: EatsColors.cream,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: EatsColors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: EatsColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: EatsColors.ink,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: EatsColors.ink),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: EatsColors.coral,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
