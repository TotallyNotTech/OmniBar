import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omni_bar/global_control.dart';
import 'package:omni_bar/providers/hotkey_provider.dart';
import 'package:omni_bar/providers/startup_config_provider.dart';
import 'package:omni_bar/tools/color_tool.dart';
import 'package:omni_bar/tools/json_tool.dart';
import 'package:omni_bar/tools/omni_tools.dart';
import 'package:omni_bar/providers/theme_provider.dart';
import 'package:omni_bar/tools/uuid_tool.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

class OmniBarHome extends StatefulWidget {
  const OmniBarHome({super.key});

  @override
  State<OmniBarHome> createState() => _OmniBarHomeState();
}

class _OmniBarHomeState extends State<OmniBarHome>
    with WindowListener, SingleTickerProviderStateMixin {
  // Define initial hotkey: Cmd + K

  // 2. Animation Controllers defined here
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  late final List<OmniTool> _tools;
  OmniTool? _activeTool;
  Widget? _activeToolWidget;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _inputScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  StartupConfigProvider startupConfigProvider = StartupConfigProvider();

  @override
  void initState() {
    super.initState();

    // 1. Initialize purely local variables (Controllers)
    OmniController.registerCallback(_toggleWindow);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _tools = [JsonFormatTool(), UuidTool(), ColorTool()];
    windowManager.addListener(this);
    _textController.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      OmniController.toggleUI = _toggleWindow;
      debugPrint("OmniController.toggleUI assigned in post frame");
    });

    // 2. Start the one and only setup sequence
    _setupApp();
  }

  Future<void> _setupApp() async {
    // We don't load or init hotkeys here anymore!
    // main.dart handles that globally.

    // Just start animations and request focus
    _animController.forward().whenComplete(() {
      if (mounted) {
        windowManager.setIgnoreMouseEvents(false);
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void onWindowFocus() {
    // 👇 RELOAD THEME ON FOCUS
    // This ensures that if you changed settings and clicked back to the bar,
    // the new theme applies instantly.
    context.read<ThemeProvider>().reload();
    context.read<HotKeyProvider>().reload();
  }

  // 4. Updated Toggle Logic to handle animations
  Future<void> _toggleWindow() async {
    // Prevent duplicate calls
    if (_animController.status == AnimationStatus.reverse) {
      return;
    }
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

    await _animController.reverse().orCancel;

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
    // if (OmniController.toggleUI == _toggleWindow) {
    //   OmniController.toggleUI = null;
    // }
    _animController.dispose(); // Don't forget to dispose controller
    _textController.dispose();
    _inputScrollController.dispose();
    _focusNode.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    OmniController.toggleUI = _toggleWindow;
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
