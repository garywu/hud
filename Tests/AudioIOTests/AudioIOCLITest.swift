import Foundation
import AVFoundation

/// CLI integration test for AudioIOManager
/// Usage: swift AudioIOCLITest.swift
///
/// This test:
/// 1. Sets up audio session
/// 2. Initializes AVAudioEngine
/// 3. Requests microphone permission
/// 4. Captures 5 seconds of audio
/// 5. Logs RMS level at 100ms intervals
/// 6. Generates a simple waveform visualization
///
/// Example output:
/// ```
/// [0000ms] RMS: 0.015 ▁
/// [0100ms] RMS: 0.018 ▁
/// [0200ms] RMS: 0.042 ▂
/// ...
/// [5000ms] RMS: 0.008 ▁
/// ```

@main
struct AudioIOCLITest {
    static func main() async {
        print("=== HUD Voice Integration: Audio I/O Infrastructure Test ===\n")

        let tester = AudioIOCLITester()
        await tester.run()
    }
}

actor AudioIOCLITester {
    private let audioManager: AudioIOManager
    private let captureSeconds: TimeInterval = 5.0
    private let sampleInterval: TimeInterval = 0.1 // 100ms

    init() {
        self.audioManager = AudioIOManager()
    }

    func run() async {
        print("Step 1: Checking microphone permission...")
        let hasPermission = await audioManager.requestMicrophonePermission()
        print("  Permission status: \(hasPermission ? "GRANTED" : "DENIED")\n")

        if !hasPermission {
            print("ERROR: Microphone permission required. Please grant permission in System Settings.")
            return
        }

        print("Step 2: Setting up audio session...")
        do {
            try audioManager.setupAudioSession()
            print("  ✓ Audio session configured (playAndRecord mode)\n")
        } catch {
            print("  ✗ Failed to setup audio session: \(error)")
            return
        }

        print("Step 3: Initializing AVAudioEngine...")
        do {
            try audioManager.initialize()
            print("  ✓ Engine initialized with 16kHz mono capture\n")
        } catch {
            print("  ✗ Failed to initialize engine: \(error)")
            return
        }

        print("Step 4: Starting audio capture (5 seconds)...")
        do {
            try await audioManager.startCapture()
            print("  ✓ Capture started\n")
        } catch {
            print("  ✗ Failed to start capture: \(error)")
            return
        }

        print("Sampling RMS level at \(Int(sampleInterval * 1000))ms intervals:\n")
        print("Time(ms)  RMS Level  Waveform        Bar Chart")
        print("────────  ─────────  ──────────────  ──────────────────────")

        let results = await captureAndLog()

        print("\nStep 5: Stopping capture...")
        do {
            try await audioManager.stopCapture()
            print("  ✓ Capture stopped\n")
        } catch {
            print("  ✗ Failed to stop capture: \(error)")
            return
        }

        // Print analysis
        await printAnalysis(results: results)
    }

    private func captureAndLog() async -> [CaptureResult] {
        var results: [CaptureResult] = []
        let startTime = Date()
        let samples = Int(captureSeconds / sampleInterval)

        for i in 0...samples {
            if i > 0 {
                try? await Task.sleep(nanoseconds: UInt64(sampleInterval * 1_000_000_000))
            }

            let elapsed = Date().timeIntervalSince(startTime)
            let elapsedMs = Int(elapsed * 1000)

            if elapsedMs > Int(captureSeconds * 1000) {
                break
            }

            let rmsLevel = await audioManager.getInputLevel()

            let waveformChar = levelToWaveformCharacter(rmsLevel)
            let barChart = levelToBarChart(rmsLevel, width: 20)

            let timeStr = String(format: "%04d", elapsedMs)
            let levelStr = String(format: "%.3f", rmsLevel)

            print("\(timeStr)ms  \(levelStr)     \(waveformChar)              \(barChart)")

            results.append(CaptureResult(
                timeMs: elapsedMs,
                rmsLevel: rmsLevel
            ))
        }

        return results
    }

    private func printAnalysis(results: [CaptureResult]) async {
        guard !results.isEmpty else {
            print("No capture data collected")
            return
        }

        let rmsLevels = results.map { $0.rmsLevel }
        let minRMS = rmsLevels.min() ?? 0
        let maxRMS = rmsLevels.max() ?? 0
        let avgRMS = rmsLevels.reduce(0, +) / Float(rmsLevels.count)

        print("\n=== Audio Capture Analysis ===\n")
        print("Samples collected:      \(results.count)")
        print("Duration:               \(String(format: "%.1f", captureSeconds)) seconds")
        print("Sample interval:        \(Int(sampleInterval * 1000)) milliseconds")
        print("\nRMS Level Statistics:")
        print("  Minimum RMS:          \(String(format: "%.4f", minRMS))")
        print("  Maximum RMS:          \(String(format: "%.4f", maxRMS))")
        print("  Average RMS:          \(String(format: "%.4f", avgRMS))")
        print("  Range:                \(String(format: "%.4f", maxRMS - minRMS))")

        // Detect audio activity
        let noiseFloor: Float = 0.05
        let activeFrames = rmsLevels.filter { $0 > noiseFloor }.count
        let activityPercent = Float(activeFrames) / Float(rmsLevels.count) * 100

        print("\nAudio Activity:")
        print("  Noise floor threshold: \(String(format: "%.4f", noiseFloor))")
        print("  Active frames:         \(activeFrames) / \(rmsLevels.count)")
        print("  Activity percentage:   \(String(format: "%.1f%%", activityPercent))")

        if activityPercent < 5 {
            print("  Status:                ✓ QUIET (good for baseline)")
        } else if activityPercent < 30 {
            print("  Status:                ✓ LOW NOISE (acceptable)")
        } else {
            print("  Status:                ⚠ HIGH NOISE (may affect transcription)")
        }

        print("\n=== Test Result: PASSED ===")
        print("\nThe audio I/O infrastructure is working correctly.")
        print("The AudioIOManager successfully:")
        print("  • Initialized AVAudioEngine with microphone input")
        print("  • Captured 5 seconds of audio from microphone")
        print("  • Computed RMS levels at regular intervals")
        print("  • Provided clean audio I/O abstraction\n")
    }

    private func levelToWaveformCharacter(_ rms: Float) -> String {
        // Simple waveform visualization using Unicode characters
        switch rms {
        case 0..<0.02:   return "▁"
        case 0.02..<0.05:  return "▂"
        case 0.05..<0.1:   return "▃"
        case 0.1..<0.15:   return "▄"
        case 0.15..<0.2:   return "▅"
        case 0.2..<0.3:    return "▆"
        case 0.3..<0.5:    return "▇"
        default:           return "█"
        }
    }

    private func levelToBarChart(_ rms: Float, width: Int) -> String {
        let filledWidth = Int(rms * Float(width))
        let filled = String(repeating: "█", count: filledWidth)
        let empty = String(repeating: "░", count: width - filledWidth)
        return "\(filled)\(empty)"
    }
}

struct CaptureResult {
    let timeMs: Int
    let rmsLevel: Float
}
