import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:omni_bar/providers/theme_provider.dart';
import 'package:omni_bar/tools/omni_tools.dart';
import 'package:provider/provider.dart';

class JsonFormatTool implements OmniTool {
  @override
  String get name => "JSON Pretty Printer";

  @override
  bool get canEnterText => true;

  @override
  String get helperText => "Enter JSON to format...";

  @override
  SearchSuggestion get wakeCommands =>
      SearchSuggestion(['json'], 'Format & Validate JSON', Icons.data_object);

  @override
  Widget buildDisplay(BuildContext context, String input) {
    Widget content;
    final trimmed = input.trim();

    // 1. DETERMINE CONTENT
    if (trimmed.isEmpty) {
      content = const SizedBox(key: ValueKey('empty'));
    } else {
      try {
        final decoded = jsonDecode(trimmed);
        final prettyJson = const JsonEncoder.withIndent('  ').convert(decoded);

        // 2. SUCCESS STATE
        content = _JsonResultView(
          prettyJson: prettyJson,
          // Using a static key ensures we don't re-animate on every keystroke
          // UNLESS you want it to flash. Usually keeping it stable is better.
          key: const ValueKey('valid_json'),
        );
      } catch (e) {
        // 3. ERROR / INVALID STATE
        // We return SizedBox here so it stays hidden until valid,
        // but the AnimatedSwitcher will make it "grow" nicely when it appears.
        content = const SizedBox(key: ValueKey('invalid'));
      }
    }

    // 4. SNAPPY ANIMATION
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutQuad,
      switchOutCurve: Curves.easeInQuad,
      // Prevents "jumping" by anchoring items to the top
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1.0, // Expand from top down
            child: child,
          ),
        );
      },
      child: content,
    );
  }

  @override
  String? getCopyableData(String input) {
    try {
      final decoded = jsonDecode(input);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (e) {
      return null;
    }
  }

  @override
  void resetState() {}
}

// --- INTERNAL UI WIDGET ---

class _JsonResultView extends StatelessWidget {
  final String prettyJson;

  const _JsonResultView({required this.prettyJson, super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        bool isDark;
        if (themeProvider.themeMode == ThemeMode.system) {
          isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        } else {
          isDark = themeProvider.themeMode == ThemeMode.dark;
        }

        final backgroundColor = isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.black.withOpacity(0.7);
        final accentColor = isDark
            ? Colors.greenAccent.shade100
            : const Color.fromARGB(255, 52, 232, 103);

        return Container(
          constraints: const BoxConstraints(maxHeight: 450),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: double.infinity,
                  maxHeight: 200,
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    primary: true,
                    child: SelectableText(
                      prettyJson,
                      style: TextStyle(
                        color: accentColor,
                        fontFamily: 'Courier',
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Press Enter to copy and close",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
