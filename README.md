# Building Jane — A Persistent AI Companion with Voice, Memory, Face, and Local Superpowers

An AI companion that lives in your MacBook notch is not a chatbot. It is a daemon with a face, a voice, a memory that spans months, and root access to your machine. This article is the complete technical blueprint for building one — covering speech recognition, voice synthesis, persistent memory architectures, avatar rendering, always-on daemon design, local automation capabilities, and the competitive landscape of AI companion products. If you are building an ambient AI presence that goes beyond a chat window, this is the reference you need.

**What you will learn:**

- How to capture voice input locally on macOS — Wispr Flow, whisper.cpp, WhisperKit, Apple SpeechAnalyzer, and wake word detection with Porcupine
- How to speak back — ElevenLabs, OpenAI TTS, Kokoro-82M, Piper, and AVSpeechSynthesizer compared on quality, latency, cost, and voice cloning
- How to build memory that persists across weeks — Letta/MemGPT, Mem0, Zep, and a custom three-tier architecture
- How to render a face in a 50x60pt notch display — SceneKit blend shapes, SpriteKit state machines, pixel-art approaches
- How to design an always-on daemon that does not drain the battery — wake word detection, tiered model routing, background processing
- What the AI companion market looks like — Replika, Character.AI, Pi, Friend pendant, Rewind/Limitless, Screenpipe, and the lessons from Rabbit R1 and Humane AI Pin
- How to give Jane local superpowers — file system access, AppleScript/JXA, Accessibility API, credential management, and the MCP server pattern
- How to add deep research as an ambient feature — Perplexity, OpenAI, and Gemini deep research surfaced through a notch display
- How to handle privacy and ethics for an always-listening companion
- How to monetize a desktop AI companion

---

## Table of Contents

