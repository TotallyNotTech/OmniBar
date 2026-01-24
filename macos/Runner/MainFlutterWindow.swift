import Cocoa
import FlutterMacOS
import AppKit
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  // 1. Variable to hold the reference to the app that was active before us.
  static var previousApp: NSRunningApplication?

  static var shouldReturnToExternalApp = true

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // (Your existing setup keeps the window transparent)
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = false
    self.styleMask = [.borderless, .fullSizeContentView]
    flutterViewController.backgroundColor = .clear

    RegisterGeneratedPlugins(registry: flutterViewController)

    registerControlChannel(with: flutterViewController.engine.binaryMessenger)
    registerSyncChannel(with: flutterViewController.engine.binaryMessenger)

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      self.registerControlChannel(with: controller.engine.binaryMessenger)
      self.registerSyncChannel(with: controller.engine.binaryMessenger)
    }

    // 2. Start listening for system notifications about app activation.
    NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(appDidActivate(_:)),
        name: NSWorkspace.didActivateApplicationNotification,
        object: nil
    )

    super.awakeFromNib()
  }

  func registerSyncChannel(with messenger: FlutterBinaryMessenger) {
    let syncChannel = FlutterMethodChannel(
        name: "com.omnibar.app/sync",
        binaryMessenger: messenger
    )

    syncChannel.setMethodCallHandler { (call, result) in
      if call.method == "hotkeyChanged" {
        result(nil)
        
        // --- NATIVE BROADCAST LOGIC ---
        // Iterate through all windows in the app to find Flutter engines
        for window in NSApp.windows {
            // Check if the window has a Flutter content view
            if let controller = window.contentViewController as? FlutterViewController {
                let targetChannel = FlutterMethodChannel(
                    name: "com.omnibar.app/sync",
                    binaryMessenger: controller.engine.binaryMessenger
                )
                targetChannel.invokeMethod("hotkeyChanged", arguments: nil)
            }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
  

  func registerControlChannel(with messenger: FlutterBinaryMessenger) {
      let channel = FlutterMethodChannel(
          name: "com.omnibar.app/control",
          binaryMessenger: messenger
      )
      
      channel.setMethodCallHandler { (call, result) in
          if call.method == "relinquishFocus" {
              // Access the STATIC variable
              MainFlutterWindow.previousApp?.activate(options: .activateIgnoringOtherApps)
              result(nil)
          } else {
              result(FlutterMethodNotImplemented)
          }
      }
  }

  // 3. This function is called by the OS whenever focus changes apps.
  @objc func appDidActivate(_ notification: Notification) {
      // Get the app that just became active.
      guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

      // The logic: If the app that just got focus is NOT this Flutter app,
      // it means it's an external app (like Safari or VS Code).
      // We save a reference to it.
      if activatedApp.bundleIdentifier != NSRunningApplication.current.bundleIdentifier {
          MainFlutterWindow.previousApp = activatedApp
      } else {
        if self.isVisible {
             // If this window (OmniBar) is visible during activation, 
             // the user pressed the Hotkey from outside.
             // We should go back to the external app when done.
             MainFlutterWindow.shouldReturnToExternalApp = true
          } else {
             // If this window is HIDDEN, but the app activated, 
             // it implies the user clicked the SETTINGS window.
             // We should stay in our app when done.
             MainFlutterWindow.shouldReturnToExternalApp = false
          }
      }
  }

  // 4. This function is called automatically when Flutter hides the window.
  override func orderOut(_ sender: Any?) {
    // Perform the standard hide operation first.
    super.orderOut(sender)

    // The Fix: If we have a saved previous app, force macOS to activate it.
    // .activateIgnoringOtherApps is crucial to bypass standard focus rules.
    if MainFlutterWindow.shouldReturnToExternalApp {
        // Go back to Safari/VS Code
        MainFlutterWindow.previousApp?.activate(options: .activateIgnoringOtherApps)
    } else {
        // Stay in our app (which gives focus to the next visible window: Settings)
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
    }
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }

  // 5. Clean up the observer when the window is destroyed (good practice)
  deinit {
      NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return true
  }
}