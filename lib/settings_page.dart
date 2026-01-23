import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  final String? windowId;
  const SettingsPage({super.key, this.windowId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
