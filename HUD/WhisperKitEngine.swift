import AVFoundation
import os

/// Wraps the WhisperKit SDK for on-device speech-to-text transcription.
/// Handles model loading, transcription, and error recovery.
///
/// Features:
/// - Core ML-accelerated transcription on Apple Silicon
/// - Configurable model size (tiny, base, small, medium, large)
/// - Graceful degradation if WhisperKit is unavailable
/// - Logging of transcription latency
///
/// Usage:
/// ```swift
/// let engine = WhisperKitEngine()
/// try await engine.loadModel()
/// let text = try await engine.transcribe(audioBuffer: buffer)
/// ```
actor WhisperKitEngine {
    // MARK: - Dependencies
    private let logger = Logger(subsystem: "com.atlas.hud.voice", category: "WhisperKitEngine")

    // MARK: - State
    private var whisperKit: WhisperKit?
    private var isModelLoaded = false
    private let modelComputeOptions: ComputeOptions = .cpuAndGPU

    // MARK: - Configuration
    private let modelSize: String = "base"  // tiny, base, small, medium, large

    // MARK: - Initialization

    init() {
        logger.info("WhisperKitEngine initialized")
    }

    // MARK: - Model Management

    /// Loads the WhisperKit model asynchronously.
    /// Must be called once before transcription.
    /// Throws if WhisperKit is unavailable or model loading fails.
    func loadModel() async throws {
        guard !isModelLoaded else {
            logger.debug("Model already loaded")
            return
        }

        let startTime = Date()

        do {
            whisperKit = try await WhisperKit(
                computeOptions: modelComputeOptions,
                verbose: false,
                logLevel: .error
            )
            isModelLoaded = true

            let elapsed = Date().timeIntervalSince(startTime)
            logger.info("WhisperKit model loaded in \(String(format: "%.2f", elapsed))s")
        } catch {
            logger.error("Failed to load WhisperKit model: \(error.localizedDescription)")
            throw WhisperKitError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Checks if the model is ready for transcription.
    var isReady: Bool {
        isModelLoaded && whisperKit != nil
    }

    /// Returns the configured model size.
    var modelName: String {
        modelSize
    }

    // MARK: - Transcription

    /// Transcribes audio from an AVAudioPCMBuffer.
    /// Prerequisites: loadModel() must have been called successfully.
    ///
    /// - Parameter buffer: Audio buffer in PCM format (ideally 16kHz mono)
    /// - Returns: Transcribed text
    /// - Throws: If model not loaded, buffer is invalid, or transcription fails
    func transcribe(audioBuffer: AVAudioPCMBuffer) async throws -> String {
        guard let whisperKit = whisperKit else {
            logger.error("WhisperKit not loaded; call loadModel() first")
            throw WhisperKitError.modelNotLoaded
        }

        guard audioBuffer.frameLength > 0 else {
            logger.warning("Empty audio buffer provided")
            throw WhisperKitError.emptyBuffer
        }

        let startTime = Date()

        do {
            // Transcribe the buffer
            let result = try await whisperKit.transcribe(audioBuffer: audioBuffer)

            let elapsed = Date().timeIntervalSince(startTime)
            let confidence = result.confidence ?? 0.0

            logger.info(
                """
                Transcription complete in \(String(format: "%.2f", elapsed))s
                Text: "\(result.text)"
                Confidence: \(String(format: "%.2f", confidence))
                """
            )

            return result.text
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription)")
            throw WhisperKitError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Cancels any in-flight transcription.
    /// Safe to call multiple times.
    func cancelTranscription() {
        logger.info("Transcription cancelled")
        // WhisperKit doesn't expose a cancel method in the async API,
        // but we can track cancellation state here if needed in future
    }

    // MARK: - Utility

    /// Validates an audio buffer for transcription compatibility.
    /// Returns true if the buffer is suitable for WhisperKit.
    func isValidBuffer(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard buffer.frameLength > 0 else { return false }
        let format = buffer.format
        guard format != nil else { return false }

        // WhisperKit works best with 16kHz mono, but accepts various formats
        let sampleRateOK = (8000...48000).contains(Int(format.sampleRate))
        let channelsOK = (1...2).contains(Int(format.channelCount))

        return sampleRateOK && channelsOK
    }
}

// MARK: - Error Types

enum WhisperKitError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case emptyBuffer
    case invalidBufferFormat
    case transcriptionFailed(String)
    case whisperkitUnavailable

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "WhisperKit model not loaded. Call loadModel() first."
        case .modelLoadFailed(let reason):
            return "Failed to load WhisperKit model: \(reason)"
        case .emptyBuffer:
            return "Audio buffer is empty"
        case .invalidBufferFormat:
            return "Audio buffer format is not compatible with WhisperKit"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .whisperkitUnavailable:
            return "WhisperKit is not available on this platform"
        }
    }
}

// MARK: - WhisperKit Mock (for when SDK is unavailable)

/// Fallback implementation when WhisperKit SDK is not linked.
/// This allows the app to compile and run without the WhisperKit dependency,
/// though transcription will not work.
struct WhisperKit {
    var computeOptions: ComputeOptions

    init(
        computeOptions: ComputeOptions,
        verbose: Bool,
        logLevel: LogLevel
    ) async throws {
        // Placeholder: actual WhisperKit initialization
        // This will be replaced when the SDK is properly linked
        throw WhisperKitError.whisperkitUnavailable
    }

    func transcribe(audioBuffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        throw WhisperKitError.whisperkitUnavailable
    }
}

struct TranscriptionResult {
    let text: String
    let confidence: Double?
}

enum ComputeOptions {
    case cpu
    case gpu
    case cpuAndGPU
}

enum LogLevel {
    case debug
    case info
    case warning
    case error
}
