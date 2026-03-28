import SwiftUI

// MARK: - LCD 5x7 Font Dictionary

/// Standard 5x7 dot-matrix bitmap font (HD44780-compatible).
/// Each character is 5 columns x 7 rows, stored as 7 bytes (one per row, 5 LSBs used).
enum LCDFont {
    static let lcd5x7: [Character: [UInt8]] = {
        var font: [Character: [UInt8]] = [:]
        font["A"] = [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001]
        font["B"] = [0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110]
        font["C"] = [0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110]
        font["D"] = [0b11100, 0b10010, 0b10001, 0b10001, 0b10001, 0b10010, 0b11100]
        font["E"] = [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111]
        font["F"] = [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000]
        font["G"] = [0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110]
        font["H"] = [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001]
        font["I"] = [0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110]
        font["J"] = [0b00111, 0b00010, 0b00010, 0b00010, 0b00010, 0b10010, 0b01100]
        font["K"] = [0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001]
        font["L"] = [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111]
        font["M"] = [0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001]
        font["N"] = [0b10001, 0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001]
        font["O"] = [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110]
        font["P"] = [0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000]
        font["Q"] = [0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101]
        font["R"] = [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001]
        font["S"] = [0b01110, 0b10001, 0b10000, 0b01110, 0b00001, 0b10001, 0b01110]
        font["T"] = [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100]
        font["U"] = [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110]
        font["V"] = [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100]
        font["W"] = [0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b11011, 0b10001]
        font["X"] = [0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001]
        font["Y"] = [0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100]
        font["Z"] = [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111]
        font["0"] = [0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110]
        font["1"] = [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110]
        font["2"] = [0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111]
        font["3"] = [0b01110, 0b10001, 0b00001, 0b00110, 0b00001, 0b10001, 0b01110]
        font["4"] = [0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010]
        font["5"] = [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110]
        font["6"] = [0b01110, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110]
        font["7"] = [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000]
        font["8"] = [0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110]
        font["9"] = [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b01110]
        font[" "] = [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000]
        font[":"] = [0b00000, 0b00100, 0b00100, 0b00000, 0b00100, 0b00100, 0b00000]
        font["-"] = [0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000]
        font["."] = [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00100]
        font["!"] = [0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00000, 0b00100]
        font["★"] = [0b00100, 0b00100, 0b11111, 0b01110, 0b01010, 0b10001, 0b00000]
        font["?"] = [0b01110, 0b10001, 0b00001, 0b00110, 0b00100, 0b00000, 0b00100]
        font["/"] = [0b00001, 0b00010, 0b00010, 0b00100, 0b01000, 0b01000, 0b10000]
        font["%"] = [0b11001, 0b11010, 0b00010, 0b00100, 0b01000, 0b01011, 0b10011]
        font["("] = [0b00010, 0b00100, 0b01000, 0b01000, 0b01000, 0b00100, 0b00010]
        font[")"] = [0b01000, 0b00100, 0b00010, 0b00010, 0b00010, 0b00100, 0b01000]
        font["+"] = [0b00000, 0b00100, 0b00100, 0b11111, 0b00100, 0b00100, 0b00000]
        font["="] = [0b00000, 0b00000, 0b11111, 0b00000, 0b11111, 0b00000, 0b00000]
        font["<"] = [0b00010, 0b00100, 0b01000, 0b10000, 0b01000, 0b00100, 0b00010]
        font[">"] = [0b01000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b01000]
        font["#"] = [0b01010, 0b01010, 0b11111, 0b01010, 0b11111, 0b01010, 0b01010]
        font["@"] = [0b01110, 0b10001, 0b10111, 0b10101, 0b10110, 0b10000, 0b01110]
        font["_"] = [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b11111]
        return font
    }()

    // MARK: - Custom Characters (CGRAM — HD44780 compatible, 8 slots)

