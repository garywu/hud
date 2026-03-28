import SwiftUI

// MARK: - KITT Scanner View

/// Red sweep scanner (Knight Rider style), 4pt height.
struct KITTScannerView: View, StatusBarDisplay {
    var displayId: String { "kitt-scanner" }
    var displayName: String { "KITT Scanner" }
    var minHeight: CGFloat { 4 }
    var supportedSizes: [StatusBarSize] { [.small, .medium, .large] }

    var color: Color = .red

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                // Background: dim
                let bgRect = CGRect(origin: .zero, size: size)
                context.fill(Path(bgRect), with: .color(color.opacity(0.15)))

                // Scanner position: smooth sine wave oscillation
                let cycle = 2.0
                let phase = sin(t * .pi / cycle) * 0.5 + 0.5

                let scanX = phase * size.width
                let scanWidth: CGFloat = size.width * 0.18

                // Wide glow trail — 32 layers for smooth blending
                for i in 0..<32 {
                    let trailAlpha = 0.25 - Double(i) * 0.008
                    let spread = CGFloat(i) * scanWidth * 0.08
                    let trailRect = CGRect(
                        x: scanX - (scanWidth + spread) / 2,
                        y: -size.height,
                        width: scanWidth + spread,
                        height: size.height * 3
                    )
                    context.fill(Path(ellipseIn: trailRect), with: .color(color.opacity(trailAlpha)))
                }

                // Main scanner blob
                let mainRect = CGRect(
                    x: scanX - scanWidth / 2,
                    y: -size.height,
                    width: scanWidth,
                    height: size.height * 3
                )
                context.fill(Path(ellipseIn: mainRect), with: .color(color.opacity(0.8)))

                // Hot center
                let centerW = scanWidth * 0.3
                let centerRect = CGRect(
                    x: scanX - centerW / 2,
                    y: -size.height * 0.5,
                    width: centerW,
                    height: size.height * 2
                )
                context.fill(Path(ellipseIn: centerRect), with: .color(Color(red: 1.0, green: 0.1, blue: 0.05).opacity(1.0)))

                // Core
                let coreW = scanWidth * 0.12
                let coreRect = CGRect(
                    x: scanX - coreW / 2,
                    y: -size.height * 0.3,
                    width: coreW,
                    height: size.height * 1.6
                )
                context.fill(Path(ellipseIn: coreRect), with: .color(Color(red: 1.0, green: 0.2, blue: 0.1).opacity(1.0)))
            }
        }
    }
}

// MARK: - Histogram View

/// Animated bar histogram with color-coded levels.
struct HistogramView: View, StatusBarDisplay {
    var displayId: String { "histogram" }
    var displayName: String { "Histogram" }
    var minHeight: CGFloat { 4 }
    var supportedSizes: [StatusBarSize] { [.small, .medium, .large] }

    var data: [Double]?
    var size: StatusBarSize = .small
    var color: Color?

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let barCount = data?.count ?? 40
                let barWidth = canvasSize.width / CGFloat(barCount)
                let gap: CGFloat = 0.5

                for i in 0..<barCount {
                    let value: Double
                    if let data, i < data.count {
                        // Use provided data with subtle animation
                        let wiggle = sin(t * 2.0 + Double(i) * 0.5) * 0.05
                        value = min(max(data[i] + wiggle, 0.05), 1.0)
                    } else {
                        // Generate animated values
                        let phase1 = sin(t * 2.0 + Double(i) * 0.3) * 0.3
                        let phase2 = sin(t * 3.5 + Double(i) * 0.5) * 0.2
                        let phase3 = sin(t * 1.2 + Double(i) * 0.15) * 0.25
                        let base = 0.25
                        value = min(max(base + phase1 + phase2 + phase3, 0.05), 1.0)
                    }

                    let barHeight = CGFloat(value) * canvasSize.height
                    let x = CGFloat(i) * barWidth
                    let y = canvasSize.height - barHeight

                    let rect = CGRect(x: x + gap / 2, y: y, width: barWidth - gap, height: barHeight)

                    let barColor: Color
                    if let color {
                        barColor = color
                    } else if value > 0.7 {
                        barColor = .red
                    } else if value > 0.4 {
                        barColor = .yellow
                    } else {
                        barColor = .green
                    }
                    context.fill(Path(rect), with: .color(barColor.opacity(0.85)))
                }
            }
        }
        .background(Color(red: 0.02, green: 0.02, blue: 0.02))
    }
}

// MARK: - Progress Bar View

/// Left-to-right fill with percentage display.
struct ProgressBarView: View, StatusBarDisplay {
    var displayId: String { "progress" }
    var displayName: String { "Progress Bar" }
    var minHeight: CGFloat { 4 }
    var supportedSizes: [StatusBarSize] { [.small, .medium, .large] }

    var progress: Double = 0.0   // 0.0 to 1.0
    var color: Color = .green
    var size: StatusBarSize = .small

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Color(red: 0.05, green: 0.05, blue: 0.05)

                // Fill
                color.opacity(0.85)
                    .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))

                // Percentage text (medium/large only)
                if size != .small {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: size == .large ? 10 : 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
}

