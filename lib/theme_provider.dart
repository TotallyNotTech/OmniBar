import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _key = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDark {
    if (_themeMode == ThemeMode.system) {
      // Simple check for system brightness (fallback)
      // For accurate "live" system checking, we rely on MediaQuery in the widget tree
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.reload();

    final String? themeName = prefs.getString(_key);
    if (themeName != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  // Called by Settings Window
  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners(); // Updates Settings Window immediately

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  // Called by Main Window to check for updates
  Future<void> reload() async {
    await _loadTheme();
  }
}
