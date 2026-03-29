import Foundation
import Observation

/// Merges multiple signals (voice, API, TTS, errors) into a cohesive animation state
@Observable
class JaneStateCoordinator {
    // MARK: - Public State

    /// Current animation state
    private(set) var state: JaneAnimationState = .idle

    /// Time when current state started
    private var stateStartTime: Date = Date()

    // MARK: - Input Signals

    /// Voice/microphone active
    private(set) var isVoiceActive: Bool = false {
        didSet {
            if isVoiceActive && !oldValue {
                handleEvent(.voiceOn)
            } else if !isVoiceActive && oldValue {
                handleEvent(.voiceOff)
            }
        }
    }

    /// API/LLM request in progress
    private(set) var isApiActive: Bool = false {
        didSet {
            if isApiActive && !oldValue {
                handleEvent(.apiStart)
            } else if !isApiActive && oldValue {
                handleEvent(.apiEnd)
            }
        }
    }

    /// TTS/speech synthesis in progress
    private(set) var isTtsActive: Bool = false {
        didSet {
            if isTtsActive && !oldValue {
                handleEvent(.ttsStart)
            } else if !isTtsActive && oldValue {
                handleEvent(.ttsEnd)
            }
        }
    }

    /// Error message (non-empty = error state)
    private(set) var errorMessage: String = "" {
        didSet {
            if !errorMessage.isEmpty && oldValue.isEmpty {
                handleEvent(.error(message: errorMessage))
            } else if errorMessage.isEmpty && !oldValue.isEmpty {
                handleEvent(.clearError)
            }
        }
    }

    /// Voice amplitude (0.0-1.0) for visual feedback
    private(set) var voiceAmplitude: Float = 0.0

    /// API progress (0.0-1.0) for time-to-first-token visualization
    private(set) var apiProgress: Double = 0.0

    /// Speech rate for mouth animation (1.0 = normal)
    private(set) var speechRate: Float = 1.0

    // MARK: - Transitions

    /// Animation duration for state transitions (seconds)
    let transitionDuration: TimeInterval = 0.3

    /// Current transition (if any)
    private var transitionState: TransitionState? = nil

    private enum TransitionState {
        case transitioning(from: JaneAnimationState, to: JaneAnimationState, startTime: Date)
    }

    /// Returns the expression to render, accounting for transitions
    func currentExpression(animationTime: TimeInterval) -> JaneExpression {
        if let transition = transitionState {
            switch transition {
            case .transitioning(let from, let to, let startTime):
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / transitionDuration, 1.0)

                var expr = JaneExpression.interpolate(
                    from: JaneExpression.forState(from),
                    to: JaneExpression.forState(to),
                    progress: progress,
                    easing: { easeInOutCubic($0) }
                )
                expr.animationTime = animationTime
                return expr
            }
        }

        var expr = JaneExpression.forState(state)
        expr.animationTime = animationTime
        return expr
    }

    // MARK: - Public API

    /// Set voice amplitude (0.0-1.0)
    func setVoiceAmplitude(_ amplitude: Float) {
        voiceAmplitude = max(0, min(1, amplitude))
    }

    /// Set API progress (0.0-1.0)
    func setApiProgress(_ progress: Double) {
        apiProgress = max(0, min(1, progress))
    }

    /// Set speech rate multiplier
    func setSpeechRate(_ rate: Float) {
        speechRate = max(0.5, min(2.0, rate))
    }

    /// Manually set error (triggers ERROR state)
    func setError(_ message: String) {
        errorMessage = message
    }

    /// Clear error (triggers auto-transition to IDLE after timeout)
    func clearError() {
        errorMessage = ""
    }

    /// Get elapsed time in current state
    func elapsedInState() -> TimeInterval {
        Date().timeIntervalSince(stateStartTime)
    }

    // MARK: - Internal State Machine

    private func handleEvent(_ event: JaneStateEvent) {
        let newState = JaneStateTransition.nextState(from: state, event: event)

        if newState != state {
            beginTransition(from: state, to: newState)
        }
    }

    private func beginTransition(from: JaneAnimationState, to: JaneAnimationState) {
        transitionState = .transitioning(from: from, to: to, startTime: Date())
        state = to
        stateStartTime = Date()
    }

    /// Called regularly from the animation loop to check for auto-transitions
    func updateAutoTransitions() {
        let elapsed = elapsedInState()
        if let nextState = JaneStateTransition.autoTransition(from: state, elapsedSeconds: elapsed) {
            if nextState != state {
                beginTransition(from: state, to: nextState)
            }
        }

        // Check if transition is complete
        if let transition = transitionState {
            switch transition {
            case .transitioning(_, _, let startTime):
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > transitionDuration {
                    transitionState = nil
                }
            }
        }
    }
}

// MARK: - Test/Debug Helpers

extension JaneStateCoordinator {
    /// For testing: directly set the state without transitions
    func setState(_ newState: JaneAnimationState) {
        state = newState
        stateStartTime = Date()
        transitionState = nil
    }

    /// For testing: simulate an event
    func simulateEvent(_ event: JaneStateEvent) {
        handleEvent(event)
    }
}

// MARK: - Easing Helper

private func easeInOutCubic(_ t: Double) -> Double {
    if t < 0.5 {
        return 4 * t * t * t
    } else {
        let f = 2 * t - 2
        return 0.5 * f * f * f + 1
    }
}
