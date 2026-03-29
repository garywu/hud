import AVFoundation
import os

/// Manages audio I/O infrastructure for voice capture and playback.
/// Provides:
/// - Microphone capture with configurable buffer size (256-512 frames)
/// - Speaker playback via AVAudioPlayerNode
/// - Audio session configuration (playAndRecord category)
/// - RMS level metering for visual feedback
/// - Error recovery for audio interruptions
///
/// Thread-safe and reusable across voice capture sessions.
actor AudioIOManager {
    // MARK: - Dependencies
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioEngine = AVAudioEngine()
    private let logger = Logger(subsystem: "com.atlas.hud.audio", category: "AudioIOManager")

    // MARK: - Audio Nodes
    private var inputNode: AVAudioInputNode? { audioEngine.inputNode }
    private var playbackNode: AVAudioPlayerNode?

    // MARK: - Buffer Management
    private var circularBuffer: [Float] = []
    private let bufferLock = NSLock()
    private var captureBuffers: [(AVAudioPCMBuffer) -> Void] = []
    private var rmsLevel: Float = 0.0

    // MARK: - State
    private var isSessionSetup = false
    private var isCapturing = false
    private var isPlayingBack = false

    // MARK: - Configuration
    private let defaultSampleRate: Double = 16000 // 16kHz for Whisper compatibility
    private let defaultChannels: AVAudioChannelCount = 1 // Mono
    private let defaultBufferFrameSize: AVAudioFrameCount = 256 // ~16ms @ 16kHz

    // MARK: - Initialization

    init() {
        // Note: Audio session interruptions are primarily an iOS concern
        // macOS doesn't typically have audio interruptions like phone calls
    }


    // MARK: - Setup & Teardown

    /// Sets up the audio session with playAndRecord category.
    /// Must be called once before any capture/playback operations.
    /// Throws if audio session setup fails.
    func setupAudioSession() throws {
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker]
        )
        // macOS: setActive is not available; audio is handled by the system
        logger.info("Audio session configured: playAndRecord mode")
    }

    /// Initializes the AVAudioEngine with input/output nodes and attachment tap.
    /// Call this once during app startup (e.g., in AppDelegate).
    func initialize() throws {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: defaultSampleRate,
            channels: defaultChannels
        )
        guard let format = format else {
            throw AudioIOError.invalidFormat
        }

        // Attach playback node to engine
        let playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.outputNode, format: format)

        // Install tap on input node for capture
        guard let inputNode = audioEngine.inputNode else {
            throw AudioIOError.inputNodeUnavailable
        }

        inputNode.installTap(
            onBus: 0,
            bufferSize: defaultBufferFrameSize,
            format: format,
            block: { [weak self] buffer, _ in
                Task {
                    await self?.processInputBuffer(buffer)
                }
            }
        )

        // Start the engine
        try audioEngine.start()
        logger.info("AVAudioEngine initialized and started")
    }

    // MARK: - Capture

    /// Starts audio capture from the microphone.
    /// Prerequisites: setupAudioSession() and initialize() must have been called.
    func startCapture() throws {
        guard !isCapturing else {
            logger.warning("Capture already active")
            return
        }

        guard audioEngine.isRunning else {
            throw AudioIOError.engineNotRunning
        }

        // Reset circular buffer
        bufferLock.lock()
        circularBuffer.removeAll(keepingCapacity: true)
        bufferLock.unlock()

        isCapturing = true
        rmsLevel = 0.0
        logger.info("Capture started")
    }

    /// Stops audio capture from the microphone.
    func stopCapture() throws {
        guard isCapturing else {
            logger.warning("Capture not active")
            return
        }

        isCapturing = false
        logger.info("Capture stopped")
    }

    /// Retrieves the current RMS (root mean square) audio level.
    /// Returns a value between 0.0 (silence) and 1.0 (maximum).
    /// Useful for visual feedback during recording (e.g., waveform animation).
    func getInputLevel() -> Float {
        return min(rmsLevel, 1.0)
    }

    // MARK: - Playback

    /// Plays audio data via the speaker.
    /// Converts raw PCM data to an AVAudioPCMBuffer and enqueues it for playback.
    ///
    /// - Parameters:
    ///   - data: Raw PCM audio data (16-bit signed mono)
    ///   - completion: Called when playback completes
    /// - Throws: Playback errors
    func playAudio(data: Data, completion: @escaping () -> Void = {}) throws {
        guard let playbackNode = audioEngine.outputNode.engine?.nodes.first(where: { $0 is AVAudioPlayerNode }) as? AVAudioPlayerNode else {
            throw AudioIOError.playbackNodeUnavailable
        }

        let format = AVAudioFormat(
            standardFormatWithSampleRate: defaultSampleRate,
            channels: defaultChannels
        )
        guard let format = format else {
            throw AudioIOError.invalidFormat
        }

        // Convert data to PCM buffer
        let buffer = try pcmBufferFromData(data, format: format)

        // Start playback if not already playing
        if !playbackNode.isPlaying {
            try audioSession.setActive(true)
            playbackNode.play()
            isPlayingBack = true
        }

        playbackNode.scheduleBuffer(buffer) { [weak self] in
            self?.isPlayingBack = false
            completion()
        }

        logger.info("Audio playback enqueued (\(data.count) bytes)")
    }

    /// Stops audio playback immediately.
    func stopPlayback() {
        guard let playbackNode = audioEngine.outputNode.engine?.nodes.first(where: { $0 is AVAudioPlayerNode }) as? AVAudioPlayerNode else {
            logger.warning("Playback node not available")
            return
        }

        playbackNode.stop()
        isPlayingBack = false
        logger.info("Playback stopped")
    }

    /// Returns whether audio is currently playing.
    var isPlaying: Bool {
        isPlayingBack
    }

    // MARK: - Buffer Processing

    /// Processes incoming audio buffer from the input tap.
    /// Computes RMS level and updates circular buffer for future capture operations.
    private func processInputBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isCapturing else { return }

        // Compute RMS level for metering
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        var sumSquares: Float = 0.0

        for i in 0..<frameLength {
            let sample = channelData[0][i]
            sumSquares += sample * sample
        }

        rmsLevel = sqrt(sumSquares / Float(frameLength))

        // Store buffer in circular buffer
        bufferLock.lock()
        defer { bufferLock.unlock() }

        if let channelData = buffer.floatChannelData {
            for i in 0..<frameLength {
                circularBuffer.append(channelData[0][i])
            }
        }

        // Notify any registered capture callbacks
        for callback in captureBuffers {
            callback(buffer)
        }

        logger.debug("Buffer processed: \(frameLength) frames, RMS: \(String(format: "%.3f", rmsLevel))")
    }

    // MARK: - Helpers

    /// Converts raw PCM data to an AVAudioPCMBuffer.
    /// Assumes 16-bit signed PCM, mono, 16kHz sample rate.
    private func pcmBufferFromData(_ data: Data, format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(data.count / 2)
        ) else {
            throw AudioIOError.bufferCreationFailed
        }

        data.withUnsafeBytes { rawBytes in
            let int16Data = rawBytes.bindMemory(to: Int16.self)
            let floatChannelData = buffer.floatChannelData

            for i in 0..<int16Data.count {
                floatChannelData?[0][i] = Float(int16Data[i]) / 32768.0
            }
        }

        buffer.frameLength = AVAudioFrameCount(data.count / 2)
        return buffer
    }

    // MARK: - Interruption Handling

    // Note: Audio interruption handling is not needed on macOS

    // MARK: - Permissions

    /// Checks and requests microphone permission.
    /// Returns true if permission is granted.
    func requestMicrophonePermission() async -> Bool {
        let status = AVAudioApplication.shared.recordPermission
        switch status {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        @unknown default:
            return false
        }
    }
}

// MARK: - Error Types

enum AudioIOError: LocalizedError {
    case inputNodeUnavailable
    case playbackNodeUnavailable
    case invalidFormat
    case bufferCreationFailed
    case engineNotRunning
    case sessionSetupFailed(String)

    var errorDescription: String? {
        switch self {
        case .inputNodeUnavailable:
            return "Microphone input node is not available"
        case .playbackNodeUnavailable:
            return "Playback node is not available"
        case .invalidFormat:
            return "Invalid audio format (expected 16kHz mono PCM)"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .engineNotRunning:
            return "Audio engine is not running"
        case .sessionSetupFailed(let reason):
            return "Audio session setup failed: \(reason)"
        }
    }
}
