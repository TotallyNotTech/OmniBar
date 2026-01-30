import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:omni_bar/providers/theme_provider.dart';
import 'package:omni_bar/tools/omni_tools.dart';
import 'package:provider/provider.dart';

class Base64EncodeTool extends OmniTool {
  @override
  String get name => "Base64 Encoder";

  @override
  get helperText => "Enter text to encode...";

  @override
  get wakeCommands => SearchSuggestion(
    ['base64encode', 'base64encrypt'],
    'Base64 Encode',
    Icons.lock_outline,
  );

  Color backgroundColor = Colors.black.withOpacity(0.7);

  @override
  Widget buildDisplay(BuildContext context, String input) {
    // Input comes in raw because of your new "Lock" system
    final textToProcess = input;
    String result = "";
    bool isError = false;

    try {
      result = base64.encode(utf8.encode(textToProcess));
    } catch (e) {
      isError = true;
      result = "Error encoding text";
    }

    final content = _buildContentContainer("BASE64 ENCODED", result, isError);

    return _buildThemeWrapper(context, content);
  }

  @override
  String? getCopyableData(String input) {
    if (input.isEmpty) return null;
    try {
      return base64.encode(utf8.encode(input));
    } catch (_) {
      return null;
    }
  }

  Widget _buildContentContainer(String label, String result, bool isError) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: SelectableText(
              result,
              strutStyle: const StrutStyle(
                fontFamily: 'Menlo',
                fontSize: 14,
                height: 1.5,
                forceStrutHeight: true,
              ),
              style: TextStyle(
                color: isError ? Colors.orangeAccent : Colors.white,
                fontFamily: 'Menlo',
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Press Enter to copy result",
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeWrapper(BuildContext context, Widget child) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, childWidget) {
        bool isDark;
        if (themeProvider.themeMode == ThemeMode.system) {
          isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        } else {
          isDark = themeProvider.themeMode == ThemeMode.dark;
        }

        backgroundColor = isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.black.withOpacity(0.7);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (Widget child, Animation<double> animation) {
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
          child: child,
        );
      },
      child: child,
    );
  }
}
