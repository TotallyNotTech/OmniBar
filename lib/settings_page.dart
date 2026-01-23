import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:window_manager/window_manager.dart';

class SettingsPage extends StatefulWidget {
  final String windowId;
  const SettingsPage({super.key, required this.windowId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WindowListener {
  bool _isClosing = false;
  bool _startAtLogin = false;

  // 1. New State Variable for Theme Mode
  ThemeMode _themeMode = ThemeMode.system;

  int _pageIndex = 0;

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

  void _updateThemeMode(ThemeMode? newMode) {
    if (newMode != null) {
      setState(() {
        _themeMode = newMode;
      });
      // TODO: Save this preference to shared_preferences or similar
    }
  }

  @override
  Widget build(BuildContext context) {
    return MacosWindow(
      sidebar: Sidebar(
        minWidth: 200,
        // topOffset:
        //     0, // No extra padding needed since TitleBar handles traffic lights
        builder: (context, scrollController) {
          return SidebarItems(
            currentIndex: _pageIndex,
            onChanged: (index) {
              setState(() => _pageIndex = index);
            },
            items: const [
              SidebarItem(
                leading: MacosIcon(Icons.settings),
                label: Text('General'),
              ),
              SidebarItem(
                leading: MacosIcon(Icons.rocket_launch),
                label: Text('Startup'),
              ),
              SidebarItem(
                leading: MacosIcon(Icons.view_agenda),
                label: Text('Bar Options'),
              ),
            ],
          );
        },
      ),
      child: MacosScaffold(
        toolBar: const ToolBar(title: Text("OmniBar Settings")),
        children: [
          ContentArea(
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: _buildPageContent(_pageIndex),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(int index) {
    switch (index) {
      case 0: // General
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Appearance"),
            _buildMacosRadioRow(
              title: "System Default",
              value: ThemeMode.system,
            ),
            _buildMacosRadioRow(title: "Light Mode", value: ThemeMode.light),
            _buildMacosRadioRow(title: "Dark Mode", value: ThemeMode.dark),
          ],
        );
      case 1: // Startup
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("System Startup"),
            _buildMacosSwitchRow(
              title: "Start at Login",
              subtitle: "Launch OmniBar automatically when you sign in.",
              value: _startAtLogin,
              onChanged: (val) => setState(() => _startAtLogin = val),
            ),
          ],
        );
      case 2: // Bar Options
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Bar Configuration"),
            const SizedBox(height: 10),
            Text(
              "Future settings for Bar Width, Height, and Position will go here.",
              style: MacosTheme.of(
                context,
              ).typography.body.copyWith(color: MacosColors.systemGrayColor),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: MacosTheme.of(context).typography.headline.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: MacosColors.systemGrayColor,
        ),
      ),
    );
  }

  Widget _buildMacosSwitchRow({
    required String title,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: MacosTheme.of(context).typography.body),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: MacosTheme.of(context).typography.caption1.copyWith(
                    color: MacosColors.systemGrayColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        MacosSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildMacosRadioRow({
    required String title,
    required ThemeMode value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          MacosRadioButton<ThemeMode>(
            value: value,
            groupValue: _themeMode,
            onChanged: _updateThemeMode,
          ),
          const SizedBox(width: 8),
          Text(title, style: MacosTheme.of(context).typography.body),
        ],
      ),
    );
  }
}
