import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // The app is portrait-first, so the desktop window is pinned to a phone
    // shape (390 x 844 logical points) and resizing is disabled. Remove the
    // block below to get an ordinary resizable window back.
    let phoneSize = NSSize(width: 390, height: 844)
    self.setContentSize(phoneSize)
    let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    self.setFrameOrigin(
      NSPoint(
        x: visible.midX - phoneSize.width / 2,
        y: visible.midY - phoneSize.height / 2
      )
    )
    self.styleMask.remove(.resizable)
    self.title = "Pet Health Tracker"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
