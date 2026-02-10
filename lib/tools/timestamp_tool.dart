import 'dart:async';
import 'package:flutter/material.dart';
import 'package:omni_bar/providers/theme_provider.dart';
import 'package:omni_bar/tools/omni_tools.dart';
import 'package:provider/provider.dart';

class TimestampTool extends OmniTool {
  @override
  String get name => "Timestamp Converter";

  @override
  String get helperText => "Enter timestamp or ISO string...";

  @override
  SearchSuggestion get wakeCommands => SearchSuggestion(
    ['ts', 'time', 'date'],
    'Timestamp / Date Converter',
    Icons.schedule,
  );

  @override
  Widget buildDisplay(BuildContext context, String input) {
    final trimmed = input.trim();
    Widget content;

    String? error;
    DateTime? parsedDate;

    // 1. PARSE LOGIC
    if (trimmed.isNotEmpty) {
      final number = int.tryParse(trimmed);
      if (number != null && trimmed.length < 13) {
        if (trimmed.length > 11) {
          parsedDate = DateTime.fromMillisecondsSinceEpoch(number);
        } else {
          parsedDate = DateTime.fromMillisecondsSinceEpoch(number * 1000);
        }
      } else {
        try {
          parsedDate = DateTime.parse(trimmed);
        } catch (_) {
          error = "Invalid format";
        }
      }
    }

    // 2. CONTENT SELECTION
    // We group 'Live' (empty input) and 'Static' (valid input) into the SAME widget key.
    // This prevents AnimatedSwitcher from firing when switching between them.
    if (error != null) {
      content = Container(
        key: const ValueKey('error'), // Different key triggers animation
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        alignment: Alignment.center,
        child: Text(error, style: const TextStyle(color: Colors.orange)),
      );
    } else {
      // Both LIVE and STATIC use this widget.
      // parsedDate == null implies "Live Mode" inside the widget.
      content = _UnifiedTimestampDisplay(
        key: const ValueKey('valid_content'), // SAME KEY = NO JUMP
        date: parsedDate,
      );
    }

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutQuad,
          switchOutCurve: Curves.easeInQuad,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: child,
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
    DateTime dt;

    if (trimmed.isEmpty) {
      dt = DateTime.now();
      return dt.toIso8601String();
    }

    final number = int.tryParse(trimmed);
    if (number != null) {
      if (trimmed.length > 11) {
        dt = DateTime.fromMillisecondsSinceEpoch(number);
      } else {
        dt = DateTime.fromMillisecondsSinceEpoch(number * 1000);
      }
      return dt.toUtc().toIso8601String();
    } else {
      try {
        dt = DateTime.parse(trimmed);
        return "${(dt.millisecondsSinceEpoch / 1000).floor()}";
      } catch (_) {
        return null;
      }
    }
  }
}

// --- UNIFIED WIDGET (Handles both Live and Static) ---

class _UnifiedTimestampDisplay extends StatefulWidget {
  final DateTime? date; // If null, we run in "Live Mode"

  const _UnifiedTimestampDisplay({super.key, this.date});

  @override
  State<_UnifiedTimestampDisplay> createState() =>
      _UnifiedTimestampDisplayState();
}

class _UnifiedTimestampDisplayState extends State<_UnifiedTimestampDisplay> {
  Timer? _timer;
  late DateTime _displayDate;

  @override
  void initState() {
    super.initState();
    _updateState();
  }

  @override
  void didUpdateWidget(covariant _UnifiedTimestampDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateState();
  }

  void _updateState() {
    if (widget.date != null) {
      // STATIC MODE: Cancel timer, use provided date
      _timer?.cancel();
      _displayDate = widget.date!;
    } else {
      // LIVE MODE: Start timer if not running
      if (_timer == null || !_timer!.isActive) {
        _displayDate = DateTime.now();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _displayDate = DateTime.now();
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- UI RENDERING ---

  String _twoDigits(int n) => n >= 10 ? "$n" : "0$n";

  String _formatDate(DateTime dt) {
    return "${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} "
        "${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}:${_twoDigits(dt.second)}";
  }

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inSeconds.abs() < 2) return "just now";

    final isPast = date.isBefore(now);
    final prefix = isPast ? "" : "in ";
    final suffix = isPast ? " ago" : "";

    final seconds = difference.inSeconds.abs();
    final minutes = difference.inMinutes.abs();
    final hours = difference.inHours.abs();
    final days = difference.inDays.abs();

    if (seconds < 60) return "$prefix$seconds seconds$suffix";
    if (minutes < 60) return "$prefix$minutes mins$suffix";
    if (hours < 24) return "$prefix$hours hours$suffix";
    if (days < 30) return "$prefix$days days$suffix";
    return "$prefix${(days / 30).floor()} months$suffix";
  }

  @override
  Widget build(BuildContext context) {
    final utc = _displayDate.toUtc();
    final local = _displayDate.toLocal();
    final unixSec = (utc.millisecondsSinceEpoch / 1000).floor();
    final unixMs = utc.millisecondsSinceEpoch;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.themeMode == ThemeMode.system
            ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
            : themeProvider.themeMode == ThemeMode.dark;

        final containerBackgroundColor = isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.black.withOpacity(0.7);

        final bgColor = isDark
            ? Colors.white.withOpacity(0.3)
            : Colors.white.withOpacity(0.05);
        final labelColor = Colors.white.withOpacity(0.3);
        final valueColor = Colors.white;

        return Container(
          padding: const EdgeInsets.all(16),
          color: containerBackgroundColor,
          child: Column(
            children: [
              _buildTimeRow(
                "Unix (Seconds)",
                "$unixSec",
                bgColor,
                labelColor,
                valueColor,
              ),
              const SizedBox(height: 8),
              _buildTimeRow(
                "Unix (Millis)",
                "$unixMs",
                bgColor,
                labelColor,
                valueColor,
              ),
              const SizedBox(height: 8),
              _buildTimeRow(
                "ISO 8601 (UTC)",
                utc.toIso8601String(),
                bgColor,
                labelColor,
                valueColor,
              ),
              const SizedBox(height: 8),
              _buildTimeRow(
                "Local Time",
                _formatDate(local),
                bgColor,
                labelColor,
                valueColor,
              ),
              const SizedBox(height: 8),
              _buildTimeRow(
                "Relative",
                _getRelativeTime(local),
                bgColor,
                labelColor,
                valueColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeRow(
    String label,
    String value,
    Color bg,
    Color labelColor,
    Color valueColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontFamily: 'Menlo',
                color: valueColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
