import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Set content size to 1280x800 points (2560x1600 pixels on Retina)
    // to match the primary Mac App Store screenshot requirement.
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    self.setContentSize(NSSize(width: 1280, height: 800))
    // Center the window on screen
    let originX = screenFrame.origin.x + (screenFrame.width - 1280) / 2
    let originY = screenFrame.origin.y + (screenFrame.height - 800) / 2
    self.setFrameOrigin(NSPoint(x: originX, y: originY))

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
