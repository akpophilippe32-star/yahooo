import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrôleur global du thème (clair / sombre / système).
///
/// - Persisté localement (SharedPreferences) pour un effet immédiat,
///   même hors ligne ou avant le premier chargement du profil.
/// - `MaterialApp` écoute ce contrôleur (via ListenableBuilder dans
///   main.dart) et se reconstruit dès que le mode change — y compris
///   pendant l'inscription, pour un aperçu en direct.
class ThemeController extends ChangeNotifier {
  static const String _prefsKey = 'theme_mode_preference';

  ThemeController._();

  static final ThemeController instance = ThemeController._();

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// À appeler une fois au démarrage de l'app, avant runApp().
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);

    _mode = _themeModeFromString(stored);

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _themeModeToString(mode));
  }

  static ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// Conversion pratique pour l'enregistrer côté Supabase
  /// (profiles.theme_preference).
  static String themeModeToPreferenceString(ThemeMode mode) =>
      _themeModeToString(mode);
}