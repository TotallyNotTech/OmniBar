import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:omni_bar/omni_bar.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Window Manager
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600), // Size of your search bar + results area
    center: true,
    backgroundColor: Colors.transparent, // Crucial for "Glass" effect
    skipTaskbar: false, // Set to true if you don't want it in the Dock
    titleBarStyle: TitleBarStyle.hidden, // Removes the mac title bar
    alwaysOnTop: true, // Keeps it above other windows
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await hotKeyManager.unregisterAll();

  runApp(const OmniBarApp());
}

class OmniBarApp extends StatelessWidget {
  const OmniBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const OmniBarHome());
  }
}