    /// Custom 5x7 sprite characters — loaded into CGRAM slots 0-7
    static var customChars: [UInt8: [UInt8]] = [:]

    /// Built-in sprite library
    static let sprites: [String: [UInt8]] = [
        // Pac-Man frames
        "pacman_open":   [0b01110, 0b11011, 0b11100, 0b11000, 0b11100, 0b11111, 0b01110],
        "pacman_closed": [0b01110, 0b11111, 0b11111, 0b11111, 0b11111, 0b11111, 0b01110],
        "ghost":         [0b01110, 0b11111, 0b10101, 0b11111, 0b11111, 0b11111, 0b10101],
        "dot":           [0b00000, 0b00000, 0b00000, 0b00100, 0b00000, 0b00000, 0b00000],
        "pellet":        [0b00000, 0b01110, 0b01110, 0b01110, 0b01110, 0b01110, 0b00000],

        // Hearts & icons
        "heart":         [0b00000, 0b01010, 0b11111, 0b11111, 0b01110, 0b00100, 0b00000],
        "heart_empty":   [0b00000, 0b01010, 0b10101, 0b10001, 0b01010, 0b00100, 0b00000],
        "skull":         [0b01110, 0b10001, 0b10101, 0b10001, 0b01110, 0b01110, 0b01010],
        "smiley":        [0b00000, 0b01010, 0b00000, 0b10001, 0b01110, 0b00000, 0b00000],
        "frown":         [0b00000, 0b01010, 0b00000, 0b01110, 0b10001, 0b00000, 0b00000],

        // Arrows
        "arrow_right":   [0b00000, 0b00100, 0b00010, 0b11111, 0b00010, 0b00100, 0b00000],
        "arrow_left":    [0b00000, 0b00100, 0b01000, 0b11111, 0b01000, 0b00100, 0b00000],
        "arrow_up":      [0b00100, 0b01110, 0b10101, 0b00100, 0b00100, 0b00100, 0b00000],
        "arrow_down":    [0b00000, 0b00100, 0b00100, 0b00100, 0b10101, 0b01110, 0b00100],

        // Progress blocks
        "block_full":    [0b11111, 0b11111, 0b11111, 0b11111, 0b11111, 0b11111, 0b11111],
        "block_half":    [0b11000, 0b11000, 0b11000, 0b11000, 0b11000, 0b11000, 0b11000],
        "block_quarter": [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000],
        "block_top":     [0b11111, 0b11111, 0b11111, 0b00000, 0b00000, 0b00000, 0b00000],
        "block_bottom":  [0b00000, 0b00000, 0b00000, 0b00000, 0b11111, 0b11111, 0b11111],

        // Music
        "note":          [0b00100, 0b00110, 0b00101, 0b00100, 0b00100, 0b11100, 0b11100],
        "speaker":       [0b00001, 0b00011, 0b11111, 0b11111, 0b11111, 0b00011, 0b00001],

        // Weather
        "sun":           [0b00100, 0b10101, 0b01110, 0b11111, 0b01110, 0b10101, 0b00100],
        "cloud":         [0b00000, 0b01100, 0b11110, 0b01111, 0b11111, 0b00000, 0b00000],
        "rain":          [0b00000, 0b01110, 0b11111, 0b00000, 0b01010, 0b10100, 0b01010],
        "bolt":          [0b00010, 0b00100, 0b01000, 0b11111, 0b00010, 0b00100, 0b01000],

        // System
        "check":         [0b00000, 0b00001, 0b00010, 0b10100, 0b01000, 0b00000, 0b00000],
        "cross":         [0b00000, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b00000],
        "lock":          [0b01110, 0b10001, 0b10001, 0b11111, 0b11011, 0b11011, 0b11111],
        "wifi":          [0b01110, 0b10001, 0b00100, 0b01010, 0b00000, 0b00100, 0b00000],
        "battery":       [0b01110, 0b11111, 0b10001, 0b10001, 0b10001, 0b11111, 0b11111],
        "hourglass":     [0b11111, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b11111],
    ]

