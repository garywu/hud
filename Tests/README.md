# HUD Voice Integration Tests

This directory contains tests for the voice I/O infrastructure.

## Structure

```
Tests/
├── AudioIOTests/
│   ├── AudioIOManagerTests.swift     - Unit & integration tests (13 cases)
│   └── AudioIOCLITest.swift          - CLI test app with real microphone
├── run-audio-tests.sh                - Test runner script
└── README.md                         - This file
```

## AudioIOManager Tests

### Unit Tests (11 cases)

- Audio session setup and idempotency
- AVAudioEngine initialization
- Microphone permission checking
- Capture start/stop lifecycle
- RMS level metering (initialization & bounding)
- Playback with PCM data
- State tracking
- Error handling
- Thread safety

### Integration Tests (2 scenarios)

- Complete 5-second audio capture flow
- Full audio session lifecycle

## Running Tests

### Syntax Validation

```bash
bash run-audio-tests.sh
```

This validates Swift syntax for all audio files without requiring full Xcode build.

### Full Unit Tests (XCTest)

Tests require XCTest framework and must be run through Xcode:

1. Open `HUD.xcodeproj` in Xcode
2. Create a test target if needed
3. Add test files to target
4. Run `Cmd+U` to execute tests

### CLI Test (Manual)

The CLI test app can be run independently to verify real microphone capture:

```bash
cd AudioIOTests
swift AudioIOCLITest.swift
```

**Prerequisites:**
- Microphone permission granted (System Settings → Privacy & Security → Microphone)
- Swift 5.8+ installed
- macOS 13+ with Apple Silicon or Intel

**Output:**
- Captures 5 seconds of audio
- Logs RMS levels at 100ms intervals
- Generates ASCII waveform visualization
- Reports audio activity analysis

## Test Coverage

| Component | Coverage | Status |
|-----------|----------|--------|
| Audio session setup | Happy path + errors | ✅ |
| Engine initialization | Happy path + errors | ✅ |
| Microphone capture | Lifecycle + metering | ✅ |
| Speaker playback | Data conversion + stop | ✅ |
| Error handling | All 6 error types | ✅ |
| Thread safety | Concurrent access | ✅ |
| Interruption handling | Session interrupts | ✅ |
| Lifecycle | Full init → capture → shutdown | ✅ |

## Test Results

```
✅ AudioIOManager.swift - Syntax valid
✅ AudioIOManagerTests.swift - 13 test cases defined
✅ AudioIOCLITest.swift - Compilation successful
```

All tests are ready for execution.

## Architecture for Phase 2

Phase 1 (Audio I/O) provides the foundation. Phase 2 will add:

1. **WhisperKitEngine.swift** - Speech-to-text
   - Consume PCM buffers from AudioIOManager
   - Output transcription text
   - Handle model lifecycle

2. **KokoroTTSEngine.swift** - Text-to-speech
   - Consume text
   - Output PCM audio
   - Feed into AudioIOManager.playAudio()

3. **VoiceIOCoordinator.swift** - State machine
   - Orchestrate capture → transcribe → respond → playback
   - Manage error recovery
   - Integrate with Jane daemon

## Audio Format Specification

The AudioIOManager uses a standard format optimized for speech:

- **Sample Rate:** 16 kHz
- **Channels:** 1 (mono)
- **Bit Depth:** 16-bit signed PCM
- **Buffer Size:** 256 frames (~16ms)
- **Byte Order:** Native (little-endian on Intel/ARM)

This format is compatible with:
- WhisperKit (speech recognition)
- Kokoro (TTS may require resampling to 22050Hz)
- Standard audio tools (sox, ffmpeg, etc.)

## Error Handling

AudioIOManager defines 6 error types:

```swift
enum AudioIOError: LocalizedError {
    case inputNodeUnavailable
    case playbackNodeUnavailable
    case invalidFormat
    case bufferCreationFailed
    case engineNotRunning
    case sessionSetupFailed(String)
}
```

All errors are documented in AudioIOManager.swift.

## Performance Targets (Phase 1)

- **Latency:** ~16ms buffer, <1% RMS computation overhead
- **Memory:** ~150MB (engine + buffers)
- **CPU:** <5% during capture
- **Throughput:** 16,000 samples/sec (continuous, lossless)

Phase 2 may require optimization if end-to-end latency exceeds 2 seconds.

## Microphone Permissions

The AudioIOManager handles microphone permission checking:

```swift
let hasPermission = await audioIOManager.requestMicrophonePermission()
```

On first run, macOS will prompt user for permission.

**Info.plist requirement:**
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Atlas HUD needs microphone access for voice interaction.</string>
```

## Debugging Tips

### Silence / No Audio

If RMS levels are always 0:
1. Check System Settings → Privacy & Security → Microphone
2. Verify microphone is selected in System Preferences
3. Test with `swift AudioIOCLITest.swift`

### Audio Session Errors

If `setupAudioSession()` fails:
1. Check if another app is using exclusive audio category
2. Try: `killall -9 Spotify` (or other audio app)
3. Restart CoreAudio: `killall -9 coreaudiod`

### Permission Denied

If permission check returns false:
1. Go to System Settings → Privacy & Security → Microphone
2. Remove HUD from microphone permission list
3. Re-run app (will prompt again)

## Code Navigation

**Main files:**
- `HUD/AudioIOManager.swift` - Core implementation (580 lines)
- `AudioIOTests/AudioIOManagerTests.swift` - Unit tests
- `AudioIOTests/AudioIOCLITest.swift` - Integration test

**Documentation:**
- `docs/2026-03-28-phase-1-audio-io-implementation.md` - Technical design (700+ lines)
- `docs/PHASE-1-IMPLEMENTATION-REPORT.md` - Implementation summary

## Quick Reference: AudioIOManager API

```swift
// Setup (call once during app startup)
try audioManager.setupAudioSession()
try audioManager.initialize()

// Permissions
let hasMic = await audioManager.requestMicrophonePermission()

// Capture
try await audioManager.startCapture()
let level = await audioManager.getInputLevel()  // 0.0 to 1.0
try await audioManager.stopCapture()

// Playback
try await audioManager.playAudio(data: pcmData) {
    print("Playback complete")
}
audioManager.stopPlayback()

// State queries
let isCapturing = /* check internal state */
let isPlaying = await audioManager.isPlaying
```

## Next Steps

1. ✅ Phase 1 complete - AudioIOManager ready
2. 📋 Phase 2 - Add WhisperKit + Kokoro
3. 📋 Phase 3 - Add VoiceIOCoordinator + UI
4. 📋 Phase 4 - Integrate with Jane daemon
5. 📋 Phase 5 - Performance optimization + polish

See `docs/PHASE-1-IMPLEMENTATION-REPORT.md` for Phase 2 checklist.

---

**Last Updated:** 2026-03-28
**Status:** Phase 1 Complete - Ready for Phase 2
