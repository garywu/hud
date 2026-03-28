import SwiftUI
import Observation

// MARK: - Theme Data Model

struct HUDTheme: Codable, Equatable {
    let name: String
    let colors: ThemeColors?
    let typography: ThemeTypography?
    let animations: ThemeAnimations?
    let bannerStyle: String?  // default banner style for this theme
}

struct ThemeColors: Codable, Equatable {
    let info: String?       // hex color for green/nominal
    let success: String?
    let warning: String?    // hex for yellow
    let error: String?      // hex for red
    let critical: String?
    let background: String?
    let foreground: String?
}

struct ThemeTypography: Codable, Equatable {
    let font: String?       // "monospaced" | "rounded" | "serif"
    let size: CGFloat?
    let weight: String?     // "heavy" | "bold" | "medium"
    let letterSpacing: CGFloat?
    let textTransform: String?  // "uppercase" | "none"
}

struct ThemeAnimations: Codable, Equatable {
    let expand: String?     // "bounce" | "ease" | "spring"
    let collapse: String?
    let bannerSpeed: Double?
}

// MARK: - ThemeEngine

@Observable
class ThemeEngine {
    static let shared = ThemeEngine()

    var activeTheme: HUDTheme = HUDTheme(
        name: "minimal", colors: nil, typography: nil, animations: nil, bannerStyle: nil
    )

    private var themeMonitor: DispatchSourceFileSystemObject?
    private let themePath = NSString("~/.atlas/hud-theme.json").expandingTildeInPath

    func startWatching() {
        readTheme()
        let fd = open(themePath, O_EVTONLY)
        guard fd >= 0 else {
            // Theme file doesn't exist yet — write the default
            writeDefaultTheme()
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename], queue: .main
        )
        source.setEventHandler { [weak self] in self?.readTheme() }
        source.setCancelHandler { close(fd) }
        source.resume()
        themeMonitor = source
    }

    private func readTheme() {
        guard let data = FileManager.default.contents(atPath: themePath),
              let theme = try? JSONDecoder().decode(HUDTheme.self, from: data) else {
            return
        }
        activeTheme = theme
    }

    // MARK: - Color resolution

    /// Resolve a Color for a severity string, checking theme colors first then falling back.
    func colorForSeverity(_ severity: String) -> Color {
        if let colors = activeTheme.colors {
            let hex: String?
            switch severity {
            case "green":   hex = colors.info ?? colors.success
            case "yellow":  hex = colors.warning
            case "red":     hex = colors.error
            case "critical": hex = colors.critical ?? colors.error
            default:        hex = colors.foreground
            }
            if let hex, let color = Color(hex: hex) {
                return color
            }
        }
        // Fallback defaults
        switch severity {
        case "green":   return .green
        case "yellow":  return .yellow
        case "red":     return .red
        default:        return .white
        }
    }

    /// Themed foreground color (falls back to white).
    var foregroundColor: Color {
        if let hex = activeTheme.colors?.foreground, let c = Color(hex: hex) { return c }
        return .white
    }

    /// Themed background color (falls back to black).
    var backgroundColor: Color {
        if let hex = activeTheme.colors?.background, let c = Color(hex: hex) { return c }
        return .black
    }

    // MARK: - Font resolution

    /// Build a Font from the theme typography settings.
    func bannerFont() -> Font {
        let size = activeTheme.typography?.size ?? 12
        let base: Font
        switch activeTheme.typography?.font {
        case "rounded":
            base = .system(size: size, design: .rounded)
        case "serif":
            base = .system(size: size, design: .serif)
        default:
            base = .system(size: size, design: .monospaced)
        }
        return base.weight(resolveWeight())
    }

    private func resolveWeight() -> Font.Weight {
        switch activeTheme.typography?.weight {
        case "heavy":      return .heavy
        case "bold":       return .bold
        case "medium":     return .medium
        case "light":      return .light
        case "semibold":   return .semibold
        default:           return .heavy
        }
    }

    /// Whether text should be uppercased per theme.
    var textTransformUppercase: Bool {
        activeTheme.typography?.textTransform == "uppercase"
    }

    /// Letter spacing from theme (defaults to 0).
    var letterSpacing: CGFloat {
        activeTheme.typography?.letterSpacing ?? 0
    }

    // MARK: - Animation resolution

    /// Expand animation from theme.
    var expandAnimation: Animation {
        switch activeTheme.animations?.expand {
        case "bounce":  return .bouncy
        case "ease":    return .easeInOut(duration: 0.3)
        case "spring":  return .spring(response: 0.4, dampingFraction: 0.6)
        default:        return .easeInOut(duration: 0.3)
        }
    }

    /// Banner scroll speed (points per second, default 50).
    var bannerSpeed: Double {
        activeTheme.animations?.bannerSpeed ?? 50
    }

    /// Effective banner style: theme default, overridable per-status.
    func effectiveBannerStyle(statusOverride: String?) -> String {
        statusOverride ?? activeTheme.bannerStyle ?? "scroll"
    }

    // MARK: - Default theme file

    private func writeDefaultTheme() {
        let defaultTheme = HUDTheme(
            name: "minimal",
            colors: ThemeColors(
                info: "#34D399", success: nil, warning: "#FBBF24",
                error: "#F87171", critical: nil, background: "#000000", foreground: "#FFFFFF"
            ),
            typography: ThemeTypography(
                font: "monospaced", size: 12, weight: "heavy",
                letterSpacing: nil, textTransform: nil
            ),
            animations: nil,
            bannerStyle: "scroll"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(defaultTheme) else { return }

        // Ensure ~/.atlas directory exists
        let atlasDir = NSString("~/.atlas").expandingTildeInPath
        try? FileManager.default.createDirectory(
            atPath: atlasDir, withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: themePath, contents: data)

        // Now read it back and start watching
        readTheme()
        let fd = open(themePath, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename], queue: .main
        )
        source.setEventHandler { [weak self] in self?.readTheme() }
        source.setCancelHandler { close(fd) }
        source.resume()
        themeMonitor = source
    }
}

// MARK: - Color hex parsing

extension Color {
    /// Create a Color from a hex string like "#FF9900" or "FF9900".
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
