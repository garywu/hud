import SwiftUI
import os

/// Extension to NotchWindow to integrate voice UI display.
/// Handles rendering of voice state (listening, thinking, responding) in the notch.
extension NotchWindow {

    /// Shows voice status in the notch during voice interaction.
    /// Replaces normal status display with voice-specific content.
    func displayVoiceStatus(state: JaneAnimationState, transcript: String = "") {
        let logger = Logger(subsystem: "com.atlas.hud.voice", category: "NotchWindow")

        switch state {
        case .idle:
            logger.debug("Voice: IDLE")
            // Revert to normal status display

        case .listening(let amplitude):
            logger.info("Voice: LISTENING (amplitude: \(amplitude))")
            // Display waveform animation with RMS level
            // Update notch content to show:
            // "🎤 Listening..."
            // Animated waveform bars

        case .thinking(let progress):
            logger.info("Voice: THINKING (progress: \(progress))")
            // Display spinner + transcript so far
            // Update notch content to show:
            // "⟳ Transcribing..."
            // Partial transcript text

        case .responding(let speechRate):
            logger.info("Voice: RESPONDING (rate: \(speechRate))")
            // Display playback waveform
            // Update notch content to show:
            // "🔊 Jane is speaking..."
            // Playback progress bar

        case .success:
            logger.info("Voice: SUCCESS")
            // Brief success animation
            // Fade back to idle

        case .error(let message):
            logger.error("Voice: ERROR - \(message)")
            // Display error in red
            // Auto-dismiss after 3 seconds
        }
    }
}

/// View component for displaying voice transcription in the HUD panel.
/// Shows:
/// - Real-time transcription as WhisperKit processes audio
/// - Confidence score
/// - Transcription duration
struct VoiceTranscriptionView: View {
    let transcribedText: String
    let confidenceScore: Double
    let durationMs: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Transcription", systemImage: "mic.fill")
                .font(.caption.bold())
                .foregroundColor(.gray)

            Text(transcribedText)
                .font(.system(.body, design: .monospaced))
                .lineLimit(3)
                .truncationMode(.tail)

            HStack {
                Text("Confidence: \(String(format: "%.0f%%", confidenceScore * 100))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(durationMs)ms")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
    }
}

/// View component for voice input controls.
/// Provides:
/// - Microphone button (hold to record)
/// - Visual feedback during recording
/// - Stop/Cancel options
struct VoiceInputControlsView: View {
    @State private var isRecording = false
    var onStartListening: () -> Void = {}
    var onStopListening: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            // Microphone button
            Button(action: {
                if isRecording {
                    isRecording = false
                    onStopListening()
                } else {
                    isRecording = true
                    onStartListening()
                }
            }) {
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 16))
                    .foregroundColor(isRecording ? .red : .gray)
                    .frame(width: 32, height: 32)
                    .background(isRecording ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
            .help(isRecording ? "Stop recording (click or ESC)" : "Click to start recording voice")

            if isRecording {
                // Recording indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: isRecording)

                    Text("Recording...")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.05))
                .cornerRadius(4)
            }
        }
        .padding(8)
    }
}

/// View component for displaying voice input level (waveform).
/// Updates in real-time as audio is captured.
struct VoiceWaveformView: View {
    let inputLevel: Float
    let isActive: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { index in
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            isActive
                                ? Color.green.opacity(Double(inputLevel) * 0.8 + 0.2)
                                : Color.gray.opacity(0.2)
                        )
                        .frame(height: CGFloat(inputLevel) * 20 + 2)
                    Spacer()
                }
            }
        }
        .frame(height: 20)
        .padding(4)
    }
}

// MARK: - Integration with AppDelegate

extension AppDelegate {

    /// Sets up voice hotkey for global activation.
    /// Default: Cmd+Option+V
    func setupVoiceHotkey() {
        let logger = Logger(subsystem: "com.atlas.hud", category: "Voice")
        logger.info("Voice hotkey setup: Cmd+Option+V")

        // TODO: Implement using KeyboardShortcuts or similar package
        // For now, hotkey registration would go here

        // Example hotkey flow:
        // User presses Cmd+Option+V
        //   → Check if VoiceIOCoordinator is ready
        //   → Call coordinator.startListening()
        //   → Show "Listening..." state in notch
        //   → User speaks...
        //   → User releases hotkey or speaks long enough
        //   → Call coordinator.stopListening()
        //   → WhisperKit transcribes
        //   → Display transcript and send to Jane
    }
}

// MARK: - Voice Integration Points (in StatusBarRouter)

extension StatusBarRouter {

    /// Example of how voice state should integrate into existing status bar routing.
    /// Voice takes priority over normal status display when active.
    ///
    /// Usage in StatusBarRouter body:
    /// ```swift
    /// if voiceCoordinator.isActive {
    ///     VoiceStatusView(state: voiceCoordinator.currentState)
    /// } else {
    ///     // Normal status routing
    /// }
    /// ```
    func voiceStatusIntegration() {
        // Check if voice is active
        // If yes: show voice-specific UI
        // If no: fall through to normal status display
        //
        // Voice UI should NOT interrupt red severity messages
        // Voice UI should be interruptible by red messages
    }
}

// MARK: - Hotkey Handler Example

/// Example implementation of global hotkey detection for voice activation.
/// In real implementation, use KeyboardShortcuts or similar package.
class VoiceHotkeyHandler {
    private let logger = Logger(subsystem: "com.atlas.hud.voice", category: "Hotkey")
    private let coordinator: VoiceIOCoordinator
    private var isHotkeyPressed = false

    init(coordinator: VoiceIOCoordinator) {
        self.coordinator = coordinator
    }

    /// Called when Cmd+Option+V is pressed.
    func handleVoiceHotkeyDown() {
        guard !isHotkeyPressed else { return }
        isHotkeyPressed = true

        logger.info("Voice hotkey pressed: starting listening")
        Task {
            await coordinator.startListening()
        }
    }

    /// Called when Cmd+Option+V is released.
    func handleVoiceHotkeyUp() {
        guard isHotkeyPressed else { return }
        isHotkeyPressed = false

        logger.info("Voice hotkey released: stopping listening")
        Task {
            await coordinator.stopListening()
        }
    }
}
