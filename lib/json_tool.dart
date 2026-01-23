import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:omni_bar/omni_tools.dart';

class JsonFormatTool implements OmniTool {
  @override
  String get name => "JSON Pretty Printer";

  @override
  bool canHandle(String input) {
    input = input.trim();
    // Fast checks: Must start/end with JSON-like structure
    if (input.isEmpty) return false;
    if (!(input.startsWith('{') && input.endsWith('}')) &&
        !(input.startsWith('[') && input.endsWith(']'))) {
      return false;
    }

    try {
      // The real test: try to parse it.
      jsonDecode(input);
      return true;
    } catch (e) {
      // Parsing failed, not valid JSON
      return false;
    }
  }

  @override
  Widget buildDisplay(BuildContext context, String input) {
    try {
      final decoded = jsonDecode(input);
      final prettyJson = const JsonEncoder.withIndent('  ').convert(decoded);

      return Container(
        constraints: const BoxConstraints(maxHeight: 450),
        width: double.infinity,
        // This outer padding is fine, keep it.
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
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
                      color: Colors.greenAccent.shade100,
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
