# HUD Voice Integration Architecture: WhisperKit + Kokoro TTS

**Date:** 2026-03-28
**Status:** Design (not implemented)
**Objective:** Enable Jane to speak to the HUD (STT via WhisperKit) and receive spoken responses (TTS via Kokoro)
**Scope:** Architecture design + proof-of-concept, not full implementation

---

## 1. Architecture Overview

### System Flow

```
┌─────────────────────────────────────────────────────────────┐
│                         HUD (macOS App)                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐                ┌──────────────────┐   │
│  │  Voice Input UI  │                │  Voice Output UI │   │
│  │   (mic button)   │                │  (speaker icon)  │   │
│  └────────┬─────────┘                └────────┬─────────┘   │
│           │                                   │              │
│  ┌────────▼──────────────────────────────────▼────────┐     │
│  │       VoiceIOCoordinator                           │     │
│  │  • Manages lifecycle                               │     │
│  │  • Routes audio I/O                                │     │
│  │  • Handles state transitions                       │     │
│  └────────┬──────────────────────────────────┬────────┘     │
│           │                                  │               │
│  ┌────────▼──────────┐           ┌──────────▼──────┐        │
│  │ WhisperKit Engine │           │ Kokoro TTS      │        │
│  │ • On-device STT   │           │ • Local inference        │
│  │ • Core ML         │           │ • 82M params            │
│  │ • Real-time       │           │ • Sub-100ms              │
│  └────────┬──────────┘           └──────────┬──────┘        │
│           │                                  │               │
│  ┌────────▼──────────────────────────────────▼────────┐     │
│  │         AudioIOManager                             │     │
│  │  • AVAudioEngine (input capture)                    │     │
│  │  • AVAudioPlayerNode (playback)                     │     │
│  │  • Buffer management (256-512 frames)               │     │
│  │  • Session category: playAndRecord                  │     │
│  └────────┬──────────────────────────────────┬────────┘     │
│           │                                  │               │
└───────────┼──────────────────────────────────┼───────────────┘
            │                                  │
       ┌────▼─────┐              ┌─────────────▼───┐
       │  Mic     │              │   Speaker/Line  │
       │  Input   │              │    Output       │
       └──────────┘              └─────────────────┘
```

### Event Loop Integration

The voice system integrates into the HUD's existing message queue and status bar routing:

```
StatusQueue (~/.atlas/status-queue.json)
       │
       ├─► MessageQueueManager (polls/watches)
       │
       ├─► StatusBarRouter (renders to notch)
       │
       └─► [NEW] VoiceIOCoordinator
            │
            ├─► Detects voice activation (mic button / hotkey)
            │
            ├─► Captures audio → WhisperKit → transcription
            │
            ├─► Send transcription to Jane daemon OR local intent
            │
            ├─► Receive response text
            │
            └─► Kokoro TTS → playback

```

---

## 2. Component Design

### 2.1 VoiceIOCoordinator (Swift)

**File:** `AtlasHUD/VoiceIOCoordinator.swift`

**Responsibility:** Orchestrates the entire voice I/O lifecycle. Manages state machines, coordinates between WhisperKit and Kokoro, handles error recovery.

**Key Properties:**
- `audioIOManager: AudioIOManager` — audio capture/playback
- `whisperEngine: WhisperKitEngine` — STT
- `kokoroTTSEngine: KokoroTTSEngine` — TTS
- `voiceState: VoiceState` — enum (idle, listening, transcribing, responding, playing)
- `activationGestureRecognizer: NSGestureRecognizer` — hotkey or button detection

**Key Methods:**
```swift
// Voice activation
func startListening() async
func stopListening() async

// After transcription
func onTranscriptionComplete(_ text: String) async
func onTranscriptionError(_ error: Error) async

// Response handling
func speakResponse(_ text: String) async
func onSpeechComplete() async

// State queries
var isListening: Bool { voiceState == .listening }
var canSpeak: Bool { voiceState == .idle || voiceState == .responding }
```

