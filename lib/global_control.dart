import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OmniController {
  static const _channel = MethodChannel('com.omnibar.app/control');
  // A static reference that persists in the Main Isolate memory
  static VoidCallback? _toggleUI;

  static void registerCallback(VoidCallback callback) {
    _toggleUI = callback;

    // This tells this specific window to listen for the channel
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'triggerToggle') {
        _toggleUI?.call();
      }
      return null;
    });
  }

  // Getter/setter with logging
  static set toggleUI(VoidCallback? callback) {
    _toggleUI = callback;

    // Set up the listener in the window where the callback is assigned (Main Window)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'triggerToggle') {
        _internalExecute();
      }
      return null;
    });
  }

  static void executeToggle() async {
    debugPrint("OmniController: Sending toggle request to Window 0");
    try {
      // 0 is the ID of your Main OmniBar window
      await _channel.invokeMethod('triggerToggle');
    } catch (e) {
      debugPrint("Failed to send toggle via multi-window: $e");
      // Fallback: if we are already in the main window, try local execution
      _toggleUI?.call();
    }
  }

  static VoidCallback? get toggleUI {
    debugPrint(
      "OmniController.toggleUI GET: ${_toggleUI != null ? 'Non-null' : 'NULL'}",
    );
    return _toggleUI;
  }

  static void _internalExecute() {
    if (_toggleUI != null) {
      debugPrint("OmniController: Running toggleUI callback");
      _toggleUI!();
    } else {
      debugPrint("OmniController ERROR: toggleUI is null in this isolate");
    }
  }

  // Added for debugging
  // static void executeToggle() {
  //   debugPrint("OmniController.executeToggle() called");
  //   debugPrint("toggleUI is not null: ${toggleUI != null}");

  //   if (toggleUI != null) {
  //     debugPrint("Calling toggleUI now...");
  //     toggleUI!();
  //     debugPrint("toggleUI call completed");
  //   } else {
  //     debugPrint("!!! OmniController: Cannot toggle, toggleUI is NULL !!!");
  //   }
  // }
}
