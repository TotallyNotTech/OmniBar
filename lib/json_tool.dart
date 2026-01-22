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
      // Re-encode with 2-space indentation
      final prettyJson = const JsonEncoder.withIndent('  ').convert(decoded);

      return Container(
        // Limit height so giant JSON doesn't take over the whole screen
        constraints: const BoxConstraints(maxHeight: 450),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3), // Darker background for results
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            primary: true,
            child: SelectableText(
              // MUST be selectable to copy results!
              prettyJson,
              style: TextStyle(
                color: Colors.greenAccent.shade100, // "Hacker" monospace look
                fontFamily: 'Courier',
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      // Should be caught by canHandle, but safety first.
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
}
