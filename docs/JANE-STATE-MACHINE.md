# Jane's Animation State Machine

**Version:** 1.0 (Complete)
**Last Updated:** 2026-03-28
**Status:** IMPLEMENTED

---

## State Diagram

```
                         ┌─────────────────────────┐
                         │       IDLE STATE        │
                         │  ● Smile mouth          │
                         │  ● Normal eyes          │
                         │  ● Green glow           │
                         │  ● Blink: 3.5s interval │
                         │  ● Scanlines: 20 px/s   │
                         └────────────┬────────────┘
                                ▲    │
                        voiceOff │    │ voiceOn
                                │    ▼
                    ┌────────────┴──────────────┐
                    │                           │
              ┌─────▼─────┐              ┌──────▼──────┐
              │ LISTENING │              │  THINKING   │
              │ ● Neutral │              │ ● Neutral   │
              │ ● Dilated │              │ ● Narrowed  │
              │ ● Yellow  │              │ ● Yellow    │
              │ ● Track   │              │ ● Pulsing   │
              │ ● 40 px/s │              │ ● 40→80px/s │
              │ ● 5 ptcls │              │ ● 8 ptcls   │
              └─────┬─────┘              └──────┬──────┘
                    │                          │
              voiceOff           apiStart ▼    │
                OR                             │
              apiStart           voiceOff      │
                    │                          │
                    └──────────┬───────────────┘
                               │
                    ttsStart   ▼
              ┌────────────────────────┐
              │    RESPONDING STATE     │
              │ ● Oscillating mouth     │
              │ ● Engaged eyes          │
              │ ● Green glow            │
              │ ● 80 px/s scanlines     │
              │ ● 10 particles          │
              └────────────┬────────────┘
                           │
                  ┌────────┴────────┐
                  │                 │
            success           ttsEnd
                  │                 │
                  ▼                 ▼
            ┌──────────┐        ┌──────┐
            │ SUCCESS  │        │ IDLE │
            │ ● Warm   │        │      │
            │ ● Expand │        └──────┘
            │ ● 5 px/s │
            │ ● Pulse  │
            │ ▼ (2s)   │
            └────┬─────┘
                 │
          auto→  ▼
             IDLE

        ANY STATE
            │
     error(msg)
            │
            ▼
       ┌─────────┐
       │ ERROR   │
       │ ● Open  │
       │ ● Pulse │
       │ ● Red   │
       │ ● Chaos │
       │ ● 80 px/s (glitch)
       │ ● 12 ptcls
       │ ▼ (3s) OR clearError
       └────┬────┘
            │
        auto→ IDLE
           OR
        clearError
```

---

## State Definitions

