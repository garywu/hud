import Foundation

/// Jane's animation state machine
/// Models the 6 core expression states with transitions based on events
enum JaneAnimationState: Equatable {
    case idle
    case listening(voiceAmplitude: Float = 0.5)
    case thinking(progress: Double = 0.0)
    case responding(speechRate: Float = 1.0)
    case success
    case error(message: String = "")

    /// Human-readable name for the current state
    var name: String {
        switch self {
        case .idle: return "IDLE"
        case .listening: return "LISTENING"
        case .thinking: return "THINKING"
        case .responding: return "RESPONDING"
        case .success: return "SUCCESS"
        case .error: return "ERROR"
        }
    }

    /// Severity color for this state
    var severity: String {
        switch self {
        case .idle, .responding, .success:
            return "green"
        case .listening, .thinking:
            return "yellow"
        case .error:
            return "red"
        }
    }
}

// MARK: - State Machine Events

enum JaneStateEvent {
    /// Voice input detected
    case voiceOn
    /// Voice input stopped
    case voiceOff
    /// API request started (LLM/processing)
    case apiStart
    /// API request completed
    case apiEnd
    /// TTS/speech output started
    case ttsStart
    /// TTS/speech output completed
    case ttsEnd
    /// Operation completed successfully
    case success
    /// Error occurred
    case error(message: String)
    /// Clear error state (after timeout or user action)
    case clearError
}

// MARK: - State Transition Logic

struct JaneStateTransition {
    static func nextState(
        from current: JaneAnimationState,
        event: JaneStateEvent
    ) -> JaneAnimationState {
        switch (current, event) {
        // IDLE → LISTENING
        case (.idle, .voiceOn):
            return .listening()

        // LISTENING → THINKING
        case (.listening, .apiStart):
            return .thinking()

        // LISTENING → IDLE (voice stopped without API call)
        case (.listening, .voiceOff):
            return .idle

        // THINKING → RESPONDING
        case (.thinking, .ttsStart):
            return .responding()

        // THINKING → IDLE (no response from API)
        case (.thinking, .voiceOff):
            return .idle

        // RESPONDING → SUCCESS
        case (.responding, .success):
            return .success

        // RESPONDING → IDLE (output complete)
        case (.responding, .ttsEnd):
            return .idle

        // Any state → ERROR
        case (_, .error(let msg)):
            return .error(message: msg)

        // ERROR → IDLE
        case (.error, .clearError):
            return .idle
        case (.error, .voiceOn):
            return .listening()

        // SUCCESS → IDLE (auto-transition via timeout)
        case (.success, _):
            return .idle

        // Default: state unchanged
        default:
            return current
        }
    }

    /// Auto-transitions based on elapsed time in a state
    /// Returns the new state if an auto-transition should occur, nil otherwise
    static func autoTransition(
        from current: JaneAnimationState,
        elapsedSeconds: TimeInterval
    ) -> JaneAnimationState? {
        switch current {
        case .success:
            // SUCCESS auto-transitions to IDLE after 2 seconds
            return elapsedSeconds > 2.0 ? .idle : nil

        case .error:
            // ERROR auto-transitions to IDLE after 3 seconds
            return elapsedSeconds > 3.0 ? .idle : nil

        default:
            return nil
        }
    }
}

// MARK: - Expression Configuration

/// Animatable expression parameters for rendering
struct JaneExpression: Equatable {
    /// Mouth curve depth (0.0 = straight line, 0.06 = warm smile)
    let mouthCurve: CGFloat

    /// Eye size multiplier (1.0 = normal, 1.2 = dilated, 0.8 = narrowed)
    let eyeSize: CGFloat

    /// Eye height in pixels (7 = normal, 9 = dilated, 6 = narrowed)
    let eyeHeight: CGFloat

    /// Whether mouth oscillates (for RESPONDING state)
    let mouthOscillates: Bool

