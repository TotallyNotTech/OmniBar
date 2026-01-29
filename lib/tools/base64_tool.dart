import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:omni_bar/providers/theme_provider.dart';
import 'package:omni_bar/tools/omni_tools.dart';
import 'package:provider/provider.dart';

class Base64Tool extends OmniTool {
  @override
  String get name => "Base64 Encoder/Decoder";

  @override
  bool canHandle(String input) {
    final trimmed = input.trim();
    // if (trimmed.length < 6) return false;
    return trimmed.startsWith('b64e') || trimmed.startsWith('b64d');
  }

  // TODO: split encrypt and decrypt commands
  @override
  get wakeCommands => SearchSuggestion(
    ['b64e', 'b64d'],
    'Base64 Encryption/Decryption',
    Icons.lock_outline,
  );

  Color backgroundColor = Colors.black.withOpacity(0.7);

  String _normalize(String input) {
    // 1. JWTs use Base64URL: convert back to standard Base64 characters
    String s = input.trim().replaceAll('-', '+').replaceAll('_', '/');
    // 2. Remove whitespace
    s = s.replaceAll(RegExp(r'\s+'), '');
    // 3. Add padding
    while (s.length % 4 != 0) {
      s += '=';
    }
    return s;
  }

  @override
  Widget buildDisplay(BuildContext context, String input) {
    final trimmed = input.trim();
    String label = "";
    String result = "";
    bool isError = false;

    final textToProcess = trimmed.substring(4).trim();

    Widget content;
    // try {
    if (trimmed.startsWith('b64e')) {
      label = "Base64 Encoded";
      try {
        result = base64.encode(utf8.encode(textToProcess));
      } catch (e) {
        isError = true;
      }
    } else if (trimmed.startsWith('b64d')) {
      // --- JWT HANDLING ---
      if (textToProcess.contains('.')) {
        label = "JWT Decoded";
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
        label = "Base64 Decoded (UTF-8)";
        final normalized = _normalize(textToProcess);
        print(normalized + "hadsf");
        try {
          result = utf8.decode(base64.decode(normalized));
        } catch (e) {
          label = "Base64 Raw Bytes";
          try {
            result =
                "Binary data detected (${base64.decode(normalized).length} bytes)";
          } catch (e) {
            result = "";
          }

          isError = true;
        }
        print(result + "result");
      }
    }

    content = Container(
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
            label.toUpperCase(),
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
              strutStyle: StrutStyle(
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
    // } catch (e) {
    //   print(" its being catched");
    //   content = const SizedBox.shrink(key: ValueKey('b64_empty'));
    // }

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
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
          child: content,
        );
      },
    );
  }

  @override
  String? getCopyableData(String input) {
    final trimmed = input.trim();
    final textToProcess = trimmed.length > 5 ? trimmed.substring(5).trim() : "";
    if (textToProcess.isEmpty) return null;

    try {
      if (trimmed.startsWith('b64e ')) {
        return base64.encode(utf8.encode(textToProcess));
      } else if (trimmed.startsWith('b64d ')) {
        // For copying JWTs, we just return the full decoded result
        if (textToProcess.contains('.')) {
          // We could recreate the result logic here or simplify it for clipboard
          return textToProcess
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
        return utf8.decode(base64.decode(_normalize(textToProcess)));
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
