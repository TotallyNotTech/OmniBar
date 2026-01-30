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
  get helperText => "Enter JSON to format...";

  @override
  get wakeCommands =>
      SearchSuggestion(['json'], 'Format & Validate JSON', Icons.data_object);

  @override
  Widget buildDisplay(BuildContext context, String input) {
    try {
      final decoded = jsonDecode(input);
      final prettyJson = const JsonEncoder.withIndent('  ').convert(decoded);

      return Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          bool isDark;
          if (themeProvider.themeMode == ThemeMode.system) {
            isDark =
                MediaQuery.platformBrightnessOf(context) == Brightness.dark;
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
            // This outer padding is fine, keep it.
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
                    maxHeight:
                        200, // Adjust this value if you want it taller/shorter
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      primary: true,
                      // Removed the hacky internal padding. It shouldn't be needed now.
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
    } catch (e) {
      return const SizedBox.shrink();
    }
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
  void resetState() {
    // This tool holds no cached state between runs,
    // so this implementation intentionally does nothing.
  }
}