    /// Mouth oscillation amplitude (if mouthOscillates)
    let mouthOscillationAmplitude: CGFloat

    /// Whether mouth is open (for ERROR state)
    let mouthOpen: Bool

    /// Whether eyes pulse (ERROR state)
    let eyePulses: Bool

    /// Whether glow pulses (THINKING/ERROR state)
    let glowPulses: Bool

    /// Glow pulse frequency (Hz)
    let glowPulseFrequency: CGFloat

    /// Glow expansion (SUCCESS state)
    let glowExpands: Bool

    /// Blink interval in seconds (0 = disabled)
    let blinkInterval: TimeInterval

    /// Scanline speed in pixels per second
    let scanlineSpeed: CGFloat

    /// Whether scanlines glitch (ERROR state)
    let scanlineGlitches: Bool

    /// Number of particles
    let particleCount: Int

    /// Particle motion type
    let particleMotion: ParticleMotion

    /// Eye glow alpha
    let glowAlpha: CGFloat

    /// Overall animation time (for calculating oscillations, pulses, etc.)
    var animationTime: TimeInterval = 0

    // MARK: - Static Expressions by State

    static let idle = JaneExpression(
        mouthCurve: 0.04,
        eyeSize: 1.0,
        eyeHeight: 7,
        mouthOscillates: false,
        mouthOscillationAmplitude: 0,
        mouthOpen: false,
        eyePulses: false,
        glowPulses: false,
        glowPulseFrequency: 1.0,
        glowExpands: false,
        blinkInterval: 3.5,
        scanlineSpeed: 20,
        scanlineGlitches: false,
        particleCount: 3,
        particleMotion: .orbitingSine,
        glowAlpha: 0.2
    )

    static let listening = JaneExpression(
        mouthCurve: 0.0,
        eyeSize: 1.2,
        eyeHeight: 9,
        mouthOscillates: false,
        mouthOscillationAmplitude: 0,
        mouthOpen: false,
        eyePulses: false,
        glowPulses: false,
        glowPulseFrequency: 1.0,
        glowExpands: false,
        blinkInterval: 3.5,
        scanlineSpeed: 40,
        scanlineGlitches: false,
        particleCount: 5,
        particleMotion: .scattered,
        glowAlpha: 0.4
    )

    static let thinking = JaneExpression(
        mouthCurve: 0.0,
        eyeSize: 0.8,
        eyeHeight: 6,
        mouthOscillates: false,
        mouthOscillationAmplitude: 0,
        mouthOpen: false,
        eyePulses: false,
        glowPulses: true,
        glowPulseFrequency: 1.0,
        glowExpands: false,
        blinkInterval: 5.0,
        scanlineSpeed: 40,  // Will accelerate to 80
        scanlineGlitches: false,
        particleCount: 8,
        particleMotion: .convergingCenter,
        glowAlpha: 0.3
    )

    static let responding = JaneExpression(
        mouthCurve: 0.0,
        eyeSize: 1.1,
        eyeHeight: 7.5,
        mouthOscillates: true,
        mouthOscillationAmplitude: 0.03,
        mouthOpen: false,
        eyePulses: false,
        glowPulses: false,
        glowPulseFrequency: 1.0,
        glowExpands: false,
        blinkInterval: 10.0,
        scanlineSpeed: 80,
        scanlineGlitches: false,
        particleCount: 10,
        particleMotion: .scattered,
        glowAlpha: 0.4
    )

    static let success = JaneExpression(
        mouthCurve: 0.06,
        eyeSize: 1.0,
        eyeHeight: 7,
        mouthOscillates: false,
        mouthOscillationAmplitude: 0,
        mouthOpen: false,
        eyePulses: false,
        glowPulses: false,
        glowPulseFrequency: 1.0,
        glowExpands: true,
        blinkInterval: 3.5,
        scanlineSpeed: 5,
        scanlineGlitches: false,
        particleCount: 3,
        particleMotion: .convergingCenter,
        glowAlpha: 0.3
    )

