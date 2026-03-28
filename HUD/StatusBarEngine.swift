import SwiftUI

// MARK: - Status Bar Display Protocol

/// Any display engine that can render in the status bar area.
protocol StatusBarDisplay: View {
    var displayId: String { get }
    var displayName: String { get }
    var minHeight: CGFloat { get }
    var supportedSizes: [StatusBarSize] { get }
}

// MARK: - Status Bar Enums

enum StatusBarSize: String, Codable {
    case xs, small, medium, large, xl

    /// Unified heights — shared by text and LCD
    /// XS=13  S=15  M=17  L=20  XL=28
    var height: CGFloat {
        switch self {
        case .xs:     return 13
        case .small:  return 15
        case .medium: return 17
        case .large:  return 20
        case .xl:     return 28
        }
    }

    /// Text font size for each level
    var textFontSize: CGFloat {
        switch self {
        case .xs:     return 9
        case .small:  return 10
        case .medium: return 12
        case .large:  return 14
        case .xl:     return 18
        }
    }

    /// LCD cell pitch (height / 7 rows)
    var lcdCellSize: CGFloat {
        height / 7.0
    }

    /// Whether LCD is supported at this size
    var lcdSupported: Bool {
        self != .xs  // XS is text-only
    }
}

// What the bar displays (visualization type)
enum StatusBarMode: String, Codable {
    case scanner, histogram, sparkline, heatmap, progress  // scanner-class (4pt, animated)
    case content  // text/lcd content (uses renderer + presentation)
}

// How to draw the content
enum StatusBarRenderer: String, Codable {
    case text   // smooth system font
    case lcd    // 5×7 dot-matrix pixels
}

// How to present the content
enum StatusBarPresentation: String, Codable {
    case `static`  // fixed in place
    case scroll    // scrolling left
    case rsvp      // one word at a time
}

// MARK: - Status Bar Config (declarative, JSON-driven)

struct StatusBarConfig: Codable, Equatable {
    let mode: String         // "scanner", "histogram", "content", etc.
    let size: String?        // "xs", "small", "medium", "large", "xl"
    let color: String?       // color theme (hex or named: "red", "green", "amber", "blue")
    let data: [Double]?      // for data-driven displays (histogram, sparkline, wpm)
    let text: String?        // text content
    let renderer: String?    // "text" or "lcd" (default: "text")
    let presentation: String? // "static", "scroll", "rsvp" (default: "static")

    var resolvedSize: StatusBarSize {
        StatusBarSize(rawValue: size ?? "medium") ?? .medium
    }

    var resolvedMode: StatusBarMode {
        // Map legacy modes
        switch mode {
        case "lcd", "text", "rsvp", "lcdrsvp": return .content
        default: return StatusBarMode(rawValue: mode) ?? .scanner
        }
    }

    var resolvedRenderer: StatusBarRenderer {
        // Explicit renderer wins, then infer from legacy mode
        if let r = renderer { return StatusBarRenderer(rawValue: r) ?? .text }
        switch mode {
        case "lcd", "lcdrsvp": return .lcd
        default: return .text
        }
    }

    var resolvedPresentation: StatusBarPresentation {
        // Explicit presentation wins, then infer from legacy mode
        if let p = presentation { return StatusBarPresentation(rawValue: p) ?? .static }
        switch mode {
        case "rsvp", "lcdrsvp": return .rsvp
        case "scroll": return .scroll
        default: return .static
        }
    }

    /// Resolved color (falls back to red)
    var resolvedColor: Color {
        guard let color else { return .red }
        switch color.lowercased() {
        case "red":    return .red
        case "green":  return .green
        case "yellow": return .yellow
        case "blue":   return .blue
        case "white":  return .white
        case "orange": return .orange
        case "cyan":   return .cyan
        default:       return Color(hex: color) ?? .red
        }
    }

    /// Default config — KITT scanner, small size
    static let `default` = StatusBarConfig(
        mode: "scanner", size: "small", color: nil, data: nil, text: nil, renderer: nil, presentation: nil
    )
}

// MARK: - Status Bar Layout (shared sizing)

enum StatusBarLayout {
    enum Mode {
        case thin    // 4pt — KITT scanner, color segments
        case medium  // 14pt — single line LCD dot-matrix text
        case thick   // 24pt — two lines or pixel grid
    }

    static var currentConfig: StatusBarConfig? {
        StatusWatcher.shared.currentStatus.statusBar
    }

    static var mode: Mode {
        guard let config = currentConfig else {
            let status = StatusWatcher.shared.currentStatus.status
            if status == "green" { return .thin }
            return .medium
        }
        switch config.mode {
        case "scanner", "histogram", "progress", "heartbeat", "vu", "sparkline":
            return .thin
        default:
            let resolved = StatusBarSize(rawValue: config.size ?? "medium") ?? .medium
            switch resolved {
            case .xs, .small, .medium: return .medium
            case .large, .xl:          return .thick
            }
        }
    }

    static var height: CGFloat {
        guard let config = currentConfig else {
            return mode == .thin ? 4 : 17
        }
        switch config.mode {
        case "scanner", "histogram", "progress", "heartbeat", "vu", "sparkline":
            return 4
        default:
            let resolved = StatusBarSize(rawValue: config.size ?? "medium") ?? .medium
            return resolved.height
        }
    }
}
