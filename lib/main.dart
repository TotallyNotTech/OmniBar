import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:omni_bar/omni_bar_home.dart';
import 'package:omni_bar/settings_page.dart';
import 'package:omni_bar/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Window Manager
  await windowManager.ensureInitialized();

  if (args.firstOrNull == 'multi_window') {
    final windowController = await WindowController.fromCurrentEngine();
    final argument =
        jsonDecode(windowController.arguments) as Map<String, dynamic>;

    // 1. FIX: Call a setup function for the Settings Window
    await _startSettingsWindow(windowController.windowId, argument);
  } else {
    await _startOmniBarApp();
  }

  // const Size windowSize = Size(800, 600);
  // const double topOffset = 350.0;

  // WindowOptions windowOptions = const WindowOptions(
  //   size: windowSize, // Size of your search bar + results area
  //   center: true,
  //   backgroundColor: Colors.transparent, // Crucial for "Glass" effect
  //   skipTaskbar: true, // Set to true if you don't want it in the Dock
  //   // titleBarStyle: TitleBarStyle.hidden, // Removes the mac title bar
  //   alwaysOnTop: true, // Keeps it above other windows
  // );

  // await windowManager.waitUntilReadyToShow(windowOptions, () async {
  //   Offset currentPos = await windowManager.getPosition();

  //   // Use current position to move the window down
  //   await windowManager.setPosition(Offset(currentPos.dx, topOffset));

  //   await windowManager.show();
  //   await windowManager.focus();
  // });

  // await hotKeyManager.unregisterAll();

  // await initSystemTray();

  // runApp(const OmniBarApp());
}

Future<void> _startOmniBarApp() async {
  await windowManager.ensureInitialized();

  const Size windowSize = Size(800, 600);
  const double topOffset = 350.0;

  WindowOptions windowOptions = const WindowOptions(
    size: windowSize, // Size of your search bar + results area
    center: true,
    backgroundColor: Colors.transparent, // Crucial for "Glass" effect
    skipTaskbar: true, // Set to true if you don't want it in the Dock
    // titleBarStyle: TitleBarStyle.hidden, // Removes the mac title bar
    alwaysOnTop: true, // Keeps it above other windows
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    Offset currentPos = await windowManager.getPosition();

    // Use current position to move the window down
    await windowManager.setPosition(Offset(currentPos.dx, topOffset));

    await windowManager.show();
    await windowManager.focus();
  });

  await hotKeyManager.unregisterAll();
  await initSystemTray();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const OmniBarApp(),
    ),
  );

  // runApp(const OmniBarApp());
}

Future<void> _startSettingsWindow(
  String windowId,
  Map<String, dynamic> args,
) async {
  // Initialize window manager inside this new isolate
  await windowManager.ensureInitialized();

  // Define how the settings window should look
  WindowOptions windowOptions = const WindowOptions(
    size: Size(700, 650),
    center: true,
    backgroundColor: Colors.transparent, // Or standard colors
    skipTaskbar: false, // Settings should appear in taskbar
    // titleBarStyle: TitleBarStyle.normal, // Standard title bar
    // title: "OmniBar Settings",
    titleBarStyle: TitleBarStyle.hidden,
  );

  // Wait until it's ready, then show it
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: SettingsWindowEntry(windowId: windowId, args: args),
    ),
  );

  // runApp(SettingsWindowEntry(windowId: windowId, args: args));
}

Future<void> initSystemTray() async {
  final SystemTray systemTray = SystemTray();

  // Initialize the tray with the path to the real file
  await systemTray.initSystemTray(
    title: "", // No text, just the icon
    iconPath: "assets/tray_icon.png",
    isTemplate: true,
  );

  // Define the Menu
  final Menu menu = Menu();
  await menu.buildFrom([
    // A regular item with a direct callback
    MenuItemLabel(
      label: 'Toggle OmniBar',
      onClicked: (menuItem) async {
        showOmniBarGlobal?.call();
      },
    ),
    MenuItemLabel(
      label: 'Settings',
      onClicked: (_) async {
        // Create the new window using WindowController
        await WindowController.create(
          WindowConfiguration(
            arguments: jsonEncode({'action': 'settings_init'}),
          ),
        );
      },
    ),
    MenuSeparator(),
    MenuItemLabel(
      label: 'Quit',
      onClicked: (menuItem) {
        // This is how you fully terminate the background app
        exit(0);
      },
    ),
  ]);

  // Attach the menu to the tray icon
  await systemTray.setContextMenu(menu);

  // Handle clicking the icon itself to show the menu
  systemTray.registerSystemTrayEventHandler((eventName) {
    debugPrint("Tray Event: $eventName");
    if (eventName == kSystemTrayEventClick ||
        eventName == kSystemTrayEventRightClick) {
      systemTray.popUpContextMenu();
    }
  });
}

class OmniBarApp extends StatelessWidget {
  const OmniBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const OmniBarHome());
  }
}

class SettingsWindowEntry extends StatelessWidget {
  final String windowId;
  final Map<String, dynamic>? args;

  const SettingsWindowEntry({super.key, required this.windowId, this.args});

  @override
  Widget build(BuildContext context) {
    // TODO: implement light mode for settings page
    // This is currently blocked by a Bug in Macos UI
    // https://github.com/macosui/macos_ui/pull/588

    final themeMode = ThemeMode.dark;
    return MacosApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      home: SettingsPage(windowId: windowId),
    );
  }
}
