import 'package:flutter/material.dart';
import 'package:omni_bar/omni_tools.dart';
import 'package:omni_bar/theme_provider.dart';
import 'package:provider/provider.dart';
// 1. Import the package
import 'package:uuid/uuid.dart';

class UuidTool implements OmniTool {
  @override
  String get name => "UUID Generator";

  String? _cachedInput;
  String? _cachedResult;

  @override
  bool canHandle(String input) {
    // 2. The Trigger: Only activate if the user types exactly "uuid"
    // (trim whitespace and ignore case)
    return input.trim().toLowerCase() == 'uuid';
  }

  @override
  Widget buildDisplay(BuildContext context, String input) {
    if (_cachedInput != input) {
      _cachedResult = const Uuid().v4();
      _cachedInput = input;
    }
    // 3. The Action: Generate a new v4 (random) UUID
    // We use 'const Uuid()' for efficiency as the generator instance can be reused.
    final displayUuid = _cachedResult ?? "Error";

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
        final borderColor = isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.1);
        // final textColor = isDark
        //     ? Colors.white.withOpacity(0.6)
        //     : Colors.black.withOpacity(0.6);
        // final accentColor = isDark
        //     ? Colors.cyanAccent.shade100
        //     : Colors.blue.shade800;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24), // Generous padding for emphasis
          decoration: BoxDecoration(
            color: backgroundColor, // Dark background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                displayUuid,
                style: TextStyle(
                  // Using a blue accent to differentiate from JSON green
                  color: Colors.cyanAccent.shade100,
                  fontFamily: 'Courier', // Monospace is essential for UUIDs
                  fontSize: 26, // Nice and big
                  fontWeight: FontWeight.w600,
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

    // 4. The UI: Consistent container style, but different accent color
  }

  @override
  String? getCopyableData(String input) {
    // Ensure we are returning data for the current input match
    if (input == _cachedInput) {
      return _cachedResult;
    }
    return null;
  }

  @override
  void resetState() {
    // Clear the cache so the next time it runs, it generates a fresh UUID.
    _cachedInput = null;
    _cachedResult = null;
  }
}
