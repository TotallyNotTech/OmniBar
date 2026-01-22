import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:omni_bar/omni_bar.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Window Manager
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600), // Size of your search bar + results area
    center: true,
    backgroundColor: Colors.transparent, // Crucial for "Glass" effect
    skipTaskbar: true, // Set to true if you don't want it in the Dock
    // titleBarStyle: TitleBarStyle.hidden, // Removes the mac title bar
    alwaysOnTop: true, // Keeps it above other windows
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await hotKeyManager.unregisterAll();

  await initSystemTray();

  runApp(const OmniBarApp());
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
      label: 'Show OmniBar',
      onClicked: (menuItem) async {
        await windowManager.show();
        await windowManager.focus();
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
