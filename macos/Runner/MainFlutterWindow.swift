import Cocoa
import FlutterMacOS
// ERROR: Needs AppKit for NSWorkspace notifications
import AppKit

class MainFlutterWindow: NSWindow {
  // 1. Variable to hold the reference to the app that was active before us.
  private var previousApp: NSRunningApplication?

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

    // 2. Start listening for system notifications about app activation.
    NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(appDidActivate(_:)),
        name: NSWorkspace.didActivateApplicationNotification,
        object: nil
    )

    super.awakeFromNib()
  }

  // 3. This function is called by the OS whenever focus changes apps.
  @objc func appDidActivate(_ notification: Notification) {
      // Get the app that just became active.
      guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

      // The logic: If the app that just got focus is NOT this Flutter app,
      // it means it's an external app (like Safari or VS Code).
      // We save a reference to it.
      if activatedApp.bundleIdentifier != NSRunningApplication.current.bundleIdentifier {
          previousApp = activatedApp
      }
  }

  // 4. This function is called automatically when Flutter hides the window.
  override func orderOut(_ sender: Any?) {
    // Perform the standard hide operation first.
    super.orderOut(sender)

    // The Fix: If we have a saved previous app, force macOS to activate it.
    // .activateIgnoringOtherApps is crucial to bypass standard focus rules.
    previousApp?.activate(options: .activateIgnoringOtherApps)
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