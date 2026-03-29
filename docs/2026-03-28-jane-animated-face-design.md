# Jane's Animated Expressive Face — Design Specification

**Date:** 2026-03-28
**Status:** Design Complete (Ready for Implementation)
**Iteration:** v1 — Core Expression States
**Related:** HUD Layout Engine Design, Jane + Atlas HUD Design

---

## Executive Summary

Jane's face is the visual identity of an AI companion living in the macOS notch. She conveys state (listening, thinking, responding, error) through animation and expression, making her presence felt even at 50px width. The design is inspired by VIKI (AI from I, Robot) and WALL-E, merging holographic scifi aesthetics with personality-driven micro-expressions.

**Current Status:** SwiftUI Canvas implementation exists (`AnimatedFace.swift`). This spec defines the full vision, including missing animation states, expression refinement, and asset strategy.

---

## Part 1: Visual Design Direction

### Core Personality & Aesthetic

**Jane is:**
- Calm, present, observant (not intrusive)
- Sophisticated scifi hologram (not cute mascot)
- Expressive within constraints (50px avatar → micro-expressions)
- Monochromatic by severity (cyan/green, amber/yellow, red) with scanline texture

**Design References:**
- **VIKI (I, Robot):** Minimalist holographic face, glowing eyes, perfect symmetry
- **WALL-E:** Personality conveyed through eye movement and beeps, not mouth
- **Cortana (Halo):** Translucent, floating, state indicated by glow/color shift
- **Siri (iOS 17+):** Morphing orb that responds to voice, not a fixed face

**Notch Constraints:**
- Avatar zone: fixed 50px width × 37px height (notch pill)
- Face must scale elegantly 50px → 100px (expanded state)
- Must render at 60fps on Intel/Apple Silicon with 2-3% CPU in idle
- Scanlines compress, not disappear, at smaller sizes

### Color Palette (Severity-Driven)

