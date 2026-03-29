# Jane's Face — Visual Reference Card

Quick lookup for designers and implementers.

---

## State Transition Matrix

```
IDLE ──(voice on)──> LISTENING ──(api call)──> THINKING
                          │                         │
                          └─────────────────────────┘
                                    │
                            (response received)
                                    ▼
                               RESPONDING
                                    │
                        ┌───────────┴───────────┐
                   (success)              (error)
                        │                       │
                        ▼                       ▼
                      SUCCESS                 ERROR
                        │                       │
                    (2s timeout)           (3s timeout)
                        │                       │
                        └───────────┬───────────┘
                                    ▼
                                   IDLE
```

---

## Expression Parameters by State

### IDLE
```
mouthCurve:     0.04    (relaxed smile)
eyeSize:        1.0x    (normal)
eyeHeight:      7px     (normal)
blinkRate:      3.5s    (normal, 150ms blinks)
scanlineSpeed:  20 px/s (slow)
particleCount:  3       (subtle)
glowAlpha:      0.2     (calm)
color:          cyan    (#00E5FF)
duration:       ∞       (indefinite)
easing:         n/a     (steady state)
```

### LISTENING
```
mouthCurve:     0.0     (neutral straight line)
eyeSize:        1.2x    (dilated, alert)
eyeHeight:      9px     (wider)
eyeDrift:       true    (horizontal ±2px @ 1.5Hz)
blinkRate:      3.5s    (normal, shows focus)
scanlineSpeed:  40 px/s (faster)
particleCount:  5       (increased)
glowAlpha:      0.4     (engaged)
color:          amber   (#FFD700) — upgrade from green
duration:       until VAD drops
easing:         0.3s ease-in from IDLE
```

### THINKING
```
mouthCurve:     0.0     (neutral)
eyeSize:        0.8x    (narrowed, concentrating)
eyeHeight:      6px     (compressed)
eyeDrift:       false   (focused, no drift)
blinkRate:      5.0s    (rare, shows concentration)
scanlineSpeed:  40→80 px/s (animated acceleration)
glowPulse:      true    (subtle pulse 0.3→0.5 @ 1Hz)
particleCount:  8       (busy)
particleMotion: converging toward center
color:          amber   (#FFD700) or red if urgent
duration:       TTF (time-to-first-token)
easing:         0.5s ease-in from LISTENING
```

### RESPONDING
```
mouthCurve:     0.0     (neutral baseline)
mouthOscillation: true  (amplitude ±0.03 height)
mouthFrequency: 5 Hz    (matches speech rate)
eyeSize:        1.1x    (engaged, engaged with output)
eyeHeight:      7.5px   (slightly raised, 10% boost)
eyeDrift:       false   (focused on output)
blinkRate:      10s     (rare while speaking)
scanlineSpeed:  80 px/s (fast)
particleCount:  10      (busy/processing)
particleMotion: scattered, responsive to speech
glowAlpha:      0.4     (steady bright)
color:          green or from context (#00E5FF)
duration:       duration of TTS/stream
easing:         0.2s ease-out from THINKING
```

### SUCCESS
```
mouthCurve:     0.06    (warm smile, deeper than idle)
eyeSize:        1.0x    (normal)
eyeHeight:      7px     (normal)
pupilFlash:     true    (pupil shrinks to 0.8x for 200ms)
blinkRate:      normal  (allows smile to show)
scanlineSpeed:  5 px/s  (minimal, peaceful)
glowExpand:     true    (pulse outward at 300ms, 700ms)
particleMotion: converge to center, fade
color:          green   (#00E5FF)
duration:       2s then fade to IDLE
easing:         none (immediate from RESPONDING)
transition:     fade-out 1s to IDLE
```

### ERROR
```
mouthCurve:     0.0     (neutral baseline)
mouthOpen:      true    (fixed open oval, 0.06 height)
eyeSize:        1.3x    (alarmed, maximum size during pulse)
eyeHeight:      10px    (fully open)
eyePulse:       true    (oscillates 0.7x → 1.3x @ 0.6s)
blinkRate:      disabled (eyes stay open)
scanlineSpeed:  80 px/s (maximum)
scanlineGlitch: true    (skip every 5th line @ 20% opacity)
glowPulse:      true    (0.6 → 0.8 @ 0.8s)
particleCount:  12      (maximum)
particleMotion: chaotic (random direction/speed)
color:          red     (#FF4D7F)
duration:       until dismissed
easing:         0.1s ease-out (immediate alert)
clearTrigger:   user clicks or 3s auto-timeout
```

