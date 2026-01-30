import 'package:flutter/material.dart';
import 'package:omni_bar/tools/omni_tools.dart';

class SearchResultsWidget extends StatefulWidget {
  final bool isDark;
  final Color textColor;
  final int itemIndex;
  final bool isSelected;
  final void Function(SearchSuggestion) acceptSuggestion;
  final SearchSuggestion searchSuggestion;
  const SearchResultsWidget({
    super.key,
    required this.isDark,
    required this.textColor,
    required this.itemIndex,
    required this.isSelected,
    required this.acceptSuggestion,
    required this.searchSuggestion,
  });

  @override
  State<SearchResultsWidget> createState() => _SearchResultsWidgetState();
}

class _SearchResultsWidgetState extends State<SearchResultsWidget> {
  @override
  Widget build(BuildContext context) {
    final highlightColor = widget.isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);
    return Material(
      color: widget.isSelected ? highlightColor : Colors.transparent,
      child: InkWell(
        onTap: () => widget.acceptSuggestion(widget.searchSuggestion),
        hoverColor: widget.isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(
                widget.searchSuggestion.icon,
                color: widget.textColor.withOpacity(0.5),
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                // TODO: fix this here broski
                widget.searchSuggestion.trigger.first,
                style: TextStyle(
                  color: widget.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Menlo', // Monospace looks cool for commands
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "-  ${widget.searchSuggestion.description}",
                style: TextStyle(
                  color: widget.textColor.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (widget.isSelected)
                Text(
                  "TAB / ENTER",
                  style: TextStyle(
                    color: widget.textColor.withOpacity(0.3),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