1. [The Problem](#1-the-problem)
2. [Architecture Overview](#2-architecture-overview)
3. [Voice Input — Hearing Jane](#3-voice-input--hearing-jane)
4. [Voice Output — Jane Speaks](#4-voice-output--jane-speaks)
5. [Memory Systems — Jane Remembers](#5-memory-systems--jane-remembers)
6. [Avatar and Face — Jane Has a Presence](#6-avatar-and-face--jane-has-a-presence)
7. [Always-On Daemon Architecture](#7-always-on-daemon-architecture)
8. [Local Superpowers — What Cloud Cannot Do](#8-local-superpowers--what-cloud-cannot-do)
9. [Deep Research as an Ambient Feature](#9-deep-research-as-an-ambient-feature)
10. [Competitive Landscape — AI Companion Products](#10-competitive-landscape--ai-companion-products)
11. [Anti-Patterns](#11-anti-patterns)
12. [Privacy and Ethics](#12-privacy-and-ethics)
13. [Monetization](#13-monetization)
14. [Patterns — Putting It All Together](#14-patterns--putting-it-all-together)
15. [References](#15-references)

---

## 1. The Problem

Every AI assistant today lives in a browser tab or a chat window. You open it, you type, you get a response, you close it. The assistant forgets you between sessions (or remembers poorly). It cannot see your screen. It cannot open files. It cannot hear you unless you are actively holding down a button. It has no face, no ambient presence, no personality continuity.

This is the state of AI interaction in 2026:

- **ChatGPT, Claude, Gemini** — powerful but ephemeral. Memory is shallow (ChatGPT stores "facts" but misses nuance). No local access. No ambient presence. You go to them; they do not come to you.
- **Siri, Alexa, Google Assistant** — always-listening but brain-dead. They handle timers and weather but cannot do multi-step reasoning, cannot remember a conversation from last week, cannot write code or analyze documents.
- **AI coding tools (Claude Code, Cursor)** — deep local access but task-scoped. They exist only during a coding session. No persistence, no personality, no voice.
- **AI companion apps (Replika, Character.AI, Pi)** — emotional presence but no capability. They remember conversations but cannot open a file, check a calendar, or run a script. They live on your phone, not your workstation.

The gap is clear: **no product combines persistent memory, voice interaction, local machine access, ambient visual presence, and deep AI reasoning in a single always-on companion.**

Jane fills this gap. She lives in the macOS notch — a 50x60pt display surface that is always visible. She listens through the microphone. She speaks through the speakers. She remembers every conversation across weeks and months. She can read your files, control your apps, check your calendar, and run deep research in the background. She has a face that reacts to what she is saying and hearing.

Jane is not a chatbot you visit. She is an ambient intelligence that lives with you.

### What changes if you get this right

| Before Jane | After Jane |
|-------------|------------|
| Open ChatGPT tab, type question, close tab | Say "Jane, what was that restaurant Sarah recommended?" and hear the answer |
| Check calendar app, mentally plan day | Jane surfaces your next meeting 5 minutes before, knows your prep preferences |
| Search through emails for that one attachment | "Jane, find the PDF Dave sent about the Q3 budget" — she opens it |
| Forget what you discussed with your team last Tuesday | Jane remembers. She was listening. She can summarize. |
| Run a research query, wait, read results | Jane runs deep research in the background, alerts you when done |
| No awareness of system state | Jane monitors Docker containers, Git status, build failures — surfaces issues proactively |

---

## 2. Architecture Overview

Jane is not a single component. She is a system of interconnected subsystems, each handling a distinct concern. The architecture follows a pipeline model: input flows through recognition, reasoning, memory, and output stages, with a persistent daemon coordinating everything.

```
┌──────────────────────────────────────────────────────────────┐
│                     macOS Notch Display                       │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │  Avatar   │  │  Status Bar  │  │  Notification Queue    │  │
│  │  (Face)   │  │  (LCD/Text)  │  │  (Policy Engine)       │  │
│  └──────────┘  └──────────────┘  └────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
         ▲                    ▲                    ▲
         │                    │                    │
┌────────┴────────────────────┴────────────────────┴───────────┐
│                     Jane Core Daemon                          │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐  │
│  │  Voice In    │  │  Reasoning   │  │  Voice Out           │  │
│  │  (STT)       │  │  (LLM)       │  │  (TTS)               │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬───────────┘  │
│         │                │                     │              │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────────▼───────────┐  │
│  │  Wake Word   │  │  Memory     │  │  Avatar Animator     │  │
│  │  (Porcupine) │  │  (3-tier)   │  │  (Viseme → Face)     │  │
│  └─────────────┘  └─────────────┘  └──────────────────────┘  │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐  │
│  │  Local       │  │  Deep        │  │  Plugin              │  │
│  │  Runner      │  │  Research    │  │  Registry             │  │
│  │  (JXA/AS)    │  │  (Async)     │  │  (HTTP API)           │  │
│  └─────────────┘  └─────────────┘  └──────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
         ▲                    ▲                    ▲
         │                    │                    │
    File System          Cloud APIs          localhost:7070
    Apps (JXA)           (Anthropic,          (HUD Server)
    Accessibility        OpenAI, etc.)
```

### Core Types

```typescript
interface JaneConfig {
  voice: {
    input: "whisperkit" | "whisper-cpp" | "apple-speech" | "wispr-flow";
    output: "elevenlabs" | "openai-tts" | "kokoro" | "piper" | "apple-tts";
    wakeWord: string; // e.g., "Hey Jane"
    wakeWordEngine: "porcupine" | "custom";
    alwaysListening: boolean;
    voiceId?: string; // For ElevenLabs voice cloning
  };
  memory: {
    backend: "letta" | "mem0" | "custom";
    coreMemoryTokens: number; // Tokens reserved for core memory in context
    archivalBackend: "sqlite-vec" | "qdrant" | "chroma";
    retentionDays: number; // How long before memories decay
    localOnly: boolean;
  };
  reasoning: {
    fast: "claude-haiku" | "gpt-4o-mini"; // Quick responses, cheap
    balanced: "claude-sonnet" | "gpt-4o"; // Most interactions
    deep: "claude-opus" | "o3"; // Deep research, complex reasoning
    routingStrategy: "cost-first" | "quality-first" | "adaptive";
  };
  avatar: {
    renderer: "scenekit" | "spritekit" | "pixel-art";
    expressionSet: "basic" | "full"; // 6 vs 52 blend shapes
    lipSync: boolean;
    idleAnimations: boolean;
  };
  localRunner: {
    allowFileSystem: boolean;
    allowAppleScript: boolean;
    allowAccessibility: boolean;
    allowNetwork: boolean;
    sandboxLevel: "strict" | "moderate" | "permissive";
    approvalRequired: "always" | "destructive-only" | "never";
  };
  daemon: {
    startAtLogin: boolean;
    powerMode: "aggressive" | "balanced" | "conservative";
    backgroundResearch: boolean;
    proactiveAlerts: boolean;
  };
}
```

```typescript
interface JaneState {
  conversationId: string;
  isListening: boolean;
  isSpeaking: boolean;
  currentEmotion: Emotion;
  activeResearchTasks: ResearchTask[];
  lastInteractionAt: Date;
  memorySnapshot: {
    coreMemory: CoreMemoryBlock[];
    recentConversations: number;
    archivalEntries: number;
  };
}

type Emotion =
  | "neutral"
  | "happy"
  | "thinking"
  | "concerned"
  | "excited"
  | "listening"
  | "speaking";

interface CoreMemoryBlock {
  key: string; // e.g., "user_preferences", "current_projects"
  content: string;
  lastUpdated: Date;
  tokenCount: number;
}
```

> **Key insight:** Jane is a daemon, not an app. She starts at login, runs continuously, and persists state across reboots. The notch display is her face, not her body. Her body is the entire local machine.

---

## 3. Voice Input — Hearing Jane

Voice input is the most critical subsystem. If Jane cannot hear reliably, nothing else matters. There are five viable approaches on macOS in 2026, each with different tradeoffs.

### 3.1 Wispr Flow

[Wispr Flow](https://wisprflow.ai/) is a commercial macOS dictation tool that works system-wide — in any text field, in any app. It is the closest thing to "just works" voice input on macOS.

**How it works:**
- Runs as a macOS app with accessibility permissions
- Captures audio from the microphone, processes through cloud STT
- Inserts transcribed text into the active text field
- Adds AI-powered formatting — automatically punctuates, fixes grammar, expands shortcuts
- Supports voice shortcuts (custom triggers that insert saved snippets)
- Has native IDE extensions for Cursor, Windsurf, and Replit (enabling "vibe coding")

**Integration for Jane:**
Wispr Flow does not expose a public SDK or API. It is designed as an end-user dictation tool, not a developer platform. You cannot programmatically access the transcription stream, register custom wake words, or route audio to your own processing pipeline.

**Workaround:** You could use Wispr Flow as the dictation layer and have Jane monitor a designated text field or file for incoming transcriptions. This is fragile and not recommended for a production companion.

```typescript
// Wispr Flow workaround — monitor a file for dictated text
// NOT RECOMMENDED: fragile, no wake word support, no streaming
import { watch } from "fs";

const WISPR_BUFFER_FILE = "/tmp/jane-wispr-buffer.txt";

watch(WISPR_BUFFER_FILE, (eventType) => {
  if (eventType === "change") {
    const text = readFileSync(WISPR_BUFFER_FILE, "utf-8").trim();
    if (text.length > 0) {
      handleUserInput(text);
      writeFileSync(WISPR_BUFFER_FILE, ""); // Clear buffer
    }
  }
});
```

**Verdict:** Wispr Flow is excellent for personal dictation but unsuitable as Jane's hearing system. No API, no wake word, no streaming access.

### 3.2 whisper.cpp

[whisper.cpp](https://github.com/ggml-org/whisper.cpp) is the C/C++ port of OpenAI's Whisper speech recognition model. It runs entirely locally on Apple Silicon with Core ML acceleration.

**Performance on Apple Silicon (2025 benchmarks):**

| Model | M1 Pro | M2 Pro | M3 Pro | M4 Pro | Memory |
|-------|--------|--------|--------|--------|--------|
| tiny.en | 27x realtime | 35x | 42x | 50x | ~200MB |
| base.en | 15x realtime | 20x | 25x | 30x | ~500MB |
| small.en | 8x realtime | 12x | 15x | 18x | ~1GB |
| medium.en | 3x realtime | 5x | 7x | 9x | ~2GB |
| large-v3 | 1.5x realtime | 2.5x | 3.5x | 5x | ~3GB |

The medium model hits the sweet spot for accuracy versus performance. Real-time dictation works smoothly with minimal delay on any Apple Silicon Mac.

**Integration pattern:**

```typescript
import { execFile } from "child_process";
import { createReadStream } from "fs";

interface WhisperResult {
  text: string;
  segments: Array<{
    start: number;
    end: number;
    text: string;
    confidence: number;
  }>;
}

class WhisperSTT {
  private modelPath: string;
  private binaryPath: string;

  constructor(model: "tiny" | "base" | "small" | "medium" | "large" = "medium") {
    this.modelPath = `${process.env.HOME}/.jane/models/ggml-${model}.en.bin`;
    this.binaryPath = "/usr/local/bin/whisper-cpp";
  }

  async transcribeFile(audioPath: string): Promise<WhisperResult> {
    return new Promise((resolve, reject) => {
      execFile(
        this.binaryPath,
        [
          "--model", this.modelPath,
          "--file", audioPath,
          "--output-json",
          "--language", "en",
          "--threads", "4",
        ],
        { maxBuffer: 10 * 1024 * 1024 },
        (error, stdout) => {
          if (error) return reject(error);
          resolve(JSON.parse(stdout));
        }
      );
    });
  }

  // Stream mode: process audio chunks in near-real-time
  async transcribeStream(
    audioStream: NodeJS.ReadableStream,
    onSegment: (text: string) => void
  ): Promise<void> {
    const chunkDurationMs = 3000; // Process 3-second chunks
    let buffer = Buffer.alloc(0);
    const sampleRate = 16000;
    const bytesPerChunk = (sampleRate * 2 * chunkDurationMs) / 1000; // 16-bit PCM

    audioStream.on("data", (chunk: Buffer) => {
      buffer = Buffer.concat([buffer, chunk]);

      if (buffer.length >= bytesPerChunk) {
        const audioChunk = buffer.subarray(0, bytesPerChunk);
        buffer = buffer.subarray(bytesPerChunk);

        // Write chunk to temp file and transcribe
        const tempPath = `/tmp/jane-chunk-${Date.now()}.wav`;
        this.writeWav(tempPath, audioChunk, sampleRate);
        this.transcribeFile(tempPath).then((result) => {
          if (result.text.trim()) {
            onSegment(result.text.trim());
          }
        });
      }
    });
  }

  private writeWav(path: string, pcm: Buffer, sampleRate: number): void {
    // WAV header + PCM data
    const header = Buffer.alloc(44);
    header.write("RIFF", 0);
    header.writeUInt32LE(36 + pcm.length, 4);
    header.write("WAVE", 8);
    header.write("fmt ", 12);
    header.writeUInt32LE(16, 16);
    header.writeUInt16LE(1, 20); // PCM
    header.writeUInt16LE(1, 22); // Mono
    header.writeUInt32LE(sampleRate, 24);
    header.writeUInt32LE(sampleRate * 2, 28);
    header.writeUInt16LE(2, 30);
    header.writeUInt16LE(16, 32);
    header.write("data", 36);
    header.writeUInt32LE(pcm.length, 40);
    require("fs").writeFileSync(path, Buffer.concat([header, pcm]));
  }
}
```

**Verdict:** Excellent for Jane. Fully local, fast on Apple Silicon, no cloud dependency. Use the medium model for best accuracy-to-speed ratio. The only downside is slightly higher CPU usage than Apple's built-in speech recognition.

### 3.3 WhisperKit (Native Swift)

[WhisperKit](https://github.com/argmaxinc/WhisperKit) is a Swift-native implementation of Whisper optimized specifically for Apple Silicon. It uses Core ML and the Apple Neural Engine directly, which makes it more efficient than whisper.cpp for macOS/iOS apps.

**Key advantages over whisper.cpp:**
- Native Swift API — integrates directly into the HUD's Swift codebase
- Core ML optimized — uses ANE (Apple Neural Engine) for better power efficiency
- 0.45s mean latency for per-word transcription
- Ships as a Swift Package — `swift package add WhisperKit`

```swift
import WhisperKit

class JaneSTT {
    private var whisperKit: WhisperKit?

    func initialize() async throws {
        whisperKit = try await WhisperKit(
            model: "openai_whisper-large-v3",
            computeOptions: .init(
                audioEncoderCompute: .cpuAndNeuralEngine,
                textDecoderCompute: .cpuAndNeuralEngine
            )
        )
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard let kit = whisperKit else {
            throw JaneError.sttNotInitialized
        }

        let result = try await kit.transcribe(audioPath: audioURL.path)
        return result.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    // Real-time streaming transcription
    func startListening(onTranscript: @escaping (String) -> Void) async throws {
        guard let kit = whisperKit else {
            throw JaneError.sttNotInitialized
        }

        // WhisperKit supports streaming via audio buffer callbacks
        try await kit.transcribe(
            audioArray: [], // Populated from microphone buffer
            decodeOptions: DecodingOptions(
                language: "en",
                task: .transcribe,
                temperatureFallbackCount: 3,
                sampleLength: 224,
                usePrefillPrompt: true,
                skipSpecialTokens: true
            )
        )
    }
}
```

> **Key insight:** Since HUD is already a Swift/macOS app, WhisperKit is the natural choice. It integrates natively, uses the Neural Engine for power efficiency, and avoids the overhead of shelling out to a C++ binary. The 0.45s per-word latency is fast enough for real-time conversation.

### 3.4 Apple SpeechAnalyzer (WWDC 2025)

Apple introduced [SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/) at WWDC 2025 as the successor to SFSpeechRecognizer. It is available in iOS 26 and macOS (presumably macOS 26 as well).

**Three transcription modules:**

| Module | Purpose | Use Case |
|--------|---------|----------|
| `DictationTranscriber` | Natural punctuation-aware dictation | User dictating messages to Jane |
| `SpeechTranscriber` | Clean speech-to-text for commands | "Hey Jane, open the terminal" |
| `SpeechDetector` | Detect speech presence and timing | Wake word pre-filter (is someone talking?) |

**Advantages:**
- Zero download size — model runs in system memory, not your app's
- Completely on-device — no network required
- Power efficient — optimized by Apple for background use
- Free — no API costs

**Disadvantages:**
- Only available on macOS 26+ (ships late 2025 / early 2026)
- Accuracy trails Whisper large-v3 on complex speech
- No custom model training
- Limited language support compared to Whisper

```swift
import Speech

class JaneAppleSTT {
    private let transcriber = SpeechTranscriber()

    func startListening(onResult: @escaping (String) -> Void) async throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true)

        for try await result in transcriber.results {
            let transcript = result.bestTranscription.formattedString
            if !transcript.isEmpty {
                onResult(transcript)
            }
        }
    }
}
```

### 3.5 Wake Word Detection with Porcupine

None of the STT engines above solve the "always listening" problem efficiently. Running Whisper continuously would drain the battery in hours. The solution is a two-stage pipeline: a lightweight wake word detector runs continuously, and full STT only activates when the wake word is detected.

[Porcupine](https://picovoice.ai/platform/porcupine/) by Picovoice is the industry standard for wake word detection:

- **97%+ accuracy** with less than 1 false alarm per 10 hours
- **Custom wake words** — type "Hey Jane" and get a trained model in seconds
- Runs on macOS (x86_64 and arm64)
- Extremely low CPU usage — designed for always-on operation
- Supports English, French, German, Italian, Japanese, Korean, Portuguese, Spanish

```typescript
// Two-stage voice input pipeline: Porcupine → WhisperKit
interface VoicePipeline {
  stage1_wakeWord: {
    engine: "porcupine";
    keyword: "Hey Jane";
    sensitivity: 0.7; // 0-1, higher = more sensitive but more false positives
    alwaysRunning: true;
    cpuUsage: "<1%";
  };
  stage2_stt: {
    engine: "whisperkit";
    model: "medium.en";
    activatedBy: "stage1_wakeWord";
    timeout: 30_000; // Stop listening after 30s of silence
    cpuUsage: "5-15% when active";
  };
}
```

```swift
import Porcupine

class JaneWakeWord {
    private var porcupine: Porcupine?
    private var audioEngine: AVAudioEngine?
    private let onWakeWord: () -> Void

    init(onWakeWord: @escaping () -> Void) {
        self.onWakeWord = onWakeWord
    }

    func start() throws {
        // Custom wake word trained via Picovoice Console
        porcupine = try Porcupine(
            accessKey: ProcessInfo.processInfo.environment["PICOVOICE_KEY"] ?? "",
            keywordPath: Bundle.main.path(forResource: "Hey-Jane", ofType: "ppn")!,
            sensitivity: 0.7
        )

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            guard let self = self, let porcupine = self.porcupine else { return }

            let pcm = self.bufferToInt16(buffer)
            let keywordIndex = porcupine.process(pcm)

            if keywordIndex >= 0 {
                DispatchQueue.main.async {
                    self.onWakeWord()
                }
            }
        }

        audioEngine!.prepare()
        try audioEngine!.start()
    }

    private func bufferToInt16(_ buffer: AVAudioPCMBuffer) -> [Int16] {
        let floatData = buffer.floatChannelData![0]
        let frameCount = Int(buffer.frameLength)
        return (0..<frameCount).map { Int16(floatData[$0] * 32767) }
    }
}
```

### Voice Input Comparison

| Feature | Wispr Flow | whisper.cpp | WhisperKit | Apple SpeechAnalyzer | Porcupine |
|---------|-----------|-------------|------------|---------------------|-----------|
| **Purpose** | Dictation tool | General STT | Apple-native STT | System STT | Wake word only |
| **Local processing** | Partial (cloud STT) | Fully local | Fully local | Fully local | Fully local |
| **API/SDK** | None | C/C++ CLI | Swift Package | Swift API | Swift/Python SDK |
| **Wake word** | No | No | No | SpeechDetector (partial) | Yes (custom) |
| **Accuracy** | High (cloud) | High (medium+) | High | Medium-High | 97%+ (wake word) |
| **Latency** | 200-500ms | 100-300ms | 450ms/word | 200-400ms | <50ms |
| **Power usage** | Medium | Medium-High | Low (ANE) | Very Low | Negligible |
| **Cost** | $10/mo | Free | Free | Free | Free tier + $0.08/device/mo |
| **Best for Jane** | No (no API) | Fallback option | Primary STT | Future option | Wake word layer |

> **Key insight:** The recommended pipeline for Jane is **Porcupine (always-on wake word) → WhisperKit (on-demand STT)**. Porcupine uses negligible CPU to listen for "Hey Jane" 24/7. When triggered, WhisperKit activates for full transcription using the Neural Engine. Total idle power draw: under 1%. Active transcription: 5-10%.

---

## 4. Voice Output — Jane Speaks

Jane needs a voice. Not a robotic one — a voice with personality, warmth, and the ability to convey emotion. The options range from free and local to premium and cloud-based.

### 4.1 ElevenLabs

[ElevenLabs](https://elevenlabs.io/) is the gold standard for AI voice synthesis in 2026. Their voices are consistently ranked most natural-sounding, and they offer voice cloning from as little as 30 seconds of audio.

**Key specs:**
- Flash v2.5 latency: 75ms (first byte)
- 29 languages supported
- Voice cloning from 30 seconds of audio (Starter plan, $5/mo)
- Professional voice cloning with higher fidelity (Pro plan, $99/mo)
- Emotion control via SSML-like tags
- Streaming API — audio starts playing before the full response is generated

**Pricing (2026):**

| Plan | Characters/mo | Cost | Per 1M chars | Voice Cloning |
|------|---------------|------|-------------|---------------|
| Free | 10,000 | $0 | N/A | No |
| Starter | 30,000 | $5/mo | $167 | Instant (30s) |
| Creator | 100,000 | $22/mo | $220 | Instant |
| Pro | 500,000 | $99/mo | $198 | Professional |
| Scale | 2,000,000 | $330/mo | $165 | Professional |

**Jane's usage estimate:** A typical day might involve 50 spoken responses averaging 100 characters each = 5,000 characters/day = 150,000 characters/month. This fits the Creator plan ($22/mo).

```typescript
import { ElevenLabsClient } from "elevenlabs";

class JaneVoice {
  private client: ElevenLabsClient;
  private voiceId: string;

  constructor(apiKey: string, voiceId: string) {
    this.client = new ElevenLabsClient({ apiKey });
    this.voiceId = voiceId; // Jane's cloned voice ID
  }

  async speak(text: string, emotion: Emotion = "neutral"): Promise<ReadableStream> {
    const emotionSettings = this.emotionToSettings(emotion);

    const audio = await this.client.textToSpeech.convertAsStream(this.voiceId, {
      text,
      model_id: "eleven_flash_v2_5",
      voice_settings: {
        stability: emotionSettings.stability,
        similarity_boost: emotionSettings.similarity,
        style: emotionSettings.style,
        use_speaker_boost: true,
      },
      output_format: "mp3_44100_128",
    });

    return audio;
  }

  private emotionToSettings(emotion: Emotion) {
    const settings: Record<Emotion, { stability: number; similarity: number; style: number }> = {
      neutral:   { stability: 0.5, similarity: 0.75, style: 0.0 },
      happy:     { stability: 0.3, similarity: 0.75, style: 0.8 },
      thinking:  { stability: 0.7, similarity: 0.80, style: 0.2 },
      concerned: { stability: 0.6, similarity: 0.80, style: 0.5 },
      excited:   { stability: 0.2, similarity: 0.70, style: 1.0 },
      listening: { stability: 0.5, similarity: 0.75, style: 0.0 },
      speaking:  { stability: 0.5, similarity: 0.75, style: 0.3 },
    };
    return settings[emotion];
  }
}
```

### 4.2 OpenAI TTS

[OpenAI TTS](https://platform.openai.com/docs/guides/text-to-speech) offers simpler, cheaper voice synthesis. No voice cloning, but good quality at scale.

**Key specs:**
- 6 built-in voices: alloy, echo, fable, onyx, nova, shimmer
- TTS-1 (fast): $15/1M characters
- TTS-1-HD (quality): $30/1M characters
- TTS-1-mini: $0.60/1M characters
- Latency: ~200ms first byte
- Streaming supported

**At Jane's 150K chars/month:**
- TTS-1: $2.25/month
- TTS-1-HD: $4.50/month
- TTS-1-mini: $0.09/month

```typescript
import OpenAI from "openai";

class JaneOpenAIVoice {
  private client: OpenAI;
  private voice: "alloy" | "echo" | "fable" | "onyx" | "nova" | "shimmer";

  constructor(apiKey: string, voice: "nova" = "nova") {
    this.client = new OpenAI({ apiKey });
    this.voice = voice; // "nova" has a warm, feminine quality
  }

  async speak(text: string): Promise<Buffer> {
    const response = await this.client.audio.speech.create({
      model: "tts-1-hd",
      voice: this.voice,
      input: text,
      response_format: "mp3",
      speed: 1.0,
    });

    return Buffer.from(await response.arrayBuffer());
  }

  // Streaming for lower latency
  async speakStream(text: string): Promise<ReadableStream> {
    const response = await this.client.audio.speech.create({
      model: "tts-1",
      voice: this.voice,
      input: text,
      response_format: "mp3",
    });

    return response.body as unknown as ReadableStream;
  }
}
```

### 4.3 Kokoro-82M (Local, Open Source)

[Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) is the breakthrough local TTS model of 2025-2026. At just 82 million parameters, it produces speech quality comparable to ElevenLabs while running entirely on-device.

**Why Kokoro matters for Jane:**
- **Fully local** — no API calls, no latency, no cost per character
- **82M parameters** — runs on any Mac without GPU strain
- **54 voices** across 8 languages
- **Apache license** — free for commercial use
- **OpenAI-compatible API** via [kokoro-web](https://github.com/eduardolat/kokoro-web) — drop-in replacement
- Ranked just behind ElevenLabs in TTS Arena quality benchmarks

```typescript
// Kokoro via OpenAI-compatible local API (kokoro-web)
import OpenAI from "openai";

class JaneKokoroVoice {
  private client: OpenAI;

  constructor() {
    // kokoro-web runs locally and exposes OpenAI-compatible API
    this.client = new OpenAI({
      baseURL: "http://localhost:8880/v1",
      apiKey: "not-needed", // Local server, no auth
    });
  }

  async speak(text: string): Promise<Buffer> {
    const response = await this.client.audio.speech.create({
      model: "kokoro",
      voice: "af_heart", // Warm female voice
      input: text,
      response_format: "mp3",
      speed: 1.0,
    });

    return Buffer.from(await response.arrayBuffer());
  }
}
```

### 4.4 Apple AVSpeechSynthesizer (Built-in, Free)

macOS includes AVSpeechSynthesizer with dozens of high-quality voices. Since macOS 14, the "Premium" voices are surprisingly natural.

```swift
import AVFoundation

class JaneAppleVoice {
    private let synthesizer = AVSpeechSynthesizer()

    // List all available premium voices
    func listPremiumVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter {
            $0.quality == .premium && $0.language.starts(with: "en")
        }
    }

    func speak(_ text: String, voice: AVSpeechSynthesisVoice? = nil) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice ?? AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-US.Zoe")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8

        synthesizer.speak(utterance)
    }

    // Get word-level timing for lip sync
    func speakWithTimings(
        _ text: String,
        onWord: @escaping (String, TimeInterval) -> Void
    ) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-US.Zoe")

        // AVSpeechSynthesizerDelegate provides word boundaries
        // Use these to drive avatar lip sync
        synthesizer.speak(utterance)
    }
}
```

### 4.5 Piper (Local, Open Source)

[Piper](https://github.com/rhasspy/piper) is a fast, local neural TTS system optimized for efficiency. It uses ONNX models and runs on CPU.

**Compared to Kokoro:**
- Piper is older and more battle-tested (originally for Home Assistant)
- Kokoro sounds more natural (newer architecture)
- Piper has more voices and languages
- Both are fully local and free

Development has moved to [OHF-Voice/piper1-gpl](https://github.com/OHF-Voice/piper1-gpl) under the Open Home Foundation.

### Voice Output Comparison

| Feature | ElevenLabs | OpenAI TTS | Kokoro-82M | Piper | Apple TTS |
|---------|-----------|-----------|-----------|-------|-----------|
| **Quality** | Best | Very Good | Near-best | Good | Good (Premium) |
| **Latency (first byte)** | 75ms | 200ms | 50-100ms | 20-50ms | 10ms |
| **Local** | No | No | Yes | Yes | Yes |
| **Cost at 150K chars/mo** | $22/mo | $2.25-4.50/mo | $0 | $0 | $0 |
| **Voice cloning** | Yes (30s audio) | No | No | Limited | No |
| **Emotion control** | Yes | No | Limited | No | Pitch/rate only |
| **Lip sync data** | No (must derive) | No | No | No | Yes (word boundaries) |
| **Languages** | 29 | 6 | 8 | 40+ | 60+ |
| **Best for Jane** | Premium tier | Budget cloud | Default local | Fallback local | System fallback |

> **Key insight:** The recommended strategy is **Kokoro-82M as default (free, local, near-ElevenLabs quality) with ElevenLabs as premium upgrade (voice cloning, emotion control)**. This gives users a great experience out of the box with an upsell path. For lip sync, Apple's AVSpeechSynthesizer uniquely provides word-level timing callbacks.

### Voice Cloning: Creating Jane's Voice

For a consistent companion personality, Jane needs a consistent voice. ElevenLabs' Instant Voice Cloning can create a unique voice from 30 seconds of audio:

1. Record 30-60 seconds of the target voice reading diverse content
2. Upload to ElevenLabs Voice Lab
3. Get a voice ID that produces consistent output
4. Store the voice ID in Jane's config

For a fully local approach, [XTTS by Coqui](https://github.com/coqui-ai/TTS) supports voice cloning with local inference, though the project was archived in late 2023. Forks exist but quality varies.

---

## 5. Memory Systems — Jane Remembers

Memory is what separates Jane from every other AI assistant. Without memory, she is a stateless function: input goes in, output comes out, nothing persists. With memory, she knows your name, your projects, your preferences, your relationships, your schedule, your recurring frustrations, and the conversation you had three weeks ago about switching to a new framework.

### 5.1 The Three-Tier Memory Architecture

Inspired by [MemGPT/Letta](https://docs.letta.com/concepts/memgpt/), Jane uses a three-tier memory system that mirrors how human memory works:

```
┌─────────────────────────────────────────────────────┐
│ Tier 1: Core Memory (always in context)             │
│ ┌─────────────────────────────────────────────────┐ │
│ │ user_identity: "Gary Wu, software engineer..."  │ │
│ │ current_projects: "HUD, Atlas, Course Wire..."  │ │
│ │ preferences: "Prefers direct communication..."  │ │
│ │ relationships: "Sarah (partner), Dave (CTO)..." │ │
│ │ jane_persona: "Warm, direct, slightly witty..." │ │
│ └─────────────────────────────────────────────────┘ │
│ Size: 2,000-4,000 tokens. Updated by Jane herself. │
├─────────────────────────────────────────────────────┤
│ Tier 2: Recall Memory (searchable conversations)    │
│ ┌─────────────────────────────────────────────────┐ │
│ │ Timestamped conversation log                    │ │
│ │ Full-text search by date, keyword, topic        │ │
│ │ Last 30 days of conversations                   │ │
│ └─────────────────────────────────────────────────┘ │
│ Size: Unlimited. Stored in SQLite. Searched on demand. │
├─────────────────────────────────────────────────────┤
│ Tier 3: Archival Memory (semantic long-term store)  │
│ ┌─────────────────────────────────────────────────┐ │
│ │ Vectorized facts, insights, decisions           │ │
│ │ Semantic search (embeddings)                    │ │
│ │ Distilled from conversations over time          │ │
│ │ User preferences, technical decisions, etc.     │ │
│ └─────────────────────────────────────────────────┘ │
│ Size: Unlimited. SQLite + sqlite-vec for embeddings.│
└─────────────────────────────────────────────────────┘
```

**How the tiers interact:**

1. **Core Memory** is always injected into the LLM's system prompt. Jane sees it on every interaction. She can update it herself using tool calls (e.g., "update core memory: user's current project is HUD").

2. **Recall Memory** is searched when Jane needs to reference a past conversation. She has tools like `search_recall(query, date_range)` that return relevant conversation snippets.

3. **Archival Memory** stores distilled knowledge. After each conversation, a background process extracts key facts and stores them as embeddings. Jane can search archival memory semantically.

```typescript
interface MemorySystem {
  core: CoreMemory;
  recall: RecallMemory;
  archival: ArchivalMemory;
}

interface CoreMemory {
  blocks: Map<string, CoreMemoryBlock>;
  maxTokens: number; // 4096 default
  currentTokens: number;

  read(key: string): string;
  update(key: string, content: string): void;
  append(key: string, addition: string): void;
  replace(key: string, oldText: string, newText: string): void;
}

interface CoreMemoryBlock {
  key: string;
  content: string;
  maxTokens: number;
  lastUpdated: Date;
}

interface RecallMemory {
  search(query: string, options?: {
    startDate?: Date;
    endDate?: Date;
    limit?: number;
  }): ConversationSnippet[];

  getRecent(count: number): ConversationSnippet[];
  logMessage(role: "user" | "assistant", content: string, timestamp: Date): void;
}

interface ConversationSnippet {
  timestamp: Date;
  role: "user" | "assistant";
  content: string;
  relevanceScore?: number;
}

interface ArchivalMemory {
  insert(content: string, metadata?: Record<string, string>): string; // returns ID
  search(query: string, limit?: number): ArchivalEntry[];
  delete(id: string): void;
  count(): number;
}

interface ArchivalEntry {
  id: string;
  content: string;
  embedding: Float32Array;
  metadata: Record<string, string>;
  createdAt: Date;
  relevanceScore: number;
}
```

### 5.2 Implementation: SQLite + sqlite-vec

For a local-first companion, SQLite is the obvious storage backend. Combined with [sqlite-vec](https://github.com/asg017/sqlite-vec), it provides both relational storage and vector similarity search in a single file.

```typescript
import Database from "better-sqlite3";

class JaneMemoryStore {
  private db: Database.Database;

  constructor(dbPath: string) {
    this.db = new Database(dbPath);
    this.db.loadExtension("sqlite-vec"); // Vector similarity extension
    this.initialize();
  }

  private initialize() {
    this.db.exec(`
      -- Core memory blocks
      CREATE TABLE IF NOT EXISTS core_memory (
        key TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        max_tokens INTEGER DEFAULT 1024,
        updated_at TEXT DEFAULT (datetime('now'))
      );

      -- Recall memory (conversation log)
      CREATE TABLE IF NOT EXISTS recall_memory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
        content TEXT NOT NULL,
        timestamp TEXT DEFAULT (datetime('now')),
        conversation_id TEXT,
        token_count INTEGER
      );

      CREATE INDEX IF NOT EXISTS idx_recall_timestamp ON recall_memory(timestamp);
      CREATE INDEX IF NOT EXISTS idx_recall_conversation ON recall_memory(conversation_id);

      -- Archival memory with vector embeddings
      CREATE TABLE IF NOT EXISTS archival_memory (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        metadata TEXT DEFAULT '{}',
        created_at TEXT DEFAULT (datetime('now'))
      );

      -- Vector index for semantic search
      CREATE VIRTUAL TABLE IF NOT EXISTS archival_embeddings USING vec0(
        id TEXT PRIMARY KEY,
        embedding float[1536]  -- OpenAI text-embedding-3-small dimensions
      );

      -- Memory operations log (for debugging and transparency)
      CREATE TABLE IF NOT EXISTS memory_ops (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        target_tier TEXT NOT NULL,
        details TEXT,
        timestamp TEXT DEFAULT (datetime('now'))
      );
    `);

    // Initialize default core memory blocks
    this.initCoreMemory();
  }

  private initCoreMemory() {
    const defaults: Array<{ key: string; content: string; maxTokens: number }> = [
      {
        key: "user_identity",
        content: "Name: [unknown]\nRole: [unknown]\nLocation: [unknown]",
        maxTokens: 512,
      },
      {
        key: "user_preferences",
        content: "Communication style: [learning]\nTechnical level: [unknown]",
        maxTokens: 512,
      },
      {
        key: "current_context",
        content: "Active projects: [none yet]\nRecent topics: [none yet]",
        maxTokens: 1024,
      },
      {
        key: "jane_persona",
        content:
          "Jane is a warm, direct AI companion. She remembers conversations " +
          "and builds on them. She asks clarifying questions when unsure. " +
          "She is slightly witty but never sarcastic. She takes initiative " +
          "when she notices patterns or potential issues.",
        maxTokens: 512,
      },
      {
        key: "relationship_notes",
        content: "People mentioned: [none yet]",
        maxTokens: 1024,
      },
    ];

    const insert = this.db.prepare(
      "INSERT OR IGNORE INTO core_memory (key, content, max_tokens) VALUES (?, ?, ?)"
    );

    for (const block of defaults) {
      insert.run(block.key, block.content, block.maxTokens);
    }
  }

  // Core memory operations (called by Jane via tools)
  updateCoreMemory(key: string, content: string): void {
    this.db.prepare(
      "UPDATE core_memory SET content = ?, updated_at = datetime('now') WHERE key = ?"
    ).run(content, key);

    this.logOperation("update", "core", `Updated ${key}`);
  }

  getCoreMemory(): Map<string, string> {
    const rows = this.db.prepare("SELECT key, content FROM core_memory").all() as Array<{
      key: string;
      content: string;
    }>;
    return new Map(rows.map((r) => [r.key, r.content]));
  }

  // Recall memory operations
  logConversation(role: string, content: string, conversationId: string): void {
    this.db.prepare(
      "INSERT INTO recall_memory (role, content, conversation_id) VALUES (?, ?, ?)"
    ).run(role, content, conversationId);
  }

  searchRecall(query: string, limit: number = 10): ConversationSnippet[] {
    // Full-text search on conversation history
    return this.db.prepare(`
      SELECT role, content, timestamp
      FROM recall_memory
      WHERE content LIKE ?
      ORDER BY timestamp DESC
      LIMIT ?
    `).all(`%${query}%`, limit) as ConversationSnippet[];
  }

  // Archival memory operations
  async insertArchival(content: string, embedding: number[], metadata?: Record<string, string>): Promise<string> {
    const id = crypto.randomUUID();

    this.db.prepare(
      "INSERT INTO archival_memory (id, content, metadata) VALUES (?, ?, ?)"
    ).run(id, content, JSON.stringify(metadata || {}));

    this.db.prepare(
      "INSERT INTO archival_embeddings (id, embedding) VALUES (?, ?)"
    ).run(id, new Float32Array(embedding));

    this.logOperation("insert", "archival", content.substring(0, 100));
    return id;
  }

  searchArchival(queryEmbedding: number[], limit: number = 5): ArchivalEntry[] {
    return this.db.prepare(`
      SELECT
        a.id, a.content, a.metadata, a.created_at,
        vec_distance_cosine(e.embedding, ?) as distance
      FROM archival_embeddings e
      JOIN archival_memory a ON a.id = e.id
      ORDER BY distance ASC
      LIMIT ?
    `).all(new Float32Array(queryEmbedding), limit) as ArchivalEntry[];
  }

  private logOperation(operation: string, tier: string, details: string): void {
    this.db.prepare(
      "INSERT INTO memory_ops (operation, target_tier, details) VALUES (?, ?, ?)"
    ).run(operation, tier, details);
  }
}
```

### 5.3 Memory Tools for the LLM

Jane's reasoning model (Claude, GPT-4o, etc.) interacts with memory through tool calls. This is the MemGPT pattern: the LLM itself decides what to remember, what to forget, and what to search for.

```typescript
const JANE_MEMORY_TOOLS = [
  {
    name: "core_memory_update",
    description: "Update a core memory block. Core memory is ALWAYS visible to you. Use this to store important facts about the user, their preferences, current projects, and relationship details.",
    input_schema: {
      type: "object",
      properties: {
        key: {
          type: "string",
          enum: ["user_identity", "user_preferences", "current_context", "jane_persona", "relationship_notes"],
          description: "Which core memory block to update",
        },
        content: {
          type: "string",
          description: "The new content for this memory block. Include ALL existing important info plus the update.",
        },
      },
      required: ["key", "content"],
    },
  },
  {
    name: "core_memory_append",
    description: "Append to a core memory block without replacing existing content.",
    input_schema: {
      type: "object",
      properties: {
        key: { type: "string" },
        addition: { type: "string", description: "Text to append to the block" },
      },
      required: ["key", "addition"],
    },
  },
  {
    name: "recall_search",
    description: "Search past conversations. Use when the user references something you discussed before, or when you need to verify a past statement.",
    input_schema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Search query" },
        days_back: { type: "number", description: "How many days back to search. Default 30." },
        limit: { type: "number", description: "Max results. Default 10." },
      },
      required: ["query"],
    },
  },
  {
    name: "archival_insert",
    description: "Store a fact or insight in long-term archival memory. Use for important information that doesn't fit in core memory but should be retrievable later.",
    input_schema: {
      type: "object",
      properties: {
        content: { type: "string", description: "The fact or insight to store" },
        tags: {
          type: "array",
          items: { type: "string" },
          description: "Tags for categorization",
        },
      },
      required: ["content"],
    },
  },
  {
    name: "archival_search",
    description: "Semantically search long-term archival memory. Use when you need to find stored facts or insights that aren't in core memory.",
    input_schema: {
      type: "object",
      properties: {
        query: { type: "string" },
        limit: { type: "number" },
      },
      required: ["query"],
    },
  },
];
```

### 5.4 The Memory Extraction Pipeline

After each conversation, a background process extracts key facts and stores them in archival memory. This runs asynchronously so it does not slow down the conversation.

```typescript
class MemoryExtractionPipeline {
  private memoryStore: JaneMemoryStore;
  private embeddingModel: EmbeddingModel;
  private extractionModel: LLMClient; // Use Haiku for cost efficiency

  async processConversation(messages: Message[]): Promise<void> {
    // Step 1: Extract salient facts using a cheap model
    const extraction = await this.extractionModel.complete({
      model: "claude-3-5-haiku-20241022",
      system: `You are a memory extraction system. Given a conversation, extract facts worth remembering long-term.

Rules:
- Extract ONLY facts that would be useful in future conversations
- Include: preferences, decisions, important dates, project details, relationship info
- Exclude: greetings, small talk, transient questions
- Format each fact as a single clear sentence
- If a fact UPDATES a previously known fact, note the update`,
      messages: [
        {
          role: "user",
          content: `Extract memorable facts from this conversation:\n\n${messages
            .map((m) => `${m.role}: ${m.content}`)
            .join("\n")}`,
        },
      ],
    });

    const facts = this.parseFacts(extraction.content);

    // Step 2: For each fact, check if it updates an existing memory
    for (const fact of facts) {
      const embedding = await this.embeddingModel.embed(fact);
      const existing = this.memoryStore.searchArchival(embedding, 3);

      if (existing.length > 0 && existing[0].relevanceScore > 0.9) {
        // Very similar memory exists — this might be an update
        await this.handleMemoryUpdate(fact, existing[0], embedding);
      } else {
        // New fact — insert into archival memory
        await this.memoryStore.insertArchival(fact, embedding, {
          source: "conversation_extraction",
          extractedAt: new Date().toISOString(),
        });
      }
    }

    // Step 3: Check if core memory needs updating
    await this.maybeUpdateCoreMemory(facts);
  }

  private async handleMemoryUpdate(
    newFact: string,
    existingEntry: ArchivalEntry,
    embedding: number[]
  ): Promise<void> {
    // Use LLM to determine: ADD, UPDATE, DELETE, or NOOP
    const decision = await this.extractionModel.complete({
      model: "claude-3-5-haiku-20241022",
      messages: [
        {
          role: "user",
          content: `Existing memory: "${existingEntry.content}"
New information: "${newFact}"

Should we: ADD (keep both), UPDATE (replace old with new), DELETE (old is wrong), or NOOP (no change needed)?
Respond with just the action and optionally the merged text.`,
        },
      ],
    });

    const action = this.parseAction(decision.content);

    switch (action.type) {
      case "UPDATE":
        this.memoryStore.deleteArchival(existingEntry.id);
        await this.memoryStore.insertArchival(action.mergedText || newFact, embedding);
        break;
      case "ADD":
        await this.memoryStore.insertArchival(newFact, embedding);
        break;
      case "DELETE":
        this.memoryStore.deleteArchival(existingEntry.id);
        break;
      case "NOOP":
        break;
    }
  }

  private async maybeUpdateCoreMemory(facts: string[]): Promise<void> {
    // Check if any extracted facts should be promoted to core memory
    const coreMemory = this.memoryStore.getCoreMemory();
    const coreString = Array.from(coreMemory.entries())
      .map(([k, v]) => `[${k}]: ${v}`)
      .join("\n\n");

    const decision = await this.extractionModel.complete({
      model: "claude-3-5-haiku-20241022",
      messages: [
        {
          role: "user",
          content: `Current core memory:\n${coreString}\n\nNew facts:\n${facts.join("\n")}\n\nDo any of these facts warrant updating core memory? Core memory is always visible and should contain the most important, frequently-referenced information. Respond with specific update instructions or "no updates needed".`,
        },
      ],
    });

    // Parse and apply core memory updates
    // ...
  }

  private parseFacts(content: string): string[] {
    return content
      .split("\n")
      .map((line) => line.replace(/^[-*\d.]+\s*/, "").trim())
      .filter((line) => line.length > 10);
  }

  private parseAction(content: string): { type: string; mergedText?: string } {
    const upper = content.toUpperCase();
    if (upper.startsWith("UPDATE")) return { type: "UPDATE", mergedText: content.replace(/^UPDATE:?\s*/i, "") };
    if (upper.startsWith("ADD")) return { type: "ADD" };
    if (upper.startsWith("DELETE")) return { type: "DELETE" };
    return { type: "NOOP" };
  }
}
```

### 5.5 Comparison: Memory Frameworks

| Feature | Letta (MemGPT) | Mem0 | Zep | Jane Custom |
|---------|----------------|------|-----|-------------|
| **Architecture** | Agent-managed memory | Extraction + hybrid store | Temporal knowledge graph | Three-tier (core/recall/archival) |
| **Core memory** | Yes (editable blocks) | No (implicit) | No | Yes |
| **Archival memory** | Yes (vector DB) | Yes (vector + graph + KV) | Yes (graph) | Yes (sqlite-vec) |
| **Recall (conversations)** | Yes (searchable log) | Session-scoped | Yes (timestamped) | Yes (SQLite FTS) |
| **Self-managing** | Yes (LLM decides) | Automatic extraction | Automatic | Hybrid (LLM + pipeline) |
| **Conflict resolution** | LLM-driven | ADD/UPDATE/DELETE/NOOP | Temporal invalidation | LLM-driven (Mem0-style) |
| **Deployment** | Self-hosted or cloud | SaaS or self-hosted | SaaS (beta) | Fully local |
| **Storage** | PostgreSQL + pgvector | Vector + Graph + KV | PostgreSQL | SQLite + sqlite-vec |
| **Benchmark (LOCOMO)** | Not published | 26% over baseline | 18.5% accuracy gain | Not benchmarked |
| **Token reduction** | Significant | 90% vs full context | 90% latency reduction | Proportional to core memory size |
| **Best for** | Persistent agents with identity | Memory-as-infrastructure | Enterprise with temporal needs | Local-first companions |

> **Key insight:** For Jane, a custom three-tier system using SQLite + sqlite-vec is the right choice. It runs fully locally (privacy), requires no external services, and gives Jane the MemGPT-style self-managing memory through tool calls. Letta is excellent but adds deployment complexity. Mem0 is excellent but assumes cloud or requires configuring multiple storage backends. Jane needs a single `.db` file.

### 5.6 What Should Jane Remember?

Not all information is worth remembering. Here is a prioritization framework:

| Priority | Category | Example | Storage Tier |
|----------|----------|---------|--------------|
| **Critical** | Identity | User's name, role, location | Core |
| **Critical** | Relationships | People mentioned, their roles | Core |
| **High** | Preferences | Communication style, tech preferences | Core |
| **High** | Active projects | What user is working on now | Core |
| **Medium** | Decisions | "Decided to use Rust for the backend" | Archival |
| **Medium** | Important dates | Deadlines, meetings, milestones | Archival |
| **Medium** | Technical context | Stack details, API keys (encrypted) | Archival |
| **Low** | Conversation content | Full message history | Recall |
| **Low** | Transient questions | "What's the weather?" | Not stored |
| **Forget** | Sensitive data | Passwords, tokens (unless encrypted) | Never stored |

### 5.7 Memory Decay and Forgetting

Jane should not remember everything forever. Memory decay prevents the archival store from growing unboundedly and keeps retrieved results relevant.

```typescript
class MemoryDecayPolicy {
  // Run weekly as a background task
  async applyDecay(store: JaneMemoryStore): Promise<void> {
    const now = new Date();

    // 1. Archive old recall memory (compress conversations older than 30 days)
    const oldConversations = store.getRecallOlderThan(30);
    for (const batch of chunk(oldConversations, 50)) {
      const summary = await this.summarizeConversations(batch);
      await store.insertArchival(summary, await this.embed(summary), {
        source: "recall_compression",
        originalRange: `${batch[0].timestamp} to ${batch[batch.length - 1].timestamp}`,
      });
    }
    store.deleteRecallOlderThan(30);

    // 2. Decay archival entries never accessed (relevance fading)
    const staleEntries = store.getArchivalNeverAccessed(90); // 90 days
    for (const entry of staleEntries) {
      store.markForReview(entry.id); // Flag but don't delete
    }

    // 3. Merge duplicate archival entries
    await this.deduplicateArchival(store);
  }

  private async deduplicateArchival(store: JaneMemoryStore): Promise<void> {
    const allEntries = store.getAllArchival();
    const clusters = await this.clusterBySimlarity(allEntries, 0.92);

    for (const cluster of clusters) {
      if (cluster.length > 1) {
        // Merge cluster into a single entry
        const merged = await this.mergeEntries(cluster);
        const embedding = await this.embed(merged);
        await store.insertArchival(merged, embedding, { source: "deduplication" });
        for (const entry of cluster) {
          store.deleteArchival(entry.id);
        }
      }
    }
  }
}
```

---

## 6. Avatar and Face — Jane Has a Presence

Jane lives in a 50x60pt notch display. This is tiny — roughly 100x120 pixels on a Retina display. Photorealistic avatars are out of the question. What works at this scale?

### 6.1 What Fits in 50x60 Points?

At 2x Retina scale, the notch display is approximately 100x120 physical pixels. This rules out:
- Photorealistic faces (Soul Machines, Synthesia, HeyGen) — need 200x200 minimum
- 3D MetaHuman-style rendering — too heavy for a tiny display
- Complex facial features — cannot resolve fine detail at this resolution

What works:
- **Pixel art faces** (8-16px character sprites scaled up)
- **Minimalist vector faces** (eyes + mouth, like a Tamagotchi)
- **Abstract representations** (waveform, orb, geometric patterns)
- **SceneKit/SpriteKit simple 3D** (basic head with blend shapes, heavily stylized)
- **LED matrix style** (the HUD's existing LCD engine)

### 6.2 The Tamagotchi Approach — Pixel Art State Machine

The most charming and technically appropriate approach for a notch display is a pixel-art avatar with discrete emotional states. Think Tamagotchi meets AI.

```swift
import SpriteKit

enum JaneFaceState: String, CaseIterable {
    case idle          // Neutral, blinking occasionally
    case listening     // Ears perked, eyes wide
    case thinking      // Eyes looking up-left, dot-dot-dot
    case speaking      // Mouth animating
    case happy         // Smile, slightly squinted eyes
    case concerned     // Furrowed brow
    case excited       // Wide eyes, big smile
    case sleeping      // Closed eyes, z-z-z
    case researching   // Magnifying glass animation
    case error         // X_X face
}

class JaneFaceView: SKView {
    private var faceScene: SKScene!
    private var eyesNode: SKSpriteNode!
    private var mouthNode: SKSpriteNode!
    private var accessoryNode: SKSpriteNode!
    private var currentState: JaneFaceState = .idle

    func setup() {
        faceScene = SKScene(size: CGSize(width: 50, height: 60))
        faceScene.backgroundColor = .clear
        faceScene.scaleMode = .aspectFit

        // Eyes — 2 sprites, each 8x8pt
        let leftEye = SKSpriteNode(imageNamed: "eye_open")
        leftEye.position = CGPoint(x: 17, y: 38)
        leftEye.size = CGSize(width: 8, height: 8)

        let rightEye = SKSpriteNode(imageNamed: "eye_open")
        rightEye.position = CGPoint(x: 33, y: 38)
        rightEye.size = CGSize(width: 8, height: 8)

        // Mouth — 1 sprite, 16x8pt
        mouthNode = SKSpriteNode(imageNamed: "mouth_neutral")
        mouthNode.position = CGPoint(x: 25, y: 22)
        mouthNode.size = CGSize(width: 16, height: 8)

        faceScene.addChild(leftEye)
        faceScene.addChild(rightEye)
        faceScene.addChild(mouthNode)

        presentScene(faceScene)

        // Start idle blink animation
        startBlinkLoop(leftEye: leftEye, rightEye: rightEye)
    }

    func transition(to state: JaneFaceState) {
        guard state != currentState else { return }
        currentState = state

        // Each state maps to a set of sprite textures and animations
        switch state {
        case .idle:
            setEyes("eye_open")
            setMouth("mouth_neutral")
            removeAccessory()

        case .listening:
            setEyes("eye_wide")
            setMouth("mouth_slight_open")
            removeAccessory()

        case .thinking:
            setEyes("eye_look_up")
            setMouth("mouth_neutral")
            showAccessory("dots_thinking", animated: true)

        case .speaking:
            setEyes("eye_open")
            startMouthAnimation() // Cycles through mouth shapes

        case .happy:
            setEyes("eye_happy")
            setMouth("mouth_smile")
            removeAccessory()

        case .concerned:
            setEyes("eye_concerned")
            setMouth("mouth_frown")
            removeAccessory()

        case .excited:
            setEyes("eye_wide")
            setMouth("mouth_big_smile")
            showAccessory("sparkles", animated: true)

        case .sleeping:
            setEyes("eye_closed")
            setMouth("mouth_neutral")
            showAccessory("zzz", animated: true)

        case .researching:
            setEyes("eye_focused")
            setMouth("mouth_neutral")
            showAccessory("magnifier", animated: true)

        case .error:
            setEyes("eye_x")
            setMouth("mouth_flat")
            removeAccessory()
        }
    }

    private func startBlinkLoop(leftEye: SKSpriteNode, rightEye: SKSpriteNode) {
        let blink = SKAction.sequence([
            SKAction.wait(forDuration: 3.0, withRange: 2.0), // Random 2-5s between blinks
            SKAction.setTexture(SKTexture(imageNamed: "eye_closed")),
            SKAction.wait(forDuration: 0.15),
            SKAction.setTexture(SKTexture(imageNamed: "eye_open")),
        ])
        leftEye.run(SKAction.repeatForever(blink))
        rightEye.run(SKAction.repeatForever(blink))
    }

    private func startMouthAnimation() {
        // Cycle through mouth shapes to simulate speaking
        let shapes = ["mouth_open_a", "mouth_open_o", "mouth_closed", "mouth_open_e"]
        let frames = shapes.map { SKTexture(imageNamed: $0) }
        let animation = SKAction.animate(with: frames, timePerFrame: 0.12)
        mouthNode.run(SKAction.repeatForever(animation))
    }

    private func setEyes(_ textureName: String) { /* ... */ }
    private func setMouth(_ textureName: String) { /* ... */ }
    private func showAccessory(_ name: String, animated: Bool) { /* ... */ }
    private func removeAccessory() { /* ... */ }
}
```

### 6.3 The LCD Face — Using HUD's Existing Engine

HUD already has an LCD dot-matrix display engine. Jane's face could be rendered as LCD pixels, giving her a retro-futuristic aesthetic that fits the existing design language.

```swift
// Jane's face rendered via HUD's LCD engine
// Eyes: 2 blocks of 5x7 LCD characters
// Mouth: 1 block of 5x7 LCD characters
// Emotion conveyed through different LCD patterns

struct LCDFacePatterns {
    // Each pattern is a 5x7 grid of booleans
    static let eyeOpen: [[Bool]] = [
        [false, true,  true,  true,  false],
        [true,  false, false, false, true ],
        [true,  false, true,  false, true ],
        [true,  false, true,  false, true ],
        [true,  false, false, false, true ],
        [false, true,  true,  true,  false],
        [false, false, false, false, false],
    ]

    static let eyeClosed: [[Bool]] = [
        [false, false, false, false, false],
        [false, false, false, false, false],
        [false, true,  true,  true,  false],
        [true,  false, false, false, true ],
        [false, false, false, false, false],
        [false, false, false, false, false],
        [false, false, false, false, false],
    ]

    static let eyeHappy: [[Bool]] = [
        [false, false, false, false, false],
        [true,  false, false, false, true ],
        [false, true,  false, true,  false],
        [false, false, true,  false, false],
        [false, false, false, false, false],
        [false, false, false, false, false],
        [false, false, false, false, false],
    ]

    static let mouthSmile: [[Bool]] = [
        [false, false, false, false, false],
        [true,  false, false, false, true ],
        [true,  false, false, false, true ],
        [false, true,  false, true,  false],
        [false, false, true,  false, false],
        [false, false, false, false, false],
        [false, false, false, false, false],
    ]

    static let mouthOpen: [[Bool]] = [
        [false, false, false, false, false],
        [false, true,  true,  true,  false],
        [true,  false, false, false, true ],
        [true,  false, false, false, true ],
        [false, true,  true,  true,  false],
        [false, false, false, false, false],
        [false, false, false, false, false],
    ]
}
```

### 6.4 Avatar Technology Comparison

| Technology | Resolution Needed | Latency | Local? | Cost | Fits 50x60pt? |
|------------|------------------|---------|--------|------|---------------|
| Soul Machines | 400x400+ | 100ms | No | Enterprise | No |
| HeyGen LiveAvatar | 300x300+ | 200ms | No | $0.10/30s | No |
| Synthesia Video Agent | 300x300+ | 300ms | No | $29+/mo | No |
| Ready Player Me 3D | 200x200+ | 20ms | Yes (WebGL) | Free | Marginal |
| SceneKit Blend Shapes | 50x50+ | 5ms | Yes | Free | Yes |
| SpriteKit Pixel Art | 16x16+ | 1ms | Yes | Free | **Perfect** |
| LCD Matrix (HUD engine) | 10x14+ | 1ms | Yes | Free | **Perfect** |
| Canvas 2D Vector | 30x30+ | 2ms | Yes | Free | Yes |

> **Key insight:** For a 50x60pt notch display, photorealistic avatars are wasted. The two best approaches are **SpriteKit pixel art** (charming, expressive, Tamagotchi-like) and **LCD matrix** (retro, fits HUD's existing aesthetic). Both render in under 1ms and use negligible GPU. The constraint is the asset: the face lives or dies on the quality of the pixel art sprites, not the rendering engine.

### 6.5 Lip Sync at Tiny Scale

Full viseme-based lip sync (mapping phonemes to mouth shapes) is overkill at 50x60pt. At this scale, you can distinguish maybe 4 mouth states:

1. **Closed** — resting, between words
2. **Slightly open** — soft consonants (m, n, l)
3. **Open** — vowels (a, o)
4. **Wide** — emphasis, exclamation

Rather than phoneme analysis, derive mouth state from audio amplitude:

```swift
// Simple amplitude-based mouth animation
class JaneLipSync {
    private var audioLevel: Float = 0.0
    private var timer: Timer?

    func startMonitoring(audioEngine: AVAudioEngine) {
        let inputNode = audioEngine.outputNode // Monitor output (Jane's speech)
        inputNode.installTap(onBus: 0, bufferSize: 256, format: nil) { [weak self] buffer, _ in
            let level = self?.rmsLevel(buffer: buffer) ?? 0
            DispatchQueue.main.async {
                self?.audioLevel = level
            }
        }

        // Update face at 15fps (plenty for a tiny display)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            self?.updateMouth()
        }
    }

    private func updateMouth() {
        let state: MouthState
        switch audioLevel {
        case 0..<0.01:    state = .closed
        case 0.01..<0.05: state = .slightlyOpen
        case 0.05..<0.15: state = .open
        default:          state = .wide
        }
        NotificationCenter.default.post(name: .janeMouthStateChanged, object: state)
    }

    private func rmsLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<count { sum += data[i] * data[i] }
        return sqrt(sum / Float(count))
    }
}
```

---

## 7. Always-On Daemon Architecture

Jane runs as a macOS daemon — starting at login, running continuously, and surviving app crashes. This section covers how to build a companion that is always present without destroying battery life.

### 7.1 The Daemon Lifecycle

```
System Boot → Login → launchd starts Jane daemon
                         │
                         ▼
                    Initialize:
                    - Load memory from SQLite
                    - Start Porcupine (wake word)
                    - Start HUD display
                    - Connect to localhost:7070
                    - Begin ambient monitoring
                         │
                         ▼
               ┌── Idle Loop (99% of time) ──┐
               │  - Porcupine listening (<1%) │
               │  - Display showing status     │
               │  - Periodic memory decay      │
               │  - Background research check  │
               └──────────────┬───────────────┘
                              │ Wake word detected
                              ▼
               ┌── Active Conversation ──────┐
               │  - WhisperKit transcribing   │
               │  - LLM reasoning             │
               │  - TTS speaking              │
               │  - Avatar animating          │
               │  - Memory updating           │
               └──────────────┬──────────────┘
                              │ 30s silence timeout
                              ▼
                         Return to Idle
```

### 7.2 Power Management

The key to an always-on companion is aggressive power state management. Jane should use <1% CPU when idle and only ramp up during active interaction.

```typescript
interface PowerProfile {
  idle: {
    wakeWordDetection: true;    // Porcupine: <1% CPU
    sttActive: false;           // Off until wake word
    llmActive: false;           // No inference
    ttsActive: false;           // Silent
    displayRefresh: "1fps";     // Minimal updates (clock, status)
    memoryOperations: false;    // No background processing
    networkRequests: false;     // No API calls
    estimatedCPU: "<1%";
    estimatedPower: "negligible";
  };
  listening: {
    wakeWordDetection: false;   // Suspend (already activated)
    sttActive: true;            // WhisperKit on Neural Engine
    llmActive: false;           // Not yet
    ttsActive: false;           // Not yet
    displayRefresh: "15fps";    // Animate listening face
    estimatedCPU: "5-10%";
    estimatedPower: "low";
  };
  thinking: {
    sttActive: false;           // Finished transcribing
    llmActive: true;            // API call in flight
    displayRefresh: "15fps";    // Thinking animation
    estimatedCPU: "2-5%";       // Mostly waiting for network
    estimatedPower: "low-medium";
  };
  speaking: {
    ttsActive: true;            // Audio playback
    displayRefresh: "15fps";    // Lip sync animation
    estimatedCPU: "3-8%";
    estimatedPower: "low";
  };
  research: {
    llmActive: true;            // Extended API calls
    displayRefresh: "1fps";     // Show progress
    estimatedCPU: "2-5%";
    estimatedPower: "medium";   // Sustained over minutes
  };
}
```

### 7.3 Tiered Model Routing

Not every interaction needs Claude Opus. Most need Haiku. The routing strategy dramatically affects both cost and response time.

```typescript
type ModelTier = "fast" | "balanced" | "deep";

interface ModelRouter {
  route(input: UserInput, context: JaneState): ModelTier;
}

class AdaptiveModelRouter implements ModelRouter {
  route(input: UserInput, context: JaneState): ModelTier {
    const text = input.transcript;

    // Fast tier (Haiku / GPT-4o-mini): ~80% of interactions
    // Simple questions, quick commands, status checks
    if (this.isSimpleQuestion(text)) return "fast";
    if (this.isCommand(text)) return "fast";
    if (text.length < 50) return "fast";

    // Deep tier (Opus / o3): ~2% of interactions
    // Explicit research requests, complex analysis, code review
    if (this.isResearchRequest(text)) return "deep";
    if (this.isComplexAnalysis(text)) return "deep";
    if (text.includes("deep research") || text.includes("analyze")) return "deep";

    // Balanced tier (Sonnet / GPT-4o): ~18% of interactions
    // Everything else: conversation, moderate reasoning, creative work
    return "balanced";
  }

  private isSimpleQuestion(text: string): boolean {
    const patterns = [
      /^(what|when|where|who|how)\s+(is|are|was|were|do|does|did)\b/i,
      /^(tell me|remind me|what's)\b/i,
      /\b(time|weather|date|status|next meeting)\b/i,
    ];
    return patterns.some((p) => p.test(text)) && text.length < 100;
  }

  private isCommand(text: string): boolean {
    const commands = [
      /^(open|close|run|start|stop|show|hide|check)\b/i,
      /^(set|update|change|switch|toggle)\b/i,
    ];
    return commands.some((p) => p.test(text));
  }

  private isResearchRequest(text: string): boolean {
    return /\b(research|investigate|deep dive|comprehensive|thorough)\b/i.test(text);
  }

  private isComplexAnalysis(text: string): boolean {
    return /\b(compare|analyze|evaluate|review|design|architect)\b/i.test(text);
  }
}
```

**Cost impact of tiered routing:**

| Tier | Model | Input/1M | Output/1M | % of interactions | Monthly cost (50 interactions/day) |
|------|-------|---------|----------|-------------------|-----------------------------------|
| Fast | Claude 3.5 Haiku | $0.80 | $4.00 | 80% | ~$1.50 |
| Balanced | Claude 3.5 Sonnet | $3.00 | $15.00 | 18% | ~$3.00 |
| Deep | Claude Opus 4 | $15.00 | $75.00 | 2% | ~$1.50 |
| **Total** | | | | | **~$6.00/month** |

Without tiered routing (all Sonnet): ~$16/month. With routing: ~$6/month — a 62% cost reduction.

### 7.4 Context Management Across Days

A companion that runs for weeks needs to maintain conversational coherence without stuffing the entire history into context.

```typescript
class ContextManager {
  private memoryStore: JaneMemoryStore;
  private maxContextTokens: number = 8192; // Reserve for conversation

  buildSystemPrompt(): string {
    const coreMemory = this.memoryStore.getCoreMemory();

    return `You are Jane, a persistent AI companion. You live in the user's MacBook notch display. You have been running for ${this.daysSinceFirstBoot()} days.

## Your Core Memory (always current)
${Array.from(coreMemory.entries())
  .map(([key, value]) => `### ${key}\n${value}`)
  .join("\n\n")}

## Your Capabilities
You can: search past conversations (recall_search), update your memory (core_memory_update), store long-term facts (archival_insert), search stored facts (archival_search), run local commands (local_run), read files (file_read), open apps (app_open), search the web (web_search), and trigger deep research (deep_research).

## Guidelines
- You remember conversations from past sessions. Use recall_search to find them.
- Update core memory when you learn important new facts about the user.
- Be proactive: if you notice patterns, mention them.
- Be concise in voice responses (user is listening, not reading).
- For long answers, offer to display details in the HUD text panel.
- Never pretend to remember something — search first, then respond.
- If you haven't talked to the user in a while, acknowledge it naturally.`;
  }

  buildConversationContext(recentMessages: Message[]): Message[] {
    // Include last N messages that fit within token budget
    const budgetTokens = this.maxContextTokens;
    const result: Message[] = [];
    let usedTokens = 0;

    for (let i = recentMessages.length - 1; i >= 0; i--) {
      const msg = recentMessages[i];
      const tokens = this.estimateTokens(msg.content);

      if (usedTokens + tokens > budgetTokens) break;

      result.unshift(msg);
      usedTokens += tokens;
    }

    return result;
  }

  // When starting a new session after idle period
  async buildResumeContext(): Promise<string> {
    const lastConversation = this.memoryStore.getRecentRecall(5);
    const timeSinceLastChat = this.timeSinceLastInteraction();

    if (timeSinceLastChat < 60 * 60 * 1000) {
      // Less than 1 hour — continue conversation naturally
      return "";
    }

    if (timeSinceLastChat < 24 * 60 * 60 * 1000) {
      // Less than 1 day — brief recap
      return `[System: It has been ${Math.round(timeSinceLastChat / 3600000)} hours since your last conversation. Last topic: "${lastConversation[0]?.content.substring(0, 100)}..."]`;
    }

    // More than 1 day — search for anything notable since last chat
    const recentMemories = await this.memoryStore.searchArchival("recent events", 3);
    return `[System: It has been ${Math.round(timeSinceLastChat / 86400000)} days since your last conversation. Relevant memories from this period: ${recentMemories.map((m) => m.content).join("; ")}]`;
  }

  private estimateTokens(text: string): number {
    return Math.ceil(text.length / 4); // Rough estimate
  }

  private daysSinceFirstBoot(): number {
    // Read from persistent config
    return 0;
  }

  private timeSinceLastInteraction(): number {
    return Date.now() - (this.memoryStore.getLastInteractionTimestamp()?.getTime() ?? Date.now());
  }
}
```

### 7.5 launchd Configuration

Jane should start at login and restart if it crashes.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.jane.daemon</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Jane.app/Contents/MacOS/Jane</string>
        <string>--daemon</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>ThrottleInterval</key>
    <integer>10</integer>

    <key>StandardOutPath</key>
    <string>/tmp/jane.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/jane.error.log</string>

    <key>ProcessType</key>
    <string>Interactive</string>

    <key>LowPriorityBackgroundIO</key>
    <true/>
</dict>
</plist>
```

---

## 8. Local Superpowers — What Cloud Cannot Do

This is Jane's unfair advantage over every cloud-based AI assistant. She runs on your machine. She can see your files, control your apps, read your clipboard, and execute commands. Cloud assistants can only talk. Jane can act.

### 8.1 The Capability Matrix

| Capability | Cloud AI | Siri | Jane | How |
|-----------|----------|------|------|-----|
| Read files | No | Limited | Yes | File system access |
| Write files | No | No | Yes | File system access |
| Open/control apps | No | Limited | Yes | AppleScript/JXA |
| Read screen content | No | No | Yes | Accessibility API |
| Click UI elements | No | No | Yes | Accessibility API |
| Run terminal commands | No | No | Yes | Process spawning |
| Access clipboard | No | No | Yes | NSPasteboard |
| Read calendar | No | Yes | Yes | EventKit |
| Send messages | No | Yes | Yes | AppleScript + Messages.app |
| Control music | No | Yes | Yes | MediaPlayer framework |
| Monitor Docker | No | No | Yes | Docker CLI/API |
| Check Git status | No | No | Yes | Git CLI |
| Monitor builds | No | No | Yes | File watchers + CLI |
| Access Keychain | No | No | Possible | Security framework |
| GPU compute | No | No | Yes | Metal/Core ML |
| Network scanning | No | No | Yes | Network framework |

### 8.2 AppleScript/JXA Integration

AppleScript and JavaScript for Automation (JXA) are Jane's primary interface to other applications. The [macos-automator-mcp](https://github.com/steipete/macos-automator-mcp) project demonstrates this pattern.

```typescript
import { execSync } from "child_process";

class JaneLocalRunner {
  // Execute AppleScript
  runAppleScript(script: string): string {
    return execSync(`osascript -e '${script.replace(/'/g, "'\\''")}'`, {
      encoding: "utf-8",
      timeout: 10000,
    }).trim();
  }

  // Execute JXA (JavaScript for Automation)
  runJXA(script: string): string {
    return execSync(`osascript -l JavaScript -e '${script.replace(/'/g, "'\\''")}'`, {
      encoding: "utf-8",
      timeout: 10000,
    }).trim();
  }

  // High-level capabilities built on AppleScript/JXA

  openApp(appName: string): void {
    this.runAppleScript(`tell application "${appName}" to activate`);
  }

  getFrontmostApp(): string {
    return this.runAppleScript(
      'tell application "System Events" to get name of first application process whose frontmost is true'
    );
  }

  getSelectedText(): string {
    return this.runJXA(`
      const se = Application("System Events");
      se.keystroke("c", { using: "command down" });
      delay(0.1);
      return Application("System Events").theClipboard();
    `);
  }

  openFile(path: string): void {
    execSync(`open "${path}"`);
  }

  getCalendarEvents(daysAhead: number = 1): string {
    return this.runJXA(`
      const cal = Application("Calendar");
      const now = new Date();
      const end = new Date(now.getTime() + ${daysAhead} * 86400000);
      const events = [];
      cal.calendars().forEach(c => {
        c.events.whose({
          _greaterThan: [{ startDate: now }],
          _lessThan: [{ startDate: end }]
        })().forEach(e => {
          events.push({
            title: e.summary(),
            start: e.startDate().toISOString(),
            end: e.endDate().toISOString(),
            location: e.location() || ""
          });
        });
      });
      return JSON.stringify(events);
    `);
  }

  getDockerContainers(): string {
    try {
      return execSync("docker ps --format json", { encoding: "utf-8" });
    } catch {
      return "Docker not running";
    }
  }

  getGitStatus(repoPath: string): string {
    try {
      return execSync(`cd "${repoPath}" && git status --short`, { encoding: "utf-8" });
    } catch {
      return "Not a git repository";
    }
  }

  readFile(path: string, maxLines: number = 100): string {
    try {
      return execSync(`head -n ${maxLines} "${path}"`, { encoding: "utf-8" });
    } catch {
      return `Cannot read file: ${path}`;
    }
  }

  searchFiles(directory: string, query: string): string {
    try {
      return execSync(`grep -rl "${query}" "${directory}" --include="*.{ts,js,swift,py,md}" | head -20`, {
        encoding: "utf-8",
      });
    } catch {
      return "No matches found";
    }
  }

  getSystemInfo(): object {
    return {
      cpu: execSync("sysctl -n machdep.cpu.brand_string", { encoding: "utf-8" }).trim(),
      memory: execSync("sysctl -n hw.memsize", { encoding: "utf-8" }).trim(),
      disk: execSync("df -h / | tail -1", { encoding: "utf-8" }).trim(),
      uptime: execSync("uptime", { encoding: "utf-8" }).trim(),
      battery: execSync("pmset -g batt | grep -Eo '\\d+%'", { encoding: "utf-8" }).trim(),
    };
  }
}
```

### 8.3 The MCP Server Pattern

Jane's local capabilities are best exposed as an [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) server. This means any MCP-compatible client (Claude Desktop, Cursor, etc.) can also use Jane's capabilities.

```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new Server(
  { name: "jane-local", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler("tools/list", async () => ({
  tools: [
    {
      name: "file_read",
      description: "Read a file from the local filesystem",
      inputSchema: {
        type: "object",
        properties: {
          path: { type: "string", description: "Absolute file path" },
          maxLines: { type: "number", description: "Maximum lines to read" },
        },
        required: ["path"],
      },
    },
    {
      name: "file_search",
      description: "Search for files containing a query string",
      inputSchema: {
        type: "object",
        properties: {
          directory: { type: "string" },
          query: { type: "string" },
        },
        required: ["directory", "query"],
      },
    },
    {
      name: "app_open",
      description: "Open a macOS application",
      inputSchema: {
        type: "object",
        properties: {
          name: { type: "string", description: "Application name" },
        },
        required: ["name"],
      },
    },
    {
      name: "calendar_events",
      description: "Get upcoming calendar events",
      inputSchema: {
        type: "object",
        properties: {
          daysAhead: { type: "number", description: "Days to look ahead" },
        },
      },
    },
    {
      name: "shell_command",
      description: "Execute a shell command (requires approval for destructive commands)",
      inputSchema: {
        type: "object",
        properties: {
          command: { type: "string" },
          workingDirectory: { type: "string" },
          timeout: { type: "number", description: "Timeout in milliseconds" },
        },
        required: ["command"],
      },
    },
    {
      name: "system_info",
      description: "Get system information (CPU, memory, disk, battery)",
      inputSchema: { type: "object", properties: {} },
    },
  ],
}));

server.setRequestHandler("tools/call", async (request) => {
  const { name, arguments: args } = request.params;
  const runner = new JaneLocalRunner();

  switch (name) {
    case "file_read":
      return { content: [{ type: "text", text: runner.readFile(args.path, args.maxLines) }] };
    case "file_search":
      return { content: [{ type: "text", text: runner.searchFiles(args.directory, args.query) }] };
    case "app_open":
      runner.openApp(args.name);
      return { content: [{ type: "text", text: `Opened ${args.name}` }] };
    case "calendar_events":
      return { content: [{ type: "text", text: runner.getCalendarEvents(args.daysAhead || 1) }] };
    case "shell_command":
      return { content: [{ type: "text", text: runner.runShellCommand(args.command, args.workingDirectory) }] };
    case "system_info":
      return { content: [{ type: "text", text: JSON.stringify(runner.getSystemInfo(), null, 2) }] };
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

### 8.4 Security Model

Local superpowers require a security model. Jane should not be able to `rm -rf /` without explicit user consent.

```typescript
type ApprovalLevel = "always" | "destructive-only" | "never";

interface SecurityPolicy {
  fileSystem: {
    read: ApprovalLevel;        // Default: "never" (auto-approve reads)
    write: ApprovalLevel;       // Default: "destructive-only"
    delete: ApprovalLevel;      // Default: "always" (always ask)
    allowedPaths: string[];     // Whitelist of readable paths
    blockedPaths: string[];     // Blacklist (e.g., ~/.ssh, ~/Library/Keychains)
  };
  apps: {
    open: ApprovalLevel;        // Default: "never"
    control: ApprovalLevel;     // Default: "destructive-only"
    allowedApps: string[];      // Apps Jane can control
  };
  shell: {
    execute: ApprovalLevel;     // Default: "always" for unknown commands
    safeCommands: string[];     // Auto-approved: git status, docker ps, etc.
    blockedCommands: string[];  // Never allowed: rm -rf, sudo, etc.
  };
  network: {
    outbound: ApprovalLevel;    // Default: "never" (API calls are fine)
    listen: ApprovalLevel;      // Default: "always"
  };
}

const DEFAULT_SECURITY_POLICY: SecurityPolicy = {
  fileSystem: {
    read: "never",
    write: "destructive-only",
    delete: "always",
    allowedPaths: [
      process.env.HOME + "/Work",
      process.env.HOME + "/Documents",
      process.env.HOME + "/Desktop",
      "/tmp",
    ],
    blockedPaths: [
      process.env.HOME + "/.ssh",
      process.env.HOME + "/Library/Keychains",
      process.env.HOME + "/.gnupg",
      process.env.HOME + "/.env",
    ],
  },
  apps: {
    open: "never",
    control: "destructive-only",
    allowedApps: [
      "Calendar", "Reminders", "Notes", "Safari", "Finder",
      "Terminal", "Visual Studio Code", "Slack", "Messages",
    ],
  },
  shell: {
    execute: "always",
    safeCommands: [
      "git status", "git log", "git diff", "git branch",
      "docker ps", "docker logs",
      "ls", "pwd", "whoami", "date", "uptime",
      "brew list", "npm list", "pnpm list",
    ],
    blockedCommands: [
      "rm -rf", "sudo", "chmod 777", "mkfs",
      "curl | sh", "wget | sh",
      "> /dev/sda", "dd if=",
    ],
  },
  network: {
    outbound: "never",
    listen: "always",
  },
};
```

### 8.5 How Existing Tools Handle Local Access

| Tool | Local Access | Permission Model | Scope |
|------|-------------|-----------------|-------|
| **Claude Code** | Full file system + shell | Per-command approval, `.claude/` config | Active coding session |
| **Cursor** | Full file system + shell | Workspace-scoped, MCP servers | Active coding session |
| **Siri** | Contacts, Calendar, HomeKit | Per-app permission prompts | System-wide |
| **Shortcuts** | Broad app integration | Per-shortcut approval | User-triggered |
| **Screenpipe** | Screen recording + audio | One-time permission | Always-on daemon |
| **Jane (proposed)** | File, app, shell, screen | Tiered policy (safe/ask/block) | Always-on daemon |

---

## 9. Deep Research as an Ambient Feature

Deep research — the multi-minute, multi-source investigation that Perplexity and OpenAI offer — is a natural fit for an ambient companion. You ask Jane a question, she works on it in the background for 2-5 minutes, and alerts you when the results are ready.

### 9.1 How Deep Research Works

| Platform | Model | Time | Sources | Output |
|----------|-------|------|---------|--------|
| [Perplexity Deep Research](https://research.perplexity.ai/) | Multi-model ensemble (Opus 4.6 core, Gemini sub-agents) | 2-4 min | Dozens of web pages | Comprehensive report with citations |
| [OpenAI Deep Research](https://chatgpt.com/) | o3 reasoning model | 5-30 min | Web + internal tools | Synthesized analysis |
| [Google Gemini Deep Research](https://gemini.google.com/) | Gemini 2.0 | 3-10 min | Google Search | Structured report |

The common pattern:
1. **Plan** — decompose the question into sub-queries
2. **Search** — execute parallel web searches for each sub-query
3. **Read** — fetch and extract relevant content from top results
4. **Synthesize** — combine findings into a coherent report
5. **Cite** — attribute every claim to a source

### 9.2 Jane's Deep Research Pipeline

```typescript
interface ResearchTask {
  id: string;
  query: string;
  status: "planning" | "searching" | "reading" | "synthesizing" | "complete" | "failed";
  startedAt: Date;
  completedAt?: Date;
  progress: number; // 0-100
  result?: ResearchResult;
}

interface ResearchResult {
  summary: string;       // 2-3 sentence executive summary
  fullReport: string;    // Detailed findings (markdown)
  sources: Array<{
    url: string;
    title: string;
    relevance: string;
  }>;
  confidence: "high" | "medium" | "low";
}

class JaneDeepResearch {
  private activeTasks: Map<string, ResearchTask> = new Map();
  private hudServer: HUDClient; // Interface to notch display

  async startResearch(query: string): Promise<string> {
    const task: ResearchTask = {
      id: crypto.randomUUID(),
      query,
      status: "planning",
      startedAt: new Date(),
      progress: 0,
    };

    this.activeTasks.set(task.id, task);

    // Show research indicator in notch
    this.hudServer.updateFace("researching");
    this.hudServer.showStatus(`Researching: ${query.substring(0, 30)}...`);

    // Run research in background
    this.executeResearch(task).catch((err) => {
      task.status = "failed";
      this.hudServer.showNotification({
        title: "Research failed",
        body: err.message,
        level: "active",
      });
    });

    return task.id;
  }

  private async executeResearch(task: ResearchTask): Promise<void> {
    // Step 1: Plan (use Sonnet for planning)
    task.status = "planning";
    task.progress = 10;
    this.updateHUDProgress(task);

    const plan = await this.planResearch(task.query);

    // Step 2: Search (parallel web searches)
    task.status = "searching";
    task.progress = 30;
    this.updateHUDProgress(task);

    const searchResults = await Promise.all(
      plan.subQueries.map((q) => this.webSearch(q))
    );

    // Step 3: Read (fetch and extract from top results)
    task.status = "reading";
    task.progress = 60;
    this.updateHUDProgress(task);

    const pageContents = await Promise.all(
      searchResults.flat().slice(0, 10).map((r) => this.fetchAndExtract(r.url, task.query))
    );

    // Step 4: Synthesize (use Opus for deep synthesis)
    task.status = "synthesizing";
    task.progress = 85;
    this.updateHUDProgress(task);

    const report = await this.synthesize(task.query, pageContents, plan);

    // Step 5: Complete
    task.status = "complete";
    task.progress = 100;
    task.completedAt = new Date();
    task.result = report;

    // Alert user via notch display
    this.hudServer.updateFace("excited");
    this.hudServer.showNotification({
      title: "Research complete",
      body: report.summary,
      level: "time-sensitive",
      actions: [
        { label: "Read full report", action: "open_research", data: task.id },
        { label: "Summarize aloud", action: "speak_summary", data: task.id },
      ],
    });
  }

  private updateHUDProgress(task: ResearchTask): void {
    this.hudServer.showProgress(task.progress, `${task.status}: ${task.query.substring(0, 20)}...`);
  }

  private async planResearch(query: string): Promise<{ subQueries: string[] }> {
    // Use Sonnet to decompose the question
    const response = await this.llm.complete({
      model: "claude-sonnet-4-20250514",
      messages: [
        {
          role: "user",
          content: `Decompose this research question into 3-5 specific web search queries that together would comprehensively answer it:\n\nQuestion: ${query}\n\nRespond as JSON: { "subQueries": ["query1", "query2", ...] }`,
        },
      ],
    });
    return JSON.parse(response.content);
  }

  private async synthesize(
    query: string,
    sources: PageContent[],
    plan: { subQueries: string[] }
  ): Promise<ResearchResult> {
    // Use Opus for synthesis (this is the 2% "deep" tier use case)
    const response = await this.llm.complete({
      model: "claude-opus-4-20250514",
      messages: [
        {
          role: "user",
          content: `You are conducting deep research. Synthesize these sources into a comprehensive report.

Original question: ${query}

Sources:
${sources.map((s, i) => `[${i + 1}] ${s.url}\n${s.extractedContent}`).join("\n\n---\n\n")}

Produce:
1. A 2-3 sentence executive summary
2. A detailed report (use markdown, cite sources by number)
3. A confidence assessment (high/medium/low) based on source quality and agreement`,
        },
      ],
    });

    return this.parseResearchResponse(response.content, sources);
  }
}
```

### 9.3 Surfacing Research Through the Notch

The notch display cannot show a full research report. Instead, Jane uses progressive disclosure:

1. **While researching:** Show a progress bar and status text in the notch LCD. Face shows "researching" state.
2. **When complete:** Show a notification with the executive summary. Face shows "excited" state.
3. **On request:** Speak the summary aloud. Offer to open the full report in a panel or browser.
4. **Follow-up:** "Jane, tell me more about the third section" — she reads from the cached report.

```
┌──────────────────────────────────────────┐
│  🔍  Researching: AI companion memory...  │
│  ████████████░░░░░  68% — Reading sources  │
└──────────────────────────────────────────┘
         ↓ (3 minutes later)
┌──────────────────────────────────────────┐
│  ✓  Research complete                     │
│  "Three main approaches exist for..."     │
│  [Read Report]  [Speak Summary]           │
└──────────────────────────────────────────┘
```

---

## 10. Competitive Landscape — AI Companion Products

Understanding what exists (and what failed) is essential before building Jane. The market spans mobile apps, hardware pendants, desktop tools, and cloud services.

### 10.1 The Players

#### Replika

| Attribute | Details |
|-----------|---------|
| **What** | Mobile AI companion app (iOS, Android) |
| **Founded** | 2017 |
| **Users** | 10M+ downloads, 2.5M MAU at peak |
| **Pricing** | Free + Pro ($19.99/mo or $69.99/yr) + Ultra tier |
| **Memory** | Long-term fact storage, "Memory" tab for manual editing, "Diary" entries |
| **Voice** | Voice messages and video calls (Pro tier) |
| **Avatar** | 3D customizable avatar |
| **Revenue** | Estimated $40-60M/yr |
| **Controversies** | [5M euro GDPR fine in Italy](https://companionguide.ai/companions/replika); romantic content restrictions; pivot to "wellness companion" |

**What Replika gets right:** Emotional connection. Users genuinely feel attached. The 3D avatar creates presence. Memory tab gives users control over what the AI remembers.

**What Replika gets wrong:** No local capabilities. No productivity features. Memory is shallow (stores facts, misses nuance). The wellness pivot alienated the core user base.

#### Character.AI

| Attribute | Details |
|-----------|---------|
| **What** | Role-playing AI chat platform |
| **Founded** | 2022 |
| **Users** | Massive (peak 3.5M DAU) |
| **Pricing** | Free + c.ai+ ($9.99/mo) |
| **Memory** | "Chat memories" (persona details, up to 2,250 characters), no long-term cross-session memory |
| **Voice** | Character voices (TTS) |
| **Revenue** | Estimated $15-20M/yr |
| **Note** | Google licensed technology for $2.7B in 2024 |

**What Character.AI gets right:** Persona diversity (millions of characters). Engaged community. Low price point drives adoption.

**What Character.AI gets wrong:** Memory is essentially a static persona prompt, not dynamic learning. No local integration. Characters are entertainment, not useful.

#### Pi (Inflection AI)

| Attribute | Details |
|-----------|---------|
| **What** | Conversational AI companion |
| **Founded** | 2022 (Mustafa Suleyman, DeepMind co-founder) |
| **Users** | 1M+ DAU at peak |
| **Pricing** | Free |
| **Memory** | Up to 100 conversational turns; remembers preferences across sessions when logged in |
| **Voice** | Excellent voice mode — one of the best in the category |
| **Note** | Microsoft acquired most of Inflection AI in March 2024 for ~$650M |

**What Pi gets right:** Voice quality is exceptional — natural, warm, patient. The conversational style feels more human than any competitor. Memory persistence across sessions (when logged in) creates genuine continuity.

**What Pi gets wrong:** No local capabilities. No visual presence. Memory is limited to conversational context (no structured fact extraction). Acquired by Microsoft, future uncertain.

#### Friend Pendant

| Attribute | Details |
|-----------|---------|
| **What** | $99 always-listening AI pendant |
| **Founded** | 2024 (Avi Schiffmann) |
| **How it works** | Connects to phone via Bluetooth, sends audio clips to Claude 3.5 Sonnet for analysis, texts you responses throughout the day |
| **Funding** | $2.5M from Solana/Perplexity founders |
| **Status** | Shipping (limited) |

**What Friend gets right:** The always-listening ambient concept. No screen, no buttons — just context capture. Uses Claude (smart) instead of a custom small model (dumb).

**What Friend gets wrong:** Social awkwardness of wearing a recording device. Battery life constraints. Dependent on phone + cloud. No local capabilities. Responses are text-only (no voice output).

#### Rewind AI / Limitless

| Attribute | Details |
|-----------|---------|
| **What** | Desktop "total recall" — records everything you see and hear |
| **Founded** | 2022 |
| **Pivot** | Rebranded to Limitless in 2024, launched $99 pendant |
| **Acquired** | Meta acquired Limitless in December 2025 for ~$150-200M |
| **Status** | Rewind desktop app discontinued December 19, 2025. Pendant support "for at least another year." |
| **Lesson** | The technology worked but the business model did not. Total recall is powerful but creepy. Meta acquired the team, not the product. |

#### Screenpipe

| Attribute | Details |
|-----------|---------|
| **What** | Open source Rewind alternative — records screen and audio, AI-searchable |
| **Founded** | 2024 |
| **Stars** | Growing fast (open source, MIT license) |
| **Pricing** | $400 one-time (lifetime) or $600 (lifetime + 1 year pro) |
| **Features** | MCP server (works with Claude Desktop), 50+ automation "pipes", local AI via Ollama |
| **Funding** | $2.8M (July 2025) |
| **CPU usage** | 5-10% typical |

**What Screenpipe gets right:** Open source. Local-first. MCP integration. The "pipe" automation system is clever. One-time pricing (no subscription fatigue).

**What Screenpipe gets wrong:** No voice interaction. No avatar/presence. No companion personality. It is a tool, not a companion.

### 10.2 Hardware Failures: Rabbit R1 and Humane AI Pin

These are cautionary tales for anyone building AI companions.

#### Humane AI Pin ($700 + $24/mo)
- Launched November 2023
- **Failed catastrophically**: slow processing, unreliable hardware, overheating
- HP acquired remains for $116M in February 2025
- Device "bricked" February 28, 2025 — all units became paperweights
- **Lesson:** Do not ask people to carry a new device. Do not charge $24/month for something unreliable.

#### Rabbit R1 ($199)
- Launched May 2024
- Sold 100,000 pre-orders
- **95% abandonment rate** — only 5,000 active users after 5 months
- Founder Jesse Lyu admitted launching too early
- **Lesson:** A standalone AI device must be more reliable than the phone in your pocket. Neither was.

### 10.3 The Key Takeaway

Every successful AI companion runs on an existing device (phone or computer). Every dedicated AI hardware device has failed. The correct approach is:

> **The best AI companion is software that lives on a device you already own and love.**

Jane runs on your MacBook. She does not require you to buy new hardware, charge a new device, or explain to strangers why you are wearing a microphone. She lives in the notch — invisible until you need her.

### 10.4 Competitive Positioning Map

```
                    HIGH CAPABILITY (local access, actions)
                              │
              Screenpipe       │        Jane
              (tools,          │        (tools + voice + memory
               no voice)       │         + presence + personality)
                              │
    ──────────────────────────┼──────────────────────────────
    NO PERSONALITY            │            STRONG PERSONALITY
    (tool-first)              │            (companion-first)
                              │
              Claude Code      │        Replika
              Cursor           │        Character.AI
              (deep but        │        Pi
               session-only)   │        (personality but no tools)
                              │
                    LOW CAPABILITY (chat only)
```

Jane occupies the upper-right quadrant: high capability AND strong personality. No existing product lives there.

---

## 11. Anti-Patterns

| Don't | Do Instead | Why |
|-------|-----------|-----|
| Run STT continuously on full Whisper model | Use Porcupine wake word, then activate STT | Continuous Whisper drains battery in 2-3 hours |
| Send all interactions to Opus/GPT-4 | Route 80% to Haiku, 18% to Sonnet, 2% to Opus | Costs 3x more and adds latency for simple questions |
| Store all conversation text in core memory | Use three-tier architecture: core (key facts), recall (conversations), archival (distilled knowledge) | Core memory has a token budget; overflow makes responses worse |
| Use photorealistic avatar in 50x60pt display | Use pixel art, LCD matrix, or stylized vector art | Photorealistic faces look terrible at low resolution |
| Let Jane execute any shell command without review | Implement tiered approval: safe (auto), destructive (ask), blocked (never) | One `rm -rf ~` and trust is permanently destroyed |
| Build a standalone hardware device | Run as software on the user's existing MacBook | Every dedicated AI device has failed (Rabbit R1, Humane AI Pin) |
| Require cloud for all features | Default to local (Whisper, Kokoro, SQLite), cloud as optional upgrade | Users value privacy; local-first means Jane works offline |
| Store passwords and tokens in memory | Never store credentials in memory; use Keychain references only | One memory dump and all credentials leak |
| Speak long responses verbatim | Summarize for voice, offer "show details" for text display | Nobody wants to listen to a 3-minute monologue |
| Forget to handle "I don't remember" | Search memory first, admit uncertainty if not found | Fake memories destroy trust faster than no memory |
| Ship without a memory viewer/editor | Build a "Jane's Memory" panel where users can see and edit what she knows | Transparency builds trust; opacity breeds suspicion |
| Transcribe and store all ambient audio | Only process audio after wake word; discard ambient data | Always-recording is a privacy and legal liability |
| Run deep research synchronously | Run research in background, alert when complete | 3-5 minutes of silence during a voice interaction is unacceptable |
| Use one voice for all contexts | Adjust voice parameters (speed, pitch, style) based on context | Technical explanations sound wrong with excited intonation |
| Skip the idle state | Put Jane to sleep when idle (face shows sleeping, minimal CPU) | A companion that stares at you 24/7 is unsettling |

---

## 12. Privacy and Ethics

An always-listening AI companion with file system access and persistent memory is a privacy minefield. Getting this wrong is not just a product failure — it is a potential legal liability.

### 12.1 The Privacy Hierarchy

| Level | What It Means | Jane's Default |
|-------|---------------|---------------|
| **Level 0: Cloud-only** | Audio sent to cloud, processed remotely, stored on servers | No |
| **Level 1: Cloud processing, local storage** | Audio sent to cloud for STT, but transcripts stored locally | Optional (ElevenLabs TTS) |
| **Level 2: Local processing, local storage** | All processing on-device, all data on-device | **Default** |
| **Level 3: Ephemeral** | Nothing stored, everything discarded after use | Available (disable memory) |

Jane defaults to Level 2. All voice processing (Porcupine + WhisperKit) runs locally. Memory is stored in a local SQLite database. The only cloud calls are to the LLM API (Anthropic, OpenAI) for reasoning and optionally to ElevenLabs for premium TTS.

### 12.2 What Data Flows Where

```
                        LOCAL ONLY                    CLOUD (optional)
┌──────────────────────────────────┐    ┌──────────────────────────────┐
│ Wake word audio → Porcupine      │    │ Transcript → LLM API         │
│ Speech audio → WhisperKit        │    │ (Anthropic/OpenAI)           │
│ Transcript → Memory (SQLite)     │    │                              │
│ Files read → Local only          │    │ Text → ElevenLabs TTS        │
│ App automation → Local only      │    │ (if premium voice enabled)   │
│ Screen content → Local only      │    │                              │
│ Memory database → ~/.jane/       │    │ Deep research → Web APIs     │
└──────────────────────────────────┘    └──────────────────────────────┘

Audio is NEVER sent to the cloud.
Transcripts are sent to the LLM API (necessary for reasoning).
File contents may be included in LLM context when relevant.
```

### 12.3 GDPR and Privacy Compliance

The EU's GDPR and the incoming [EU AI Act](https://www.parloa.com/blog/AI-privacy-2026/) (fully applicable August 2, 2026) impose specific requirements on AI systems that process personal data.

**Key GDPR principles for Jane:**

| Principle | How Jane Complies |
|-----------|-------------------|
| **Data minimization** | Only processes audio after wake word. Discards raw audio immediately after transcription. |
| **Purpose limitation** | Memory stores only what is needed for companion functionality. No advertising, no profiling. |
| **Storage limitation** | Memory decay policy removes stale data. User can set retention period. |
| **Right to erasure** | "Jane, forget everything about X" — triggers deletion from all memory tiers. |
| **Right to access** | "Jane, what do you remember about me?" — reads core memory aloud. Memory viewer UI available. |
| **Transparency** | Memory operations log shows every read/write/delete. User can audit. |
| **Consent** | First-run wizard explains what Jane stores, what goes to cloud, and asks for explicit consent. |

### 12.4 The "Always-Listening" Problem

The biggest ethical concern is the microphone. Even though Jane only processes audio after a wake word, the microphone is technically active at all times (Porcupine needs it).

**Mitigations:**

1. **Hardware indicator:** macOS shows an orange dot in the menu bar when the microphone is active. This is always visible.
2. **Quick mute:** A single keystroke or notch tap mutes Jane's microphone. The face shows "sleeping" state with a mute icon.
3. **Scheduled quiet hours:** Jane automatically stops listening during configured hours (e.g., 10 PM to 7 AM).
4. **No ambient transcription:** Jane does NOT transcribe ambient conversations. She only transcribes speech directed at her (after wake word).
5. **Audio is ephemeral:** Raw audio is never written to disk. It is processed in memory and immediately discarded.

```swift
class JanePrivacyManager {
    var isMuted: Bool = false {
        didSet {
            if isMuted {
                audioEngine?.stop()
                updateFace(.sleeping)
                showMuteIndicator()
            } else {
                try? audioEngine?.start()
                updateFace(.idle)
                hideMuteIndicator()
            }
        }
    }

    // Scheduled quiet hours
    func checkQuietHours() {
        let now = Calendar.current.dateComponents([.hour], from: Date())
        let hour = now.hour ?? 0

        if hour >= quietHoursStart || hour < quietHoursEnd {
            if !isMuted {
                isMuted = true
                log("Entering quiet hours")
            }
        } else {
            if isMuted && !manuallyMuted {
                isMuted = false
                log("Exiting quiet hours")
            }
        }
    }

    // Right to erasure
    func forgetEverything() {
        memoryStore.deleteAllCoreMemory()
        memoryStore.deleteAllRecallMemory()
        memoryStore.deleteAllArchivalMemory()
        memoryStore.deleteAllOperationLogs()
        log("Complete memory erasure performed at user request")
    }

    func forgetAbout(topic: String) async {
        // Search all memory tiers for the topic and delete matches
        let archivalMatches = memoryStore.searchArchival(topic, limit: 100)
        for match in archivalMatches {
            memoryStore.deleteArchival(match.id)
        }

        let recallMatches = memoryStore.searchRecall(topic, limit: 1000)
        for match in recallMatches {
            memoryStore.deleteRecall(match.id)
        }

        // Update core memory to remove references
        let coreMemory = memoryStore.getCoreMemory()
        for (key, value) in coreMemory {
            if value.lowercased().contains(topic.lowercased()) {
                let cleaned = await removeTopic(from: value, topic: topic)
                memoryStore.updateCoreMemory(key, cleaned)
            }
        }
    }
}
```

### 12.5 Multi-Person Consent

If Jane can hear conversations, she might overhear other people. This requires consideration:

- **Default behavior:** Jane only responds to the wake word from the primary user. She does not process or store overheard conversations.
- **Meeting mode:** When the user says "Jane, join this meeting," she enters a mode where she transcribes (with a visible indicator) and can be asked to summarize later. All participants should be notified.
- **Guest mode:** "Jane, go to sleep" — disables all listening.

---

## 13. Monetization

### 13.1 Market Context

The AI companion market reached approximately $120M in app revenue in 2025, with projections of $49.52B (broader definition) by 2026. The mental health and productivity subsegments are growing fastest.

**What people pay today:**

| Product | Price | What They Get |
|---------|-------|---------------|
| Replika Pro | $19.99/mo | Unlimited voice, 3D avatar, deeper personality |
| Character.AI+ | $9.99/mo | Priority access, faster responses |
| Notion AI | $10/mo | AI writing in workspace |
| Raycast Pro | $8/mo | AI commands, clipboard history |
| Setapp | $10/mo | Bundle of 250+ Mac apps |
| GitHub Copilot | $19/mo | AI code completion |
| Claude Pro | $20/mo | Extended usage, Opus access |

**Key observation:** Desktop productivity tools command $8-20/month. AI companions command $10-20/month. Jane straddles both categories.

### 13.2 Pricing Strategy

```
┌─────────────────────────────────────────────────────────┐
│                    JANE — FREE TIER                      │
│                                                          │
│  ✓ Local voice (WhisperKit STT + Kokoro TTS)            │
│  ✓ Basic memory (core + recall, 7-day retention)        │
│  ✓ Pixel art avatar                                      │
│  ✓ 10 LLM interactions/day (Haiku)                      │
│  ✓ File reading, basic app control                       │
│  ✗ No deep research                                      │
│  ✗ No premium voice                                      │
│  ✗ No long-term archival memory                          │
│                                                          │
│                    Cost to serve: ~$0.15/month            │
├─────────────────────────────────────────────────────────┤
│                    JANE PRO — $12/mo                     │
│                                                          │
│  ✓ Everything in Free                                    │
│  ✓ Unlimited LLM interactions (Haiku + Sonnet)          │
│  ✓ Full three-tier memory (unlimited retention)         │
│  ✓ Deep research (5/day, Opus)                          │
│  ✓ Premium TTS (ElevenLabs, voice cloning)              │
│  ✓ Full local runner (shell commands, automation)       │
│  ✓ Background monitoring (Docker, Git, builds)          │
│  ✓ Proactive alerts                                      │
│                                                          │
│                    Cost to serve: ~$6-8/month             │
├─────────────────────────────────────────────────────────┤
│                    JANE TEAM — $25/user/mo               │
│                                                          │
│  ✓ Everything in Pro                                     │
│  ✓ Shared memory (team context)                         │
│  ✓ Meeting transcription                                │
│  ✓ Multi-machine sync                                   │
│  ✓ Admin controls                                        │
│  ✓ SSO                                                   │
│                                                          │
│                    Cost to serve: ~$10-12/month           │
└─────────────────────────────────────────────────────────┘
```

### 13.3 Revenue Model

| Metric | Conservative | Moderate | Optimistic |
|--------|-------------|----------|-----------|
| Free users (Year 1) | 5,000 | 20,000 | 50,000 |
| Free → Pro conversion | 5% | 8% | 12% |
| Pro subscribers | 250 | 1,600 | 6,000 |
| Pro MRR | $3,000 | $19,200 | $72,000 |
| Pro ARR | $36,000 | $230,400 | $864,000 |
| Gross margin | 40% | 55% | 65% |

**The BYO-API option:** Users who have their own Anthropic/OpenAI API keys could use Jane for free (or a reduced price), paying only for their own API usage. This is common in developer tools (Cursor, Continue) and dramatically reduces cost-to-serve.

### 13.4 Is There a Market for Desktop AI Companions?

The honest answer: **it is unproven but plausible.**

Arguments for:
- 100M+ MacBook users, ~65M with notch
- GitHub Copilot proved developers pay $19/mo for AI tools
- Raycast proved Mac users pay for productivity tools
- The "ambient AI" category does not exist yet — first-mover advantage
- Desktop companions have more local power than mobile ones

Arguments against:
- Every hardware AI device has failed
- Mobile companions (Replika, Character.AI) dominate the market
- Apple could add similar features to Siri (they are trying)
- Small niche — not every Mac user wants an AI companion

**The bet:** Jane is not competing with Replika (emotional companion) or Siri (system assistant). She is competing with the combination of ChatGPT + Raycast + a calendar app + a system monitor. The value prop is consolidation: one ambient interface that replaces five separate tools.

---

## 14. Patterns — Putting It All Together

### Pattern 1: The Wake-to-Response Pipeline

The complete flow from "Hey Jane" to a spoken response, covering every subsystem.

```typescript
class JanePipeline {
  private wakeWord: PorcupineEngine;
  private stt: WhisperKitEngine;
  private memory: JaneMemoryStore;
  private router: AdaptiveModelRouter;
  private llm: LLMClient;
  private tts: TTSEngine; // Kokoro default, ElevenLabs premium
  private avatar: JaneFaceView;
  private localRunner: JaneLocalRunner;
  private contextManager: ContextManager;

  async initialize(): Promise<void> {
    // Load memory
    await this.memory.load();

    // Start wake word detection
    this.wakeWord.onDetected(() => this.onWakeWord());

    // Set initial face state
    this.avatar.transition("idle");

    console.log("Jane initialized. Listening for wake word...");
  }

  private async onWakeWord(): Promise<void> {
    // 1. Visual feedback — Jane is listening
    this.avatar.transition("listening");
    this.playChime("listening"); // Subtle audio confirmation

    // 2. Start speech-to-text
    const transcript = await this.stt.listen({
      timeout: 30_000, // 30s silence timeout
      onPartial: (partial) => {
        // Show partial transcript in HUD status bar
        this.hud.showStatus(partial);
      },
    });

    if (!transcript.trim()) {
      this.avatar.transition("idle");
      return;
    }

    // 3. Log user input to recall memory
    this.memory.logConversation("user", transcript, this.currentConversationId);

    // 4. Determine model tier
    const tier = this.router.route(
      { transcript },
      { conversationId: this.currentConversationId, memorySnapshot: this.memory.getSnapshot() }
    );

    // 5. Build context
    this.avatar.transition("thinking");
    const systemPrompt = this.contextManager.buildSystemPrompt();
    const resumeContext = await this.contextManager.buildResumeContext();
    const recentMessages = this.contextManager.buildConversationContext(
      this.memory.getRecentRecall(20)
    );

    // 6. Call LLM with memory tools
    const response = await this.llm.complete({
      model: this.getModel(tier),
      system: systemPrompt,
      messages: [
        ...(resumeContext ? [{ role: "system" as const, content: resumeContext }] : []),
        ...recentMessages,
        { role: "user" as const, content: transcript },
      ],
      tools: [
        ...JANE_MEMORY_TOOLS,
        ...JANE_LOCAL_TOOLS,
        ...JANE_RESEARCH_TOOLS,
      ],
    });

    // 7. Process tool calls (memory updates, local actions, etc.)
    const finalResponse = await this.processToolCalls(response);

    // 8. Log assistant response to recall memory
    this.memory.logConversation("assistant", finalResponse, this.currentConversationId);

    // 9. Speak the response
    this.avatar.transition("speaking");
    const audioStream = await this.tts.speak(finalResponse, this.inferEmotion(finalResponse));

    // 10. Play audio with lip sync
    await this.playWithLipSync(audioStream);

    // 11. Return to idle (or keep listening for follow-up)
    this.avatar.transition("idle");

    // 12. Background: extract memories from this interaction
    this.memoryExtractor.processConversation([
      { role: "user", content: transcript },
      { role: "assistant", content: finalResponse },
    ]).catch(console.error); // Fire and forget
  }

  private getModel(tier: ModelTier): string {
    switch (tier) {
      case "fast": return "claude-3-5-haiku-20241022";
      case "balanced": return "claude-sonnet-4-20250514";
      case "deep": return "claude-opus-4-20250514";
    }
  }

  private async processToolCalls(response: LLMResponse): Promise<string> {
    let currentResponse = response;

    while (currentResponse.stop_reason === "tool_use") {
      const toolResults = [];

      for (const toolCall of currentResponse.content.filter((c) => c.type === "tool_use")) {
        const result = await this.executeTool(toolCall.name, toolCall.input);
        toolResults.push({
          type: "tool_result" as const,
          tool_use_id: toolCall.id,
          content: result,
        });
      }

      // Continue conversation with tool results
      currentResponse = await this.llm.complete({
        model: currentResponse.model,
        messages: [...this.currentMessages, ...toolResults],
        tools: [...JANE_MEMORY_TOOLS, ...JANE_LOCAL_TOOLS],
      });
    }

    return currentResponse.content
      .filter((c) => c.type === "text")
      .map((c) => c.text)
      .join("");
  }

  private async executeTool(name: string, input: Record<string, unknown>): Promise<string> {
    switch (name) {
      case "core_memory_update":
        this.memory.updateCoreMemory(input.key as string, input.content as string);
        return "Core memory updated.";

      case "recall_search":
        const results = this.memory.searchRecall(input.query as string, input.limit as number);
        return JSON.stringify(results);

      case "archival_search":
        const embedding = await this.embed(input.query as string);
        const entries = this.memory.searchArchival(embedding, input.limit as number);
        return JSON.stringify(entries);

      case "file_read":
        return this.localRunner.readFile(input.path as string, input.maxLines as number);

      case "shell_command":
        if (await this.checkSecurityApproval(name, input)) {
          return this.localRunner.runShellCommand(input.command as string);
        }
        return "Command blocked by security policy.";

      case "deep_research":
        const taskId = await this.research.startResearch(input.query as string);
        return `Research started (task ${taskId}). I'll alert you when it's done.`;

      default:
        return `Unknown tool: ${name}`;
    }
  }

  private inferEmotion(text: string): Emotion {
    // Simple heuristic — could be upgraded to LLM-based
    if (text.includes("!") || text.match(/great|awesome|excellent/i)) return "excited";
    if (text.includes("?") || text.match(/hmm|let me think/i)) return "thinking";
    if (text.match(/sorry|unfortunately|issue|problem/i)) return "concerned";
    if (text.match(/sure|of course|happy to|here's/i)) return "happy";
    return "neutral";
  }

  private async playWithLipSync(audioStream: ReadableStream): Promise<void> {
    // Play audio and drive avatar lip sync from amplitude
    const lipSync = new JaneLipSync();
    const player = new AudioPlayer();

    lipSync.startMonitoring(player.audioEngine);
    await player.play(audioStream);
    lipSync.stop();
  }
}
```

### Pattern 2: Proactive Monitoring

Jane does not just respond to questions. She monitors the local environment and proactively surfaces issues.

```typescript
class JaneProactiveMonitor {
  private monitors: Monitor[] = [];
  private hudServer: HUDClient;
  private memory: JaneMemoryStore;

  registerDefaults(): void {
    // Calendar: Alert 5 minutes before meetings
    this.monitors.push(
      new CalendarMonitor({
        checkInterval: 60_000, // Every minute
        alertBefore: 5 * 60_000, // 5 minutes before
        onAlert: (event) => {
          this.hudServer.showNotification({
            title: `Meeting in 5 minutes`,
            body: event.title,
            level: "time-sensitive",
          });
          // If user has spoken to Jane about meeting prep before, remind them
          this.checkPrepNotes(event);
        },
      })
    );

    // Docker: Alert on container crashes
    this.monitors.push(
      new DockerMonitor({
        checkInterval: 30_000,
        onContainerCrash: (container) => {
          this.hudServer.showNotification({
            title: `Container crashed: ${container.name}`,
            body: `Exit code: ${container.exitCode}`,
            level: "active",
          });
        },
      })
    );

    // Git: Alert on uncommitted changes older than 2 hours
    this.monitors.push(
      new GitMonitor({
        checkInterval: 300_000, // Every 5 minutes
        watchPaths: this.getActiveProjectPaths(),
        onStaleChanges: (repo, changeAge) => {
          if (changeAge > 2 * 60 * 60 * 1000) {
            this.hudServer.showNotification({
              title: `Uncommitted changes in ${repo.name}`,
              body: `${repo.changedFiles} files changed ${Math.round(changeAge / 3600000)}h ago`,
              level: "passive",
            });
          }
        },
      })
    );

    // Battery: Alert at 20% and 10%
    this.monitors.push(
      new BatteryMonitor({
        thresholds: [20, 10],
        onThreshold: (level) => {
          this.hudServer.showNotification({
            title: `Battery at ${level}%`,
            body: level <= 10 ? "Connect charger soon" : "Consider charging",
            level: level <= 10 ? "time-sensitive" : "passive",
          });
        },
      })
    );

    // Build failures: Watch for common CI/CD indicators
    this.monitors.push(
      new FileWatcher({
        paths: ["~/Work/**/build.log", "~/Work/**/.build-status"],
        onChange: async (path) => {
          const content = await readFile(path, "utf-8");
          if (content.includes("FAILED") || content.includes("error")) {
            this.hudServer.showNotification({
              title: "Build failure detected",
              body: path.split("/").slice(-3).join("/"),
              level: "active",
            });
          }
        },
      })
    );
  }

  private getActiveProjectPaths(): string[] {
    // Read from core memory to know what projects to watch
    const context = this.memory.getCoreMemory().get("current_context") || "";
    const paths: string[] = [];

    // Parse project paths from memory
    const matches = context.match(/~\/Work\/[\w-]+/g);
    if (matches) paths.push(...matches);

    return paths.length > 0 ? paths : [`${process.env.HOME}/Work`];
  }

  private async checkPrepNotes(event: CalendarEvent): Promise<void> {
    // Search memory for preparation notes related to this meeting
    const results = this.memory.searchArchival(
      `meeting prep ${event.title} ${event.attendees?.join(" ") || ""}`,
      3
    );

    if (results.length > 0) {
      this.hudServer.showNotification({
        title: `Prep notes for: ${event.title}`,
        body: results[0].content.substring(0, 100) + "...",
        level: "active",
      });
    }
  }
}
```

### Pattern 3: The Conversation Resume

When Jane has not talked to the user in a while, she should acknowledge the gap naturally.

```typescript
class ConversationResumer {
  async buildResumeGreeting(
    memory: JaneMemoryStore,
    timeSinceLastChat: number
  ): Promise<string | null> {
    // Less than 5 minutes — no greeting needed (continuing conversation)
    if (timeSinceLastChat < 5 * 60 * 1000) return null;

    // 5 minutes to 1 hour — brief acknowledgment
    if (timeSinceLastChat < 60 * 60 * 1000) {
      return "[System: Brief pause since last interaction. Continue naturally.]";
    }

    // 1 to 24 hours — "welcome back" with context
    if (timeSinceLastChat < 24 * 60 * 60 * 1000) {
      const hours = Math.round(timeSinceLastChat / 3600000);
      const lastTopic = memory.getRecentRecall(1)[0]?.content.substring(0, 80);
      const pendingResearch = memory.getPendingResearch();

      let context = `[System: ${hours} hours since last chat.`;
      if (lastTopic) context += ` Last topic: "${lastTopic}".`;
      if (pendingResearch.length > 0) {
        context += ` ${pendingResearch.length} research task(s) completed since then.`;
      }
      context += " Greet briefly and naturally.]";
      return context;
    }

    // More than 24 hours — fuller recap
    const days = Math.round(timeSinceLastChat / 86400000);
    const highlights = await memory.getHighlightsSince(
      new Date(Date.now() - timeSinceLastChat)
    );

    return `[System: ${days} day(s) since last conversation. Key events since then: ${highlights.join("; ")}. Greet warmly, acknowledge the gap, and mention anything notable.]`;
  }
}
```

### Pattern 4: The HUD Integration Bridge

Jane talks to the HUD display through the existing localhost:7070 HTTP API.

```typescript
class JaneHUDBridge {
  private baseUrl = "http://localhost:7070";

  // Show Jane's face in the notch
  async setFaceState(state: JaneFaceState): Promise<void> {
    await fetch(`${this.baseUrl}/jane/face`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ state }),
    });
  }

  // Show status text in the LCD bar
  async showStatus(text: string, color: "green" | "amber" | "red" = "green"): Promise<void> {
    await fetch(`${this.baseUrl}/display`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        renderer: "lcd",
        text,
        color,
        size: "s",
      }),
    });
  }

  // Show a notification through the HUD's policy engine
  async showNotification(notification: {
    title: string;
    body: string;
    level: "passive" | "active" | "time-sensitive" | "critical";
    actions?: Array<{ label: string; action: string; data?: string }>;
  }): Promise<void> {
    await fetch(`${this.baseUrl}/notify`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        source: "jane",
        ...notification,
      }),
    });
  }

  // Show research progress bar
  async showProgress(percent: number, label: string): Promise<void> {
    await fetch(`${this.baseUrl}/display`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        renderer: "scanner",
        mode: "progress",
        value: percent / 100,
        label,
      }),
    });
  }

  // RSVP a long text through the notch display
  async rsvpText(text: string, wpm: number = 300): Promise<void> {
    await fetch(`${this.baseUrl}/display`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        renderer: "text",
        presentation: "rsvp",
        text,
        wpm,
      }),
    });
  }
}
```

### Pattern 5: BYO API Key Configuration

For cost-sensitive users, Jane can use their own API keys instead of a managed subscription.

```typescript
interface JaneAPIConfig {
  mode: "managed" | "byo";

  // Managed mode: Jane handles billing
  managed?: {
    subscription: "free" | "pro" | "team";
    janeApiKey: string; // Jane's backend proxy key
  };

  // BYO mode: User provides their own keys
  byo?: {
    anthropicKey?: string;
    openaiKey?: string;
    elevenLabsKey?: string;
    picovoiceKey?: string;
  };
}

class JaneAPIRouter {
  private config: JaneAPIConfig;

  async callLLM(params: LLMParams): Promise<LLMResponse> {
    if (this.config.mode === "managed") {
      // Route through Jane's backend (metered, managed billing)
      return fetch("https://api.jane.ai/v1/chat", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.config.managed!.janeApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(params),
      }).then((r) => r.json());
    }

    // BYO mode: call provider directly
    if (params.model.startsWith("claude")) {
      return this.callAnthropic(params, this.config.byo!.anthropicKey!);
    } else {
      return this.callOpenAI(params, this.config.byo!.openaiKey!);
    }
  }

  private async callAnthropic(params: LLMParams, key: string): Promise<LLMResponse> {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: params.model,
        max_tokens: params.maxTokens || 4096,
        system: params.system,
        messages: params.messages,
        tools: params.tools,
      }),
    });
    return response.json();
  }
}
```

### Pattern 6: The Memory Viewer

Users need to see and edit what Jane remembers. Trust requires transparency.

```typescript
// Exposed via localhost:7070/jane/memory
interface MemoryViewerAPI {
  // GET /jane/memory/core — all core memory blocks
  getCoreMemory(): Promise<{
    blocks: Array<{
      key: string;
      content: string;
      lastUpdated: string;
      tokenCount: number;
    }>;
    totalTokens: number;
    maxTokens: number;
  }>;

  // PUT /jane/memory/core/:key — user edits a core memory block
  updateCoreMemory(key: string, content: string): Promise<void>;

  // GET /jane/memory/archival?q=search&limit=20 — search archival memory
  searchArchival(query: string, limit?: number): Promise<Array<{
    id: string;
    content: string;
    createdAt: string;
    tags: string[];
  }>>;

  // DELETE /jane/memory/archival/:id — user deletes an archival entry
  deleteArchival(id: string): Promise<void>;

  // GET /jane/memory/recall?date=2026-03-28&limit=50 — browse conversations
  getRecallByDate(date: string, limit?: number): Promise<Array<{
    role: string;
    content: string;
    timestamp: string;
  }>>;

  // DELETE /jane/memory/recall?before=2026-01-01 — bulk delete old conversations
  deleteRecallBefore(date: string): Promise<{ deletedCount: number }>;

  // GET /jane/memory/stats — memory statistics
  getStats(): Promise<{
    coreBlocks: number;
    coreTokens: number;
    recallMessages: number;
    recallOldest: string;
    archivalEntries: number;
    databaseSizeBytes: number;
  }>;

  // POST /jane/memory/export — export all memory as JSON
  exportAll(): Promise<JaneMemoryExport>;

  // POST /jane/memory/import — import memory from JSON
  importAll(data: JaneMemoryExport): Promise<void>;

  // DELETE /jane/memory/all — nuclear option
  eraseAll(): Promise<void>;
}
```

---

## 15. References

### Official Documentation

- [WhisperKit — On-device Speech Recognition for Apple Silicon](https://github.com/argmaxinc/WhisperKit) — Swift package for running Whisper models natively on Apple Neural Engine
- [whisper.cpp — Port of OpenAI's Whisper in C/C++](https://github.com/ggml-org/whisper.cpp) — Local STT with Core ML acceleration for macOS
- [Porcupine Wake Word Detection](https://picovoice.ai/platform/porcupine/) — Always-on wake word engine with custom keyword support
- [Apple SpeechAnalyzer (WWDC 2025)](https://developer.apple.com/videos/play/wwdc2025/277/) — New Apple speech-to-text API replacing SFSpeechRecognizer
- [Apple SFSpeechRecognizer Documentation](https://developer.apple.com/documentation/speech/sfspeechrecognizer) — Legacy Apple Speech framework
- [ElevenLabs API Documentation](https://elevenlabs.io/pricing/api) — TTS API pricing and capabilities
- [OpenAI TTS API Pricing](https://costgoat.com/pricing/openai-tts) — OpenAI text-to-speech cost calculator
- [Kokoro-82M on HuggingFace](https://huggingface.co/hexgrad/Kokoro-82M) — Open-weight 82M parameter TTS model
- [Piper TTS](https://github.com/rhasspy/piper) — Fast local neural text-to-speech system
- [kokoro-web — OpenAI-compatible Kokoro API](https://github.com/eduardolat/kokoro-web) — Self-hosted Kokoro with OpenAI API compatibility
- [Letta (MemGPT) Documentation](https://docs.letta.com/concepts/memgpt/) — Agent framework with self-managing memory
- [Letta Memory Management Guide](https://docs.letta.com/advanced/memory-management/) — Core, recall, and archival memory tiers
- [Mem0 — Memory Layer for AI Apps](https://mem0.ai/) — Hybrid memory infrastructure (vector + graph + KV)
- [Zep — Context Engineering for AI Agents](https://www.getzep.com/) — Temporal knowledge graph memory
- [Model Context Protocol](https://modelcontextprotocol.io/) — Standard protocol for LLM tool integration
- [macos-automator-mcp](https://github.com/steipete/macos-automator-mcp) — MCP server for AppleScript/JXA automation
- [Perplexity Deep Research](https://research.perplexity.ai/) — Multi-model ensemble research system
- [HeyGen LiveAvatar](https://help.heygen.com/en/articles/12758516-introducing-liveavatar) — Real-time interactive AI avatar API
- [Synthesia Pricing](https://www.synthesia.io/pricing) — AI video generation with interactive avatars
- [Soul Machines](https://www.soulmachines.com/) — Photorealistic AI avatar platform
- [sqlite-vec](https://github.com/asg017/sqlite-vec) — Vector similarity search extension for SQLite

### Research Papers and Technical Deep Dives

- [MemGPT: Towards LLMs as Operating Systems (arXiv:2310.08560)](https://arxiv.org/abs/2310.08560) — Original MemGPT paper introducing virtual context management
- [WhisperKit: On-device Real-time ASR with Billion-Scale Transformers](https://arxiv.org/html/2507.10860v1) — WhisperKit architecture and benchmarks
- [Teller: Real-Time Streaming Audio-Driven Portrait Animation](https://www.koreaherald.com/article/10452038) — Soul Machines CVPR 2025 paper on real-time face animation
- [Memoria: A Scalable Agentic Memory Framework](https://arxiv.org/html/2512.12686v1) — Scalable memory architecture for conversational AI
- [Whisper Speech Recognition on Mac M4: Benchmarks](https://dev.to/theinsyeds/whisper-speech-recognition-on-mac-m4-performance-analysis-and-benchmarks-2dlp) — Performance analysis across Apple Silicon generations
- [Apple and Argmax: SpeechAnalyzer and WhisperKit](https://www.argmaxinc.com/blog/apple-and-argmax) — How Apple's new SpeechAnalyzer relates to WhisperKit

### Comparison Articles and Market Analysis

- [5 AI Agent Memory Systems Compared (2026 Benchmark Data)](https://dev.to/varun_pratapbhardwaj_b13/5-ai-agent-memory-systems-compared-mem0-zep-letta-supermemory-superlocalmemory-2026-benchmark-59p3) — Benchmark comparison of Mem0, Zep, Letta, and others
- [Letta vs Mem0 vs Zep: Picking Between AI Memory Solutions](https://medium.com/asymptotic-spaghetti-integration/from-beta-to-battle-tested-picking-between-letta-mem0-zep-for-ai-memory-6850ca8703d1) — Production readiness comparison
- [ElevenLabs vs OpenAI TTS](https://vapi.ai/blog/elevenlabs-vs-openai) — Detailed quality, latency, and pricing comparison
- [Best TTS APIs in 2026: 12 Services Compared](https://www.speechmatics.com/company/articles-and-news/best-tts-apis-in-2025-top-12-text-to-speech-services-for-developers) — Comprehensive TTS landscape review
- [Top 12 Open-Source TTS Models Compared (2025)](https://www.inferless.com/learn/comparing-different-text-to-speech---tts--models-part-2) — Latency, quality, and voice cloning comparison
- [Best Open-Source TTS Models in 2026](https://www.bentoml.com/blog/exploring-the-world-of-open-source-text-to-speech-models) — Kokoro, Piper, XTTS, and others ranked
- [Perplexity Deep Research vs OpenAI Deep Research (2026)](https://www.clickittech.com/ai/perplexity-deep-research-vs-openai-deep-research/) — Architecture and capability comparison
- [Wispr Flow vs Monologue: Dictation Tools Compared](https://wisprflow.ai/post/wispr-flow-vs-monologue) — macOS dictation tool comparison
- [Open Source Speech-to-Text on macOS](https://whisperclip.com/blog/posts/open-source-speech-to-text-on-macos-whisper-cpp-aiko-and-more) — whisper.cpp, Aiko, and alternatives

### AI Companion Products and Market Data

- [The Complete Guide to the AI Companion Market in 2026](https://companionguide.ai/news/ai-companion-market-120m-revenue) — Revenue data and market analysis
- [AI Companions Statistics: Usage, Market Size, Apps](https://electroiq.com/stats/ai-companions-statistics/) — Comprehensive market statistics
- [AI Companion Market Growth 2026-2034](https://www.fortunebusinessinsights.com/ai-companion-market-113258) — Market projections ($49.52B by 2026)
- [Replika Review 2026](https://companionguide.ai/companions/replika) — Features, pricing, memory system analysis
- [Character.AI: Helping Characters Remember](https://blog.character.ai/helping-characters-remember-what-matters-most/) — Character.AI's memory system
- [Pi AI Review: Voice Mode and Memory](https://aicompanionguides.com/blog/what-i-learned-this-week-pi-vs-expectations/) — Pi's conversational memory and voice quality
- [Friend AI Necklace Review](https://www.techbuzz.ai/articles/friend-ai-necklace-review-the-129-wearable-that-bullies-you) — Always-listening pendant analysis
- [Meta Acquires Limitless (formerly Rewind)](https://techcrunch.com/2025/12/05/meta-acquires-ai-device-startup-limitless/) — Rewind/Limitless acquisition story
- [Screenpipe — Open Source Rewind Alternative](https://screenpi.pe) — Screen recording + AI memory daemon
- [Why Rabbit R1 and Humane AI Pin Failed](https://medium.com/@thcookieh/why-did-the-rabbit-r1-and-humane-ai-pin-fail-at-launch-c108d6e2bebb) — Post-mortem analysis
- [Top 5 AI Gadget Flops of 2025](https://www.everydayaitech.com/en/articles/ai-gadgets-flop-2025) — Hardware companion failures
- [5 Mistakes to Avoid for AI Devices](https://www.techradar.com/computing/artificial-intelligence/5-mistakes-sam-altman-and-jony-ive-need-to-avoid-to-stop-their-chatgpt-ai-device-going-the-way-of-the-rabbit-r1-and-humane-ai-pin) — Lessons from hardware failures

### Privacy, Ethics, and Compliance

- [AI Privacy Rules: GDPR, EU AI Act, and U.S. Law](https://www.parloa.com/blog/AI-privacy-2026/) — Comprehensive privacy regulation overview
- [Privacy-by-Design: How On-Device AI Solves GDPR & CCPA](https://sensory.com/compliance-privacy-by-design/) — Local processing as privacy solution
- [GDPR and AI in 2026: Rules, Risks & Tools](https://www.sembly.ai/blog/gdpr-and-ai-rules-risks-tools-that-comply/) — Practical GDPR compliance for AI systems
- [Complete GDPR Compliance Guide (2026-Ready)](https://secureprivacy.ai/blog/gdpr-compliance-2026) — Updated compliance checklist

### Avatar and Face Animation

- [Jeeliz WebGL Face Tracking](https://github.com/jeeliz/jeelizWeboji) — Real-time face tracking and emoji animation in browser
- [Pose Animator — SVG Character Animation via Motion Capture](https://blog.tensorflow.org/2020/05/pose-animator-open-source-tool-to-bring-svg-characters-to-life.html) — 2D vector character animation
- [Live2D Real-Time Facial Animation](https://visagetechnologies.com/case-studies/live2d/) — 2D illustration animation with face tracking
- [Avatar Animator — Real-time 2D Vector Avatar](https://github.com/letmaik/avatar-animator) — Webcam-driven 2D avatar

### Voice Dictation and Input

- [Wispr Flow](https://wisprflow.ai/) — macOS system-wide voice dictation with AI formatting
- [WisprFlow Review: 179WPM Writing by Talking](https://zackproser.com/blog/wisprflow-review) — Detailed user review
- [Wispr Flow 2026 Review](https://max-productive.ai/ai-tools/wispr-flow/) — Feature overview and auto-editing capabilities
- [OpenWhispr — Open Source Voice-to-Text](https://github.com/OpenWhispr/openwhispr) — Cross-platform dictation with local and cloud models

### Memory System Deep Dives

- [Agent Memory: How to Build Agents that Learn and Remember](https://www.letta.com/blog/agent-memory) — Letta's guide to agent memory patterns
- [Adding Memory to LLMs with Letta](https://tersesystems.com/blog/2025/02/14/adding-memory-to-llms-with-letta/) — Practical Letta integration guide
- [AI Memory Layer Guide (December 2025)](https://mem0.ai/blog/ai-memory-layer-guide) — Mem0's perspective on memory architecture
- [Top 10 AI Memory Products 2026](https://medium.com/@bumurzaqov2/top-10-ai-memory-products-2026-09d7900b5ab1) — Market overview of memory solutions
- [Graph Memory for AI Agents (January 2026)](https://mem0.ai/blog/graph-memory-solutions-ai-agents) — Graph-based memory approaches
- [Survey of AI Agent Memory Frameworks](https://www.graphlit.com/blog/survey-of-ai-agent-memory-frameworks) — Comprehensive framework comparison

---

*This article covers the complete technical blueprint for building Jane — a persistent AI companion with voice, memory, face, and local superpowers. Every section includes real code, honest comparisons, and specific recommendations. The architecture is modular: start with voice + memory, add the face, add local capabilities, add deep research. Each component works independently and integrates through the HUD's existing HTTP API on localhost:7070.*

*Jane is not a chatbot. She is a daemon with a personality, a memory measured in months, and root access to your machine. The notch is just her face.*
