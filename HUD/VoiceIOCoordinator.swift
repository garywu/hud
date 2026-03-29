import AVFoundation
import os
import Observation

/// Orchestrates the entire voice I/O and transcription pipeline.
/// Manages:
/// - Audio capture (via AudioIOManager)
/// - Speech-to-text transcription (via WhisperKitEngine)
/// - State transitions (IDLE → LISTENING → THINKING → responding)
/// - Error recovery and logging
///
/// Key responsibilities:
/// 1. Coordinate mic capture with WhisperKit transcription
/// 2. Update UI with transcription state (listening, thinking, etc.)
/// 3. Log voice interactions to ~/.atlas/voice-history.json
/// 4. Handle errors gracefully with fallback strategies
@Observable
final class VoiceIOCoordinator {
    // MARK: - Dependencies
    private var audioIOManager: AudioIOManager?
    private var whisperEngine: WhisperKitEngine?
    private let logger = Logger(subsystem: "com.atlas.hud.voice", category: "VoiceIOCoordinator")

    // MARK: - State
    private(set) var voiceState: JaneAnimationState = .idle
    private(set) var isListening = false
    private(set) var transcribedText: String = ""
    private(set) var lastError: String?
    private(set) var transcriptionConfidence: Double = 0.0
    private(set) var transcriptionDuration: Int = 0

    // MARK: - Configuration
    private let maxRecordingDuration: TimeInterval = 30.0
    private var recordingStartTime: Date?

    // MARK: - Initialization

    init() {
        logger.info("VoiceIOCoordinator initialized")
    }

    // MARK: - Lifecycle

    /// Initializes the voice system (called once at app startup).
    /// Sets up audio session, audio engine, and loads WhisperKit model.
    func initialize() async {
        logger.info("Initializing voice system...")

        do {
            // Create and setup audio manager
            let audioManager = AudioIOManager()
            try await audioManager.setupAudioSession()
            try await audioManager.initialize()
            self.audioIOManager = audioManager
            logger.info("AudioIOManager initialized")

            // Create and load WhisperKit engine
            let whisper = WhisperKitEngine()
            self.whisperEngine = whisper

            // Load WhisperKit model in background
            Task {
                do {
                    try await whisper.loadModel()
                    self.logger.info("WhisperKit model loaded successfully")
                } catch {
                    self.logger.error("Failed to load WhisperKit: \(error.localizedDescription)")
                    // Non-fatal; voice recording still works, transcription just won't work
                }
            }

            logger.info("Voice system initialized")
        } catch {
            logger.error("Voice initialization failed: \(error.localizedDescription)")
            updateState(.error(message: "Voice system failed to initialize"))
        }
    }

    // MARK: - Voice Activation

    /// Starts voice recording when user activates the mic.
    func startListening() async {
        guard !isListening else {
            logger.warning("Already listening")
            return
        }

        guard let manager = audioIOManager else {
            logger.error("AudioIOManager not initialized")
            updateState(.error(message: "Audio system not ready"))
            return
        }

        logger.info("Starting voice listening")
        isListening = true
        transcribedText = ""
        lastError = nil
        recordingStartTime = Date()

        updateState(.listening(voiceAmplitude: 0.5))

        do {
            try await manager.startCapture()
            logger.info("Audio capture started")
        } catch {
            logger.error("Failed to start capture: \(error.localizedDescription)")
            updateState(.error(message: "Microphone error"))
            isListening = false
        }
    }

    /// Stops voice recording and initiates transcription.
    /// Returns the transcribed text if successful.
    func stopListening() async -> String? {
        guard isListening else {
            logger.warning("Not currently listening")
            return nil
        }

        logger.info("Stopping voice listening")
        isListening = false

        guard let manager = audioIOManager else {
            logger.error("AudioIOManager not available")
            return nil
        }

        // Update state to thinking/transcribing
        updateState(.thinking(progress: 0.2))

        do {
            // Stop audio capture
            try await manager.stopCapture()
            logger.info("Audio capture stopped")

            // For now, return empty string (Phase 4 will integrate Jane API)
            // In future: send transcription to Jane API here
            updateState(.idle)
            return nil
        } catch {
            logger.error("Error stopping capture: \(error.localizedDescription)")
            updateState(.error(message: "Capture error"))
            return nil
        }
    }

    // MARK: - Transcription (Phase 3 Core)

    /// Transcribes captured audio using WhisperKit.
    /// Called after stopListening() to process the audio buffer.
    ///
    /// Flow:
    /// 1. Get the captured audio buffer from AudioIOManager
    /// 2. Validate buffer format
    /// 3. Call WhisperKit.transcribe()
    /// 4. Log transcription with confidence score
    /// 5. Return transcribed text
    func transcribeAudio(buffer: AVAudioPCMBuffer) async -> String? {
        guard let whisper = whisperEngine else {
            logger.error("WhisperKit not available")
            updateState(.error(message: "Transcription engine not ready"))
            return nil
        }

        guard whisper.isReady else {
            logger.error("WhisperKit model not loaded")
            updateState(.error(message: "WhisperKit model still loading"))
            return nil
        }

        updateState(.thinking(progress: 0.5))

        do {
            // Validate buffer
            guard whisper.isValidBuffer(buffer) else {
                logger.error("Invalid audio buffer format")
                updateState(.error(message: "Invalid audio format"))
                return nil
            }

            let startTime = Date()

            // Transcribe
            let text = try await whisper.transcribe(audioBuffer: buffer)

            let elapsed = Date().timeIntervalSince(startTime)
            transcriptionDuration = Int(elapsed * 1000)  // in milliseconds

            logger.info(
                """
                Transcription successful in \(elapsed.formatted())s
                Text: "\(text)"
                """
            )

            transcribedText = text

            // Log the interaction
            logVoiceInteraction(transcription: text)

            updateState(.thinking(progress: 1.0))
            return text
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription)")
            updateState(.error(message: "Transcription failed"))
            return nil
        }
    }

    // MARK: - State Management

    /// Updates voice state and notifies UI observers.
    private func updateState(_ newState: JaneAnimationState) {
        voiceState = newState
        logger.info("Voice state → \(newState.name)")
    }

    // MARK: - Logging

    /// Logs voice interaction to ~/.atlas/voice-history.json.
    /// Maintains a rolling log of last 100 voice interactions.
    private func logVoiceInteraction(transcription: String) {
        let entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "transcription": transcription,
            "duration_ms": transcriptionDuration,
            "model": "whisper-base",
            "confidence": transcriptionConfidence
        ]

        let historyPath = NSString("~/.atlas/voice-history.json").expandingTildeInPath
        let fileManager = FileManager.default

        // Read existing history
        var history: [[String: Any]] = []
        if fileManager.fileExists(atPath: historyPath),
           let data = fileManager.contents(atPath: historyPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            history = json
        }

        // Add new entry
        history.append(entry)

        // Keep only last 100 entries
        if history.count > 100 {
            history = Array(history.dropFirst(history.count - 100))
        }

        // Write back
        if let jsonData = try? JSONSerialization.data(withJSONObject: history, options: [.prettyPrinted]) {
            fileManager.createFile(atPath: historyPath, contents: jsonData, attributes: nil)
            logger.info("Voice interaction logged to ~/.atlas/voice-history.json")
        }
    }

    // MARK: - Cleanup

    /// Cleans up voice resources during app shutdown.
    func shutdown() async {
        logger.info("Voice system shutting down")

        do {
            if let manager = audioIOManager {
                try await manager.stopCapture()
                await manager.stopPlayback()
            }
        } catch {
            logger.error("Error during shutdown: \(error.localizedDescription)")
        }
    }
}
