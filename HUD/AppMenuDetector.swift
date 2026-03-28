import AppKit
import Observation

@Observable
class AppMenuDetector {
    static let shared = AppMenuDetector()

    /// Estimated width of the frontmost app's menu bar items (in points)
    var menuBarWidth: CGFloat = 0

    /// The frontmost app's bundle identifier
    var frontmostApp: String = ""

    /// Expansion mode based on available space
    var expansionMode: ExpansionMode = .persistent

    /// Cached menu widths per app bundle ID
    private var cache: [String: CGFloat] = [:]

    enum ExpansionMode: String {
        case persistent    // lots of space — keep HUD expanded
        case notification  // tight space — toast-style, auto-hide
        case minimal       // very tight — dots only
    }

    func startWatching() {
        // Detect initial state
        detectFrontmostApp()

        // Watch for app switches
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appDidActivate(_ notification: Notification) {
        detectFrontmostApp()
    }

    private func detectFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let bundleId = app.bundleIdentifier ?? "unknown"
        frontmostApp = bundleId

        // Check cache first
        if let cached = cache[bundleId] {
            menuBarWidth = cached
            updateExpansionMode()
            return
        }

        // Detect menu bar width using CGWindowList
        let width = detectMenuBarWidth(for: app)
        menuBarWidth = width
        cache[bundleId] = width
        updateExpansionMode()

        // Write to geometry file for other tools
        writeMenuInfo()
    }

    private func detectMenuBarWidth(for app: NSRunningApplication) -> CGFloat {
        // Use CGWindowListCopyWindowInfo to find menu bar windows
        // Menu bar items appear as windows at screen top with small heights
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return estimateFromBundleId(app.bundleIdentifier ?? "")
        }

        let pid = app.processIdentifier
        var maxMenuRight: CGFloat = 0

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == pid,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let y = bounds["Y"],
                  let x = bounds["X"],
                  let w = bounds["Width"],
                  let h = bounds["Height"] else { continue }

            // Menu bar items are at y=0 (top of screen) and typically < 30pt tall
            if y == 0 && h < 40 {
                let right = x + w
                if right > maxMenuRight {
                    maxMenuRight = right
                }
            }
        }

        // If we couldn't detect, estimate from known apps
        if maxMenuRight == 0 {
            return estimateFromBundleId(app.bundleIdentifier ?? "")
        }

        return maxMenuRight
    }

    /// Fallback estimates for common apps
    private func estimateFromBundleId(_ bundleId: String) -> CGFloat {
        switch bundleId {
        case "com.apple.Safari":           return 350
        case "com.google.Chrome":          return 500
        case "com.apple.Xcode":            return 550
        case "com.microsoft.VSCode":       return 400
        case "com.mitchellh.ghostty":      return 200
        case "com.apple.Terminal":         return 250
        case "com.apple.finder":           return 350
        case "net.kovidgoyal.kitty":       return 200
        default:                           return 300  // conservative default
        }
    }

    private func updateExpansionMode() {
        guard let screen = NSScreen.main else { return }
        let notchCenter = screen.frame.width / 2
        let notchLeft = notchCenter - 92  // approx notch left edge

        let availableForHUD = notchLeft - menuBarWidth

        if availableForHUD > 200 {
            expansionMode = .persistent
        } else if availableForHUD > 50 {
            expansionMode = .notification
        } else {
            expansionMode = .minimal
        }

        // Post notification so NotchWindow can adapt
        NotificationCenter.default.post(
            name: Notification.Name("HUDExpansionModeChanged"),
            object: nil,
            userInfo: ["mode": expansionMode.rawValue, "available": availableForHUD]
        )
    }

    private func writeMenuInfo() {
        let info: [String: Any] = [
            "frontmostApp": frontmostApp,
            "menuBarWidth": menuBarWidth,
            "expansionMode": expansionMode.rawValue,
            "detected": ISO8601DateFormatter().string(from: Date())
        ]
        if let data = try? JSONSerialization.data(withJSONObject: info, options: .prettyPrinted) {
            let path = NSString("~/.atlas/hud-app-context.json").expandingTildeInPath
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
