import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omni_bar/global_control.dart';
import 'package:omni_bar/omniBar/search_bar.dart';
import 'package:omni_bar/omniBar/search_results.dart';
import 'package:omni_bar/providers/hotkey_provider.dart';
import 'package:omni_bar/providers/startup_config_provider.dart';
import 'package:omni_bar/tools/base64_tool.dart';
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
  late final List<SearchSuggestion> _allSuggestions;

  // Active states
  OmniTool? _activeTool;
  Widget? _activeToolWidget;

  // LOCKED STATE VARIABLES
  OmniTool? _lockedTool;
  String? _lockedTrigger;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _inputScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<SearchSuggestion> _filteredSuggestions = [];

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

    _tools = [JsonFormatTool(), UuidTool(), ColorTool(), Base64Tool()];
    _allSuggestions = _tools.map((e) => e.wakeCommands).toList();

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
        _lockedTool = null;
        _lockedTrigger = null;
        _filteredSuggestions = [];
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

  void _onTextChanged() {
    final text = _textController.text;

    // MODE A: LOCKED (Tool is active, passing payload)
    if (_lockedTool != null) {
      // Pass the raw text directly to the tool. No searching.
      final widget = _lockedTool!.buildDisplay(context, text);

      if (_activeToolWidget != widget) {
        setState(() {
          _activeToolWidget = widget;
        });
      }
      return;
    }

    // MODE B: SEARCH (Filtering suggestions)
    // We do NOT check tool.canHandle here anymore.

    List<SearchSuggestion> newSuggestions = [];
    if (text.trim().isNotEmpty) {
      final lowerText = text.trim().toLowerCase();
      newSuggestions = _allSuggestions.where((s) {
        return s.trigger.any((t) => t.toLowerCase().contains(lowerText));
      }).toList();
    }

    if (_filteredSuggestions != newSuggestions) {
      setState(() {
        _filteredSuggestions = newSuggestions;
        // Ensure no tool is showing while searching/filtering
        _activeToolWidget = null;
        _activeTool = null;
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

  void _acceptSuggestion(SearchSuggestion suggestion) {
    final tool = _tools.firstWhere(
      (t) => t.wakeCommands.description == suggestion.description,
    );
    final trigger = suggestion.trigger.first;

    setState(() {
      _lockedTool = tool;
      _lockedTrigger = trigger;
      _activeTool = tool; // Keep this for copy/paste logic

      // Clear text so user can type payload
      _textController.clear();
      // Hide suggestions
      _filteredSuggestions = [];

      // Initialize tool with empty input
      _activeToolWidget = tool.buildDisplay(context, "");
    });

    // Ensure focus stays on input
    _focusNode.requestFocus();
  }

  void _unlock() {
    setState(() {
      _lockedTool = null;
      _lockedTrigger = null;
      _activeTool = null;
      _activeToolWidget = null;
      _textController.clear();
      _filteredSuggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    print(_allSuggestions.map((e) => e.description));

    print("activeactive $_activeTool");

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

    Widget mainContent;
    Key contentKey;
    if (_activeToolWidget != null) {
      // Case A: A tool is active (result shown)
      contentKey = ValueKey(_activeTool?.runtimeType);
      mainContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: Colors.white.withOpacity(0.1)),
          _activeToolWidget!,
        ],
      );
    } else if (_filteredSuggestions.isNotEmpty) {
      // Case B: No tool, but we have suggestions
      contentKey = const ValueKey('suggestions');
      mainContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: Colors.white.withOpacity(0.1)),
          // 6. Build the Suggestions List
          ..._filteredSuggestions.mapIndexed((index, suggestion) {
            return SearchResultsWidget(
              isDark: isDark,
              itemIndex: index,
              searchSuggestion: suggestion,
              acceptSuggestion: _acceptSuggestion,
              textColor: textColor,
            );
          }),
        ],
      );
    } else {
      // Case C: Nothing
      contentKey = const ValueKey('empty');
      mainContent = const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: MouseRegion(
          onEnter: (_) {
            if (_animController.isCompleted) {
              windowManager.setIgnoreMouseEvents(false);
            }
          },
          onExit: (_) {
            if (!_focusNode.hasFocus) {
              windowManager.setIgnoreMouseEvents(true);
            }
          },
          child: FadeTransition(
            opacity: _animController,
            child: SlideTransition(
              position: _slideAnimation,
              child: AnimatedContainer(
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
                          SearchBarWidget(
                            textController: _textController,
                            textColor: textColor,
                            inputScrollController: _inputScrollController,
                            filteredSuggestions: _filteredSuggestions,
                            acceptSuggestion: _acceptSuggestion,
                            onSubmitted: _onSubmitted,
                            focusNode: _focusNode,
                            toolIcon:
                                (_activeTool ?? _lockedTool)?.wakeCommands.icon,
                            lockedTrigger: _lockedTrigger,
                            onUnlock: _unlock,
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              return SizeTransition(
                                sizeFactor: animation,
                                axisAlignment: -1.0,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, -0.2),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            // Use the content determined above
                            child: KeyedSubtree(
                              key: contentKey,
                              child: mainContent,
                            ),
                          ),
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
}
