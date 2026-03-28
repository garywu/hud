import SwiftUI

// MARK: - Plain Text Bar View

/// Simple monospace text display for the status bar.
struct PlainTextBarView: View, StatusBarDisplay {
    var displayId: String { "plain-text" }
    var displayName: String { "Plain Text" }
    var minHeight: CGFloat { 10 }
    var supportedSizes: [StatusBarSize] { [.small, .medium, .large] }

    var text: String
    var size: StatusBarSize = .medium
    var color: Color = .red

    private var fontSize: CGFloat {
        size.textFontSize
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
            Text(text.uppercased())
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.bottom, 1)
        }
        .clipShape(Capsule())
    }
}

// MARK: - RSVP Speed Reading Bar

/// Rapid Serial Visual Presentation — one word at a time, flashing in place.
/// The focus letter (ORP — Optimal Recognition Point) is highlighted.
struct RSVPBarView: View, StatusBarDisplay {
    var displayId: String { "rsvp" }
    var displayName: String { "Speed Reading" }
    var minHeight: CGFloat { 13 }
    var supportedSizes: [StatusBarSize] { [.xs, .small, .medium, .large, .xl] }

    var text: String
    var size: StatusBarSize = .medium
    var color: Color = .white
    var wpm: Int = 300  // words per minute

    @State private var currentWordIndex: Int = 0
    @State private var timer: Timer?

    private let interruptionManager = RSVPInterruptionManager.shared

    private var words: [String] {
        text.split(separator: " ").map(String.init)
    }

    private var interval: TimeInterval {
        60.0 / Double(wpm)
    }

    private var fontSize: CGFloat {
        size.textFontSize + 2  // slightly larger for readability
    }

    private var currentWord: String {
        guard !words.isEmpty else { return "" }
        return words[currentWordIndex % words.count]
    }

    /// Optimal Recognition Point — the letter the eye should fixate on
    /// Rule: word length 1-3: first letter, 4-6: second, 7-9: third, 10+: fourth
    private var orpIndex: Int {
        let len = currentWord.count
        if len <= 3 { return 0 }
        if len <= 6 { return 1 }
        if len <= 9 { return 2 }
        return 3
    }

    var body: some View {
        ZStack {
            Color.black

            // ORP guide line (thin vertical mark at center)
            Rectangle()
                .fill(color.opacity(0.15))
                .frame(width: 1, height: .infinity)

            // The word — ORP letter highlighted
            HStack(spacing: 0) {
                let word = currentWord
                let orp = orpIndex
                ForEach(Array(word.enumerated()), id: \.offset) { idx, char in
                    Text(String(char))
                        .font(.system(size: fontSize, weight: idx == orp ? .black : .medium, design: .monospaced))
                        .foregroundColor(idx == orp ? color : color.opacity(0.6))
                }
            }
            .offset(x: -CGFloat(orpIndex) * fontSize * 0.6)  // center on ORP
        }
        .clipShape(Capsule())
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
            renderer: "text",
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
            withAnimation(.none) {
                currentWordIndex += 1
                interruptionManager.updateWordIndex(currentWordIndex)
            }
        }
    }
}
