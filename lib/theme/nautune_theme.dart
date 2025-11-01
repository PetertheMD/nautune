import 'package:flutter/material.dart';

class NautuneTheme {
  static const Color deepPurple = Color(0xFF4B1D77);
  static const Color violetAccent = Color(0xFF7A3DF1);
  static const Color surface = Color(0xFF1E102D);

  static ThemeData build() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.dark(
        primary: deepPurple,
        secondary: violetAccent,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}
