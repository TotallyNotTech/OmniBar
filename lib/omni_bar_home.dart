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

  late final List<OmniTool> _tools;
  OmniTool? _activeTool;
  Widget? _activeToolWidget;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _inputScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // final List<OmniTool> _tools = [
  //   JsonFormatTool(),
  //   UuidTool(),
  //   // Later: ColorTool(), UuidTool(), etc.
  // ];

  @override
  void initState() {
    super.initState();
    _tools = [JsonFormatTool(), UuidTool()];
    windowManager.addListener(this);
    _initHotKeys();
    _textController.addListener(_onTextChanged);

    windowManager.setIgnoreMouseEvents(true);
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
      await _hideWindow();
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
    _hideWindow();
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
    // 1. Add this variable to track the tool instance found
    OmniTool? foundTool;

    // Ask every tool: "Can you handle this text?"
    for (final tool in _tools) {
      if (tool.canHandle(text)) {
        // Found one! Build its display.
        foundWidget = tool.buildDisplay(context, text);
        // 2. Capture the tool instance
        foundTool = tool;
        break; // Stop looking once we find a match
      }
    }

    // Update UI if the active tool changed
    if (_activeToolWidget != foundWidget) {
      setState(() {
        _activeToolWidget = foundWidget;
        // 3. IMPORTANT: Update the active tool reference in state
        _activeTool = foundTool; // <-- ADD THIS LINE
      });
    }
  }

  Future<void> _onSubmitted(String value) async {
    // 1. Check if we have an active tool and if it has data to copy
    final dataToCopy = _activeTool?.getCopyableData(value);

    if (dataToCopy != null && dataToCopy.isNotEmpty) {
      // 2. Copy to system clipboard
      await Clipboard.setData(ClipboardData(text: dataToCopy));

      // 3. Close the OmniBar window
      await _hideWindow();
    }
  }

  Future<void> _hideWindow() async {
    // 1. Hide the window visually.
    await windowManager.hide();

    // 2. THE CRITICAL STEP: Tell all tools to reset their internal cache.
    for (final tool in _tools) {
      tool.resetState();
    }

    // 3. Clear text for a clean slate next time.
    _textController.clear();

    // Reset local active tool state variables
    setState(() {
      _activeTool = null;
      _activeToolWidget = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        // Use AnimatedContainer for smooth growing/shrinking
        child: MouseRegion(
          // When mouse enters the visible box, CAPTURE clicks
          onEnter: (_) {
            windowManager.setIgnoreMouseEvents(false);
          },
          // When mouse leaves the visible box, IGNORE clicks (pass through)
          onExit: (_) {
            windowManager.setIgnoreMouseEvents(true);
          },
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
      ),
    );
  }

  // In lib/omni_bar_home.dart

  // In lib/omni_bar_home.dart

  Widget _buildSearchBar() {
    return Scrollbar(
      controller: _inputScrollController,
      thumbVisibility: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          // 👇 NEW: Wrap the TextField in a RawKeyboardListener
          child: Focus(
            onKeyEvent: (FocusNode node, KeyEvent event) {
              // 1. Check if it's a Key Down event for the 'Enter' key
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter) {
                // 2. Check if Shift is NOT pressed.
                if (!HardwareKeyboard.instance.isShiftPressed) {
                  // 3. Manually trigger submission
                  _onSubmitted(_textController.text);

                  // 4. CRITICAL: Tell Flutter we handled this key.
                  // This stops the event from reaching the TextField,
                  // preventing it from inserting a newline \n.
                  return KeyEventResult.handled;
                }
              }
              // If it wasn't plain Enter, let the event pass through to the TextField
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _textController,
              scrollController: _inputScrollController,
              focusNode: _focusNode,
              // onSubmitted is useless for multiline on desktop, so we remove it.
              // onSubmitted: _onSubmitted,
              // textInputAction is also ignored on desktop multiline.
              // textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.white, fontSize: 24),
              maxLines: null,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: TextInputType.multiline,
              scrollPhysics: const ClampingScrollPhysics(),
              decoration: const InputDecoration(
                hintText: "Enter a command...",
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.white54, size: 28),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
