import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController

    let channel = FlutterMethodChannel(
      name: "pixel_color",
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      if call.method == "getPixelColor" {
        let mouse = NSEvent.mouseLocation

        let screen = NSScreen.screens.first {
          NSMouseInRect(mouse, $0.frame, false)
        }

        // We need the displayID if someone has multiple screens connected to their mac
        let displayID =
          screen!.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
          ] as! CGDirectDisplayID

        let frame = screen!.frame

        let x = Int(mouse.x - frame.origin.x)  // idk man CoreGraphics coordinate system be really weird...
        let y = Int(frame.height - (mouse.y - frame.origin.y))  // flip Y for CoreGraphics

        let color = self.getPixelColor(x: x, y: y, displayID: displayID)
        result(color)
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  func getPixelColor(x: Int, y: Int, displayID: CGDirectDisplayID) -> UInt32 {

    let rect = CGRect(x: x, y: y, width: 1, height: 1)

    guard let image = CGDisplayCreateImage(displayID, rect: rect) else {
      return 0xFF00_0000
    }

    // sRGB!!! IDK if it is the way to go to force it but with sRGB i had better reading then the default BGRA(?)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bytesPerPixel = 4
    var pixelData = [UInt8](repeating: 0, count: 4)

    let ctx = CGContext(
      data: &pixelData,
      width: 1,
      height: 1,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerPixel,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))

    let r = UInt32(pixelData[0])
    let g = UInt32(pixelData[1])
    let b = UInt32(pixelData[2])
    let a = UInt32(pixelData[3])

    return (a << 24) | (r << 16) | (g << 8) | b
  }
}
