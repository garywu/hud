import Foundation
import Observation

/// Manages voice recording state and UI updates.
/// Observable class that coordinates with AudioIOManager and provides
/// real-time RMS level updates for visual feedback.
@Observable
final class VoiceRecordingState {
    // MARK: - Recording State
    private(set) var isRecording = false
    private(set) var rmsLevel: Float = 0.0
    private(set) var elapsedSeconds: Int = 0
    private(set) var errorMessage: String?

    private var audioIOManager: AudioIOManager?
    private var levelUpdateTask: Task<Void, Never>?
    private var recordingStartTime: Date?

    init() {}

    // MARK: - Recording Control

    /// Starts microphone recording and begins level monitoring.
    func startRecording() async {
        guard !isRecording else {
            NSLog("Already recording")
            return
        }

        errorMessage = nil

        // Initialize audio IO if needed
        if audioIOManager == nil {
            audioIOManager = AudioIOManager()
        }

        do {
            let manager = audioIOManager!
            try await manager.setupAudioSession()
            try await manager.initialize()

            // Request microphone permission
            let hasPermission = await manager.requestMicrophonePermission()
            guard hasPermission else {
                errorMessage = "Microphone permission denied"
                NSLog("AtlasHUD: Microphone permission denied")
                return
            }

            try await manager.startCapture()
            isRecording = true
            recordingStartTime = Date()
            NSLog("AtlasHUD: Voice recording started")

            // Start level monitoring loop
            startLevelMonitoring()
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            NSLog("AtlasHUD: Voice recording error: \(error)")
        }
    }

    /// Stops microphone recording and level monitoring.
    func stopRecording() async {
        guard isRecording, let manager = audioIOManager else {
            return
        }

        do {
            try await manager.stopCapture()
            isRecording = false
            levelUpdateTask?.cancel()
            levelUpdateTask = nil
            rmsLevel = 0.0
            elapsedSeconds = 0
            recordingStartTime = nil
            NSLog("AtlasHUD: Voice recording stopped")
        } catch {
            errorMessage = "Failed to stop recording: \(error.localizedDescription)"
            NSLog("AtlasHUD: Voice stop error: \(error)")
        }
    }

    // MARK: - Level Monitoring

    /// Continuously monitors RMS level from AudioIOManager.
    private func startLevelMonitoring() {
        levelUpdateTask?.cancel()
        levelUpdateTask = Task {
            while !Task.isCancelled {
                if let manager = audioIOManager {
                    let newLevel = await manager.getInputLevel()
                    DispatchQueue.main.async {
                        self.rmsLevel = newLevel
                        if let start = self.recordingStartTime {
                            self.elapsedSeconds = Int(-start.timeIntervalSinceNow)
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms update rate
            }
        }
    }

    // MARK: - Public Properties

    var recordingButtonLabel: String {
        if isRecording {
            let seconds = elapsedSeconds
            return "⏹️ Stop (\(seconds)s)"
        } else {
            return "🎤 Record"
        }
    }

    var recordingButtonColor: Double {
        // Color ranges from blue (idle) to red (loud)
        return Double(min(rmsLevel, 1.0))
    }
}
