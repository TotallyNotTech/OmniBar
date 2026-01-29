import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omni_bar/tools/omni_tools.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController textController;
  final Color textColor;
  final ScrollController inputScrollController;
  final List<SearchSuggestion> filteredSuggestions;
  final void Function(SearchSuggestion) acceptSuggestion;
  final Future<void> Function(String) onSubmitted;
  final FocusNode focusNode;

  const SearchBarWidget({
    super.key,
    required this.textController,
    required this.textColor,
    required this.inputScrollController,
    required this.filteredSuggestions,
    required this.acceptSuggestion,
    required this.onSubmitted,
    required this.focusNode,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 130),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Focus(
          onKeyEvent: (FocusNode node, KeyEvent event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.tab) {
              if (widget.textController.text.isEmpty ||
                  widget.filteredSuggestions.isEmpty) {
                return KeyEventResult.handled;
              } else {
                widget.acceptSuggestion(widget.filteredSuggestions.first);
                return KeyEventResult.handled;
              }
            }
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              if (!HardwareKeyboard.instance.isShiftPressed) {
                widget.onSubmitted(widget.textController.text);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: widget.textController,
            // Keeping this linked ensures TextField uses our controller
            scrollController: widget.inputScrollController,
            focusNode: widget.focusNode,
            style: TextStyle(color: widget.textColor, fontSize: 24),
            maxLines: null,
            textAlignVertical: TextAlignVertical.center,
            keyboardType: TextInputType.multiline,
            scrollPhysics: const ClampingScrollPhysics(),
            decoration: InputDecoration(
              hintText: "Start typing command...",
              hintStyle: TextStyle(color: widget.textColor),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: widget.textColor, size: 28),
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
