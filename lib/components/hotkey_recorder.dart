import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:macos_ui/macos_ui.dart';

class HotKeyRecorderComponent extends StatefulWidget {
  final HotKey? initialHotKey;
  final ValueChanged<HotKey> onHotKeyRecorded;

  final Future<void> Function()? onStartRecording;
  final Future<void> Function()? onStopRecording;

  const HotKeyRecorderComponent({
    super.key,
    this.initialHotKey,
    required this.onHotKeyRecorded,
    this.onStartRecording,
    this.onStopRecording,
  });

  @override
  State<HotKeyRecorderComponent> createState() => _HotKeyRecorderState();
}

class _HotKeyRecorderState extends State<HotKeyRecorderComponent> {
  bool _isRecording = false;
  HotKey? _currentHotKey;

  // Separate state for "Live" recording visualization
  List<HotKeyModifier> _tempModifiers = [];
  PhysicalKeyboardKey? _tempKey;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentHotKey = widget.initialHotKey;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording() async {
    if (widget.onStartRecording != null) {
      await widget.onStartRecording!();
    }
    setState(() {
      _isRecording = true;
      _tempModifiers = [];
      _tempKey = null;
    });
    // Ensure we catch the keys
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _stopAndSave() async {
    setState(() {
      _isRecording = false;
      // Only save if we actually have a valid main key
      if (_tempKey != null) {
        final newHotKey = HotKey(
          key: _tempKey!,
          modifiers: _tempModifiers,
          scope: HotKeyScope.system,
        );
        _currentHotKey = newHotKey;
        widget.onHotKeyRecorded(newHotKey);
      }
    });
    _focusNode.unfocus();

    if (widget.onStopRecording != null) {
      await widget.onStopRecording!();
    }
  }

  Future<void> _handleKeyEvent(KeyEvent event) async {
    if (!_isRecording) return;

    // Update on KeyDown (press) and KeyRepeat (hold)
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    // 1. Capture Modifiers directly from hardware state
    List<HotKeyModifier> modifiers = [];
    if (HardwareKeyboard.instance.isMetaPressed)
      modifiers.add(HotKeyModifier.meta);
    if (HardwareKeyboard.instance.isShiftPressed)
      modifiers.add(HotKeyModifier.shift);
    if (HardwareKeyboard.instance.isAltPressed)
      modifiers.add(HotKeyModifier.alt);
    if (HardwareKeyboard.instance.isControlPressed)
      modifiers.add(HotKeyModifier.control);

    // 2. Detect Main Key
    PhysicalKeyboardKey? mainKey;
    // Check if the pressed key is NOT a modifier
    if (!_isModifier(event.logicalKey)) {
      mainKey = event.physicalKey;
    }

    // 3. Update State
    setState(() {
      _tempModifiers = modifiers;
      if (mainKey != null) {
        _tempKey = mainKey;
      }
    });
  }

  bool _isModifier(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Shortcut",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),

        Focus(
          focusNode: _focusNode,
          onKeyEvent: (node, event) {
            _handleKeyEvent(event);
            return KeyEventResult.handled;
          },
          child: Row(
            children: [
              // DISPLAY AREA
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? MacosColors.systemBlueColor.withOpacity(0.1)
                        : (isDark ? const Color(0xFF333333) : Colors.white),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isRecording
                          ? MacosColors.systemBlueColor
                          : (isDark
                                ? const Color(0xFF555555)
                                : const Color(0xFFCCCCCC)),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  // Logic:
                  // If Recording -> Show temp vars
                  // If Saved -> Show _currentHotKey vars
                  child: _isRecording
                      ? _buildVisuals(
                          _tempModifiers,
                          _tempKey,
                          isDark,
                          isRecording: true,
                        )
                      : (_currentHotKey != null
                            ? _buildVisuals(
                                _currentHotKey!.modifiers,
                                _currentHotKey!.physicalKey,
                                isDark,
                              )
                            : const Text(
                                "None",
                                style: TextStyle(color: Colors.grey),
                              )),
                ),
              ),

              const SizedBox(width: 12),

              // BUTTON
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: _isRecording ? _stopAndSave : _startRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording
                        ? Colors.redAccent
                        : MacosColors.systemBlueColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    _isRecording ? "Stop & Save" : "Record",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Refactored to take raw lists instead of HotKey object
  Widget _buildVisuals(
    List<HotKeyModifier>? modifiers,
    PhysicalKeyboardKey? key,
    bool isDark, {
    bool isRecording = false,
  }) {
    final keys = <String>[];

    // Add Modifiers
    if (modifiers != null) {
      if (modifiers.contains(HotKeyModifier.meta)) keys.add("⌘");
      if (modifiers.contains(HotKeyModifier.control)) keys.add("⌃");
      if (modifiers.contains(HotKeyModifier.alt)) keys.add("⌥");
      if (modifiers.contains(HotKeyModifier.shift)) keys.add("⇧");
    }

    // Add Key (or '?' if recording and missing)
    if (key != null) {
      keys.add(key.debugName?.replaceAll("Key ", "").toUpperCase() ?? "?");
    } else if (isRecording) {
      keys.add("?"); // Placeholder for when you are holding just Cmd
    }

    if (keys.isEmpty) {
      return Text(
        "Press keys...",
        style: TextStyle(color: MacosColors.systemBlueColor, fontSize: 13),
      );
    }

    return Wrap(
      spacing: 6,
      children: keys.map((k) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF555555) : const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isDark ? const Color(0xFF666666) : const Color(0xFFDDDDDD),
            ),
          ),
          child: Text(
            k,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Menlo',
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }
}