    static let error = JaneExpression(
        mouthCurve: 0.0,
        eyeSize: 1.3,
        eyeHeight: 10,
        mouthOscillates: false,
        mouthOscillationAmplitude: 0,
        mouthOpen: true,
        eyePulses: true,
        glowPulses: true,
        glowPulseFrequency: 1.25,
        glowExpands: false,
        blinkInterval: 0,  // Disabled
        scanlineSpeed: 80,
        scanlineGlitches: true,
        particleCount: 12,
        particleMotion: .chaotic,
        glowAlpha: 0.6
    )

    /// Get expression for a given animation state
    static func forState(_ state: JaneAnimationState) -> JaneExpression {
        switch state {
        case .idle:
            return .idle
        case .listening:
            return .listening
        case .thinking:
            return .thinking
        case .responding:
            return .responding
        case .success:
            return .success
        case .error:
            return .error
        }
    }
}

enum ParticleMotion: Equatable {
    /// Orbital sine wave motion (calm)
    case orbitingSine
    /// Scattered random motion (active)
    case scattered
    /// Converging toward center (processing)
    case convergingCenter
    /// Chaotic random motion (alarm)
    case chaotic
}

// MARK: - Expression Interpolation

extension JaneExpression {
    /// Interpolate between two expressions
    /// - Parameters:
    ///   - from: Starting expression
    ///   - to: Target expression
    ///   - progress: 0.0 (from) to 1.0 (to)
    ///   - easing: Easing function (default ease-in-out)
    static func interpolate(
        from: JaneExpression,
        to: JaneExpression,
        progress: Double,
        easing: @escaping (Double) -> Double = { easeInOutCubic($0) }
    ) -> JaneExpression {
        let t = easing(progress)

        return JaneExpression(
            mouthCurve: from.mouthCurve + (to.mouthCurve - from.mouthCurve) * CGFloat(t),
            eyeSize: from.eyeSize + (to.eyeSize - from.eyeSize) * CGFloat(t),
            eyeHeight: from.eyeHeight + (to.eyeHeight - from.eyeHeight) * CGFloat(t),
            mouthOscillates: progress < 0.5 ? from.mouthOscillates : to.mouthOscillates,
            mouthOscillationAmplitude: from.mouthOscillationAmplitude + (to.mouthOscillationAmplitude - from.mouthOscillationAmplitude) * CGFloat(t),
            mouthOpen: progress < 0.5 ? from.mouthOpen : to.mouthOpen,
            eyePulses: progress < 0.5 ? from.eyePulses : to.eyePulses,
            glowPulses: progress < 0.5 ? from.glowPulses : to.glowPulses,
            glowPulseFrequency: from.glowPulseFrequency + (to.glowPulseFrequency - from.glowPulseFrequency) * CGFloat(t),
            glowExpands: progress < 0.5 ? from.glowExpands : to.glowExpands,
            blinkInterval: from.blinkInterval + (to.blinkInterval - from.blinkInterval) * t,
            scanlineSpeed: from.scanlineSpeed + (to.scanlineSpeed - from.scanlineSpeed) * CGFloat(t),
            scanlineGlitches: progress < 0.5 ? from.scanlineGlitches : to.scanlineGlitches,
            particleCount: Int(Double(from.particleCount) + (Double(to.particleCount) - Double(from.particleCount)) * t),
            particleMotion: progress < 0.5 ? from.particleMotion : to.particleMotion,
            glowAlpha: from.glowAlpha + (to.glowAlpha - from.glowAlpha) * CGFloat(t)
        )
    }
}

// MARK: - Easing Functions

private func easeInOutCubic(_ t: Double) -> Double {
    if t < 0.5 {
        return 4 * t * t * t
    } else {
        let f = 2 * t - 2
        return 0.5 * f * f * f + 1
    }
}

func easeOutCubic(_ t: Double) -> Double {
    let f = t - 1
    return f * f * f + 1
}
