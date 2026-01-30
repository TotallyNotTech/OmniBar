import 'package:flutter/material.dart';

class SearchSuggestion {
  final List<String> trigger; // e.g. "b64e"
  final String description; // e.g. "Base64 Encode"
  final IconData icon; // Visual cue

  SearchSuggestion(this.trigger, this.description, this.icon);
}

/// The blueprint that every utility blade must follow.
abstract class OmniTool {
  /// The name of the tool (for future list view)
  String get name;

  /// Logic to decide if this tool should activate based on user input.
  /// e.g., Does it look like JSON? Does it start with "#"?
  bool canHandle(String input) => true;

  // TODO: continue this for the uuid one
  bool get canEnterText => true;

  String get helperText;

  /// The UI widget to display below the search bar when active.
  Widget buildDisplay(BuildContext context, String input);
  String? getCopyableData(String input) => null;

  SearchSuggestion get wakeCommands;

  void resetState() {}
}