**Integration Points:**
- Observes `@Observable` pattern (like `JaneClient`, `MessageQueueManager`)
- Posts voice events to the main UI layer
- Updates HUD display state during voice operations
- Respects message queue priority (don't interrupt critical red messages)

---

### 2.2 AudioIOManager (Swift)

**File:** `AtlasHUD/AudioIOManager.swift`

**Responsibility:** Low-level audio I/O plumbing. Manages `AVAudioEngine`, buffer lifecycle, session category.

**Audio Session Setup:**
```swift
class AudioIOManager {
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioEngine = AVAudioEngine()

    func setupAudioSession() throws {
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
}
```

**Key Features:**
- Input tap on mic node → circular buffer
- Output node playback from Kokoro
- Buffer size: 256-512 frames @ 16kHz (5-10ms latency target)
- Level metering for visual feedback (animated waveform in notch)

**Key Methods:**
```swift
// Capture
func startCapture() throws
func stopCapture() throws
func captureBuffer(completion: @escaping (AVAudioPCMBuffer) -> Void)

// Playback
func playAudio(data: Data) throws
func stopPlayback()

// Metering
func getInputLevel() -> Float
```

---

### 2.3 WhisperKitEngine (Swift)

**File:** `AtlasHUD/WhisperKitEngine.swift`

**Responsibility:** Wraps WhisperKit SDK, handles transcription.

**Dependency:** `argmaxinc/WhisperKit` (Swift Package)

**Setup:**
```swift
import WhisperKit

class WhisperKitEngine {
    private var whisper: WhisperKit?
    private let modelComputeOptions: ComputeOptions = .cpuAndGPU

    func loadModel() async throws {
        whisper = try await WhisperKit(
            computeOptions: modelComputeOptions,
            verbose: false,
            logLevel: .error
        )
    }
}
```

**Key Methods:**
```swift
// Transcribe audio buffer
func transcribe(buffer: AVAudioPCMBuffer) async throws -> String

// Streaming transcription (for real-time display)
func startStreamingTranscription() async -> AsyncStream<TranscriptionUpdate>

// Cancel in-flight transcription
func cancelTranscription()

// Model status
var isReady: Bool
var modelSize: String  // tiny, base, small, medium, large
```

**Performance Notes:**
- Model: Use `.base` or `.small` (~140M params) for balance of accuracy/speed
- Latency: ~500ms-1s per audio chunk on Apple Silicon M1/M2
- GPU acceleration: Automatic via Core ML with `cpuAndGPU` option
- Memory: ~2GB peak for base model

---

### 2.4 KokoroTTSEngine (Swift)

**File:** `AtlasHUD/KokoroTTSEngine.swift`

**Responsibility:** Local TTS using Kokoro-82M model. No external API calls.

**Architecture:** Two options (pick one):

**Option A: Python subprocess (simpler, battle-tested)**
- Spawn `kokoro-server.py` (FastAPI) as background process
- Communicate via HTTP POST
- Pros: Easy to debug, proven deployment
- Cons: Python subprocess overhead (~300ms startup)

```swift
class KokoroTTSEngine {
    private var serverProcess: Process?
    private let serverURL = URL(string: "http://127.0.0.1:8765")!

    func startKokoroServer() throws {
        serverProcess = Process()
        serverProcess?.executableURL = URL(fileURLWithPath: "/usr/local/bin/python3")
        serverProcess?.arguments = ["/path/to/kokoro-server.py"]
        try serverProcess?.run()
    }

    func synthesize(text: String, speaker: String = "af") async throws -> Data {
        var request = URLRequest(url: serverURL.appendingPathComponent("/synthesize"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["text": text, "speaker": speaker]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}
```

**Option B: Direct Core ML (lower latency, harder to integrate)**
- Compile Kokoro to Core ML
- Load and run inference directly in Swift
- Pros: <100ms inference, no subprocess
- Cons: Requires model compilation, memory spikes

**Recommendation:** Start with Option A (Python subprocess). If latency becomes bottleneck, migrate to Option B.

**Key Methods:**
```swift
// Initialize server (called once at HUD startup)
func initialize() async throws

// Synthesize text → audio data
func synthesize(text: String, speaker: String) async throws -> Data

// Supported speakers
var speakers: [String] { ["af", "am", "as", ...] }  // 200+ voices

// Cancel in-flight synthesis
func cancelSynthesis()
```

**Performance Targets:**
- Inference time: <100ms per 100-char input
- Total latency (including server IPC): <500ms target
- Audio format: WAV PCM 22050 Hz, mono

---

## 3. UI/UX Mockup

### Notch Display

**State: Idle (Normal)**
```
┌─────────────────────┐
│ ⭕ [status message] │  ← Traffic light, normal status
└─────────────────────┘
```

**State: Listening (Hover to activate)**
```
┌──────────────────────────────────┐
│ 🎤 Listening...                  │  ← Animated waveform
│ ▮ ▮ ▮ ▮ ▮ ▮ ▮ ▮ ▮ ▮            │  ← Input level bars
│ [Stop] or press ESC              │
└──────────────────────────────────┘
```

**State: Transcribing**
```
┌──────────────────────────────────┐
│ ⟳ Transcribing...               │  ← Spinner
│ "what is the status of at..."    │  ← Live text
└──────────────────────────────────┘
```

**State: Speaking Response**
```
┌──────────────────────────────────┐
│ 🔊 Jane is speaking...           │
│ ▮ ▮ ▮ ▮ ▮ ▮ ▮ ▮ ▮ ▮            │  ← Playback waveform
│ [25% complete]                   │  ← Progress
└──────────────────────────────────┘
```

### Hover Panel (Expanded)

When user hovers over notch during voice interaction:

```
┌──────────────────────────────────────────────┐
│ Voice Interaction                            │
├──────────────────────────────────────────────┤
│                                              │
│ Transcription (from mic):                    │
│ "what is the status of athena"               │
│                                              │
│ Response (to speaker):                       │
│ "Athena last reported 5 minutes ago.         │
│  System nominal. No critical alerts."        │
│                                              │
│ ⏹ Stop [ESC]  🔇 Mute [M]                  │
│                                              │
└──────────────────────────────────────────────┘
```

### Voice Activation Methods

1. **Hover + Click**: Click microphone icon in expanded notch
2. **Global Hotkey** (configurable): Cmd+Option+V (default)
3. **Gesture**: Long-press on notch pill (drag to edge = adjust volume)
4. **Fallback**: Click "Voice" menu item in menu bar

### Gesture Controls

- **Tap mic icon**: Start/stop listening
- **Long-press notch**: Hold to record (release to stop)
- **Swipe left**: Replay last response
- **Swipe right**: Skip current playback
- **Volume gesture**: Two-finger swipe on pill = volume adjust

---

## 4. Integration Checklist

### Phase 1: Infrastructure (Week 1)

- [ ] Add WhisperKit to project (SPM dependency)
- [ ] Add Kokoro FastAPI server to repo (`tools/kokoro-server.py`)
- [ ] Create `AudioIOManager.swift` with AVAudioEngine plumbing
- [ ] Test microphone capture → buffer loop
- [ ] Test speaker playback from Data

### Phase 2: Voice Engines (Week 2)

- [ ] Implement `WhisperKitEngine.swift`
- [ ] Load base model, verify transcription works
- [ ] Implement `KokoroTTSEngine.swift` (Python subprocess)
- [ ] Test end-to-end: mic → transcription → TTS → speaker

### Phase 3: Coordinator & UI (Week 2-3)

- [ ] Implement `VoiceIOCoordinator.swift` state machine
- [ ] Create `VoiceInputView.swift` (listening UI)
- [ ] Create `VoiceOutputView.swift` (playback UI)
- [ ] Wire into `StatusBarRouter` (don't interrupt red messages)
- [ ] Add voice states to `NotchPillContent`

### Phase 4: Integration with Jane (Week 3)

- [ ] API: transcription → POST to jane-daemon `/voice/transcribe`
- [ ] Jane processes intent, returns response text
- [ ] Wire response back to Kokoro playback
- [ ] Add voice logs to ~/.atlas/voice-history.json (audit trail)

### Phase 5: Polish & Testing (Week 4)

- [ ] Error handling (mic denied, model loading failed, network timeout)
- [ ] Permissions: NSMicrophoneUsageDescription in Info.plist
- [ ] Performance: profile latency, memory, CPU
- [ ] A/B test speaker voices (male/female options)
- [ ] Accessibility: VoiceOver integration, keyboard shortcuts

---

## 5. Code Snippets: Key Integration Points

### 5.1 Wire into HUD AppDelegate

**File:** `AtlasHUD/AppDelegate.swift`

```swift
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    @ObservedReferencedObject var voiceCoordinator = VoiceIOCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize audio and voice engines
        Task {
            do {
                try await voiceCoordinator.initialize()
            } catch {
                NSLog("Voice initialization failed: \(error)")
            }
        }

        // Register global hotkey for voice activation
        // (Option: use ShortcutRecorder or similar)
        setupGlobalVoiceHotkey()
    }

    private func setupGlobalVoiceHotkey() {
        // Cmd+Option+V to toggle listening
        // Implementation: KeyboardShortcuts package or Carbon Events
    }
}
```

### 5.2 Voice State in StatusBarRouter

**File:** `AtlasHUD/StatusBarRouter.swift`

```swift
struct StatusBarRouter: View {
    let config: StatusBarConfig
    @State private var voiceCoordinator = VoiceIOCoordinator.shared

    var body: some View {
        if voiceCoordinator.isListening || voiceCoordinator.isSpeaking {
            // Voice takes priority over normal status display
            VoiceStatusView(coordinator: voiceCoordinator)
        } else {
            // Normal status bar routing
            switch config.resolvedMode {
            case .scanner: KITTScannerView(...)
            case .content: contentView
            // ... rest of existing logic
            }
        }
    }
}
```

### 5.3 Jane Integration (POST Transcription)

**File:** `AtlasHUD/JaneClient.swift`** (extension)

```swift
extension JaneClient {
    func processVoiceTranscription(_ text: String) async throws -> String {
        let endpoint = "https://atlas-serve.apiservices.workers.dev/jane/voice/transcribe"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["transcription": text, "source": "hud"]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(VoiceResponse.self, from: data)
        return response.text
    }
}

struct VoiceResponse: Codable {
    let text: String
    let duration_ms: Int
    let intent: String?
}
```

### 5.4 Microphone Permission Check

**File:** `AtlasHUD/AudioIOManager.swift`** (extension)

```swift
import AVFoundation

extension AudioIOManager {
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
```

### 5.5 Voice History Logging

**File:** `AtlasHUD/VoiceIOCoordinator.swift`** (extension)

```swift
extension VoiceIOCoordinator {
    func logVoiceInteraction(
        transcription: String,
        response: String,
        duration_ms: Int,
        intent: String?
    ) {
        let historyPath = NSString("~/.atlas/voice-history.json").expandingTildeInPath

        let entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "transcription": transcription,
            "response": response,
            "duration_ms": duration_ms,
            "intent": intent ?? "unclassified"
        ]

        // Append to JSON array (or create if missing)
        // Max 100 entries, rotate on overflow
    }
}
```

---

## 6. Performance Analysis

### Latency Budget (end-to-end)

| Component | Latency | Notes |
|-----------|---------|-------|
| Mic capture + buffer | 10-30ms | Depends on buffer size (256-512 frames @ 16kHz) |
| WhisperKit transcription | 500-1500ms | Base model on M1/M2; longer for longer audio |
| Jane HTTP roundtrip | 200-500ms | Depends on network, Jane DO latency |
| Kokoro TTS synthesis | 100-300ms | 82M params, includes server IPC overhead |
| Playback audio latency | 20-50ms | AVAudioEngine output |
| **Total (optimistic)** | ~900ms | Single-turn; improves with streaming |
| **Total (realistic)** | ~2s | Network variance, longer audio chunks |

### Memory Footprint

| Component | Peak Memory | Notes |
|-----------|------------|-------|
| WhisperKit base model | ~2 GB | Shared, loaded once |
| Audio buffers (circular) | ~50 MB | 3-5s @ 16kHz PCM |
| Kokoro server (Python) | ~500 MB | Includes PyTorch runtime |
| HUD app (rest) | ~200 MB | SwiftUI, message queue, etc. |
| **Total** | ~2.7 GB | Acceptable for modern Macs (8GB+) |

### CPU Usage

- Listening (idle, no capture): <1%
- Transcribing (active): 40-60% (2-4 cores on M1/M2)
- Playing audio: <5%
- Kokoro synthesis: 30-50% (mostly Python overhead)

**Optimization Ideas:**
- Lazy-load Kokoro (only on first TTS request)
- Use smaller Whisper model (.tiny) for low-latency mode
- Cache common responses (e.g., "what's the status?")

---

## 7. Open Questions & Blockers

### Technical

1. **Kokoro Model Access**: Is Kokoro-82M freely available on Hugging Face? Verify licensing.
   - **Answer:** Yes, [hexgrad/Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) is open-source (MIT-like)

2. **WhisperKit Model Size**: Base model is ~140M params. Will it fit on older Macs (4GB RAM)?
   - **Answer:** Probably not. Need fallback to `.tiny` (~39M) for low-memory devices.

3. **Real-time Streaming**: Can we stream transcription results to UI before full buffer is processed?
   - **Answer:** WhisperKit supports streaming (check `startStreamingTranscription()`). Need prototype.

4. **Audio Input Format**: What sample rate for WhisperKit? Kokoro expects 22050Hz or 24000Hz?
   - **Answer:** WhisperKit works with 16kHz PCM. Kokoro works with 22050Hz. Use 16kHz capture, resample if needed.

### Product

5. **Voice Activation UX**: Hotkey vs. button click vs. always-listening? Security implications of always-listening?
   - **Recommendation:** Start with explicit activation (Cmd+Option+V hotkey). Never record without user action.

6. **Speaker Customization**: How many Kokoro voices do we need? Gendered voices for accessibility?
   - **Recommendation:** Support 3-5 voices (af/am/as variants). UI selector in settings.

7. **Error Recovery**: What if Jane is offline? Fallback to local intent recognition?
   - **Recommendation:** Queue transcriptions, reply with "Jane is busy, I'll respond when she's back."

### Infrastructure

8. **Model Distribution**: How do users get WhisperKit + Kokoro models? Bundle with app or lazy-download?
   - **Recommendation:** Lazy-download on first voice activation. Cache in `~/Library/Caches/AtlasHUD/models/`.

9. **Permissions**: Microphone + Network. Need NSMicrophoneUsageDescription in Info.plist. Any other security considerations?
   - **Answer:** Yes. Also: NSAudioVideoUsageDescription (for speaker). No privacy issues (all processing local/Atlas internal).

10. **Testing**: How to mock WhisperKit + Kokoro in tests?
    - **Recommendation:** Protocol-based design. Create `WhisperKitEngine` protocol, mock for tests.

---

## 8. Estimated Effort

### Development Timeline

| Phase | Work | Effort | Dependencies |
|-------|------|--------|--------------|
| 1. Infrastructure | Audio plumbing, AVAudioEngine setup | 2-3 days | None |
| 2. Voice Engines | WhisperKit integration, Kokoro server | 3-4 days | Kokoro model access |
| 3. Coordinator | State machine, error handling | 2-3 days | Phases 1-2 |
| 4. UI/UX | Voice views, waveform animation | 3-4 days | Phase 3 |
| 5. Jane Integration | API endpoint, logging | 1-2 days | Jane daemon ready |
| 6. Testing & Polish | End-to-end tests, latency profiling, A/B testing voices | 3-4 days | Phases 1-5 |
| **Total** | | **14-20 days** (2-3 weeks) | |

### Resource Allocation

- **1 engineer, full-time**: 2-3 weeks
- **1 designer** (part-time): 1 week (UI mockups, voice selection)
- **1 QA** (concurrent): 1 week (test plan, edge cases)

### Risks & Contingencies

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Whisper model won't fit on low-memory Macs | Medium | Blocks older user base | Tiered model strategy (.tiny fallback) |
| Kokoro server latency unacceptable | Low | Blocks feature | Migrate to Core ML compilation (1-2 extra days) |
| Jane API endpoint not ready | Medium | Blocks Jane integration | Stub endpoint, test locally first |
| Audio routing conflicts with other apps | Low | Crashes HUD | Careful audio session management, fallback to system TTS |
| Hotkey conflicts with system shortcuts | Medium | UX friction | Use Cmd+Option+V (uncommon) or Settings configurability |

---

## 9. Related Architecture Decisions

### Messaging Contract Extension

Add voice log to existing `QueuedMessage` structure (optional):

```swift
struct QueuedMessage: Codable {
    // ... existing fields
    let voiceLog: VoiceLogEntry?  // nil if message not voice-originated
}

struct VoiceLogEntry: Codable {
    let transcription: String       // What user said
    let intent: String?             // Classified intent (e.g., "status_check")
    let confidence: Double          // Transcription confidence (0-1)
    let processing_ms: Int          // Total latency
}
```

### Jane Daemon Extensions

Jane daemon needs a new `/voice/transcribe` endpoint:

```
POST /jane/voice/transcribe
Content-Type: application/json

{
  "transcription": "what is the status of athena",
  "source": "hud",
  "context": {
    "last_session_id": "abc123",
    "user_location": "machine"
  }
}

Response:
{
  "text": "Athena last reported 5 minutes ago. System nominal.",
  "intent": "status_check",
  "duration_ms": 1200,
  "confidence": 0.95
}
```

### Audio Settings (~/.atlas/voice.config)

```json
{
  "enabled": true,
  "hotkey": "cmd+option+v",
  "speaker": "af",           // 200+ voices available
  "mic_sensitivity": 0.7,    // 0-1, threshold for voice detection
  "confirm_before_send": false,
  "logging": true,
  "models": {
    "whisper_size": "base",  // tiny, base, small, medium, large
    "kokoro_path": "~/Library/Caches/AtlasHUD/kokoro-82m"
  },
  "latency_targets_ms": {
    "capture_to_transcription": 2000,
    "jane_roundtrip": 1000,
    "synthesis_to_playback": 500
  }
}
```

---

## 10. References & Resources

### Toolkits & SDKs

- **WhisperKit**: [argmaxinc/WhisperKit on GitHub](https://github.com/argmaxinc/WhisperKit), [Swift Package](https://swiftpackageindex.com/argmaxinc/WhisperKit)
- **Kokoro TTS**: [hexgrad/Kokoro-82M on Hugging Face](https://huggingface.co/hexgrad/Kokoro-82M), [GitHub repo](https://github.com/hexgrad/kokoro)
- **Kokoro FastAPI Server**: [remsky/Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI) (Docker + ONNX)

### macOS Audio

- [AVAudioEngine Documentation](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [Real-time Audio Processing with AVAudioEngine (Stack Overflow discussion)](https://developer.apple.com/forums/thread/5570)
- [AVSpeechSynthesizer (native TTS alternative)](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer)

### Inspiration & Prior Art

- **TypeWhisper**: [TypeWhisper/typewhisper-mac](https://github.com/TypeWhisper/typewhisper-mac) — local macOS STT app, open-source
- **Whispera**: [sapoepsilon/Whispera](https://github.com/sapoepsilon/Whispera) — WhisperKit-based transcription app
- **macOS Speech Server**: [dokterbob/macos-speech-server](https://github.com/dokterbob/macos-speech-server) — OpenAI-compatible local API

### Performance Benchmarks

- **WhisperKit Speed**: ~0.5-1.5s per 5-10s audio (base model, M1/M2)
- **Kokoro Speed**: ~210× real-time on RTX 4090; ~3-11× on CPU
- **Combined Latency**: ~2s end-to-end for typical query

---

## 11. Success Criteria

### Functional

- [ ] User can press Cmd+Option+V and speak
- [ ] Transcription appears in notch within 2 seconds
- [ ] Jane responds with text within 3 seconds
- [ ] Response is spoken aloud within 1 second
- [ ] Voice history logged to ~/.atlas/voice-history.json
- [ ] All processing happens on-device (no third-party APIs)

### Performance

- [ ] Transcription latency <2s for typical (10s) input
- [ ] TTS latency <500ms
- [ ] HUD remains responsive (no UI freezes)
- [ ] Memory usage stays <3GB during voice session
- [ ] Works on M1/M2 Macs with 8GB+ RAM

### UX/Accessibility

- [ ] Waveform animation provides visual feedback
- [ ] Error messages are clear and actionable
- [ ] Works with Bluetooth mics and external speakers
- [ ] VoiceOver-friendly (accessible labels, keyboard shortcuts)

### Reliability

- [ ] Graceful degradation if Kokoro server crashes
- [ ] Timeout handling (Jane doesn't respond in 5s → fallback)
- [ ] Model loading failures don't crash HUD
- [ ] Clean shutdown on app quit (no zombie processes)

---

## Appendix A: Kokoro Installation

For developers setting up Kokoro locally:

```bash
# Clone Kokoro
git clone https://github.com/hexgrad/kokoro /opt/kokoro

# Create Python venv
python3 -m venv /opt/kokoro/.venv
source /opt/kokoro/.venv/bin/activate

# Install dependencies
pip install torch torchaudio transformers fastapi uvicorn

# Download model (auto on first run, ~500MB)
python3 -c "from transformers import AutoTokenizer, AutoModel; \
  AutoTokenizer.from_pretrained('hexgrad/Kokoro-82M'); \
  AutoModel.from_pretrained('hexgrad/Kokoro-82M')"

# Start server
python3 /opt/kokoro/kokoro-server.py --host 127.0.0.1 --port 8765
```

Then update `KokoroTTSEngine` to point to your installation.

---

## Appendix B: Sample Message from Voice

Example status message originating from voice interaction:

```json
{
  "id": "voice-athena-status-20260328-143000",
  "source": "hud-voice",
  "severity": "green",
  "priority": 20,
  "message": "Based on voice query: 'status of athena'. Response received.",
  "banner": "🎤 Jane: Athena nominal",
  "slots": {
    "transcription": {
      "type": "text_label",
      "label": "You said",
      "value": "what is the status of athena"
    },
    "intent": {
      "type": "text_label",
      "label": "Intent",
      "value": "status_check"
    },
    "jane_response": {
      "type": "text_label",
      "label": "Jane replied",
      "value": "Athena last reported 5 minutes ago. System nominal."
    }
  },
  "created": "2026-03-28T14:30:00Z",
  "ttl": 30
}
```

---

**Document Status:** Design Complete (Ready for Implementation Planning)
**Next Step:** Create GitHub issue with implementation plan, assign to developer.