    /// Load a sprite into a CGRAM slot (0-7), maps to characters \0 through \7
    static func loadCustomChar(slot: UInt8, name: String) {
        guard slot < 8, let sprite = sprites[name] else { return }
        customChars[slot] = sprite
    }

    /// Get bitmap for a character — checks CGRAM first, then standard font
    static func bitmap(for char: Character) -> [UInt8] {
        // CGRAM characters mapped to ASCII 0-7 or Unicode private use
        if let ascii = char.asciiValue, ascii < 8, let custom = customChars[ascii] {
            return custom
        }
        return lcd5x7[char] ?? lcd5x7["?"]!
    }
}

// MARK: - LCD Color Themes

enum LCDTheme: String, Codable {
    case red         // classic red LED
    case green       // classic green LCD
    case amber       // warm amber
    case blue        // blue LED
    case rgb         // per-character color from data
    case severity    // color from system severity

    var litColor: Color {
        switch self {
        case .red:      return Color(red: 1.0, green: 0.1, blue: 0.05)
        case .green:    return Color(red: 0.1, green: 1.0, blue: 0.2)
        case .amber:    return Color(red: 1.0, green: 0.7, blue: 0.0)
        case .blue:     return Color(red: 0.2, green: 0.5, blue: 1.0)
        case .rgb:      return .white  // overridden per-char
        case .severity: return .white  // overridden at render time
        }
    }

    var backgroundColor: Color {
        switch self {
        case .green:    return Color(red: 0.01, green: 0.04, blue: 0.01)
        case .amber:    return Color(red: 0.03, green: 0.02, blue: 0.01)
        case .blue:     return Color(red: 0.01, green: 0.01, blue: 0.04)
        default:        return Color(red: 0.02, green: 0.01, blue: 0.01)
        }
    }

    var dimAlpha: Double { 0.08 }
    var litAlpha: Double { 0.9 }
}

// MARK: - LCD GFX Primitives

/// Virtual framebuffer for the LCD — supports per-pixel color
class LCDFrameBuffer {
    let cols: Int
    let rows: Int
    var pixels: [(r: Double, g: Double, b: Double, on: Bool)]

    init(cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
        self.pixels = Array(repeating: (0, 0, 0, false), count: cols * rows)
    }

    func clear() {
        for i in pixels.indices { pixels[i] = (0, 0, 0, false) }
    }

    func setPixel(x: Int, y: Int, r: Double, g: Double, b: Double) {
        guard x >= 0, x < cols, y >= 0, y < rows else { return }
        pixels[y * cols + x] = (r, g, b, true)
    }

    func drawChar(_ char: Character, atCol col: Int, row: Int, r: Double, g: Double, b: Double) {
        let bitmap = LCDFont.bitmap(for: char)
        for dy in 0..<7 {
            let rowBits = bitmap[dy]
            for dx in 0..<5 {
                if (rowBits >> (4 - dx)) & 1 == 1 {
                    setPixel(x: col + dx, y: row + dy, r: r, g: g, b: b)
                }
            }
        }
    }

    func drawText(_ text: String, atCol col: Int, row: Int, r: Double, g: Double, b: Double) {
        for (i, char) in text.enumerated() {
            drawChar(char, atCol: col + i * 6, row: row, r: r, g: g, b: b)
        }
    }

    func drawSprite(_ name: String, atCol col: Int, row: Int, r: Double, g: Double, b: Double) {
        guard let bitmap = LCDFont.sprites[name] else { return }
        for dy in 0..<min(7, bitmap.count) {
            let rowBits = bitmap[dy]
            for dx in 0..<5 {
                if (rowBits >> (4 - dx)) & 1 == 1 {
                    setPixel(x: col + dx, y: row + dy, r: r, g: g, b: b)
                }
            }
        }
    }

