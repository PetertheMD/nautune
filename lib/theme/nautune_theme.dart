import 'package:flutter/material.dart';

class NautuneTheme {
  static const Color deepPurple = Color(0xFF4B1D77);
  static const Color violetAccent = Color(0xFF7A3DF1);
  static const Color surface = Color(0xFF1E102D);
  static const Color oceanBlue = Color(0xFF409CFF);  // Ocean blue for text

  static ThemeData build() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.dark(
        primary: deepPurple,
        secondary: violetAccent,
        tertiary: oceanBlue,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: oceanBlue),  // Track listings use ocean blue
        bodySmall: TextStyle(color: oceanBlue),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: oceanBlue),
      ),
    );
  }
}
