import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartupConfigProvider extends ChangeNotifier {
  static const String _key = 'show_at_startup';
  bool _showOnStartup = false;

  bool get showOnStartup => _showOnStartup;

  StartupConfigProvider() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.reload();

    final String? startupConfig = prefs.getString(_key);
    if (startupConfig != null && bool.tryParse(startupConfig) != null) {
      _showOnStartup = bool.parse(startupConfig);
      notifyListeners();
    }
  }

  // Called by Settings Window
  Future<void> setConfig(bool value) async {
    _showOnStartup = value;
    notifyListeners(); // Updates Settings Window immediately

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.toString());
  }

  // Called by Main Window to check for updates
  Future<void> reload() async {
    await _loadConfig();
  }
}
