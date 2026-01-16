import 'package:flutter/material.dart';

/// Represents a color palette for the Nautune app theme
class NautuneColorPalette {
  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final bool isLight; // Whether this is a light theme

  const NautuneColorPalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    this.isLight = false,
  });

  /// Build a ThemeData from this palette
  ThemeData buildTheme() {
    if (isLight) {
      return _buildLightTheme();
    }
    return _buildDarkTheme();
  }

  ThemeData _buildLightTheme() {
    final onSurface = Color(0xFF1A1A1A);
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: textPrimary,
        surface: surface,
        onSurface: onSurface,
        onPrimary: Colors.white,
        onSecondary: onSurface,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: onSurface),
        bodySmall: TextStyle(color: onSurface),
        bodyLarge: TextStyle(color: onSurface),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: onSurface),
        titleMedium: TextStyle(color: onSurface),
        titleSmall: TextStyle(color: textSecondary),
        labelLarge: TextStyle(color: onSurface),
        labelMedium: TextStyle(color: textSecondary),
        labelSmall: TextStyle(color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: primary.withValues(alpha: 0.1),
      ),
      listTileTheme: ListTileThemeData(
        textColor: onSurface,
        iconColor: primary,
      ),
      iconTheme: IconThemeData(
        color: primary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: primary.withValues(alpha: 0.3),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary.withValues(alpha: 0.5);
          return textSecondary.withValues(alpha: 0.3);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Color.alphaBlend(primary.withValues(alpha: 0.9), surface),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      dividerTheme: DividerThemeData(
        color: onSurface.withValues(alpha: 0.1),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primary.withValues(alpha: 0.1),
        labelStyle: TextStyle(color: onSurface),
        selectedColor: primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        titleTextStyle: TextStyle(color: onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: textSecondary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        textStyle: TextStyle(color: onSurface),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.2),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: textPrimary,
        surface: surface,
        onSurface: textPrimary,
        onPrimary: textPrimary,
        onSecondary: textSecondary,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textPrimary),
        bodyLarge: TextStyle(color: textPrimary),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
        titleMedium: TextStyle(color: textPrimary),
        titleSmall: TextStyle(color: textSecondary),
        labelLarge: TextStyle(color: textPrimary),
        labelMedium: TextStyle(color: textSecondary),
        labelSmall: TextStyle(color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Color.alphaBlend(primary.withValues(alpha: 0.1), surface),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: primary,
      ),
      iconTheme: IconThemeData(
        color: primary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: primary.withValues(alpha: 0.3),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary.withValues(alpha: 0.5);
          return textSecondary.withValues(alpha: 0.3);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Color.alphaBlend(primary.withValues(alpha: 0.2), surface),
        contentTextStyle: TextStyle(color: textPrimary),
      ),
      dividerTheme: DividerThemeData(
        color: textSecondary.withValues(alpha: 0.2),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: textPrimary),
        selectedColor: primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: textSecondary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Color.alphaBlend(primary.withValues(alpha: 0.1), surface),
        textStyle: TextStyle(color: textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.3),
      ),
    );
  }
}

/// All available color palettes
class NautunePalettes {
  /// Purple Ocean - The default Nautune theme
  static const purpleOcean = NautuneColorPalette(
    id: 'purple_ocean',
    name: 'Purple Ocean',
    primary: Color(0xFF4B1D77),      // Deep purple
    secondary: Color(0xFF7A3DF1),    // Violet accent
    surface: Color(0xFF1E102D),      // Dark purple surface
    textPrimary: Color(0xFF409CFF),  // Ocean blue
    textSecondary: Color(0xFF8B9DC3), // Muted blue-gray
  );

  /// Apricot Garden - Warm orange with fresh green accents
  static const apricotGarden = NautuneColorPalette(
    id: 'apricot_garden',
    name: 'Apricot Garden',
    primary: Color(0xFFFF8C42),      // Apricot orange
    secondary: Color(0xFFFFAB76),    // Light apricot
    surface: Color(0xFF1A1A2E),      // Dark navy
    textPrimary: Color(0xFF4ADE80),  // Fresh green
    textSecondary: Color(0xFFB5E48C), // Light green
  );

  /// Raspberry Sunset - Bold red with golden yellow
  static const raspberrySunset = NautuneColorPalette(
    id: 'raspberry_sunset',
    name: 'Raspberry Sunset',
    primary: Color(0xFFE63946),      // Raspberry red
    secondary: Color(0xFFFF6B6B),    // Light red
    surface: Color(0xFF1D1128),      // Dark wine
    textPrimary: Color(0xFFFFC947),  // Golden yellow
    textSecondary: Color(0xFFFFE066), // Light yellow
  );

  /// Emerald Rose - Rich green with pink highlights
  static const emeraldRose = NautuneColorPalette(
    id: 'emerald_rose',
    name: 'Emerald Rose',
    primary: Color(0xFF10B981),      // Emerald green
    secondary: Color(0xFF34D399),    // Light emerald
    surface: Color(0xFF0F1419),      // Near black
    textPrimary: Color(0xFFEC4899),  // Rose pink
    textSecondary: Color(0xFFF472B6), // Light pink
  );

  /// OLED Peach - True black OLED with salmon/peach accents
  static const oledPeach = NautuneColorPalette(
    id: 'oled_peach',
    name: 'OLED Peach',
    primary: Color(0xFFFF8A80),      // Salmon/coral
    secondary: Color(0xFFFFAB91),    // Light peach
    surface: Color(0xFF000000),      // Pure black for OLED
    textPrimary: Color(0xFFFFCCBC),  // Cream peach
    textSecondary: Color(0xFF8D6E63), // Warm brown
  );

  /// Light Lavender - Clean white with dark purple accents
  static const lightLavender = NautuneColorPalette(
    id: 'light_lavender',
    name: 'Light Lavender',
    primary: Color(0xFF6B21A8),      // Dark purple
    secondary: Color(0xFF9333EA),    // Vivid purple
    surface: Color(0xFFFAF5FF),      // Very light lavender white
    textPrimary: Color(0xFF581C87),  // Deep purple
    textSecondary: Color(0xFF9CA3AF), // Gray
    isLight: true,
  );

  /// List of all available palettes
  static const List<NautuneColorPalette> all = [
    purpleOcean,
    lightLavender,
    oledPeach,
    apricotGarden,
    raspberrySunset,
    emeraldRose,
  ];

  /// Get a palette by its ID, returns default if not found
  static NautuneColorPalette getById(String id) {
    return all.firstWhere(
      (palette) => palette.id == id,
      orElse: () => purpleOcean,
    );
  }
}

/// Legacy theme class for backwards compatibility
class NautuneTheme {
  static const Color deepPurple = Color(0xFF4B1D77);
  static const Color violetAccent = Color(0xFF7A3DF1);
  static const Color surface = Color(0xFF1E102D);
  static const Color oceanBlue = Color(0xFF409CFF);

  /// Build the default theme (Purple Ocean)
  static ThemeData build() {
    return NautunePalettes.purpleOcean.buildTheme();
  }
}