// MARK: - Heartbeat View

/// ECG-style pulse line.
struct HeartbeatView: View, StatusBarDisplay {
    var displayId: String { "heartbeat" }
    var displayName: String { "Heartbeat" }
    var minHeight: CGFloat { 4 }
    var supportedSizes: [StatusBarSize] { [.small, .medium, .large] }

    var color: Color = .green
    var bpm: Double = 72

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                // Background
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.02, green: 0.02, blue: 0.02)))

                let midY = size.height / 2
                let points = Int(size.width)
                let beatInterval = 60.0 / bpm
                var path = Path()

                for x in 0..<points {
                    let xPos = CGFloat(x)
                    let phase = (t + Double(x) * 0.008).truncatingRemainder(dividingBy: beatInterval) / beatInterval

                    let y: CGFloat
                    if phase < 0.1 {
                        // P wave
                        y = midY - sin(phase / 0.1 * .pi) * size.height * 0.15
                    } else if phase < 0.15 {
                        // baseline
                        y = midY
                    } else if phase < 0.2 {
                        // QRS up
                        let qrs = (phase - 0.15) / 0.05
                        y = midY - qrs * size.height * 0.45
                    } else if phase < 0.25 {
                        // QRS down
                        let qrs = (phase - 0.2) / 0.05
                        y = midY - (1.0 - qrs) * size.height * 0.45 + qrs * size.height * 0.1
                    } else if phase < 0.3 {
                        // Return to baseline
                        let ret = (phase - 0.25) / 0.05
                        y = midY + (1.0 - ret) * size.height * 0.1
                    } else if phase < 0.5 {
                        // T wave
                        let tw = (phase - 0.3) / 0.2
                        y = midY - sin(tw * .pi) * size.height * 0.12
                    } else {
                        y = midY
                    }

                    if x == 0 {
                        path.move(to: CGPoint(x: xPos, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: xPos, y: y))
                    }
                }

                context.stroke(path, with: .color(color.opacity(0.9)), lineWidth: 1.5)
            }
        }
    }
}

// MARK: - VU Meter View

/// Bouncing level indicator (stereo VU meter style).
struct VUMeterView: View, StatusBarDisplay {
    var displayId: String { "vu-meter" }
    var displayName: String { "VU Meter" }
    var minHeight: CGFloat { 4 }
    var supportedSizes: [StatusBarSize] { [.small, .medium, .large] }

    var level: Double?  // 0.0 to 1.0, nil = animated
    var color: Color = .green

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.02, green: 0.02, blue: 0.02)))

                let segmentCount = 20
                let segmentWidth = size.width / CGFloat(segmentCount)
                let gap: CGFloat = 1

                let currentLevel: Double
                if let level {
                    currentLevel = level
                } else {
                    // Animated bouncing
                    let fast = sin(t * 4.0) * 0.3
                    let slow = sin(t * 1.5) * 0.2
                    let med = sin(t * 2.7) * 0.15
                    currentLevel = min(max(0.4 + fast + slow + med, 0.05), 1.0)
                }

                let litSegments = Int(currentLevel * Double(segmentCount))

                for i in 0..<segmentCount {
                    let x = CGFloat(i) * segmentWidth
                    let rect = CGRect(x: x + gap / 2, y: 0, width: segmentWidth - gap, height: size.height)
                    let fraction = Double(i) / Double(segmentCount)

                    let segColor: Color
                    if fraction > 0.85 {
                        segColor = .red
                    } else if fraction > 0.65 {
                        segColor = .yellow
                    } else {
                        segColor = color
                    }

                    let isLit = i < litSegments
                    context.fill(Path(rect), with: .color(segColor.opacity(isLit ? 0.9 : 0.1)))
                }
            }
        }
    }
}

// MARK: - Sparkline View

/// Scrolling sparkline chart.
struct SparklineView: View, StatusBarDisplay {
    var displayId: String { "sparkline" }
    var displayName: String { "Sparkline" }
    var minHeight: CGFloat { 4 }
    var supportedSizes: [StatusBarSize] { [.small, .medium, .large] }

    var data: [Double]?
    var color: Color = .cyan

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.02, green: 0.02, blue: 0.02)))

                let points: [Double]
                if let data, !data.isEmpty {
                    points = data
                } else {
                    // Generate animated data
                    points = (0..<60).map { i in
                        let x = Double(i) * 0.1 + t * 0.3
                        return 0.5 + sin(x) * 0.2 + sin(x * 2.3) * 0.15 + sin(x * 0.7) * 0.1
                    }
                }

                guard points.count > 1 else { return }

                var path = Path()
                let stepX = size.width / CGFloat(points.count - 1)

                for (i, value) in points.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = size.height - CGFloat(min(max(value, 0), 1)) * size.height

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(path, with: .color(color.opacity(0.9)), lineWidth: 1)

                // Fill under the line
                var fillPath = path
                fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                fillPath.addLine(to: CGPoint(x: 0, y: size.height))
                fillPath.closeSubpath()
                context.fill(fillPath, with: .color(color.opacity(0.15)))
            }
        }
    }
}
