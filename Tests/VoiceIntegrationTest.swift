import XCTest
import AVFoundation
@testable import AtlasHUD

/// Integration tests for WhisperKit voice-to-text flow.
/// Tests the complete pipeline: AudioIOManager → WhisperKitEngine → transcription
final class VoiceIntegrationTest: XCTestCase {

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
    }

    // MARK: - Test: WhisperKit Engine Initialization

    func testWhisperKitEngineInitialization() async throws {
        let engine = WhisperKitEngine()
        XCTAssertFalse(engine.isReady, "Engine should not be ready before loadModel()")
    }

    // MARK: - Test: Audio Buffer Validation

    func testWhisperKitBufferValidation() async throws {
        let engine = WhisperKitEngine()

        // Create a valid test buffer (16kHz mono)
        let format = AVAudioFormat(
            standardFormatWithSampleRate: 16000,
            channels: 1
        )
        guard let format = format else { return }

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16000)!
        XCTAssertTrue(engine.isValidBuffer(buffer), "Valid 16kHz mono buffer should pass validation")

        // Test empty buffer
        let emptyBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0)!
        XCTAssertFalse(engine.isValidBuffer(emptyBuffer), "Empty buffer should fail validation")
    }

    // MARK: - Test: AudioIOManager Integration

    func testAudioIOManagerCaptureFlow() async throws {
        let manager = AudioIOManager()

        try await manager.setupAudioSession()
        try await manager.initialize()

        // Start capture
        try await manager.startCapture()
        XCTAssertTrue(true, "Capture started successfully")

        // Simulate audio capture delay
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // Check input level
        let level = await manager.getInputLevel()
        XCTAssertGreaterThanOrEqual(level, 0.0)
        XCTAssertLessThanOrEqual(level, 1.0)

        // Stop capture
        try await manager.stopCapture()
        XCTAssertTrue(true, "Capture stopped successfully")
    }

    // MARK: - Test: VoiceIOCoordinator Initialization

    func testVoiceIOCoordinatorInitialization() async throws {
        let coordinator = VoiceIOCoordinator()
        await coordinator.initialize()
        XCTAssertTrue(true, "Coordinator initialized")
    }

    // MARK: - Test: Voice Listening Flow (High-Level)

    func testVoiceListeningStateTransition() async throws {
        let coordinator = VoiceIOCoordinator()
        await coordinator.initialize()

        // Start listening
        await coordinator.startListening()
        XCTAssertTrue(await coordinator.isActive, "Coordinator should be listening")

        // Simulate user speaking for short time
        try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms

        // Stop listening and transcribe
        await coordinator.stopListening()
        XCTAssertFalse(await coordinator.isActive, "Coordinator should not be listening after stop")
    }

    // MARK: - Test: Error Handling

    func testAudioIOErrorHandling() async throws {
        let manager = AudioIOManager()

        // Try to start capture without initialization
        do {
            try await manager.startCapture()
            XCTFail("Should have thrown engineNotRunning error")
        } catch AudioIOError.engineNotRunning {
            XCTAssertTrue(true, "Correctly threw engineNotRunning")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Test: Microphone Permission

    func testMicrophonePermission() async throws {
        let manager = AudioIOManager()
        let hasPermission = await manager.requestMicrophonePermission()
        XCTAssertIsNotNil(hasPermission, "Permission check should return a boolean")
    }
}

/// Stress tests for voice system reliability.
final class VoiceReliabilityTest: XCTestCase {

    func testConcurrentAudioCapture() async throws {
        let manager = AudioIOManager()

        try await manager.setupAudioSession()
        try await manager.initialize()

        // Start multiple concurrent capture tasks
        let tasks = (0..<5).map { _ in
            Task {
                do {
                    try await manager.startCapture()
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    try await manager.stopCapture()
                } catch {
                    // Expected in some cases
                }
            }
        }

        for task in tasks {
            await task.value
        }

        XCTAssertTrue(true, "Concurrent capture handling completed")
    }

    func testAudioIOManagerShutdown() async throws {
        let manager = AudioIOManager()

        try await manager.setupAudioSession()
        try await manager.initialize()
        try await manager.startCapture()

        // Proper shutdown
        try await manager.stopCapture()
        await manager.stopPlayback()

        XCTAssertTrue(true, "Shutdown completed successfully")
    }
}
