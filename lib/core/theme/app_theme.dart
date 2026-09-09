import 'package:flutter/material.dart';

/// Thème visuel de Mealora — inspiré de CookBook (structure, listes
/// groupées, cartes recette avec cœur) avec la palette validée
/// (accent corail/orange + ambre).
///
/// Les deux modes (clair et sombre) suivent la même structure —
/// seules les couleurs de fond/surface changent.
class AppTheme {
  // ============================================================
  // COULEURS DE MARQUE (communes aux deux modes)
  // ============================================================

  static const Color accentPrimary = Color(0xFFE8703C); // corail/orange
  static const Color accentSecondary = Color(0xFFE8A63C); // ambre
  static const Color accentDanger = Color(0xFFE8392C); // like/cœur

  // ============================================================
  // MODE CLAIR
  // ============================================================

  static const Color _lightBackground = Color(0xFFFAF8F4);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceMuted = Color(0xFFF2EEE4);
  static const Color _lightBorder = Color(0xFFEDE8DC);
  static const Color _lightTextPrimary = Color(0xFF2B241B);
  static const Color _lightTextSecondary = Color(0xFFA69C8A);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightBackground,

    colorScheme: ColorScheme.fromSeed(
      seedColor: accentPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: accentPrimary,
      secondary: accentSecondary,
      error: accentDanger,
      surface: _lightSurface,
      onSurface: _lightTextPrimary,
      surfaceContainerHighest: _lightSurfaceMuted,
      outline: _lightBorder,
    ),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _lightTextPrimary),
      bodyMedium: TextStyle(color: _lightTextPrimary),
      titleLarge: TextStyle(
        color: _lightTextPrimary,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: _lightTextPrimary,
        fontWeight: FontWeight.w700,
      ),
      bodySmall: TextStyle(color: _lightTextSecondary),
    ),

    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: _lightTextPrimary,
      titleTextStyle: TextStyle(
        color: _lightTextPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: _lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _lightBorder),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightSurfaceMuted,
      hintStyle: const TextStyle(color: _lightTextSecondary, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentPrimary, width: 1.5),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accentPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _lightTextPrimary,
        side: const BorderSide(color: _lightBorder),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _lightSurface,
      selectedItemColor: accentPrimary,
      unselectedItemColor: _lightTextSecondary,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    dividerTheme: const DividerThemeData(
      color: _lightBorder,
      thickness: 1,
      space: 1,
    ),
  );

  // ============================================================
  // MODE SOMBRE
  // ============================================================

  static const Color _darkBackground = Color(0xFF0E0E0E);
  static const Color _darkSurface = Color(0xFF1B1B1B);
  static const Color _darkSurfaceMuted = Color(0xFF221F1B);
  static const Color _darkBorder = Color(0xFF262626);
  static const Color _darkTextPrimary = Color(0xFFF0EDE6);
  static const Color _darkTextSecondary = Color(0xFF8A8378);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkBackground,

    colorScheme: ColorScheme.fromSeed(
      seedColor: accentPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accentPrimary,
      secondary: accentSecondary,
      error: accentDanger,
      surface: _darkSurface,
      onSurface: _darkTextPrimary,
      surfaceContainerHighest: _darkSurfaceMuted,
      outline: _darkBorder,
    ),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _darkTextPrimary),
      bodyMedium: TextStyle(color: _darkTextPrimary),
      titleLarge: TextStyle(
        color: _darkTextPrimary,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: _darkTextPrimary,
        fontWeight: FontWeight.w700,
      ),
      bodySmall: TextStyle(color: _darkTextSecondary),
    ),

    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: _darkTextPrimary,
      titleTextStyle: TextStyle(
        color: _darkTextPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: _darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _darkBorder),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurfaceMuted,
      hintStyle: const TextStyle(color: _darkTextSecondary, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentPrimary, width: 1.5),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accentPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _darkTextPrimary,
        side: const BorderSide(color: _darkBorder),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _darkSurface,
      selectedItemColor: accentPrimary,
      unselectedItemColor: _darkTextSecondary,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    dividerTheme: const DividerThemeData(
      color: _darkBorder,
      thickness: 1,
      space: 1,
    ),
  );
}