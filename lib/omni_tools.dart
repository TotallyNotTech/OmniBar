import 'package:flutter/material.dart';

/// The blueprint that every utility blade must follow.
abstract class OmniTool {
  /// The name of the tool (for future list view)
  String get name;

  /// Logic to decide if this tool should activate based on user input.
  /// e.g., Does it look like JSON? Does it start with "#"?
  bool canHandle(String input);

  /// The UI widget to display below the search bar when active.
  Widget buildDisplay(BuildContext context, String input);
  String? getCopyableData(String input) => null;
}
