import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class SettingsPage extends StatefulWidget {
  final String windowId;
  const SettingsPage({super.key, required this.windowId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WindowListener {
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_isClosing) return;
    _isClosing = true;
    try {
      // 3. Hide the Dock icon (Switch app to Accessory mode)
      await windowManager.setSkipTaskbar(true);

      // 4. Give focus back to the previous app
      await _relinquishFocus();

      // 5. Cleanup: Remove listener and allow closing
      windowManager.removeListener(this);
      await windowManager.setPreventClose(false);

      // 6. Final Close
      await windowManager.close();
    } catch (e) {
      debugPrint("Error closing settings: $e");
      // Force close if something fails
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }

  Future<void> _relinquishFocus() async {
    try {
      // 👇👇👇 DIRECT NATIVE CALL 👇👇👇
      // No more "WindowController". Just call the native code directly.
      const channel = MethodChannel('com.omnibar.app/control');
      await channel.invokeMethod('relinquishFocus');
    } catch (e) {
      debugPrint("Failed to send focus signal: $e");
    }
  }

  bool _startAtLogin = false;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OmniBar Settings"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeader("General"),
          SwitchListTile(
            title: const Text("Start at Login"),
            subtitle: const Text(
              "Launch OmniBar automatically when you sign in.",
            ),
            value: _startAtLogin,
            onChanged: (val) => setState(() => _startAtLogin = val),
          ),
          const Divider(),
          _buildHeader("Appearance"),
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: _darkMode,
            onChanged: (val) => setState(() => _darkMode = val),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
    );
  }
}
