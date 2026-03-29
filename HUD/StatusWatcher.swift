import Foundation
import Observation

struct AtlasStatus: Codable, Equatable {
    let status: String        // "green" | "yellow" | "red"
    let source: String        // "athena" | "jane"
    let message: String       // shown in hover panel
    let banner: String?       // marquee text (supports emoji)
    let bannerStyle: String?  // "scroll" | "typewriter" | "flash" | "slide" | "split-flap"
    let updated: String
    let details: [String]
    let slots: [String: SlotData]?
    let statusBar: StatusBarConfig?  // declarative status bar config

    init(status: String, source: String, message: String, banner: String? = nil, bannerStyle: String? = nil, updated: String, details: [String], slots: [String: SlotData]? = nil, statusBar: StatusBarConfig? = nil) {
        self.status = status
        self.source = source
        self.message = message
        self.banner = banner
        self.bannerStyle = bannerStyle
        self.updated = updated
        self.details = details
        self.slots = slots
        self.statusBar = statusBar
    }
}

// MARK: - HUD Config (severity-driven layouts, read from ~/.atlas/hud-config.json)

struct LayoutPreset: Codable, Equatable {
    let leftEar: CGFloat
    let rightEar: CGFloat
    let bottomStrip: CGFloat
}

struct AvatarConfig: Codable, Equatable {
    let width: CGFloat
}

struct CollapsedIndicator: Codable, Equatable {
    let type: String?      // "avatar" | "severity" | "none"
    let visible: Bool?
}

struct CollapsedConfig: Codable, Equatable {
    let indicator_width: CGFloat?
    let indicator_height: CGFloat?
    let corner_radius: CGFloat?
    let edge_padding: CGFloat?
    let notch_overlap: CGFloat?
    let left: CollapsedIndicator?
    let right: CollapsedIndicator?

    static let defaults = CollapsedConfig(
        indicator_width: 30, indicator_height: 28,
        corner_radius: 8, edge_padding: 2, notch_overlap: 40,
        left: CollapsedIndicator(type: "avatar", visible: true),
        right: CollapsedIndicator(type: "severity", visible: true)
    )
}

struct AutoMinimizeConfig: Codable, Equatable {
    let yellow: TimeInterval?
    let red: TimeInterval?
    let sos: TimeInterval?
}

/// A severity layout entry: either collapsed (green) or expanded with ear/strip sizes.
struct SeverityLayout: Codable, Equatable {
    let mode: String?       // "collapsed" for green
    let leftEar: CGFloat?
    let rightEar: CGFloat?
    let bottomStrip: CGFloat?

    /// Whether this severity level means collapsed (just dots flanking notch).
    var isCollapsed: Bool {
        mode == "collapsed"
    }

    /// Convert to a LayoutPreset (for expanded states).
    var asPreset: LayoutPreset {
        LayoutPreset(
            leftEar: leftEar ?? 200,
            rightEar: rightEar ?? 50,
            bottomStrip: bottomStrip ?? 28
        )
    }
}

struct HUDConfig: Codable, Equatable {
    // Collapsed indicator profile
    let collapsed: CollapsedConfig?
    // Auto-minimize timers
    let auto_minimize: AutoMinimizeConfig?
    // New severity-driven format
    let severity_layouts: [String: SeverityLayout]?
    let avatar: AvatarConfig?

    // Display mode: "auto" | "notch" | "floating"
    let display_mode: String?
    // Floating panel position: "center" | "left" | "right"
    let floating_position: String?

    // Legacy fields (for backward compatibility)
    let layout: String?
    let presets: [String: LayoutPreset]?

    /// Resolved collapsed config (with defaults)
    var collapsedProfile: CollapsedConfig {
        let c = collapsed ?? .defaults
        return CollapsedConfig(
            indicator_width: c.indicator_width ?? 30,
            indicator_height: c.indicator_height ?? 28,
            corner_radius: c.corner_radius ?? 8,
            edge_padding: c.edge_padding ?? 2,
            notch_overlap: c.notch_overlap ?? 40,
            left: c.left ?? CollapsedIndicator(type: "avatar", visible: true),
            right: c.right ?? CollapsedIndicator(type: "severity", visible: true)
        )
    }

    /// Auto-minimize delay for a severity (-1 = never)
    func minimizeDelay(for severity: String) -> TimeInterval {
        let am = auto_minimize
        switch severity {
        case "yellow": return am?.yellow ?? 300
        case "red":    return am?.red ?? 300
        case "sos":    return am?.sos ?? -1
        default:       return 0
        }
    }

