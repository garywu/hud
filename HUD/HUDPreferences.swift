import Foundation
import Observation

// MARK: - User Preferences Model

/// Manages user preferences, persisted to ~/.atlas/hud-config.json.
/// StatusWatcher already watches this file, so changes are picked up automatically.
@Observable
class HUDPreferences {
    static let shared = HUDPreferences()

    // General
    var launchAtLogin: Bool = false
    var showInNotch: Bool = true
    var statusBarSize: StatusBarSize = .medium

    // Display
    var displayMode: String = "scanner"       // "scanner" | "lcd" | "text"
    var lcdTheme: String = "red"              // "red" | "green" | "amber" | "blue"
    var scannerSpeed: Double = 1.0            // multiplier: 0.5 - 3.0
    var rsvpWPM: Int = 150                    // 100 - 600

    // Plugins
    var rotationInterval: Double = 10.0       // seconds

    // Notifications
    var defaultTTL: Int = 300                 // seconds
    var escalationEnabled: Bool = true
    var focusMode: String = "off"             // "off" | "work" | "sleep" | "personal"
    var rateLimitPerSource: Int = 10           // notifications per minute

    private let configPath = NSString("~/.atlas/hud-config.json").expandingTildeInPath

    init() {
        load()
    }

    // MARK: - Load from hud-config.json

    func load() {
        guard let data = FileManager.default.contents(atPath: configPath),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Read user_preferences sub-object
        guard let prefs = dict["user_preferences"] as? [String: Any] else { return }

        if let v = prefs["launch_at_login"] as? Bool { launchAtLogin = v }
        if let v = prefs["show_in_notch"] as? Bool { showInNotch = v }
        if let v = prefs["status_bar_size"] as? String,
           let size = StatusBarSize(rawValue: v) { statusBarSize = size }

        if let v = prefs["display_mode"] as? String { displayMode = v }
        if let v = prefs["lcd_theme"] as? String { lcdTheme = v }
        if let v = prefs["scanner_speed"] as? Double { scannerSpeed = v }
        if let v = prefs["rsvp_wpm"] as? Int { rsvpWPM = v }

        if let v = prefs["rotation_interval"] as? Double { rotationInterval = v }

        if let v = prefs["default_ttl"] as? Int { defaultTTL = v }
        if let v = prefs["escalation_enabled"] as? Bool { escalationEnabled = v }
        if let v = prefs["focus_mode"] as? String { focusMode = v }
        if let v = prefs["rate_limit_per_source"] as? Int { rateLimitPerSource = v }
    }

    // MARK: - Save to hud-config.json (merge-safe)

    func save() {
        // Read existing config to preserve other keys
        var dict: [String: Any] = [:]
        if let data = FileManager.default.contents(atPath: configPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict = existing
        }

        // Build preferences sub-object
        let prefs: [String: Any] = [
            "launch_at_login": launchAtLogin,
            "show_in_notch": showInNotch,
            "status_bar_size": statusBarSize.rawValue,
            "display_mode": displayMode,
            "lcd_theme": lcdTheme,
            "scanner_speed": scannerSpeed,
            "rsvp_wpm": rsvpWPM,
            "rotation_interval": rotationInterval,
            "default_ttl": defaultTTL,
            "escalation_enabled": escalationEnabled,
            "focus_mode": focusMode,
            "rate_limit_per_source": rateLimitPerSource,
        ]

        dict["user_preferences"] = prefs

        // Write back
        let dir = (configPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
    }
}