    func drawBar(atCol col: Int, row: Int, width: Int, height: Int, value: Double, r: Double, g: Double, b: Double) {
        let fillWidth = Int(Double(width) * min(max(value, 0), 1))
        for dy in 0..<height {
            for dx in 0..<fillWidth {
                setPixel(x: col + dx, y: row + dy, r: r, g: g, b: b)
            }
        }
    }

    func drawTextCentered(_ text: String, canvasWidth: Int, row: Int, r: Double, g: Double, b: Double) {
        let charW = 6  // 5 + 1 gap
        let textWidth = text.count * charW
        let startCol = max(0, (canvasWidth - textWidth) / 2)
        drawText(text, atCol: startCol, row: row, r: r, g: g, b: b)
    }

    func isLit(x: Int, y: Int) -> Bool {
        guard x >= 0, x < cols, y >= 0, y < rows else { return false }
        return pixels[y * cols + x].on
    }

    func colorAt(x: Int, y: Int) -> (r: Double, g: Double, b: Double) {
        guard x >= 0, x < cols, y >= 0, y < rows else { return (0, 0, 0) }
        return (pixels[y * cols + x].r, pixels[y * cols + x].g, pixels[y * cols + x].b)
    }
}

// MARK: - LCD Grid View

/// 5x7 dot-matrix bitmap text renderer with multi-color support.
struct LCDGridView: View, StatusBarDisplay {
    var displayId: String { "lcd-grid" }
    var displayName: String { "LCD Grid" }
    var minHeight: CGFloat { 13 }
    var supportedSizes: [StatusBarSize] { [.small, .medium, .large] }

    var text: String
    var size: StatusBarSize = .medium
    var color: Color = .red
    var theme: LCDTheme = .red
    var colorWords: [(text: String, r: Double, g: Double, b: Double)]? = nil

    private var dotSize: CGFloat { size.lcdCellSize * 0.7 }
    private var cellSize: CGFloat { size.lcdCellSize }

