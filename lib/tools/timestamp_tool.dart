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

    // 1. LIVE MODE (Input is empty)
    if (trimmed.isEmpty) {
      return const _LiveTimestampView();
    }

    // 2. STATIC MODE (Input provided)
    DateTime? parsedDate;
    String error = "";

    final number = int.tryParse(trimmed);
    if (number != null && trimmed.length < 13) {
      // Heuristic: Seconds (10 digits) vs Milliseconds (13 digits)
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

    if (error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(error, style: const TextStyle(color: Colors.orange)),
      );
    }

    if (parsedDate == null) return const SizedBox();

    return _TimestampInfoDisplay(date: parsedDate);
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

// --- INTERNAL WIDGETS & HELPERS ---

// 1. The Ticking Widget (Stateful)
class _LiveTimestampView extends StatefulWidget {
  const _LiveTimestampView();

  @override
  State<_LiveTimestampView> createState() => _LiveTimestampViewState();
}

class _LiveTimestampViewState extends State<_LiveTimestampView> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Tick every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-use the display layout, passing the updating time
    return _TimestampInfoDisplay(date: _now);
  }
}

// 2. The UI Layout (Stateless)
class _TimestampInfoDisplay extends StatelessWidget {
  final DateTime date;

  const _TimestampInfoDisplay({required this.date});

  String _twoDigits(int n) => n >= 10 ? "$n" : "0$n";

  String _formatDate(DateTime dt) {
    return "${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} "
        "${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}:${_twoDigits(dt.second)}";
  }

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    // Tolerance for "just now" logic in live mode to prevent flickering "in 0 seconds"
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
    final utc = date.toUtc();
    final local = date.toLocal();
    final unixSec = (utc.millisecondsSinceEpoch / 1000).floor();
    final unixMs = utc.millisecondsSinceEpoch;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.themeMode == ThemeMode.system
            ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
            : themeProvider.themeMode == ThemeMode.dark;

        final bgColor = isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.black.withOpacity(0.05);
        final labelColor = isDark ? Colors.grey : Colors.grey[700]!;
        final valueColor = isDark ? Colors.white : Colors.black;

        return Container(
          padding: const EdgeInsets.all(16),
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
