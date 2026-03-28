import Foundation
import Observation

// MARK: - RSVP Saved State

/// Snapshot of an RSVP session's position so it can be resumed after interruption.
struct RSVPSavedState: Equatable {
    let text: String
    let wordIndex: Int
    let wpm: Int
    let renderer: String   // "text" or "lcd"
    let size: String
    let color: String?
    let savedAt: Date
}

// MARK: - Interruption Info

/// Describes the notification that caused the interruption.
struct RSVPInterruption: Equatable {
    let notificationId: String
    let level: InterruptionLevel
    let ttl: TimeInterval?          // nil = dismissed manually (critical)
    let startedAt: Date

    /// Whether this interruption has expired by timeout
    var isExpired: Bool {
        guard let ttl else { return false }
        return Date().timeIntervalSince(startedAt) >= ttl
    }
}

// MARK: - RSVP Interruption Manager

/// Coordinates RSVP pause/resume when urgent notifications preempt the display.
///
/// Flow:
/// 1. RSVP views register themselves when they start (``registerActive``).
/// 2. PolicyEngine calls ``interrupt`` when a higher-priority notification arrives.
/// 3. The manager saves the word index, pauses the RSVP, and yields the display.
/// 4. When the interrupting notification expires or is dismissed, ``resume`` restores RSVP.
@Observable
class RSVPInterruptionManager {
    static let shared = RSVPInterruptionManager()

    // MARK: - Published State

    /// Whether an RSVP session is currently registered (running or paused).
    private(set) var isRSVPActive: Bool = false

    /// Whether the RSVP is currently paused by an interruption.
    private(set) var isPaused: Bool = false

    /// The saved RSVP state (populated when paused).
    private(set) var savedState: RSVPSavedState?

    /// The active interruption that caused the pause.
    private(set) var activeInterruption: RSVPInterruption?

    // MARK: - Internal Tracking

    /// Current word index reported by the active RSVP view.
    private(set) var currentWordIndex: Int = 0

    /// Current RSVP text (needed to rebuild state).
    private var currentText: String = ""
    private var currentWPM: Int = 300
    private var currentRenderer: String = "text"
    private var currentSize: String = "medium"
    private var currentColor: String?

    /// Timer that checks for interruption expiry.
    private var expiryTimer: Timer?

    /// Callback fired when the manager wants the RSVP view to resume from a specific word index.
    /// The view sets this when it registers.
    var onResumeRequest: ((Int) -> Void)?

    /// Callback fired when the manager wants the RSVP view to pause immediately.
    var onPauseRequest: (() -> Void)?

    // MARK: - Registration (called by RSVP views)

    /// Register that an RSVP view is now actively displaying.
    func registerActive(
        text: String,
        wordIndex: Int,
        wpm: Int,
        renderer: String = "text",
        size: String = "medium",
        color: String? = nil
    ) {
        isRSVPActive = true
        currentText = text
        currentWordIndex = wordIndex
        currentWPM = wpm
        currentRenderer = renderer
        currentSize = size
        currentColor = color
    }

    /// Update the current word index (called by RSVP view on each tick).
    func updateWordIndex(_ index: Int) {
        guard !isPaused else { return }
        currentWordIndex = index
    }

    /// Unregister — RSVP view disappeared or text finished.
    func unregister() {
        isRSVPActive = false
        isPaused = false
        savedState = nil
        activeInterruption = nil
        currentWordIndex = 0
        currentText = ""
        onResumeRequest = nil
        onPauseRequest = nil
        cancelExpiryTimer()
    }

    // MARK: - Interruption (called by PolicyEngine)

    /// Interrupt the running RSVP for a higher-priority notification.
    /// Returns `true` if RSVP was active and is now paused; `false` if nothing to interrupt.
    @discardableResult
    func interrupt(notificationId: String, level: InterruptionLevel, ttl: TimeInterval?) -> Bool {
        guard isRSVPActive, !isPaused else { return false }

        // Save current position
        savedState = RSVPSavedState(
            text: currentText,
            wordIndex: currentWordIndex,
            wpm: currentWPM,
            renderer: currentRenderer,
            size: currentSize,
            color: currentColor,
            savedAt: Date()
        )

        activeInterruption = RSVPInterruption(
            notificationId: notificationId,
            level: level,
            ttl: ttl,
            startedAt: Date()
        )

        isPaused = true

        // Tell the RSVP view to stop its timer
        onPauseRequest?()

        // Start expiry monitoring if the interruption has a TTL
        startExpiryTimer(ttl: ttl)

        return true
    }

    // MARK: - Resume (called when interruption ends)

    /// Dismiss the active interruption and resume RSVP from the saved position.
    func dismiss() {
        guard isPaused, let saved = savedState else { return }
        resumeFromState(saved)
    }

    /// Resume RSVP playback from a saved state.
    private func resumeFromState(_ state: RSVPSavedState) {
        let resumeIndex = state.wordIndex
        isPaused = false
        activeInterruption = nil
        savedState = nil
        cancelExpiryTimer()

        // Tell the RSVP view to restart from the saved word index
        onResumeRequest?(resumeIndex)
    }

    // MARK: - Expiry Timer

    /// Poll for interruption expiry. Fires every 0.5s when an interruption is active.
    private func startExpiryTimer(ttl: TimeInterval?) {
        cancelExpiryTimer()
        guard let ttl, ttl > 0 else { return }  // no TTL = manual dismiss only

        expiryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.activeInterruption?.isExpired == true {
                self.dismiss()
            }
        }
    }

    private func cancelExpiryTimer() {
        expiryTimer?.invalidate()
        expiryTimer = nil
    }

    // MARK: - Query

    /// The word index to resume from (for display in UI, e.g., progress indicator).
    var resumeWordIndex: Int? {
        savedState?.wordIndex
    }

    /// Convenience: should the status bar show the interrupting notification instead of RSVP?
    var shouldYieldDisplay: Bool {
        isPaused && activeInterruption != nil
    }
}