    var body: some View {
        let upperText = text.uppercased()

        ZStack {
            theme.backgroundColor

            Canvas { context, canvasSize in
                let cols = Int(canvasSize.width / cellSize)
                let rows = Int(canvasSize.height / cellSize)

                // Build framebuffer
                let fb = LCDFrameBuffer(cols: cols, rows: rows)

                if let colorWords = colorWords {
                    // Multi-color mode: each word has its own color
                    var col = 1
                    for word in colorWords {
                        fb.drawText(word.text.uppercased(), atCol: col, row: 0, r: word.r, g: word.g, b: word.b)
                        col += word.text.count * 6
                    }
                } else {
                    // Single color from theme
                    let c = theme.litColor
                    var r = 1.0, g = 0.1, b = 0.05
                    // Extract RGB from theme color
                    switch theme {
                    case .red:    r = 1.0; g = 0.1; b = 0.05
                    case .green:  r = 0.1; g = 1.0; b = 0.2
                    case .amber:  r = 1.0; g = 0.7; b = 0.0
                    case .blue:   r = 0.2; g = 0.5; b = 1.0
                    default:      r = 1.0; g = 0.1; b = 0.05
                    }
                    fb.drawText(upperText, atCol: 1, row: 0, r: r, g: g, b: b)
                }

                // Render framebuffer to canvas
                for row in 0..<rows {
                    for col in 0..<cols {
                        let px = CGFloat(col) * cellSize + (cellSize - dotSize) / 2
                        let py = CGFloat(row) * cellSize + (cellSize - dotSize) / 2
                        let rect = CGRect(x: px, y: py, width: dotSize, height: dotSize)

                        if fb.isLit(x: col, y: row) {
                            let c = fb.colorAt(x: col, y: row)
                            context.fill(Path(roundedRect: rect, cornerRadius: 0.3),
                                with: .color(Color(red: c.r, green: c.g, blue: c.b).opacity(theme.litAlpha)))
                        } else {
                            context.fill(Path(roundedRect: rect, cornerRadius: 0.3),
                                with: .color(color.opacity(theme.dimAlpha)))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - LCD RSVP (Speed Reading on dot-matrix)

struct LCDRSVPView: View, StatusBarDisplay {
    var displayId: String { "lcd-rsvp" }
    var displayName: String { "LCD Speed Reading" }
    var minHeight: CGFloat { 15 }
    var supportedSizes: [StatusBarSize] { [.small, .medium, .large, .xl] }

    var text: String
    var size: StatusBarSize = .large
    var theme: LCDTheme = .green
    var wpm: Int = 150

    @State private var currentWordIndex: Int = 0
    @State private var timer: Timer?

    private let interruptionManager = RSVPInterruptionManager.shared

    private var words: [String] {
        text.split(separator: " ").map(String.init)
    }

    private var currentWord: String {
        guard !words.isEmpty else { return "" }
        return words[currentWordIndex % words.count].uppercased()
    }

    private var interval: TimeInterval {
        60.0 / Double(wpm)
    }

    private var dotSize: CGFloat { size.lcdCellSize * 0.7 }
    private var cellSize: CGFloat { size.lcdCellSize }

    var body: some View {
        ZStack {
            theme.backgroundColor

            Canvas { context, canvasSize in
                let cols = Int(canvasSize.width / cellSize)
                let rows = Int(canvasSize.height / cellSize)

                let fb = LCDFrameBuffer(cols: cols, rows: rows)

                var r = 1.0, g = 0.1, b = 0.05
                switch theme {
                case .red:    r = 1.0; g = 0.1; b = 0.05
                case .green:  r = 0.1; g = 1.0; b = 0.2
                case .amber:  r = 1.0; g = 0.7; b = 0.0
                case .blue:   r = 0.2; g = 0.5; b = 1.0
                default:      r = 1.0; g = 0.1; b = 0.05
                }

                fb.drawTextCentered(currentWord, canvasWidth: cols, row: 0, r: r, g: g, b: b)

                for row in 0..<rows {
                    for col in 0..<cols {
                        let px = CGFloat(col) * cellSize + (cellSize - dotSize) / 2
                        let py = CGFloat(row) * cellSize + (cellSize - dotSize) / 2
                        let rect = CGRect(x: px, y: py, width: dotSize, height: dotSize)

                        if fb.isLit(x: col, y: row) {
                            let c = fb.colorAt(x: col, y: row)
                            context.fill(Path(roundedRect: rect, cornerRadius: 0.3),
                                with: .color(Color(red: c.r, green: c.g, blue: c.b).opacity(theme.litAlpha)))
                        } else {
                            let dimColor: Color
                            switch theme {
                            case .green: dimColor = .green
                            case .amber: dimColor = .orange
                            case .blue:  dimColor = .blue
                            default:     dimColor = .red
                            }
                            context.fill(Path(roundedRect: rect, cornerRadius: 0.3),
                                with: .color(dimColor.opacity(theme.dimAlpha)))
                        }
                    }
                }
            }
        }
        .onAppear {
            registerWithInterruptionManager()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            interruptionManager.unregister()
        }
        .onChange(of: text) { _, _ in
            currentWordIndex = 0
            registerWithInterruptionManager()
            startTimer()
        }
    }

    private func registerWithInterruptionManager() {
        interruptionManager.registerActive(
            text: text,
            wordIndex: currentWordIndex,
            wpm: wpm,
            renderer: "lcd",
            size: size.rawValue,
            color: nil
        )
        interruptionManager.onPauseRequest = { [self] in
            timer?.invalidate()
            timer = nil
        }
        interruptionManager.onResumeRequest = { [self] resumeIndex in
            currentWordIndex = resumeIndex
            startTimer()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            currentWordIndex += 1
            interruptionManager.updateWordIndex(currentWordIndex)
        }
    }
}