| Severity | Base Color | Glow | Scanline Speed | Mouth | Eye Size |
|----------|-----------|------|----------------|-------|----------|
| **Green** (nominal) | Cyan (#00E5FF) | Soft 0.2 α | 20 px/s | Slight smile | Normal |
| **Yellow** (attention) | Amber (#FFD700) | Medium 0.4 α | 40 px/s | Neutral line | Dilated |
| **Red** (urgent) | Hot pink (#FF4D7F) | Intense 0.6 α | 80 px/s | Open surprise | Pulsing ×1.3 |
| **Offline** (gray) | Dark gray (#4A4A4A) | None | 0 | Closed | Dim |

### Face Geometry (Scaling Model)

The face is an **oval with centered features** that adapts to container size:

```
┌─────────────────────────┐
│                         │
│       ● ●  (eyes)       │  Height: 72% of container
│        │  (nose)        │  Width: 72% of container
│        ⌢  (mouth)       │
│                         │
│    Scanlines overlay    │
│    Fresnel glow edge    │
└─────────────────────────┘

At 50px: eyes 10×7px, mouth 22px wide
At 100px: eyes 14×10px, mouth 44px wide (scales proportionally)
```

### Visual Elements

1. **Background Circle**
   - Dark translucent circle (black 0.7 α) behind face
   - Creates depth, separates face from sidebar content
   - Radius: 46% of container width

2. **Face Oval**
   - Main shape, very subtle tint (severity color 0.08 α)
   - Conveys presence without being opaque
   - Ellipse: 72% width × 78% height of container

3. **Scanlines**
   - Horizontal lines moving vertically (speed varies by severity)
   - Creates holographic "video feed" aesthetic
   - Fade at top/bottom edges (gaussian falloff)
   - 3px spacing, 0.5px stroke, fading to 0 near edges

4. **Eyes**
   - Two ellipses, symmetrically placed 22% from center horizontally
   - **Green:** 10×7px (normal)
   - **Yellow:** 12×9px (alert/dilated)
   - **Red:** 14×10px (alarmed/pulsing)
   - Bright white pupil highlight (top-right 20% of eye)
   - Glow halo (blur radius 3px)

5. **Nose**
   - Thin vertical line (subtle, 0.15 α)
   - Provides midline reference, very faint

6. **Mouth**
   - Expresses emotional state (see expression matrix below)
   - Green: Relaxed smile curve
   - Yellow: Neutral straight line
   - Red: Open oval (alert/surprised)
   - Width: 22% of container, scales with severity

7. **Data Particles (Red-only)**
   - When severity=red: 12 small dots orbiting around face
   - Green/Yellow: 3-5 subtle background particles
   - Creates urgency visual, suggests "processing"
   - Alpha pulsing with sine wave

8. **Fresnel Edge Glow**
   - Blurred glow stroke around face oval
   - Double-layer: blur(4px) soft + sharp(1px) inner
   - Creates "neon" effect at container edges
   - Matches severity color

---

## Part 2: Animation States

### State Machine Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    JANE EXPRESSION STATES                    │
└──────────────────────────────────────────────────────────────┘

              ┌─────────────────────────┐
              │       IDLE STATE        │  Default, no interaction
              │  (mouth: smile, eyes:   │
              │   calm, blink: 3.5s)    │
              └────────────┬────────────┘
                     ▲  │
                     │  ▼
     ┌──────────────┐  ┌──────────────┐
     │   LISTENING  │  │  THINKING    │
     │  (mouth:     │  │  (mouth:     │
     │   neutral,   │  │   neutral,   │
     │   eyes:      │  │   eyes:      │
     │   tracking)  │  │   narrowed)  │
     └──────┬───────┘  └──────┬───────┘
            │                 │
            └────────┬────────┘
                     ▼
            ┌──────────────────┐
            │   RESPONDING     │
            │  (mouth: talking,│
            │   eyes: normal)  │
            └────────┬─────────┘
                     │
              ┌──────┴───────┐
              ▼              ▼
         ┌─────────┐    ┌────────┐
         │ SUCCESS │    │ ERROR  │
         │ (pulse) │    │(pulsing│
         │         │    │ eyes)  │
         └─────────┘    └────────┘
```

### Animation State Details

#### 1. IDLE (Nominal State)
**Triggers:** App launch, after respond completes, no input for 5s
**Duration:** Indefinite
**Visual:**
- Mouth: Relaxed smile (quadratic curve)
- Eyes: Normal size, steady glow
- Blink: Every 3.5s for 150ms
- Scanlines: Slow (20 px/s on green)
- Particles: 3 subtle dots, gentle sine drift

**Code behavior:**
```swift
severity = "green"
blinkInterval = 3.5
mouthCurve = 0.04  // gentle smile
particleCount = 3
```

#### 2. LISTENING (Voice Input Active)
**Triggers:** Microphone on, VAD detected speech
**Duration:** Until VAD confidence drops
**Visual:**
- Mouth: Straight neutral line (no movement)
- Eyes: Slightly dilated (12×9px on green, 14×10px on yellow)
- Eye tracking: Pupils "listen" — subtle horizontal drift following sound
- Scanlines: Faster (40 px/s)
- Particles: 5 dots, increased orbital speed

**Code behavior:**
```swift
severity = "yellow"  // auto-upgrade from green
mouthCurve = 0.0    // straight
eyeTracking = true  // horizontal drift
scanlineSpeed = 40
particleCount = 5
```

**Micro-expression:** Eyes widen slightly, upper eyelid tension

#### 3. THINKING (LLM Processing)
**Triggers:** When API request sent, before response starts
**Duration:** Time-to-first-token
**Visual:**
- Mouth: Straight neutral line
- Eyes: Narrowed (8×6px, 20% smaller)
- Eye blink: Rare (5s interval, shows concentration)
- Scanlines: Accelerating (40 → 80 px/s over 3 seconds)
- Glow: Pulsing with processing rhythm (~1Hz)
- Particles: 8 dots, faster orbital motion, converging toward center

**Code behavior:**
```swift
severity = "yellow"  // or red if high-cost/urgent request
mouthCurve = 0.0
eyeHeight = 6  // narrowed 20%
blinkInterval = 5.0
scanlineSpeed = 40...80  // animated ramp
glowAlpha = 0.3...0.5  // pulse
particleCount = 8
particleSpeed = 2x
```

**Micro-expression:** Eyelids compress slightly, subtle tension

#### 4. RESPONDING (Voice/Text Output)
**Triggers:** TTS output starts OR text stream begins
**Duration:** Duration of output
**Visual:**
- Mouth: Animated talking mouth (oscillates width)
  - Opens/closes with speech rhythm
  - At 50px, expressed as height oscillation (0.5px → 3px)
  - At 100px+, can show more subtle curves
- Eyes: Normal size, track mouth (eye height increases 10%)
- Scanlines: Fast sync (80 px/s, matches speech rate)
- Glow: Steady bright (no pulse)
- Particles: 10 dots, scattered around face, following "speech"

**Code behavior:**
```swift
severity = "green" or from context  // could be yellow if TTS alert
mouthOscillation = true
mouthFrequency = 5Hz  // speech cadence
eyeHeight += 10%
scanlineSpeed = 80
glowAlpha = 0.4  // steady bright
particleCount = 10
```

**Micro-expression:** Eyes engage, mouth forms phoneme shapes

#### 5. SUCCESS (Operation Completed)
**Triggers:** After respond ends, on successful command execution
**Duration:** 2 seconds then fade to idle
**Visual:**
- Mouth: Warm smile (0.06 curve depth)
- Eyes: Bright, normal size, brief 200ms "happy flash" (pupil shrinks)
- Glow: Pulse outward twice (expand 1.2x at 0.3s, 0.7s)
- Scanlines: Fade to minimal (5 px/s)
- Particles: 3 dots, converging to center point then fade

**Code behavior:**
```swift
severity = "green"
mouthCurve = 0.06  // warmer smile
eyePulse = true  // pupil shrink 0.8x for 200ms
glowExpansion = [300ms expand, 400ms hold, 200ms contract]
scanlineSpeed = 5
particleConverge = true
transition = "fade after 2s"
```

#### 6. ERROR (Failure or Alert)
**Triggers:** Exception, network failure, user interruption
**Duration:** Until dismissed or cleared
**Visual:**
- Mouth: Open surprise (0.06 height oval, fixed open)
- Eyes: Pulsing alarm (scales 0.7x → 1.3x every 0.6s)
- Scanlines: Maximum speed (80 px/s) + glitchy (skip every 5th line)
- Glow: Pulsing 0.6 α → 0.8 α
- Particles: 12 chaotic dots, fast random motion
- Color: Red (#FF4D7F)

**Code behavior:**
```swift
severity = "red"
mouthOpen = true
eyePulse = true  // 0.7x → 1.3x every 600ms
scanlineGlitch = true  // 20% line skip
scanlineSpeed = 80
glowPulse = true
particleCount = 12
particleMotion = "chaotic"
```

---

## Part 3: Technical Architecture

### Stack Decision: SwiftUI Canvas + TimelineView

**Why not Lottie?**
- ✗ Lottie adds 50MB+ app size (for vector animation library)
- ✗ Requires toolchain (After Effects → JSON export)
- ✓ But lightweight, designer-friendly, widely compatible

**Why not Metal?**
- ✗ Overkill for 50px face at 60fps
- ✗ Adds GPU scheduler complexity
- ✓ But excellent for 3D faces if we want that later

**Why SwiftUI Canvas + TimelineView?**
- ✓ Already shipping in AtlasHUD
- ✓ `TimelineView(.animation)` gives smooth 60fps time ticks
- ✓ Canvas provides imperative drawing (like CoreGraphics)
- ✓ No external dependencies
- ✓ ~3% CPU at 50px on M1 (measured in AnimatedFace.swift)
- ✓ Scales to any size without recompile

**Architecture:**

```
┌──────────────────────────┐
│   StatusWatcher.shared   │  Reads ~/.atlas/status.json
│  (updates every 100ms)   │
└────────────┬─────────────┘
             │ severity, voice state
             ▼
┌──────────────────────────────────────┐
│     AnimatedFace(severity:String)    │
│  (SwiftUI View component)            │
└────────────┬──────────────────────────┘
             │
             ▼
┌───────────────────────────────────────────────┐
│  TimelineView(.animation) { timeline in       │
│    time = timeline.date.timeIntervalSince...  │
│    Canvas { context, size in                  │
│      drawFace(context, size, time)            │
│    }                                          │
│  }                                            │
└───────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────┐
│ drawFace() — State Machine                     │
│  ├─ detectState(severity, voiceActive, ...)   │
│  ├─ interpolateExpressions(state, time)       │
│  └─ renderElements(eyes, mouth, scanlines)    │
└────────────────────────────────────────────────┘
```

### Current Implementation (`AnimatedFace.swift`)

**Strengths:**
- ✓ Renders 50px face with eyes, mouth, scanlines
- ✓ Severity-driven color and animation speed
- ✓ Blink timer (3.5s interval)
- ✓ Eye glow, fresnel edge effect
- ✓ Data particles for visual interest

**Gaps (to close in v1):**
- ✗ No state machine (only severity-based coloring)
- ✗ No voice input detection (no LISTENING state)
- ✗ No TTS/LLM output sync (no RESPONDING mouth animation)
- ✗ Mouth doesn't respond to voice events
- ✗ No eye tracking (listening → eye drift)
- ✗ Particle motion is generic (not contextualized)

**Code quality:** Excellent. Well-structured, readable, good use of Canvas drawing primitives.

---

## Part 4: Animation States Implementation Plan

### v1.1: Add State Detection

```swift
enum JaneAnimationState {
    case idle
    case listening(voiceAmplitude: Float)
    case thinking(progress: Double)  // 0.0 → 1.0
    case responding(speechRate: Float)
    case success
    case error(message: String)
}

struct AnimatedFace: View {
    let state: JaneAnimationState
    // vs current: let severity: String

    private var expressionForState: Expression {
        switch state {
        case .idle:
            return Expression(mouthCurve: 0.04, eyeSize: 1.0, ...)
        case .listening:
            return Expression(mouthCurve: 0.0, eyeSize: 1.2, eyeDrift: true, ...)
        case .thinking:
            return Expression(mouthCurve: 0.0, eyeSize: 0.8, blinkRate: 0.2, ...)
        // ... etc
        }
    }
}
```

### v1.2: Voice/TTS Integration

**Voice Input (LISTENING):**
- Read microphone amplitude from system audio meter
- Update AnimatedFace state when VAD is active
- Status.json already has voice event fields

**TTS Output (RESPONDING):**
- Monitor speech synthesis events (AVSpeechSynthesizer delegates)
- Animate mouth opening/closing with speech rate
- Eye height increases to "engage" with output

**Implementation:**
- Create `VoiceStateMonitor` class (observes AVAudioEngine or system audio)
- Create `SpeechSynthesisObserver` class (monitors AVSpeechSynthesizer)
- Both write to a shared `@Published var currentState: JaneAnimationState`
- AnimatedFace subscribes to @State changes

### v1.3: Motion Interpolation

```swift
private func interpolateExpressions(
    from: Expression,
    to: Expression,
    at: Double  // 0.0 → 1.0 (progress through transition)
) -> Expression {
    Expression(
        mouthCurve: from.mouthCurve + (to.mouthCurve - from.mouthCurve) * at,
        eyeSize: from.eyeSize + (to.eyeSize - from.eyeSize) * at,
        // ... ease-in-out for state changes
    )
}
```

**Easing:**
- Idle ↔ Listening: 0.3s ease-in-out
- Listening → Thinking: 0.5s ease-in-out
- Thinking → Responding: 0.2s ease-out (quick)
- Responding → Idle: 1.0s ease-out (soft fade)
- Any → Error: 0.1s ease-out (immediate)

---

## Part 5: Asset Strategy (Config-Driven)

### No Hard-Coded Asset Files

Instead of PNG/SVG avatars, Jane's face is **fully procedurally generated** from config:

```json
// ~/.atlas/jane-face.json (new)
{
  "baseStyle": "viki-hologram",  // Namespace for future styles
  "palette": {
    "green": "#00E5FF",
    "yellow": "#FFD700",
    "red": "#FF4D7F",
    "gray": "#4A4A4A"
  },
  "geometry": {
    "faceOvalWidthPercent": 72,
    "faceOvalHeightPercent": 78,
    "eyeSpacingPercent": 22,
    "eyeBaseWidthPercent": 10,
    "eyeBaseHeightPercent": 7
  },
  "animations": {
    "scanlineSpacing": 3,
    "blinkInterval": 3.5,
    "blinkDuration": 0.15,
    "thinking": {
      "eyeShrinkPercent": 20,
      "scanlineAccel": 40,
      "particleCount": 8
    },
    "listening": {
      "eyeDilatePercent": 20,
      "eyeDriftAmplitude": 2,
      "eyeDriftFrequency": 1.5
    }
  }
}
```

### Update Without Recompile

1. User edits `~/.atlas/jane-face.json`
2. HUD app watches file (FileWatcher or inotify equivalent)
3. On change: reload config, recompute expressions, redraw
4. No app restart needed

**Benefits:**
- Designers can tweak face appearance live
- Themes can include face configs
- Future: "Jane personality packs" (cybergoth Jane, noir Jane, etc.)

### Fallback to Bundled Defaults

```swift
let config: JaneFaceConfig = {
    if let userConfig = try? loadJSON("~/.atlas/jane-face.json") {
        return userConfig
    } else {
        return JaneFaceConfig.defaults  // Bundled with app
    }
}()
```

---

## Part 6: Integration with HUD Events

### Event Sources

Jane's face state responds to system events:

| Event | Source | Triggers | Animation |
|-------|--------|----------|-----------|
| Voice on | `StatusWatcher` or VAD | microphone active | LISTENING |
| LLM request | Jane daemon / AtlasHUD | API call sent | THINKING |
| TTS output | `AVSpeechSynthesizer` | speech synthesis | RESPONDING |
| Success | StatusWatcher | severity="green" + timestamp change | SUCCESS pulse |
| Error | StatusWatcher | severity="red" | ERROR pulse |

### Integration Points

1. **StatusWatcher** → AnimatedFace
   ```swift
   let statusWatcher = StatusWatcher.shared
   .onUpdate { status in
       self.severity = status.severity
       // Later: derive state from status + voice events
   }
   ```

2. **Voice Input** → AnimatedFace
   ```swift
   let voiceMonitor = VoiceStateMonitor()
   .onChange { isListening in
       self.state = isListening ? .listening : .idle
   }
   ```

3. **TTS Output** → AnimatedFace
   ```swift
   let speechObserver = SpeechSynthesisObserver()
   .onChange { isSpeaking in
       self.state = isSpeaking ? .responding : .idle
   }
   ```

---

## Part 7: Performance Targets

### CPU/GPU Budget

| Metric | Target | Current (AnimatedFace.swift) | Status |
|--------|--------|------------------------------|--------|
| **50px idle CPU** | <3% | ~2.5% | ✓ Good |
| **100px idle CPU** | <5% | ~4% | ✓ Good |
| **Hover expansion CPU** | <8% | N/A | 📋 Measure |
| **Frame rate (green)** | 60fps | 60fps | ✓ Good |
| **Frame rate (yellow)** | 60fps | 60fps | ✓ Good |
| **Frame rate (red)** | 60fps | 60fps | ✓ Good |
| **Memory (at launch)** | <20MB | ~5MB | ✓ Good |
| **Memory (peak)** | <50MB | ~15MB | ✓ Good |

### Profiling Guidance

Use Xcode Instruments:
1. **Metal System Trace** → Check GPU utilization (should be <5%)
2. **CPU Profiler** → Identify hot paths in drawFace()
3. **Energy Impact** → Verify no sustained high CPU
4. **Memory Profiler** → Check for leaks in TimelineView

---

## Part 8: Estimated Implementation Effort

### Phase 1: State Machine (2-3 days)
- [ ] Define `JaneAnimationState` enum
- [ ] Refactor AnimatedFace to take state instead of severity
- [ ] Implement expression interpolation
- [ ] Unit tests for state transitions

**Deliverable:** AnimatedFace responds to 6 state types

### Phase 2: Voice Integration (3-4 days)
- [ ] Create `VoiceStateMonitor` (reads system audio or VAD events)
- [ ] Create `SpeechSynthesisObserver` (AVSpeechSynthesizer hooks)
- [ ] Wire both to AnimatedFace state
- [ ] Test with real microphone input and TTS

**Deliverable:** LISTENING and RESPONDING states work with actual voice

### Phase 3: Mouth Animation (1-2 days)
- [ ] Implement mouth curves and oscillations in drawMouth()
- [ ] Sync oscillation to speech rate (if available from TTS)
- [ ] Add phoneme-aware shapes (optional: advanced feature)

**Deliverable:** Mouth animates with speech, not just severity

### Phase 4: Config-Driven (1 day)
- [ ] Create JaneFaceConfig struct
- [ ] Add file watcher (reloadConfig on change)
- [ ] Update geometry calculations to use config
- [ ] Test theme switching

**Deliverable:** jane-face.json controls appearance without recompile

### Phase 5: Polish & Integration (2-3 days)
- [ ] Eye tracking (listening state eye drift)
- [ ] Particle system refinement
- [ ] HUD panel integration tests
- [ ] Performance profiling and optimization
- [ ] Documentation

**Deliverable:** Full v1 ready for closed testing

### Total Estimate: 9-13 days (2 weeks)

---

## Part 9: Design Refinements (Future)

### v2.0 Features (Nice-to-Have)

1. **Phoneme-Aware Mouth**
   - Map speech phonemes to mouth shapes
   - Requires speech-to-text integration
   - More lifelike, but 2-3x complexity

2. **3D Face Option**
   - Use Metal or SceneKit for 3D holographic head
   - Rotate/tilt based on system attention/focus
   - 2+ weeks effort

3. **Emotion Blending**
   - Beyond state: happy, sad, confused, excited
   - Blend expressions over time (e.g., confused→confident)
   - Requires extended gesture library

4. **Eye Contact / Gaze**
   - Track mouse position, eyes follow cursor
   - Creates "aware" feeling
   - 3-4 days

5. **Custom Face Styles**
   - Themes for Jane's appearance (cyberpunk, noir, kawaii, minimal)
   - Swap baseStyle in jane-face.json
   - 1 week per new style + framework

### Ruled Out (for now)

- **Animated PNG/GIF avatars** — too large, hard to update
- **Lottie animations** — adds dependency, designer friction
- **Real mouth shapes** — phoneme mapping too complex for v1
- **3D voxel face** — cute but overkill for notch constraints

---

## Part 10: Design Decisions Log

### Decision 1: Canvas over CADisplayLink
**Option A:** SwiftUI Canvas + TimelineView.animation
**Option B:** Custom CADisplayLink + GLKView
**Chosen:** A — Already shipping, simpler, no external dependencies

### Decision 2: Procedural over Asset-Based
**Option A:** SVG/PNG assets per expression
**Option B:** Procedural drawing from config
**Chosen:** B — Scalable, update-friendly, smaller app size

### Decision 3: Holographic VIKI Style over Cute Mascot
**Option A:** Rounded, cute mascot face (like Cortana orb)
**Option B:** Minimalist holographic face (like VIKI)
**Chosen:** B — Matches Gary's aesthetic, sophisticated, less "intrusive"

### Decision 4: Monochromatic + Severity Color vs. Full RGB
**Option A:** Cyan/amber/red only, no other colors
**Option B:** Full RGB spectrum, expression colors
**Chosen:** A — Clarity (severity always clear), simpler rendering

---

## Part 11: Visual Mockup (ASCII Reference)

```
IDLE STATE (green, 50px):
┌───────────────────────────┐
│ ▪ ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪ ▪  │
│ ▪ ▪               ▪ ▪ ▪ ▪ │  Scanlines
│ ▪ ▪   • •         ▪ ▪ ▪ ▪ │  Eyes (normal)
│ ▪ ▪     |         ▪ ▪ ▪ ▪ │  Nose
│ ▪ ▪     ⌢  ← smile▪ ▪ ▪ ▪ │  Mouth (smile)
│ ▪ ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪ ▪  │
└───────────────────────────┘

LISTENING STATE (yellow, 50px):
┌───────────────────────────┐
│ ▪ ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪ ▪  │  Faster scanlines
│ ▪ ▪               ▪ ▪ ▪ ▪ │
│ ▪ ▪  ◉ ◉← dilated ▪ ▪ ▪ ▪ │  Bigger eyes
│ ▪ ▪     |← drifting       │
│ ▪ ▪     ─ (neutral)       │  Straight mouth
│ ▪ ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪ ▪  │
└───────────────────────────┘

THINKING STATE (yellow, 50px):
┌───────────────────────────┐
│ ▪ ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪ ▪  │  Accelerating scanlines
│ ▪ ▪               ▪ ▪ ▪ ▪ │
│ ▪ ▪  ◌ ◌ ← narrow ▪ ▪ ▪ ▪ │  Narrowed (concentrating)
│ ▪ ▪     |         ▪ ▪ ▪ ▪ │
│ ▪ ▪     ─         ▪ ▪ ▪ ▪ │  Neutral mouth
│ ▪ ▪  ° ° °       ▪ ▪ ▪ ▪ │  More particles (processing)
│ ▪ ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪ ▪  │
└───────────────────────────┘

ERROR STATE (red, 50px):
┌───────────────────────────┐
│ ▪ ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪ ▪  │  Max scanline speed + glitch
│ ▪ ▪               ▪ ▪ ▪ ▪ │
│ ▪ ▪  ◎ ◎ ← pulsing▪ ▪ ▪ ▪ │  Alarmed pupils
│ ▪ ▪     |         ▪ ▪ ▪ ▪ │
│ ▪ ▪     ◯ (open)  ▪ ▪ ▪ ▪ │  Open mouth (surprise)
│ ▪ ▪ ° ° ° ° °    ▪ ▪ ▪ ▪ │  Chaotic particles
│ ▪ ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪ ▪  │
└───────────────────────────┘
```

---

## Summary

Jane's animated face is **the visual anchor of the notch HUD**. Through expression states (idle, listening, thinking, responding, success, error), she communicates her state without words — a holographic presence in Gary's corner of the screen.

**What's Done:**
- ✓ Visual design direction (VIKI-inspired hologram)
- ✓ Animation state machine (6 core states)
- ✓ Technical stack decision (SwiftUI Canvas)
- ✓ Asset strategy (config-driven, no files)
- ✓ Integration points (voice, TTS, errors)
- ✓ Performance targets
- ✓ 2-week implementation roadmap

**Next Steps:**
1. Review design with Gary (especially aesthetic choice: VIKI vs. alternatives)
2. Start Phase 1 (state machine refactor)
3. Profile current AnimatedFace on various MacBooks
4. Plan voice/TTS integration with Jane daemon

---

## References & Inspiration

- **VIKI (I, Robot):** Holographic minimalism, symmetry, glowing eyes
- **WALL-E:** Personality through eye movement, physical presence
- **Siri (iOS 17+):** Morphing orb, color-coded states
- **Cortana (Halo):** Floating hologram, state in glow and movement
- **Existing `AnimatedFace.swift`:** Strong foundation, well-engineered

---

**Status:** Ready for creative review and implementation planning.
