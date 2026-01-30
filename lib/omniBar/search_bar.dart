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
  final IconData? toolIcon;
  final String? lockedTrigger;
  final String? triggerHelperText;
  final bool? canEnterText;
  final VoidCallback onUnlock;

  const SearchBarWidget({
    super.key,
    required this.textController,
    required this.textColor,
    required this.inputScrollController,
    required this.filteredSuggestions,
    required this.acceptSuggestion,
    required this.onSubmitted,
    required this.focusNode,
    required this.toolIcon,
    required this.lockedTrigger,
    required this.triggerHelperText,
    required this.canEnterText,
    required this.onUnlock,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  @override
  Widget build(BuildContext context) {
    print("toolicon ${widget.toolIcon}");

    bool textFieldEnabled = true;
    String? hintText;

    if (widget.lockedTrigger != null && widget.canEnterText == false) {
      textFieldEnabled = false;
    }

    hintText = widget.lockedTrigger != null
        ? widget.triggerHelperText
        : "Start typing command...";

    if (!textFieldEnabled) {
      hintText = null;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 130),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Focus(
          onKeyEvent: (FocusNode node, KeyEvent event) {
            // 1. UNLOCK LOGIC
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.backspace) {
              if (widget.lockedTrigger != null &&
                  widget.textController.text.isEmpty) {
                widget.onUnlock(); // Go back to search mode
                return KeyEventResult.handled;
              }
            }

            // 2. TAB COMPLETION
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

            // 3. SUBMIT
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              if (!HardwareKeyboard.instance.isShiftPressed) {
                // If searching and hit enter on top result -> select it
                if (widget.lockedTrigger == null &&
                    widget.filteredSuggestions.isNotEmpty) {
                  widget.acceptSuggestion(widget.filteredSuggestions.first);
                  return KeyEventResult.handled;
                }

                widget.onSubmitted(widget.textController.text);
                return KeyEventResult.handled;
              }
            }

            if (event is KeyDownEvent && !textFieldEnabled) {
              return KeyEventResult.handled;
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
            showCursor: textFieldEnabled,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: widget.textColor),
              border: InputBorder.none,
              prefixIcon: widget.lockedTrigger != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8, right: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            widget.toolIcon ?? Icons.extension,
                            color: widget.textColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.textColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: widget.textColor.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              widget.lockedTrigger!.toUpperCase(),
                              style: TextStyle(
                                color: widget.textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Menlo',
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Icon(Icons.search, color: widget.textColor, size: 28),

              // prefix: widget.lockedTrigger != null
              //     ? Padding(
              //         padding: const EdgeInsets.only(right: 10),
              //         child: Center(
              //           child: Container(
              //             padding: const EdgeInsets.symmetric(
              //               horizontal: 8,
              //               vertical: 4, // slightly more vertical padding
              //             ),
              //             decoration: BoxDecoration(
              //               color: widget.textColor.withOpacity(0.05),
              //               borderRadius: BorderRadius.circular(6),
              //               border: Border.all(
              //                 color: widget.textColor.withOpacity(0.2),
              //               ),
              //             ),
              //             child: Text(
              //               widget.lockedTrigger!.toUpperCase(),
              //               style: TextStyle(
              //                 color: widget.textColor,
              //                 fontSize: 13,
              //                 fontWeight: FontWeight.bold,
              //                 fontFamily: 'Menlo',
              //               ),
              //             ),
              //           ),
              //         ),
              //       )
              //     : null,
              // If not locked, no prefix widget exists
              // prefixIconConstraints: const BoxConstraints(
              //   minWidth: 0,
              //   minHeight: 0,
              // ),
              suffixIcon: widget.lockedTrigger != null
                  ? Padding(
                      padding: const EdgeInsets.only(
                        left: 12.0,
                      ), // Space from input text
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Force vertical center
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "DEL to clear",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: widget.textColor.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
