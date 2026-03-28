import SwiftUI

// MARK: - Jane Face Avatar

/// Jane's face — WALL-E style visor with two glowing eyes
struct JaneFace: View {
    let color: Color
    let isUrgent: Bool

    @State private var blinkPhase = false
    @State private var pulsePhase = false
    @State private var scanPhase = false

    var body: some View {
        ZStack {
            Capsule()
                .fill(color.opacity(0.15))
                .frame(width: 22, height: 10)
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )

            HStack(spacing: 7) {
                eyeDot
                eyeDot
            }

            if isUrgent {
                Capsule()
                    .fill(color.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .offset(x: scanPhase ? 7 : -7)
                    .blur(radius: 2)
            }
        }
        .shadow(color: color.opacity(isUrgent ? 0.8 : 0.4), radius: isUrgent ? 6 : 3)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.12)) { blinkPhase = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeInOut(duration: 0.12)) { blinkPhase = false }
                }
            }
            if isUrgent {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    scanPhase = true
                }
            }
        }
    }

    private var eyeDot: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: blinkPhase ? 1.5 : 4)
            .shadow(color: color, radius: isUrgent ? 4 : 2)
    }
}

// MARK: - Banner Theme Router

struct BannerView: View {
    let text: String
    let ledColor: Color
    let speed: Double
    let style: String  // "scroll" | "typewriter" | "flash" | "slide" | "split-flap"

    var body: some View {
        switch style {
        case "typewriter":
            TypewriterBanner(text: text, ledColor: ledColor)
        case "flash":
            FlashBanner(text: text, ledColor: ledColor)
        case "slide":
            SlideBanner(text: text, ledColor: ledColor, speed: speed)
        case "split-flap":
            SplitFlapBanner(text: text, ledColor: ledColor)
        default:
            ScrollBanner(text: text, ledColor: ledColor, speed: speed)
        }
    }
}

// MARK: - Scroll (classic ticker)

struct ScrollBanner: View {
    let text: String
    let ledColor: Color
    let speed: Double

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: containerWidth * 0.5) {
                bannerText
                    .background(
                        GeometryReader { textGeo in
                            Color.clear
                                .onAppear {
                                    textWidth = textGeo.size.width
                                    containerWidth = geo.size.width
                                    startScroll()
                                }
                                .onChange(of: text) { _, _ in
                                    textWidth = 0
                                    offset = geo.size.width
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        textWidth = textGeo.size.width
                                        startScroll()
                                    }
                                }
                        }
                    )
                bannerText
            }
            .offset(x: offset)
        }
        .clipped()
    }

    private var bannerText: some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .foregroundColor(ledColor)
            .fixedSize()
    }

    private func startScroll() {
        let gap = containerWidth * 0.5
        let totalDistance = textWidth + gap + containerWidth
        offset = containerWidth
        withAnimation(.linear(duration: totalDistance / speed).repeatForever(autoreverses: false)) {
            offset = -(textWidth + gap)
        }
    }
}

// MARK: - Typewriter (characters appear one at a time)

struct TypewriterBanner: View {
    let text: String
    let ledColor: Color

    @State private var visibleCount: Int = 0
    @State private var showCursor = true
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 0) {
            Text(String(text.prefix(visibleCount)))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(ledColor)
            if visibleCount < text.count {
                Text("▌")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(ledColor)
                    .opacity(showCursor ? 1 : 0)
            }
            Spacer()
        }
        .onAppear { startTyping() }
        .onChange(of: text) { _, _ in
            visibleCount = 0
            startTyping()
        }
    }

    private func startTyping() {
        timer?.invalidate()
        visibleCount = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
            if visibleCount < text.count {
                visibleCount += 1
                let char = text[text.index(text.startIndex, offsetBy: visibleCount - 1)]
                if char == " " || char == "★" || char == "⚡" {
                    t.fireDate = Date().addingTimeInterval(0.12)
                }
            } else {
                t.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    visibleCount = 0
                    startTyping()
                }
            }
        }
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            showCursor.toggle()
        }
    }
}

// MARK: - Flash (instant appear, pulse, hold)

struct FlashBanner: View {
    let text: String
    let ledColor: Color

    @State private var opacity: Double = 0
    @State private var flashCount = 0

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .foregroundColor(ledColor)
            .opacity(opacity)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear { startFlash() }
            .onChange(of: text) { _, _ in
                opacity = 0
                flashCount = 0
                startFlash()
            }
    }

    private func startFlash() {
        func doFlash() {
            withAnimation(.easeIn(duration: 0.08)) { opacity = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.08)) { opacity = 0.1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    flashCount += 1
                    if flashCount < 3 {
                        doFlash()
                    } else {
                        withAnimation(.easeIn(duration: 0.2)) { opacity = 1 }
                    }
                }
            }
        }
        doFlash()
    }
}

// MARK: - Slide (slide in, pause, slide out)

struct SlideBanner: View {
    let text: String
    let ledColor: Color
    let speed: Double

    @State private var offset: CGFloat = 400
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(ledColor)
                .fixedSize()
                .offset(x: offset)
                .onAppear {
                    containerWidth = geo.size.width
                    startSlide()
                }
                .onChange(of: text) { _, _ in
                    offset = containerWidth
                    startSlide()
                }
        }
        .clipped()
    }

    private func startSlide() {
        offset = containerWidth
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            offset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeIn(duration: 0.4)) {
                offset = -containerWidth
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                startSlide()
            }
        }
    }
}

// MARK: - Split-Flap (airport departure board)

struct SplitFlapBanner: View {
    let text: String
    let ledColor: Color

    @State private var revealed: [Bool] = []
    @State private var scrambled: [Character] = []
    private let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ★⚡●"

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { idx, target in
                Text(String(idx < scrambled.count ? scrambled[idx] : " "))
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(
                        (idx < revealed.count && revealed[idx])
                        ? ledColor
                        : ledColor.opacity(0.4)
                    )
            }
            Spacer()
        }
        .onAppear { startFlip() }
        .onChange(of: text) { _, _ in startFlip() }
    }

    private func startFlip() {
        let textChars = Array(text)
        scrambled = textChars.map { _ in chars.randomElement() ?? "X" }
        revealed = Array(repeating: false, count: textChars.count)

        for i in textChars.indices {
            let delay = Double(i) * 0.04
            let flips = Int.random(in: 3...6)

            for flip in 0..<flips {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(flip) * 0.06) {
                    if i < scrambled.count {
                        scrambled[i] = chars.randomElement() ?? "X"
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(flips) * 0.06) {
                if i < scrambled.count {
                    scrambled[i] = textChars[i]
                }
                if i < revealed.count {
                    revealed[i] = true
                }
            }
        }

        let totalDuration = Double(textChars.count) * 0.04 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 4.0) {
            startFlip()
        }
    }
}
