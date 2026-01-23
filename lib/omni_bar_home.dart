import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:omni_bar/json_tool.dart';
import 'package:omni_bar/omni_tools.dart';
import 'package:omni_bar/theme_provider.dart';
import 'package:omni_bar/uuid_tool.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;

VoidCallback? showOmniBarGlobal;

class OmniBarHome extends StatefulWidget {
  const OmniBarHome({super.key});

  @override
  State<OmniBarHome> createState() => _OmniBarHomeState();
}

class _OmniBarHomeState extends State<OmniBarHome>
    with WindowListener, SingleTickerProviderStateMixin {
  // Define initial hotkey: Cmd + K
  final HotKey _hotKey = HotKey(
    key: PhysicalKeyboardKey.keyK,
    modifiers: [HotKeyModifier.meta], // 'Meta' is Command on macOS
    scope: HotKeyScope.system, // Global (works even when app is not focused)
  );
  final HotKey _cancelHotKey = HotKey(
    key: PhysicalKeyboardKey.escape,
    modifiers: [],
    scope: HotKeyScope.inapp,
  );

  // 2. Animation Controllers defined here
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  late final List<OmniTool> _tools;
  OmniTool? _activeTool;
  Widget? _activeToolWidget;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _inputScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // 3. Initialize Animations
    showOmniBarGlobal = _toggleWindow;
    _animController = AnimationController(
      vsync: this,
      // Adjust duration for snappiness vs smoothness
      duration: const Duration(milliseconds: 200),
    );

    // Slide from slightly above (-0.2y) to exactly center (0y)
    // Using easeOutCubic for a nice "settling" effect
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic, // Faster exit
          ),
        );

    // Show on first startup
    _animController.forward().whenComplete(() {
      if (mounted) {
        windowManager.setIgnoreMouseEvents(false);
        _focusNode.requestFocus();
      }
    });

    _tools = [JsonFormatTool(), UuidTool()];
    windowManager.addListener(this);
    _initHotKeys();
    _textController.addListener(_onTextChanged);
    // windowManager.setIgnoreMouseEvents(true);
  }

  void _initHotKeys() async {
    await hotKeyManager.register(
      _hotKey,
      keyDownHandler: (_) => _toggleWindow(),
    );
    await hotKeyManager.register(
      _cancelHotKey,
      keyDownHandler: (_) => _toggleWindow(),
    );
  }

  @override
  void onWindowFocus() {
    // 👇 RELOAD THEME ON FOCUS
    // This ensures that if you changed settings and clicked back to the bar,
    // the new theme applies instantly.
    context.read<ThemeProvider>().reload();
  }

  // 4. Updated Toggle Logic to handle animations
  Future<void> _toggleWindow() async {
    // If it's currently visible or mid-animation showing...
    if (_animController.isCompleted ||
        _animController.status == AnimationStatus.forward) {
      await _hideWindow();
    } else {
      // Opening sequence:
      // 1. Show the native window instantly (it's transparent right now)
      context.read<ThemeProvider>().reload();

      await windowManager.show();
      await windowManager.focus();

      // 2. A tiny pause to let the native window engine wake up. This prevents visual stutter.
      await Future.delayed(const Duration(milliseconds: 50));

      // 3. Start the Flutter entry animation
      _animController.forward();
      _focusNode.requestFocus();
    }
  }

  // 5. Updated Hide Logic to AWAIT animation
  Future<void> _hideWindow() async {
    // Crucial: Prevent mouse interactions during the exit animation
    await windowManager.setIgnoreMouseEvents(true);

    // 1. Play the reverse animation and wait for it to finish.
    // .orCancel handles cases where it's interrupted.
    if (mounted) {
      await _animController.reverse().orCancel;
    }
    // 2. NOW hide the native window, after the UI has visibly gone.
    await windowManager.hide();

    // 3. Cleanup state
    for (final tool in _tools) {
      tool.resetState();
    }
    _textController.clear();
    if (mounted) {
      setState(() {
        _activeTool = null;
        _activeToolWidget = null;
      });
    }
  }

  @override
  void onWindowBlur() {
    // Only auto-hide if we aren't already animating out.
    if (_animController.isCompleted) {
      _hideWindow();
    }
  }

  @override
  void dispose() {
    _animController.dispose(); // Don't forget to dispose controller
    _textController.dispose();
    _inputScrollController.dispose();
    _focusNode.dispose();
    windowManager.removeListener(this);
    hotKeyManager.unregisterAll();
    showOmniBarGlobal = null;
    super.dispose();
  }

  // (... _onTextChanged and _onSubmitted remain exactly the same ...)
  void _onTextChanged() {
    final text = _textController.text;
    Widget? foundWidget;
    OmniTool? foundTool;
    for (final tool in _tools) {
      if (tool.canHandle(text)) {
        foundWidget = tool.buildDisplay(context, text);
        foundTool = tool;
        break;
      }
    }
    if (_activeToolWidget != foundWidget) {
      setState(() {
        _activeToolWidget = foundWidget;
        _activeTool = foundTool;
      });
    }
  }

  Future<void> _onSubmitted(String value) async {
    final dataToCopy = _activeTool?.getCopyableData(value);
    if (dataToCopy != null && dataToCopy.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: dataToCopy));
      await _hideWindow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    bool isDark;
    if (themeProvider.themeMode == ThemeMode.system) {
      isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    } else {
      isDark = themeProvider.themeMode == ThemeMode.dark;
    }
    final backgroundColor = isDark
        ? Colors.black.withOpacity(0.6)
        : Colors.white.withOpacity(0.6);
    final textColor = isDark ? Colors.white : Colors.black;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: MouseRegion(
          onEnter: (_) {
            // Only capture mouse if animation is finished showing
            if (_animController.isCompleted) {
              windowManager.setIgnoreMouseEvents(false);
            }
          },
          onExit: (_) {
            // Only ignore mouse if we don't have focus
            if (!_focusNode.hasFocus) {
              windowManager.setIgnoreMouseEvents(true);
            }
          },
          // 6. Wrap the entire visible container in transitions
          child: FadeTransition(
            opacity: _animController, // Fades in as controller goes 0 -> 1
            child: SlideTransition(
              position:
                  _slideAnimation, // Slides down as controller goes 0 -> 1
              child: AnimatedContainer(
                // Note: This duration defines the *resizing* speed when tools appear.
                // It is separate from the open/close animation speed.
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 700,
                decoration: BoxDecoration(
                  color: backgroundColor,
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
                    child: SingleChildScrollView(
                      primary: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSearchBar(textColor),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            // "easeOutBack" gives it a slight overshoot/pop effect (the whoosh)
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeIn,

                            transitionBuilder: (child, animation) {
                              // Combine 3 animations for the perfect feel:
                              return SizeTransition(
                                sizeFactor:
                                    animation, // 1. Expand vertical space
                                axisAlignment:
                                    -1.0, // Expand from Top to Bottom
                                child: FadeTransition(
                                  opacity: animation, // 2. Fade in
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(
                                        0.0,
                                        -0.2,
                                      ), // 3. Slide down slightly
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                              );
                            },

                            // We switch between "Content" and "Nothing"
                            child: _activeToolWidget != null
                                ? Column(
                                    // 🔑 KEY IS CRITICAL:
                                    // using runtimeType ensures we only animate when the TOOL changes
                                    // (e.g. Nothing -> JSON), not on every single character you type.
                                    key: ValueKey(_activeTool?.runtimeType),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Divider(
                                        height: 1,
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                      _activeToolWidget!,
                                    ],
                                  )
                                : const SizedBox.shrink(), // Empty widget when idle
                          ),
                          // 👆👆👆 END ANIMATION BLOCK 👆👆👆

                          // if (_activeToolWidget != null) ...[
                          //   Divider(
                          //     height: 1,
                          //     color: Colors.white.withOpacity(0.1),
                          //   ),
                          //   _activeToolWidget!,
                          // ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(Color textColor) {
    return Scrollbar(
      controller: _inputScrollController,
      thumbVisibility: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 130),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Focus(
            onKeyEvent: (FocusNode node, KeyEvent event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter) {
                if (!HardwareKeyboard.instance.isShiftPressed) {
                  _onSubmitted(_textController.text);
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _textController,
              scrollController: _inputScrollController,
              focusNode: _focusNode,
              style: TextStyle(color: textColor, fontSize: 24),
              maxLines: null,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: TextInputType.multiline,
              scrollPhysics: const ClampingScrollPhysics(),
              decoration: InputDecoration(
                hintText: "Enter a command...",
                hintStyle: TextStyle(color: textColor),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: textColor, size: 28),
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