    /// Get the layout for a given severity string ("green", "yellow", "red").
    func layoutForSeverity(_ severity: String) -> LayoutPreset {
        // Try new severity_layouts first
        if let severityLayouts = severity_layouts,
           let entry = severityLayouts[severity] {
            if entry.isCollapsed {
                // Collapsed = no ears, no strip (just notch-sized)
                return LayoutPreset(leftEar: 0, rightEar: 0, bottomStrip: 0)
            }
            return entry.asPreset
        }
        // Legacy fallback: use presets[layout]
        if let presets = presets, let layout = layout {
            return presets[layout] ?? LayoutPreset(leftEar: 200, rightEar: 50, bottomStrip: 28)
        }
        // Ultimate fallback based on severity
        switch severity {
        case "sos":
            return LayoutPreset(leftEar: 380, rightEar: 50, bottomStrip: 28)
        case "red":
            return LayoutPreset(leftEar: 380, rightEar: 50, bottomStrip: 28)
        case "yellow":
            return LayoutPreset(leftEar: 200, rightEar: 50, bottomStrip: 28)
        default:
            return LayoutPreset(leftEar: 0, rightEar: 0, bottomStrip: 0)
        }
    }

    /// Whether the given severity is collapsed (green/nominal).
    func isCollapsed(for severity: String) -> Bool {
        if let severityLayouts = severity_layouts,
           let entry = severityLayouts[severity] {
            return entry.isCollapsed
        }
        // Legacy: only green is collapsed
        return severity == "green" || severity != "yellow" && severity != "red"
    }

    /// Resolved display mode: "notch" or "floating"
    var resolvedDisplayMode: String {
        let mode = display_mode ?? "auto"
        if mode == "notch" { return "notch" }
        if mode == "floating" { return "floating" }
        // "auto": use notch if detected, else floating
        return NotchGeometry.screenHasNotch ? "notch" : "floating"
    }

    /// Resolved floating position
    var resolvedFloatingPosition: String {
        floating_position ?? "center"
    }

    static let fallback = HUDConfig(
        collapsed: .defaults,
        auto_minimize: AutoMinimizeConfig(yellow: 300, red: 300, sos: -1),
        severity_layouts: [
            "green":  SeverityLayout(mode: "collapsed", leftEar: nil, rightEar: nil, bottomStrip: nil),
            "yellow": SeverityLayout(mode: nil, leftEar: 200, rightEar: 50, bottomStrip: 28),
            "red":    SeverityLayout(mode: nil, leftEar: 380, rightEar: 50, bottomStrip: 28),
        ],
        avatar: AvatarConfig(width: 50),
        display_mode: nil,
        floating_position: nil,
        layout: nil,
        presets: nil
    )
}

// MARK: - StatusWatcher

@Observable
class StatusWatcher {
    static let shared = StatusWatcher()

    var currentStatus: AtlasStatus = AtlasStatus(
        status: "green", source: "jane",
        message: "Connecting...", updated: "", details: []
    )

    var config: HUDConfig = .fallback

    private var statusMonitor: DispatchSourceFileSystemObject?
    private var configMonitor: DispatchSourceFileSystemObject?
    private let statusPath = NSString("~/.atlas/status.json").expandingTildeInPath
    private let configPath = NSString("~/.atlas/hud-config.json").expandingTildeInPath

    func startWatching() {
        readStatus()
        readConfig()
        watchFile(path: statusPath, monitor: &statusMonitor) { [weak self] in self?.readStatus() }
        watchFile(path: configPath, monitor: &configMonitor) { [weak self] in self?.readConfig() }
    }

    private func watchFile(path: String, monitor: inout DispatchSourceFileSystemObject?, handler: @escaping () -> Void) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )
        source.setEventHandler { handler() }
        source.setCancelHandler { close(fd) }
        source.resume()
        monitor = source
    }

    private func readStatus() {
        guard let data = FileManager.default.contents(atPath: statusPath),
              let status = try? JSONDecoder().decode(AtlasStatus.self, from: data) else {
            return
        }
        currentStatus = status
    }

    private func readConfig() {
        guard let data = FileManager.default.contents(atPath: configPath),
              let config = try? JSONDecoder().decode(HUDConfig.self, from: data) else {
            return
        }
        self.config = config
        // Notify that layout changed
        NotificationCenter.default.post(name: .NotchyNotchStatusChanged, object: nil)
    }
}
