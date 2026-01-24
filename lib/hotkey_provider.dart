import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HotKeyProvider extends ChangeNotifier {
  static const String _key = 'omni_hotkey';

  static const _syncChannel = MethodChannel('com.omnibar.app/sync');

  HotKey _hotKey = HotKey(
    key: PhysicalKeyboardKey.keyK,
    modifiers: [HotKeyModifier.meta],
    scope: HotKeyScope.system,
  );

  HotKey get hotKey => _hotKey;

  HotKeyProvider() {
    _loadHotKey();
  }

  Future<void> _loadHotKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final String? jsonStr = prefs.getString(_key);

    if (jsonStr != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        _hotKey = HotKey.fromJson(map);
        notifyListeners();
      } catch (e) {
        debugPrint("Failed to load hotkey: $e");
      }
    }
  }

  Future<HotKey> get hotKeyAsync async {
    // Wait until shared prefs loads
    await _loadHotKey();
    return _hotKey;
  }

  // Called by Settings window
  Future<void> setHotKey(HotKey newKey) async {
    // 1. Save to disk
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('omni_hotkey', jsonEncode(newKey.toJson()));

    _hotKey = newKey;
    notifyListeners();

    // 2. BROADCAST: This tells ALL windows to refresh their hotkey listeners
    try {
      await _syncChannel.invokeMethod('hotkeyChanged');
    } catch (e) {
      debugPrint("Sync error: $e");
    }
  }

  // Called by Main window on focus / startup
  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('omni_hotkey');
    if (jsonStr != null) {
      _hotKey = HotKey.fromJson(jsonDecode(jsonStr));
      notifyListeners();
    }
  }
}
