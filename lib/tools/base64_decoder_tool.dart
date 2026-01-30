import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:omni_bar/providers/theme_provider.dart';
import 'package:omni_bar/tools/omni_tools.dart';
import 'package:provider/provider.dart';

class Base64DecodeTool extends OmniTool {
  @override
  String get name => "Base64 Decoder";

  @override
  get helperText => "Enter Base64 or JWT to decode...";

  @override
  get wakeCommands => SearchSuggestion(
    ['base64decode', 'base64decrypt'],
    'Base64 Decode / JWT',
    Icons.lock_open,
  );

  Color backgroundColor = Colors.black.withOpacity(0.7);

  String _normalize(String input) {
    String s = input.trim().replaceAll('-', '+').replaceAll('_', '/');
    s = s.replaceAll(RegExp(r'\s+'), '');
    while (s.length % 4 != 0) {
      s += '=';
    }
    return s;
  }

  @override
  Widget buildDisplay(BuildContext context, String input) {
    final textToProcess = input;
    String label = "";
    String result = "";
    bool isError = false;

    // --- JWT HANDLING ---
    if (textToProcess.contains('.')) {
      label = "JWT DECODED";
      final parts = textToProcess.split('.');
      List<String> decodedParts = [];

      for (int i = 0; i < parts.length; i++) {
        try {
          final normalized = _normalize(parts[i]);
          final decoded = utf8.decode(base64.decode(normalized));
          final partName = i == 0
              ? "Header"
              : (i == 1 ? "Payload" : "Signature");
          decodedParts.add("[$partName]\n$decoded");
        } catch (e) {
          if (parts[i].isNotEmpty) {
            decodedParts.add("[Part ${i + 1} Binary/Signature]");
          }
        }
      }
      result = decodedParts.join('\n\n');
    }
    // --- STANDARD BASE64 ---
    else {
      label = "BASE64 DECODED (UTF-8)";
      final normalized = _normalize(textToProcess);

      try {
        result = utf8.decode(base64.decode(normalized));
      } catch (e) {
        label = "BASE64 RAW BYTES";
        try {
          result =
              "Binary data detected (${base64.decode(normalized).length} bytes)";
        } catch (e) {
          result = "";
        }
        isError = true;
      }
    }

    final content = _buildContentContainer(label, result, isError);
    return _buildThemeWrapper(context, content);
  }

  @override
  String? getCopyableData(String input) {
    if (input.isEmpty) return null;

    // JWT Copy logic
    if (input.contains('.')) {
      return input
          .split('.')
          .map((p) {
            try {
              return utf8.decode(base64.decode(_normalize(p)));
            } catch (_) {
              return "";
            }
          })
          .join('\n');
    }

    // Standard Copy logic
    try {
      return utf8.decode(base64.decode(_normalize(input)));
    } catch (_) {
      return null;
    }
  }

  // Reuse the same UI helpers as Encode tool
  // (Ideally, move these helpers to a shared Mixin or Base Class later)
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
