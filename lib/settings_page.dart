import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:omni_bar/components/hotkey_recorder.dart';
import 'package:omni_bar/hotkey_provider.dart';
import 'package:omni_bar/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _openOnStartup = false;

  int _pageIndex = 0;

  HotKey _activeHotKey = HotKey(
    key: PhysicalKeyboardKey.keyK,
    modifiers: [HotKeyModifier.meta],
    scope: HotKeyScope.system,
  );

  @override
  void initState() {
    super.initState();
    _loadSavedHotKey();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
  }

  Future<void> _loadSavedHotKey() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('omni_hotkey');

    if (jsonStr != null) {
      try {
        final Map<String, dynamic> hotKeyMap = jsonDecode(jsonStr);
        setState(() {
          _activeHotKey = HotKey.fromJson(hotKeyMap);
        });
      } catch (e) {
        debugPrint("Failed to load hotkey: $e");
      }
    }
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
    } finally {
      Isolate.current.kill(priority: Isolate.immediate);
      super.onWindowClose();
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MacosWindow(
      sidebar: Sidebar(
        minWidth: 200,
        // topOffset:
        //     0, // No extra padding needed since TitleBar handles traffic lights
        builder: (context, scrollController) {
          return SidebarItems(
            currentIndex: _pageIndex,
            onChanged: (index) {
              if (index == 4) return;
              setState(() => _pageIndex = index);
            },
            items: const [
              SidebarItem(
                leading: MacosIcon(Icons.settings_outlined),
                label: Text('General'),
              ),
              SidebarItem(
                leading: MacosIcon(Icons.speed),
                label: Text('Startup'),
              ),
              SidebarItem(
                leading: MacosIcon(Icons.view_agenda_outlined),
                label: Text('Bar Options'),
              ),
              SidebarItem(
                leading: MacosIcon(Icons.extension_outlined),
                label: Text('Plugins'),
              ),
              SidebarItem(
                label: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 8,
                  ), // Add breathing room
                  child: Divider(
                    height: 1,
                    color:
                        MacosColors.systemGrayColor, // Or use .withOpacity(0.3)
                  ),
                ),
              ),
              SidebarItem(
                label: Text('About OmniBar'),
                leading: MacosIcon(Icons.info_outline),
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
                child: _buildPageContent(_pageIndex, themeProvider),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(int index, ThemeProvider themeProvider) {
    switch (index) {
      case 0: // General
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: "Appearance",
              subtitle:
                  "Choose the color theme the OmniBar uses. \nYou can either choose light, dark or to follow the system settings.",
            ),
            _buildMacosRadioRow(
              title: "System Default",
              value: ThemeMode.system,
              themeProvider: themeProvider,
              onChanged: (v) => themeProvider.setTheme(v),
            ),
            _buildMacosRadioRow(
              title: "Light Mode",
              value: ThemeMode.light,
              themeProvider: themeProvider,
              onChanged: (v) => themeProvider.setTheme(v),
            ),
            _buildMacosRadioRow(
              title: "Dark Mode",
              value: ThemeMode.dark,
              themeProvider: themeProvider,
              onChanged: (v) => themeProvider.setTheme(v),
            ),
            SizedBox(height: 20),
            _buildSectionHeader(
              title: "Trigger Hotkey",
              subtitle:
                  "You can configure a hotkey to toggle the visibility of OmniBar.",
            ),
            HotKeyRecorderComponent(
              key: ValueKey(_activeHotKey.identifier),
              initialHotKey: _activeHotKey,
              onStartRecording: () async {
                await hotKeyManager.unregister(_activeHotKey);
                debugPrint("Paused current hotkey for recording");
              },

              onStopRecording: () async {
                // Do nothing — main window will rebind properly after save
              },

              onHotKeyRecorded: (newHotKey) async {
                // Pause old binding locally
                await hotKeyManager.unregister(_activeHotKey);

                setState(() {
                  _activeHotKey = newHotKey;
                });

                // 🔥 Tell provider (this saves + notifies main window)
                await Provider.of<HotKeyProvider>(
                  context,
                  listen: false,
                ).setHotKey(newHotKey);

                debugPrint("Hotkey updated via provider: $newHotKey");
              },
            ),
            const SizedBox(height: 10),
            Text(
              "Tip: Pressing ESCAPE hides the bar.",
              style: MacosTheme.of(context).typography.caption1.copyWith(
                color: MacosColors.systemGrayColor,
              ),
            ),
          ],
        );
      case 1: // Startup
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: "System Startup",
              subtitle:
                  "These settings impact the way and when OmniBar starts.",
            ),
            _buildMacosSwitchRow(
              title: "Start at Login",
              subtitle: "Launch OmniBar automatically when you sign in.",
              value: _startAtLogin,
              onChanged: (val) => setState(() => _startAtLogin = val),
            ),
            const SizedBox(height: 20),
            _buildMacosSwitchRow(
              title: "Open OmniBar at Startup",
              subtitle:
                  "Open the OmniBar window immediately after you open the program.",
              value: _openOnStartup,
              onChanged: (val) => setState(() => _openOnStartup = val),
            ),
          ],
        );
      case 2: // Bar Options
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(title: "Bar Configuration"),
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

  Widget _buildSectionHeader({required String title, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MacosTheme.of(context).typography.headline.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: MacosColors.systemGrayColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),

            Text(
              subtitle,
              style: MacosTheme.of(context).typography.caption1.copyWith(
                color: MacosColors.systemGrayColor,
              ),
            ),
          ],
        ],
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
    required ThemeProvider themeProvider,
    required Function(ThemeMode) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          MacosRadioButton<ThemeMode>(
            value: value,
            groupValue: themeProvider.themeMode,
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
          const SizedBox(width: 8),
          Text(title, style: MacosTheme.of(context).typography.body),
        ],
      ),
    );
  }
}
