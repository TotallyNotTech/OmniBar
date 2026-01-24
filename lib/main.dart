import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:omni_bar/global_control.dart';
import 'package:omni_bar/hotkey_provider.dart';
import 'package:omni_bar/omni_bar_home.dart';
import 'package:omni_bar/settings_page.dart';
import 'package:omni_bar/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';

Future<void> rebindGlobalHotKey() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final String? jsonStr = prefs.getString('omni_hotkey');

  HotKey activeKey = HotKey(
    key: PhysicalKeyboardKey.keyK,
    modifiers: [HotKeyModifier.meta],
    scope: HotKeyScope.system,
  );

  if (jsonStr != null) {
    try {
      activeKey = HotKey.fromJson(jsonDecode(jsonStr));
      print(activeKey.toJson());
    } catch (e) {
      debugPrint("Failed to parse hotkey: $e");
    }
  }

  // 1. Clear existing bindings
  await hotKeyManager.unregisterAll();

  await Future.delayed(const Duration(milliseconds: 50));

  // 2. Register Global Toggle
  await hotKeyManager.register(
    activeKey,
    keyDownHandler: (_) {
      debugPrint("Hotkey detected.");
      OmniController.executeToggle(); // This now calls DesktopMultiWindow.invokeMethod(0, ...)
    },
  );

  // await hotKeyManager.register(
  //   activeKey,
  //   keyDownHandler: (_) {
  //     debugPrint("Hotkey detected, triggering toggle...");
  //     OmniController.executeToggle();
  //   },
  // );

  // 3. Register Escape (Always useful to have globally bound to the hide logic)
  await hotKeyManager.register(
    HotKey(key: PhysicalKeyboardKey.escape, scope: HotKeyScope.inapp),
    keyDownHandler: (_) {
      debugPrint("Hotkey detected, triggering toggle...");
      OmniController.executeToggle();
    },
  );

  print("Active Key: ${activeKey.physicalKey}");
  print(
    "Registered Keys: ${hotKeyManager.registeredHotKeyList.map((item) => item.physicalKey)}",
  );

  debugPrint(
    "Main Isolate: System-wide HotKey active: ${activeKey.identifier}",
  );
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  if (args.firstOrNull == 'multi_window') {
    final windowController = await WindowController.fromCurrentEngine();
    final argument =
        jsonDecode(windowController.arguments) as Map<String, dynamic>;

    await _startSettingsWindow(windowController.windowId, argument);
  } else {
    const syncChannel = MethodChannel('com.omnibar.app/sync');
    syncChannel.setMethodCallHandler((call) async {
      if (call.method == 'hotkeyChanged') {
        await rebindGlobalHotKey();
      }
      return null;
    });

    await _startOmniBarApp();
    Future.delayed(const Duration(milliseconds: 500), () {
      rebindGlobalHotKey();
    });
  }
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
    alwaysOnTop: true, // Keeps it above other windows
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    Offset currentPos = await windowManager.getPosition();

    // Use current position to move the window down
    await windowManager.setPosition(Offset(currentPos.dx, topOffset));

    await windowManager.show();
    await windowManager.focus();
  });

  await initSystemTray();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HotKeyProvider()),
      ],
      child: const OmniBarApp(),
    ),
  );
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
    titleBarStyle: TitleBarStyle.hidden,
  );

  // Wait until it's ready, then show it
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HotKeyProvider()),
      ],
      child: SettingsWindowEntry(windowId: windowId, args: args),
    ),
  );
}

Future<void> initSystemTray() async {
  final SystemTray systemTray = SystemTray();

  // Initialize the tray with the path to the real file
  await systemTray.initSystemTray(
    iconPath: "assets/tray_icon.png",
    isTemplate: true,
  );

  // Define the Menu
  final Menu menu = Menu();
  await menu.buildFrom([
    MenuItemLabel(
      label: 'Toggle OmniBar',
      onClicked: (menuItem) async {
        OmniController.executeToggle();
      },
    ),
    MenuItemLabel(
      label: 'Settings',
      onClicked: (_) async {
        final subWindowIds = await WindowController.getAll();
        print(
          "you have ${subWindowIds.map((id) => id.arguments)} windows open",
        );
        // To prevent duplicate windows, we check if the window is already open
        if (subWindowIds.any(
          (single) => single.arguments.contains("settings_init"),
        )) {
          final activeId = subWindowIds
              .firstWhere(
                (single) => single.arguments.contains("settings_init"),
              )
              .windowId;
          await WindowController.fromWindowId(activeId).show();
        } else {
          // Create the new window using WindowController
          await WindowController.create(
            WindowConfiguration(
              arguments: jsonEncode({'action': 'settings_init'}),
            ),
          );
        }
      },
    ),
    MenuSeparator(),
    MenuItemLabel(
      label: 'Quit',
      onClicked: (menuItem) {
        // Gracefully terminate the background app
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
