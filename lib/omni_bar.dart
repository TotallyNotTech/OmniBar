import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:ui' as ui;

class OmniBarHome extends StatefulWidget {
  const OmniBarHome({super.key});

  @override
  State<OmniBarHome> createState() => _OmniBarHomeState();
}

class _OmniBarHomeState extends State<OmniBarHome> with WindowListener {
  // Define initial hotkey: Cmd + K
  final HotKey _hotKey = HotKey(
    key: PhysicalKeyboardKey.keyK,
    modifiers: [HotKeyModifier.meta], // 'Meta' is Command on macOS
    scope: HotKeyScope.system, // Global (works even when app is not focused)
  );

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initHotKeys();
  }

  void _initHotKeys() async {
    try {
      await hotKeyManager.register(
        _hotKey,
        keyDownHandler: (hotKey) {
          _toggleWindow();
        },
      );
      print("Hotkey registered successfully");
    } catch (e) {
      print("CRITICAL ERROR registering hotkey: $e");
    }
  }

  Future<void> _toggleWindow() async {
    bool isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus(); // Force focus so you can type immediately
    }
  }

  @override
  void onWindowBlur() {
    // Feature: Auto-hide when user clicks away
    windowManager.hide();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    hotKeyManager.unregister(_hotKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We wrap in a transparent Scaffold to allow custom shapes
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          width: 700,
          height: 100, // Start small (just the bar)
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: 0.5,
            ), // Semi-transparent dark mode
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            // The Glassmorphism blur
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              // CHANGED: Use 'ui.ImageFilter' instead of 'section.ui.ImageFilter'
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: _buildSearchBar(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return const Center(
      child: TextField(
        style: TextStyle(color: Colors.white, fontSize: 24),
        decoration: InputDecoration(
          hintText: "What do you need?",
          hintStyle: TextStyle(color: Colors.white54),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: Colors.white54, size: 30),
          contentPadding: EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }
}