---

## Color Palette

| State | Color | Hex | RGB | Usage |
|-------|-------|-----|-----|-------|
| Green (nominal) | Cyan | #00E5FF | (0, 229, 255) | IDLE, RESPONDING, SUCCESS |
| Yellow (alert) | Amber | #FFD700 | (255, 215, 0) | LISTENING, THINKING |
| Red (urgent) | Hot Pink | #FF4D7F | (255, 77, 127) | ERROR |
| Offline | Dark Gray | #4A4A4A | (74, 74, 74) | When Jane daemon unreachable |

### Color Transitions
- Green → Yellow: 0.5s fade
- Yellow → Red: 0.2s snap (urgent)
- Red → Green: 1.0s fade (de-escalation)
- Any → Offline: 0.3s fade (loss of connection)

---

## Size Scaling Model

| Container | Eyes | Eye Distance | Mouth Width | Scanline Spacing |
|-----------|------|--------------|-------------|------------------|
| 50px | 10×7 | 11px | 11px | 3px |
| 75px | 12×8.5 | 16.5px | 16.5px | 3px |
| 100px | 14×10 | 22px | 22px | 4px |
| 150px | 21×15 | 33px | 33px | 4px |

**Formula:**
- Eye width: container_width × 0.20
- Eye height: container_height × 0.19
- Eye distance from center: container_width × 0.22
- Mouth width: container_width × 0.22
- Scanline spacing: 3px (clamped, doesn't scale)

---

## Animation Timings

| Animation | Duration | Easing | Loop |
|-----------|----------|--------|------|
| Blink (IDLE) | 150ms | ease-in-out | 3.5s interval |
| Blink (LISTENING) | 150ms | ease-in-out | 3.5s interval |
| Blink (THINKING) | 150ms | ease-in-out | 5s interval |
| Blink (ERROR) | disabled | n/a | n/a |
| Mouth oscillate (RESPONDING) | 200ms | sine | 5Hz (20ms per cycle) |
| Eye pulse (ERROR) | 600ms | sine | 0.6s period |
| Glow pulse (THINKING) | 1000ms | sine | 1s period |
| Glow pulse (ERROR) | 800ms | sine | 0.8s period |
| Glow expand (SUCCESS) | 300ms + 400ms | ease-out | once then fade |
| Particle float | variable | sine/perlin | continuous |
| State transition | 0.2-1.0s | ease-in-out | once per change |

---

## Scanline Behavior

| State | Speed | Glitch | Opacity Falloff | Notes |
|-------|-------|--------|-----------------|-------|
| IDLE | 20 px/s | none | gaussian | calm |
| LISTENING | 40 px/s | none | gaussian | attentive |
| THINKING | 40→80 px/s | none | gaussian | accelerating |
| RESPONDING | 80 px/s | none | gaussian | fast |
| SUCCESS | 5 px/s | none | gaussian | peaceful |
| ERROR | 80 px/s | 20% skip | gaussian | alarmed |

**Opacity formula:** `alpha = max(0, 1 - (distance_from_center / face_radius)²)`

---

## Particle System

| State | Count | Speed | Pattern | Opacity | Notes |
|-------|-------|-------|---------|---------|-------|
| IDLE | 3 | 15 px/s | orbital sine | 0.15 α | subtle background |
| LISTENING | 5 | 20 px/s | scattered | 0.20 α | active listening |
| THINKING | 8 | 30 px/s | converge center | pulsing | processing |
| RESPONDING | 10 | 25 px/s | scattered | 0.25 α | engaged speech |
| ERROR | 12 | 50 px/s | chaotic | 0.30 α | alarm mode |
| SUCCESS | fade | → 0 | converge center | fade out | celebration |

**Particle size:** 2px diameter (constant across all states)

---

## Mouth Shapes (Visual)

```
IDLE / SUCCESS (smile):
    ⌢  (quadratic curve, depth 0.04-0.06)

LISTENING / THINKING / RESPONDING (neutral/oscillating):
    ─  (straight line, or oscillating ─ ⌢ ─ ⌢)

ERROR (alarm):
    ◯  (open oval, fixed height, no movement)
```

---

## Eye Expressions

```
IDLE:
    • •  (normal size, calm glow)

LISTENING:
    ◉ ◉  (dilated, +20%, drifting ±2px horizontally)

THINKING:
    ◌ ◌  (narrowed, -20%, focused)

RESPONDING:
    ● ●  (engaged, normal with increased glow)

ERROR:
    ◎ ◎  (alarmed, pulsing 0.7x → 1.3x, max glow)
```

All eyes have white pupil highlight (top-right 20% of iris).

---

## Performance Targets

| Metric | Target | Threshold |
|--------|--------|-----------|
| 50px idle | <3% CPU | Fail if >4% |
| 100px idle | <5% CPU | Fail if >7% |
| 100px yellow | <6% CPU | Fail if >8% |
| 100px red | <8% CPU | Fail if >10% |
| Frame rate | 60fps | Never drop below 55fps |
| Memory (steady state) | <20MB | Fail if >30MB |
| Memory peak | <50MB | Fail if >70MB |
| Time to first frame | <100ms | Fail if >150ms |

---

## Configuration (jane-face.json)

```json
{
  "baseStyle": "viki-hologram",
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
    "eyeBaseHeightPercent": 7,
    "noseHeightPercent": 6,
    "mouthWidthPercent": 22
  },
  "animations": {
    "scanlineSpacing": 3,
    "scanlineOpacity": 0.06,
    "blinkIntervalIdle": 3.5,
    "blinkIntervalThinking": 5.0,
    "blinkDuration": 0.15,
    "listening": {
      "eyeDilatePercent": 20,
      "eyeDriftAmplitude": 2,
      "eyeDriftFrequency": 1.5,
      "scanlineSpeed": 40,
      "particleCount": 5
    },
    "thinking": {
      "eyeShrinkPercent": 20,
      "scanlineAccel": [40, 80],
      "particleCount": 8,
      "glowPulseFrequency": 1.0
    },
    "responding": {
      "mouthOscillationFrequency": 5,
      "mouthOscillationAmplitude": 0.03,
      "eyeEngagementPercent": 10,
      "scanlineSpeed": 80,
      "particleCount": 10
    },
    "error": {
      "eyePulseFrequency": 1.667,
      "eyePulseRange": [0.7, 1.3],
      "scanlineSpeed": 80,
      "scanlineGlitchPercent": 20,
      "particleCount": 12,
      "glowPulseFrequency": 1.25
    }
  }
}
```

---

## Troubleshooting Quick Reference

| Issue | Cause | Fix |
|-------|-------|-----|
| Face doesn't blink | Blink timer not started | Call `startBlinkTimer()` on appear |
| Mouth doesn't move | RESPONDING state not triggered | Check SpeechSynthesisObserver |
| Eyes don't dilate | LISTENING state not detected | Check VoiceStateMonitor |
| Scanlines glitch at red | Intentional! | No fix needed, feature working |
| High CPU on yellow | Particle count too high | Reduce in config, check scanline speed |
| Face looks blurry | Canvas rendering issue | Verify frame rate with Instruments |
| Color wrong | Severity not updated | Check StatusWatcher reading status.json |
| Config not applied | File watcher failed | Restart app, check file permissions |

---

## Design Rationale

**Why VIKI over Cortana orb?**
- VIKI is minimalist (5-6 geometric shapes)
- Cortana is soft/organic (harder to scale to 50px)
- VIKI reads well at tiny sizes with high contrast

**Why holographic scanlines?**
- Signals "data being processed" (scifi trope)
- Adds visual interest without adding complexity
- Frequency communicates urgency (slow = calm, fast = alarm)

**Why eye dilation in LISTENING?**
- Pupil dilation is involuntary sign of attention in humans
- Signals Jane is "hearing" and engaged

**Why narrowed eyes in THINKING?**
- Squinting/concentration is universal expression
- Signals cognitive effort

**Why particles?**
- Represents "processing" or "data flow"
- Chaotic particles = alarm, ordered particles = calm
- Subtle enough not to distract, visible enough to notice

---

**Last Updated:** 2026-03-28
**Version:** 1.0 (Design Complete)
