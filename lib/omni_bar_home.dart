import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:omni_bar/json_tool.dart';
import 'package:omni_bar/omni_tools.dart';
import 'package:omni_bar/uuid_tool.dart';
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

  final TextEditingController _textController = TextEditingController();
  final ScrollController _inputScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<OmniTool> _tools = [
    JsonFormatTool(),
    UuidTool(),
    // Later: ColorTool(), UuidTool(), etc.
  ];

  Widget? _activeToolWidget;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initHotKeys();
    _textController.addListener(_onTextChanged);
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
      _textController.clear();
    } else {
      await windowManager.show();
      await windowManager.focus(); // Force focus so you can type immediately
      Future.delayed(const Duration(milliseconds: 50), () {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void onWindowBlur() {
    // Feature: Auto-hide when user clicks away
    windowManager.hide();
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputScrollController.dispose();
    _focusNode.dispose();
    windowManager.removeListener(this);
    hotKeyManager.unregister(_hotKey);
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text;
    Widget? foundWidget;

    // Ask every tool: "Can you handle this text?"
    for (final tool in _tools) {
      if (tool.canHandle(text)) {
        // Found one! Build its display.
        foundWidget = tool.buildDisplay(context, text);
        break; // Stop looking once we find a match
      }
    }

    // Update UI if the active tool changed
    if (_activeToolWidget != foundWidget) {
      setState(() {
        _activeToolWidget = foundWidget;
      });
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        // Use AnimatedContainer for smooth growing/shrinking
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 700,
          // NO FIXED HEIGHT. Let the column define it.
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Shrink to fit content
                children: [
                  _buildSearchBar(),
                  // 5. Display the active tool result if it exists
                  if (_activeToolWidget != null) ...[
                    Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                    _activeToolWidget!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // In lib/omni_bar_home.dart

  Widget _buildSearchBar() {
    // Wrap in a Scrollbar so the user sees they can scroll
    return Scrollbar(
      controller: _inputScrollController,
      thumbVisibility: true,
      // Wrap in ConstrainedBox to limit height to 200 pixels
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _textController,
            // Link the TextField to our new scroll controller
            scrollController: _inputScrollController,
            focusNode: _focusNode,
            style: const TextStyle(color: Colors.white, fontSize: 24),
            // maxLines: null + constraints = scrollable multiline area
            maxLines: null,
            textAlignVertical: TextAlignVertical.center,
            keyboardType: TextInputType.multiline,
            // Clamping physics feels better for small desktop inputs
            scrollPhysics: const ClampingScrollPhysics(),
            decoration: const InputDecoration(
              hintText: "Type a command...",
              hintStyle: TextStyle(color: Colors.white24),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.white54, size: 28),
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