### IDLE
**Entry Conditions:** Application start, after operation completes, no active input for 5s
**Exit Conditions:** Voice detected, error triggered
**Duration:** Indefinite
**Severity:** GREEN (#00E5FF)

**Visual:**
- Mouth: Relaxed smile (curve 0.04)
- Eyes: Normal size (1.0x), calm glow
- Blink: Every 3.5s for 150ms
- Scanlines: Slow (20 px/s)
- Particles: 3 subtle dots, orbital sine motion
- Glow alpha: 0.2 (soft)

**Expression Values:**
```swift
mouthCurve: 0.04
eyeSize: 1.0
eyeHeight: 7
blinkInterval: 3.5
scanlineSpeed: 20
particleCount: 3
particleMotion: .orbitingSine
glowAlpha: 0.2
```

---

### LISTENING
**Entry Conditions:** Microphone active OR Voice Activity Detection confidence > threshold
**Exit Conditions:** Voice ends AND no API call, or API call starts
**Duration:** Until voice ends
**Severity:** YELLOW (#FFD700)

**Visual:**
- Mouth: Straight neutral line
- Eyes: Dilated (1.2x), alert glow, horizontal drift (±2px @ 1.5Hz)
- Blink: Normal (3.5s) showing engagement
- Scanlines: Faster (40 px/s)
- Particles: 5 dots, scattered random motion
- Glow alpha: 0.4 (bright)

**Expression Values:**
```swift
mouthCurve: 0.0
eyeSize: 1.2
eyeHeight: 9
eyeDrift: true  // ±2px horizontal
blinkInterval: 3.5
scanlineSpeed: 40
particleCount: 5
particleMotion: .scattered
glowAlpha: 0.4
```

---

### THINKING
**Entry Conditions:** API/LLM request starts (apiStart event)
**Exit Conditions:** Response starts (ttsStart), no response (apiEnd), voice stops
**Duration:** Time-to-first-token (TTF)
**Severity:** YELLOW (#FFD700)

**Visual:**
- Mouth: Straight neutral line
- Eyes: Narrowed (0.8x), concentrating, rare blinks (5s interval)
- Scanlines: Accelerating (40 → 80 px/s over 3s)
- Glow: Pulsing (0.3 → 0.5 alpha @ 1Hz)
- Particles: 8 dots, converging toward center, increasing speed
- Micro-expression: Upper eyelid tension

**Expression Values:**
```swift
mouthCurve: 0.0
eyeSize: 0.8
eyeHeight: 6
blinkInterval: 5.0
scanlineSpeed: 40  // animated acceleration
glowPulses: true
glowPulseFrequency: 1.0
particleCount: 8
particleMotion: .convergingCenter
glowAlpha: 0.3...0.5
```

---

### RESPONDING
**Entry Conditions:** TTS output starts (ttsStart event)
**Exit Conditions:** TTS ends (ttsEnd), success triggered
**Duration:** Duration of audio output
**Severity:** GREEN (#00E5FF)

**Visual:**
- Mouth: Animated oscillating line (5Hz cadence)
  - Opens/closes with speech rhythm
  - Amplitude: ±0.03 height
- Eyes: Engaged (1.1x), normal glow, steady
- Blink: Rare (10s interval) while speaking
- Scanlines: Fast sync (80 px/s)
- Glow: Steady bright (0.4 alpha)
- Particles: 10 dots, scattered, responsive to speech cadence

**Expression Values:**
```swift
mouthCurve: 0.0
mouthOscillates: true
mouthOscillationFrequency: 5.0  // Hz (speech cadence)
mouthOscillationAmplitude: 0.03
eyeSize: 1.1
eyeHeight: 7.5
blinkInterval: 10.0
scanlineSpeed: 80
particleCount: 10
particleMotion: .scattered
glowAlpha: 0.4
```

---

### SUCCESS
**Entry Conditions:** Operation completed successfully (success event)
**Exit Conditions:** Auto-transition after 2 seconds
**Duration:** 2 seconds (auto-transition)
**Severity:** GREEN (#00E5FF)

**Visual:**
- Mouth: Warm smile (deeper curve 0.06)
- Eyes: Happy flash - pupil shrinks to 0.8x for 200ms, then normal
- Glow: Pulse outward twice (expand 1.2x at 0.3s and 0.7s)
- Scanlines: Minimal (5 px/s) - peaceful
- Particles: 3 dots converging to center, fading out
- Micro-expression: Eye sparkle, smile depth

**Expression Values:**
```swift
mouthCurve: 0.06
eyeSize: 1.0
eyeHeight: 7
pupilFlash: true  // 0.8x for 200ms
glowExpands: true  // pulse at 0.3s, 0.7s
scanlineSpeed: 5
particleCount: 3
particleMotion: .convergingCenter  // fade out
glowAlpha: 0.3
autoTransition: true
autoTransitionDelay: 2.0  // seconds
```

---

### ERROR
**Entry Conditions:** Exception, network failure, user interruption, API timeout
**Exit Conditions:** Manual clearError OR auto-transition after 3 seconds
**Duration:** 3 seconds (auto-transition) OR until cleared
**Severity:** RED (#FF4D7F)

**Visual:**
- Mouth: Open oval (fixed, surprised/alarmed)
- Eyes: Pulsing alarm (oscillates 0.7x → 1.3x @ 0.6s period)
- Scanlines: Maximum speed (80 px/s) + glitch effect
  - Skip every 5th line at 20% opacity
  - Creates visual "data corruption" effect
- Glow: Pulsing (0.6 → 0.8 alpha @ 0.8s period)
- Particles: 12 chaotic dots, fast random motion
- Micro-expression: Eyes wide open, alarm state

**Expression Values:**
```swift
mouthCurve: 0.0
mouthOpen: true
mouthOpenHeight: 0.06
eyeSize: 1.3
eyeHeight: 10
eyePulses: true
eyePulseFrequency: 1.667  // 0.6s period
eyePulseRange: [0.7, 1.3]
blinkInterval: 0  // disabled
scanlineSpeed: 80
scanlineGlitches: true  // 20% skip
glowPulses: true
glowPulseFrequency: 1.25  // 0.8s period
particleCount: 12
particleMotion: .chaotic
glowAlpha: 0.6...0.8
autoTransition: true
autoTransitionDelay: 3.0  // seconds
```

---

## Event Types & Triggers

| Event | Trigger | From State | To State | Notes |
|-------|---------|-----------|----------|-------|
| `voiceOn` | Microphone active + VAD | IDLE | LISTENING | Automatic when mic activates |
| `voiceOff` | Microphone inactive | LISTENING | IDLE | Unless API call already started |
| `apiStart` | LLM request sent | LISTENING | THINKING | Also callable from IDLE |
| `apiEnd` | API response received | THINKING | (no change) | Transition happens on ttsStart |
| `ttsStart` | TTS output begins | THINKING | RESPONDING | Automatic when synthesis starts |
| `ttsEnd` | TTS output completes | RESPONDING | IDLE | Automatic when audio finishes |
| `success` | Operation succeeded | RESPONDING | SUCCESS | Explicit success signal |
| `error(msg)` | Exception or failure | ANY | ERROR | Highest priority, interrupts all |
| `clearError` | User dismisses / timeout | ERROR | IDLE | Auto-triggers after 3s |

---

## Transition Timings

### Animated Transitions (Interpolated)

| Transition | Duration | Easing | Purpose |
|------------|----------|--------|---------|
| IDLE ↔ LISTENING | 0.3s | ease-in-out | Quick response to voice |
| LISTENING → THINKING | 0.5s | ease-in-out | Deliberate thinking mode |
| THINKING → RESPONDING | 0.2s | ease-out | Quick onset of speaking |
| RESPONDING → IDLE | 1.0s | ease-out | Soft fade back to calm |
| ANY → ERROR | 0.1s | ease-out | Urgent immediate alert |

### Auto-Transitions (Timeout-Based)

| State | Timeout | Next State | Trigger |
|-------|---------|-----------|---------|
| SUCCESS | 2.0s | IDLE | Elapsed time |
| ERROR | 3.0s | IDLE | Elapsed time OR `clearError()` |

---

## Signal Priority & Concurrency

When multiple input signals are active simultaneously, the state reflects the highest-priority signal:

```
Priority (highest to lowest):
1. TTS/Speech Output (RESPONDING state)
2. API/LLM Processing (THINKING state)
3. Voice Input (LISTENING state)
4. Error (ERROR state — interrupts all, always highest)
```

**Examples:**

| Signals | Result State | Reason |
|---------|--------------|--------|
| Voice only | LISTENING | Voice is active |
| Voice + API | THINKING | API is higher priority |
| Voice + API + TTS | RESPONDING | TTS is highest priority |
| LISTENING + Error | ERROR | Error interrupts |
| THINKING + Error | ERROR | Error interrupts |
| Idle + Error | ERROR | Error interrupts |

---

## Event Sequencing Examples

### Successful Conversation Flow
```
1. User speaks → voiceOn → IDLE → LISTENING
2. System hears it → apiStart → LISTENING → THINKING
3. Response ready → ttsStart → THINKING → RESPONDING
4. Output finishes → ttsEnd → RESPONDING → IDLE
   (Optionally: success event → RESPONDING → SUCCESS → IDLE)
```

**Timeline:**
```
User's perspective:
[voice]---[thinking]---[response]-----[listening]
  0.5s      1.5s         3.0s          0.1s-2s

State transitions:
0.0s: IDLE → LISTENING (voiceOn)
0.5s: LISTENING → THINKING (apiStart)
2.0s: THINKING → RESPONDING (ttsStart)
5.0s: RESPONDING → IDLE (ttsEnd)
      or RESPONDING → SUCCESS (success event) → IDLE (auto, 2s)
```

### Error Recovery Flow
```
1. Processing started → THINKING
2. Network fails → error("Connection timeout") → ERROR
3. User sees alert, dismisses → clearError → IDLE
4. Retry initiated → voiceOn → LISTENING (restart)
```

**Timeline:**
```
1.5s: THINKING
2.0s: THINKING → ERROR (error event, 0.1s transition)
      Eyes pulse, scanlines glitch
2.5s: User dismisses error
      ERROR → IDLE (clearError event, immediate)
      or auto → IDLE (after 3s timeout)
```

### Interrupted Processing
```
1. Listening for input → LISTENING
2. API starts processing → THINKING
3. User speaks again → ERROR ("Can't process while already thinking")
4. Clear and retry → IDLE → LISTENING
```

---

## Color Transitions

Jane's glow color changes based on state severity:

### Severity Mapping
```
State → Severity → Color → Alpha
────────────────────────────
IDLE → GREEN → Cyan (#00E5FF) → 0.2
LISTENING → YELLOW → Amber (#FFD700) → 0.4
THINKING → YELLOW → Amber (#FFD700) → 0.3-0.5 (pulsing)
RESPONDING → GREEN → Cyan (#00E5FF) → 0.4
SUCCESS → GREEN → Cyan (#00E5FF) → 0.3
ERROR → RED → Hot Pink (#FF4D7F) → 0.6-0.8 (pulsing)
```

### Color Transition Times
```
Green → Yellow: 0.5s smooth fade
Yellow → Red: 0.2s snap (urgent)
Red → Green: 1.0s smooth fade (de-escalation)
```

---

## Implementation Notes

### State Machine Guarantees
1. **Deterministic** — Same state + event always produces same next state
2. **Acyclic** — No infinite loops (all paths lead to IDLE or are interrupted)
3. **Complete** — Every state has handlers for all event types
4. **Atomic** — Transitions are instantaneous (interpolation happens separately)

### Rendering Guarantees
1. **60fps minimum** — TimelineView provides hard tick
2. **No frame skipping** — All drawing operations complete < 16.7ms
3. **Smooth transitions** — Easing functions ensure no jerky movement
4. **Color consistency** — Color always matches current severity

### Observable Guarantees
1. **Property observers** — Signal changes trigger state updates automatically
2. **No missed events** — All signals buffered via @Observable
3. **Thread-safe** — All updates on MainActor
4. **Real-time** — No debouncing or throttling (phase 2 concern)

---

## Future Extensions

### Phase 2: Voice/TTS
- Add `voiceAmplitude` monitoring (0.0-1.0)
- Add `speechRate` extraction (0.5-2.0x)
- Sync mouth animation to actual speech rate

### Phase 3: Advanced Expressions
- **Emotion blending:** happy, sad, confused, excited
- **Phoneme-aware mouth:** Map phonemes to mouth shapes
- **Eye contact:** Track cursor, eyes follow (gaze)

### Phase 4: Customization
- **Config-driven:** jane-face.json controls all parameters
- **Themes:** Cyberpunk, noir, minimal, cute variants
- **Hot reload:** Update appearance without app restart

---

**Status:** IMPLEMENTED & TESTED
**Ready for:** Phase 2 (Voice/TTS Integration)
**Maintenance:** Low (pure functions, no mutable state in transitions)

---

*Generated: 2026-03-28*
*Version: 1.0 (Production-Ready)*
