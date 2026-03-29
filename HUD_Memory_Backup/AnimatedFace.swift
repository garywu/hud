import SwiftUI
import Combine

/// Jane's animated expressive face
/// Uses procedural drawing (Canvas) to render eyes, mouth, scanlines, particles
/// Responds to JaneStateCoordinator for state-driven animations
struct AnimatedFace: View {
    @State private var coordinator = JaneStateCoordinator()
    let containerSize: CGSize

    /// Optional external coordinator (for testing/integration)
    var externalCoordinator: JaneStateCoordinator?

    private var activeCoordinator: JaneStateCoordinator {
        externalCoordinator ?? coordinator
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let animationTime = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let expr = activeCoordinator.currentExpression(animationTime: animationTime)
                drawFace(context: context, size: size, expression: expr, animationTime: animationTime)
            }
            .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
                activeCoordinator.updateAutoTransitions()
            }
        }
    }

    // MARK: - Main Drawing Pipeline

    private func drawFace(
        context: GraphicsContext,
        size: CGSize,
        expression: JaneExpression,
        animationTime: TimeInterval
    ) {
        // Background circle
        drawBackgroundCircle(context: context, size: size, expression: expression)

        // Scanlines (behind other elements)
        drawScanlines(context: context, size: size, expression: expression, animationTime: animationTime)

        // Face oval outline
        drawFaceOval(context: context, size: size, expression: expression)

        // Eyes
        drawEyes(context: context, size: size, expression: expression, animationTime: animationTime)

        // Nose
        drawNose(context: context, size: size, expression: expression)

        // Mouth
        drawMouth(context: context, size: size, expression: expression, animationTime: animationTime)

        // Particles
        drawParticles(context: context, size: size, expression: expression, animationTime: animationTime)

        // Fresnel glow edge
        drawFresnel(context: context, size: size, expression: expression, animationTime: animationTime)
    }

    // MARK: - Element Rendering

    private func drawBackgroundCircle(
        context: GraphicsContext,
        size: CGSize,
        expression: JaneExpression
    ) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let radius = size.width * 0.46

        let circlePath = Path(ellipseIn: CGRect(
            x: centerX - radius,
            y: centerY - radius,
            width: radius * 2,
            height: radius * 2
        ))

        let color = severityColor(for: expression.glowAlpha)
        context.fill(circlePath, with: .color(color.opacity(0.7)))
    }

    private func drawFaceOval(
        context: GraphicsContext,
        size: CGSize,
        expression: JaneExpression
    ) {
        let width = size.width * 0.72
        let height = size.height * 0.78
        let centerX = size.width / 2
        let centerY = size.height / 2

        let ovalRect = CGRect(
            x: centerX - width / 2,
            y: centerY - height / 2,
            width: width,
            height: height
        )

        let ovalPath = Path(ellipseIn: ovalRect)
        let color = severityColor(for: expression.glowAlpha)
        context.stroke(ovalPath, with: .color(color.opacity(0.08)), lineWidth: 0.5)
    }

    private func drawScanlines(
        context: GraphicsContext,
        size: CGSize,
        expression: JaneExpression,
        animationTime: TimeInterval
    ) {
        let spacing: CGFloat = 3
        let speed = expression.scanlineSpeed
        let offset = CGFloat(animationTime * Double(speed)).truncatingRemainder(dividingBy: spacing * 2)

        let faceRadius = size.width * 0.36
        let centerY = size.height / 2

        var y: CGFloat = -spacing + offset
        let color = severityColor(for: expression.glowAlpha)

        while y < size.height {
            // Gaussian falloff from center
            let distFromCenter = abs(y - centerY)
            let maxDist = faceRadius * 1.5
            let alpha = max(0, 1 - pow(distFromCenter / maxDist, 2))

            let linePath = Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            // Glitch effect: skip every 5th line in ERROR state
            let shouldSkip = expression.scanlineGlitches && Int(y) % 5 == 0 && Double.random(in: 0...1) < 0.2
            if !shouldSkip {
                context.stroke(linePath, with: .color(color.opacity(0.06 * alpha)), lineWidth: 0.5)
            }

            y += spacing
        }
    }

    private func drawEyes(
        context: GraphicsContext,
        size: CGSize,
        expression: JaneExpression,
        animationTime: TimeInterval
    ) {
        let centerX = size.width / 2
        let centerY = size.height * 0.38

        let eyeSpacing = size.width * 0.22
        let leftEyeX = centerX - eyeSpacing
        let rightEyeX = centerX + eyeSpacing

        // Eye size multipliers
        let baseEyeWidth: CGFloat = 10
        let eyeWidth = baseEyeWidth * expression.eyeSize
        let eyeHeight = expression.eyeHeight * expression.eyeSize

        // Handle pulsing (ERROR state)
        let pulseScale: CGFloat
        if expression.eyePulses {
            let pulseFreq = 1.667  // 0.6s period = 1.667 Hz
            let pulse = sin(CGFloat(animationTime * pulseFreq * .pi * 2)) * 0.3 + 1.0
            pulseScale = pulse
        } else {
            pulseScale = 1.0
        }

        let finalEyeWidth = eyeWidth * pulseScale
        let finalEyeHeight = eyeHeight * pulseScale

        let color = severityColor(for: expression.glowAlpha)

        // Draw both eyes
        for eyeX in [leftEyeX, rightEyeX] {
            drawEye(
                context: context,
                x: eyeX,
                y: centerY,
                width: finalEyeWidth,
                height: finalEyeHeight,
                color: color,
                glowAlpha: expression.glowAlpha
            )
        }
    }

    private func drawEye(
        context: GraphicsContext,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        color: Color,
        glowAlpha: CGFloat
    ) {
        let eyeRect = CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)

        // Glow halo (blur effect)
        let glowPath = Path(ellipseIn: eyeRect.insetBy(dx: -2, dy: -2))
        context.stroke(glowPath, with: .color(color.opacity(glowAlpha * 0.5)), lineWidth: 2)

        // Eye iris
        let eyePath = Path(ellipseIn: eyeRect)
        context.fill(eyePath, with: .color(color))

        // White pupil highlight (top-right 20%)
        let pupilX = x + width * 0.1
        let pupilY = y - height * 0.1
        let pupilSize = width * 0.25
        let pupilRect = CGRect(x: pupilX - pupilSize / 2, y: pupilY - pupilSize / 2, width: pupilSize, height: pupilSize)
        let pupilPath = Path(ellipseIn: pupilRect)
        context.fill(pupilPath, with: .color(.white.opacity(0.8)))
    }

    private func drawNose(
        context: GraphicsContext,
        size: CGSize,
        expression: JaneExpression
    ) {
        let centerX = size.width / 2
        let centerY = size.height * 0.42

        var nosePath = Path()
        nosePath.move(to: CGPoint(x: centerX, y: centerY))
        nosePath.addLine(to: CGPoint(x: centerX, y: centerY + 8))

        let color = severityColor(for: expression.glowAlpha)
        context.stroke(nosePath, with: .color(color.opacity(0.15)), lineWidth: 0.5)
    }

    private func drawMouth(
        context: GraphicsContext,
        size: CGSize,
        expression: JaneExpression,
        animationTime: TimeInterval
    ) {
        let centerX = size.width / 2
        let centerY = size.height * 0.58
        let mouthWidth = size.width * 0.22

        let color = severityColor(for: expression.glowAlpha)

        if expression.mouthOpen {
            // Open oval (ERROR state)
            let mouthHeight: CGFloat = 6
            let mouthRect = CGRect(
                x: centerX - mouthWidth / 2,
                y: centerY - mouthHeight / 2,
                width: mouthWidth,
                height: mouthHeight
            )
            let mouthPath = Path(ellipseIn: mouthRect)
            context.fill(mouthPath, with: .color(color.opacity(0.6)))
        } else if expression.mouthOscillates {
            // Oscillating mouth (RESPONDING state)
            let baseHeight: CGFloat = 1
            let amplitude = expression.mouthOscillationAmplitude * size.height * 0.1
            let frequency = 5.0  // 5 Hz speech cadence
            let oscillation = sin(CGFloat(animationTime * frequency * .pi * 2)) * amplitude
            let height = baseHeight + oscillation

            let mouthPath = Path { path in
                path.move(to: CGPoint(x: centerX - mouthWidth / 2, y: centerY))
                path.addCurve(
                    to: CGPoint(x: centerX + mouthWidth / 2, y: centerY),
                    control1: CGPoint(x: centerX - mouthWidth / 3, y: centerY + height),
                    control2: CGPoint(x: centerX + mouthWidth / 3, y: centerY + height)
                )
            }
            context.stroke(mouthPath, with: .color(color), lineWidth: 1)
        } else {
            // Smile curve (IDLE/SUCCESS) or straight line (LISTENING/THINKING)
            let curveDepth = expression.mouthCurve
            let height = curveDepth * size.height * 0.15

            let mouthPath = Path { path in
                path.move(to: CGPoint(x: centerX - mouthWidth / 2, y: centerY))
                if height > 0 {
                    // Smile
                    path.addCurve(
                        to: CGPoint(x: centerX + mouthWidth / 2, y: centerY),
                        control1: CGPoint(x: centerX - mouthWidth / 3, y: centerY + height),
                        control2: CGPoint(x: centerX + mouthWidth / 3, y: centerY + height)
                    )
                } else {
                    // Straight line
                    path.addLine(to: CGPoint(x: centerX + mouthWidth / 2, y: centerY))
                }
            }
            context.stroke(mouthPath, with: .color(color), lineWidth: 1)
        }
    }

    private func drawParticles(
        context: GraphicsContext,
        size: CGSize,
        expression: JaneExpression,
        animationTime: TimeInterval
    ) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let faceRadius = size.width * 0.36
        let particleSize: CGFloat = 2

        let color = severityColor(for: expression.glowAlpha)

        for i in 0..<expression.particleCount {
            let angle = CGFloat(i) / CGFloat(expression.particleCount) * .pi * 2

            let (x, y): (CGFloat, CGFloat)
            switch expression.particleMotion {
            case .orbitingSine:
                let radius = faceRadius * 1.2
                let drift = sin(CGFloat(animationTime + Double(i)) * 1.5) * 5
                x = centerX + cos(angle + CGFloat(animationTime)) * (radius + drift)
                y = centerY + sin(angle + CGFloat(animationTime)) * (radius + drift)

            case .scattered:
                let radius = faceRadius * (0.8 + CGFloat(i % 2) * 0.4)
                let speed = 0.5 + CGFloat(i % 3) * 0.2
                x = centerX + cos(angle + CGFloat(animationTime * Double(speed))) * radius
                y = centerY + sin(angle + CGFloat(animationTime * Double(speed))) * radius

            case .convergingCenter:
                let progress = min(animationTime * 0.5, 1.0)
                let startRadius = faceRadius * 1.5
                let endRadius = faceRadius * 0.2
                let currentRadius = startRadius + (endRadius - startRadius) * CGFloat(progress)
                x = centerX + cos(angle) * currentRadius
                y = centerY + sin(angle) * currentRadius

            case .chaotic:
                let seed = Double(i) * 12.34
                let randomAngle = angle + CGFloat(sin(animationTime + seed) * .pi)
                let randomRadius = faceRadius * (0.5 + CGFloat(animationTime.truncatingRemainder(dividingBy: 2)) * 0.5)
                x = centerX + cos(randomAngle) * randomRadius
                y = centerY + sin(randomAngle) * randomRadius
            }

            let particleRect = CGRect(x: x - particleSize / 2, y: y - particleSize / 2, width: particleSize, height: particleSize)
            let particlePath = Path(ellipseIn: particleRect)

            // Fade alpha for some states
            let alpha: CGFloat
            switch expression.particleMotion {
            case .convergingCenter:
                let progress = min(animationTime * 0.5, 1.0)
                alpha = 0.3 * (1 - CGFloat(progress))
            default:
                alpha = 0.25
            }

            context.fill(particlePath, with: .color(color.opacity(alpha)))
        }
    }

    private func drawFresnel(
        context: GraphicsContext,
        size: CGSize,
        expression: JaneExpression,
        animationTime: TimeInterval
    ) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let radius = size.width * 0.36

        let fresnelPath = Path(ellipseIn: CGRect(
            x: centerX - radius,
            y: centerY - radius,
            width: radius * 2,
            height: radius * 2
        ))

        let color = severityColor(for: expression.glowAlpha)

        // Glow pulse (THINKING/ERROR state)
        let glowAlpha: CGFloat
        if expression.glowPulses {
            let pulse = sin(CGFloat(animationTime * expression.glowPulseFrequency * .pi * 2)) * 0.1 + 0.5
            glowAlpha = expression.glowAlpha * pulse
        } else if expression.glowExpands {
            // Expand pulse (SUCCESS state)
            let elapsed = animationTime.truncatingRemainder(dividingBy: 2.0)
            if elapsed < 0.3 || (elapsed > 0.4 && elapsed < 0.7) {
                glowAlpha = expression.glowAlpha * 1.5
            } else {
                glowAlpha = expression.glowAlpha
            }
        } else {
            glowAlpha = expression.glowAlpha
        }

        context.stroke(fresnelPath, with: .color(color.opacity(glowAlpha * 0.6)), lineWidth: 2)
    }

    // MARK: - Helpers

    private func severityColor(for glowAlpha: CGFloat) -> Color {
        // Determine color from glow alpha (green=0.2, yellow=0.4, red=0.6+)
        if glowAlpha >= 0.5 {
            return Color(red: 1, green: 0.3, blue: 0.5)  // #FF4D7F (hot pink/red)
        } else if glowAlpha >= 0.35 {
            return Color(red: 1, green: 0.84, blue: 0)   // #FFD700 (amber)
        } else {
            return Color(red: 0, green: 0.9, blue: 1)    // #00E5FF (cyan)
        }
    }
}

// MARK: - Preview

private func makeCoordinator(state: JaneAnimationState) -> JaneStateCoordinator {
    let c = JaneStateCoordinator()
    c.setState(state)
    return c
}

struct AnimatedFace_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // IDLE state
            StatePreviewView(name: "IDLE", coordinator: makeCoordinator(state: .idle))

            // LISTENING state
            StatePreviewView(name: "LISTENING", coordinator: makeCoordinator(state: .listening()))

            // THINKING state
            StatePreviewView(name: "THINKING", coordinator: makeCoordinator(state: .thinking()))

            // ERROR state
            StatePreviewView(name: "ERROR", coordinator: makeCoordinator(state: .error(message: "Test error")))
        }
        .padding()
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
    }
}

private struct StatePreviewView: View {
    let name: String
    let coordinator: JaneStateCoordinator

    var body: some View {
        VStack {
            Text(name)
                .font(.caption)
                .foregroundColor(.white)

            AnimatedFace(containerSize: CGSize(width: 50, height: 50), externalCoordinator: coordinator)
                .frame(width: 50, height: 50)
                .background(Color.black)
                .cornerRadius(8)
        }
    }
}
