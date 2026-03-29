# Jane's Animated Face — Implementation Checklist

**Phase:** v1 Core Expression States
**Timeline:** 2 weeks (9-13 days estimated)
**Current Status:** Design complete, ready for Phase 1

---

## Phase 1: State Machine Refactor (2-3 days)

### Code Changes
- [ ] Create `JaneAnimationState` enum in AnimatedFace.swift
  ```swift
  enum JaneAnimationState {
      case idle
      case listening(voiceAmplitude: Float)
      case thinking(progress: Double)
      case responding(speechRate: Float)
      case success
      case error(message: String)
  }
  ```

- [ ] Create `Expression` struct
  ```swift
  struct Expression {
      var mouthCurve: CGFloat
      var eyeSize: CGFloat
      var eyeHeight: CGFloat
      var eyeDrift: Bool
      var blinkRate: Double
      var scanlineSpeed: Double
      var particleCount: Int
      var glowAlpha: CGFloat
      // ... other animation parameters
  }
  ```

- [ ] Refactor `AnimatedFace` to take `state: JaneAnimationState` instead of `severity: String`

- [ ] Implement `expressionForState(_ state: JaneAnimationState) -> Expression`

- [ ] Implement state transition easing in `drawFace()`

### Testing
- [ ] Unit test: each state produces correct Expression
- [ ] Unit test: state transitions ease smoothly
- [ ] Preview: all 6 states in Xcode Canvas
- [ ] Manual: test each state visual at 50px and 100px

### Deliverable
- AnimatedFace component accepts JaneAnimationState
- All 6 expression states visual and working
- State transitions smooth (0.3-1.0s ease-in-out)

---

## Phase 2: Voice Integration (3-4 days)

### Create VoiceStateMonitor
- [ ] New file: `VoiceStateMonitor.swift`
  - Detect system microphone activity (via AVAudioEngine or system audio)
  - Emit `@Published var isListening: Bool` changes
  - Update frequency: 100ms (smooth transitions)

- [ ] Options for voice detection:
  - Option A: Hook into AVAudioEngine and read input buffer amplitude
  - Option B: Poll system audio level (if available via Core Audio)
  - Option C: Use existing VAD from Jane daemon or local runner

- [ ] Handle microphone permissions gracefully

### Create SpeechSynthesisObserver
- [ ] New file: `SpeechSynthesisObserver.swift`
  - Monitor AVSpeechSynthesizer.delegate events
  - Track `didStart` / `didFinish` / `didPause`
  - Estimate speech rate from word duration
  - Emit `@Published var speechState: SpeechState`

  ```swift
  enum SpeechState {
      case idle
      case speaking(rate: Float)  // words per second
      case paused
  }
  ```

### Wire to AnimatedFace
- [ ] Create `JaneStateCoordinator` to merge voice/speech/severity into JaneAnimationState
  ```swift
  class JaneStateCoordinator: ObservableObject {
      @Published var state: JaneAnimationState = .idle

      @StateObject var voiceMonitor = VoiceStateMonitor()
      @StateObject var speechObserver = SpeechSynthesisObserver()
      // ... also watch StatusWatcher for severity

      private func updateState() {
          if speechObserver.speechState != .idle {
              state = .responding(speechRate: rate)
          } else if voiceMonitor.isListening {
              state = .listening(amplitude: amplitude)
          } else if /* thinking */ {
              state = .thinking(progress: 0.5)
          } else {
              state = .idle
          }
      }
  }
  ```

- [ ] Update AnimatedFace to use JaneStateCoordinator

### Testing
- [ ] Manual: speak into microphone, see LISTENING state
- [ ] Manual: trigger TTS, see RESPONDING state with mouth movement
- [ ] Manual: verify state priority (speaking > listening > thinking > idle)
- [ ] Edge case: rapid state changes (toggle mic on/off quickly)

### Deliverable
- VoiceStateMonitor + SpeechSynthesisObserver working
- LISTENING state animates with voice input
- RESPONDING state animates with speech output
- State priority respected

---

## Phase 3: Mouth Animation (1-2 days)

### Enhance drawMouth()
- [ ] Extend current static curves with animation parameters
- [ ] Add idle smile (quadratic curve, 0.04 depth)
- [ ] Add listening neutral (straight line, 0.0)
- [ ] Add thinking neutral (straight line, 0.0)
- [ ] Add responding oscillation
  ```swift
  let oscillation = sin(time * speechRate * 2 * .pi)
  let mouthHeight = oscillation * 0.03  // oscillates 0.03 in each direction
  ```

- [ ] Add success smile (warmer, 0.06 depth)
- [ ] Add error alarm (open oval, fixed height)

### Phoneme Preview (optional, v2)
- [ ] Document how to add phoneme shapes later
- [ ] No implementation in v1 (defer to Phase 5 polish)

### Testing
- [ ] Manual: idle mouth is subtle smile
- [ ] Manual: listening mouth is flat
- [ ] Manual: responding mouth opens/closes with speech
- [ ] Manual: error mouth stays open
- [ ] Visual: mouth scales properly at 50px and 100px

### Deliverable
- Mouth expression updates with state changes
- Speaking mouth oscillates with speech rate
- All state-specific mouth shapes working

---

## Phase 4: Config-Driven (1 day)

### Create JaneFaceConfig
- [ ] New file: `JaneFaceConfig.swift`
  - Struct matching jane-face.json schema
  - Codable for JSON serialization
  - Fallback to bundled defaults

- [ ] Default config (bundled)
  ```swift
  static let defaults: JaneFaceConfig = JaneFaceConfig(
      palette: [...],
      geometry: [...],
      animations: [...]
  )
  ```

### File Watcher
- [ ] New file: `JaneFaceConfigWatcher.swift`
  - Watch `~/.atlas/jane-face.json` for changes
  - Use FileWatcher or NSFileCoordinator
  - On change: reload config, invalidate cached values

- [ ] Update AnimatedFace to use config values
  - `faceOval` dimensions from config
  - Eye spacing/size from config
  - Scanline spacing from config
  - Colors from config.palette

### Create ~/.atlas/jane-face.json Template
- [ ] Generate default jane-face.json if missing
- [ ] Include in app bundle, copy on first launch

### Testing
- [ ] Manual: edit jane-face.json, verify changes render live
- [ ] Manual: delete jane-face.json, verify fallback to defaults
- [ ] Manual: invalid JSON handled gracefully with error log

### Deliverable
- jane-face.json drives appearance
- Changes apply without restart
- Config file can be version-controlled (theme support)

---

## Phase 5: Polish & Integration (2-3 days)

### Eye Tracking (Listening State)
- [ ] Implement `eyeDrift` parameter in Expression
- [ ] In LISTENING: eyes drift left/right with sine wave
  ```swift
  let driftAmount = eyeDriftAmplitude * sin(time * eyeDriftFrequency * 2 * .pi)
  let pupilX = ex + driftAmount
  ```
- [ ] Test: eyes track during listening

### Particle System Refinement
- [ ] Separate particle behavior per state
- [ ] IDLE: 3 gentle orbiting dots
- [ ] LISTENING: 5 scattered dots, increased speed
- [ ] THINKING: 8 dots converging toward center
- [ ] RESPONDING: 10 dots scattered, responsive to speech rate
- [ ] ERROR: 12 chaotic dots, no pattern

- [ ] Implement parametric particle motion
  ```swift
  struct ParticleConfig {
      var count: Int
      var speed: Double
      var pattern: ParticlePattern  // orbit, scatter, converge, chaos
  }
  ```

### Eye Emotion (Optional)
- [ ] Implement pupil dilation / constriction based on state
- [ ] THINKING: pupils shrink 20%
- [ ] ERROR: pupils pulse (0.7x → 1.3x)
- [ ] SUCCESS: brief pupil flash (happy expression)

### HUD Panel Integration
- [ ] Verify AnimatedFace renders correctly in NotchPillContent
- [ ] Test expansion animation (50px → expanded width)
- [ ] Test color transitions (green → yellow → red)
- [ ] Verify no performance regression on expansion

### Performance Profiling
- [ ] Profile 50px idle: target <3% CPU
- [ ] Profile 100px idle: target <5% CPU
- [ ] Profile expanded (yellow): target <8% CPU
- [ ] Profile red: verify no CPU spike
- [ ] Memory: verify no leaks in 1hr continuous use

### Documentation
- [ ] Update AnimatedFace.swift comments
- [ ] Document Expression struct and state machine
- [ ] Add integration guide for Voice/Speech observers
- [ ] Add troubleshooting section (common issues)

### Testing
- [ ] Integration: all states work together in HUD
- [ ] Integration: severity changes don't break animation
- [ ] Regression: existing NotchPill content still renders
- [ ] Performance: no jank on older Macs (Intel i7)

### Deliverable
- v1.0 feature-complete
- All 6 animation states + transitions working
- Voice input and TTS output integrated
- Config-driven appearance
- Performance meets targets
- Ready for closed testing with Gary

---

## Testing Matrix

### Unit Tests (Phase 1-2)
| Test | Module | Passes |
|------|--------|--------|
| State enum compiles | AnimatedFace | ✓ |
| Expression interpolation | AnimatedFace | ✓ |
| Voice monitor detects audio | VoiceStateMonitor | ✓ |
| Speech observer tracks TTS | SpeechSynthesisObserver | ✓ |
| State coordinator priority | JaneStateCoordinator | ✓ |

### Integration Tests (Phase 3-5)
| Test | Scenario | Passes |
|------|----------|--------|
| Idle rendering | Show idle face, no input | ✓ |
| Listening | Mic on → LISTENING state | ✓ |
| Thinking | API call → THINKING state | ✓ |
| Responding | TTS starts → RESPONDING state | ✓ |
| Success | Command finishes → SUCCESS pulse | ✓ |
| Error | Exception → ERROR alarm | ✓ |
| State transition | IDLE → LISTENING → IDLE | ✓ |
| Config reload | Edit jane-face.json, verify change | ✓ |
| Performance (50px) | Idle CPU <3% for 5 min | ✓ |
| Performance (100px) | Idle CPU <5% for 5 min | ✓ |

### Manual Testing (Phase 5)
- [ ] Speak into mic, watch eyes dilate and track
- [ ] Run speech synthesis, watch mouth move with words
- [ ] Trigger error, watch eyes pulse and mouth open
- [ ] Switch between green/yellow/red severity
- [ ] Expand/collapse notch, verify face scales
- [ ] Test on Intel i7 MacBook Pro 13" (2019)
- [ ] Test on M1 Mac mini
- [ ] Test on M3 MacBook Pro 16" (verify no overkill animation)

---

## Dependencies

### External Libraries (None new!)
- SwiftUI (already used)
- Combine (already used)
- AVFoundation (for SpeechSynthesisObserver) — standard library

### Internal Dependencies
- StatusWatcher (already exists)
- NotchWindow / NotchPillView (already exist)
- HUD layout engine (being built separately)

### System Frameworks
- CoreAudio (optional, for VoiceStateMonitor alternative)
- AppKit (already used)

---

## File Structure After v1

```
atlas/apps/hud/AtlasHUD/
├── AnimatedFace.swift          (refactored, ~400 lines)
├── JaneAnimationState.swift    (new, ~30 lines)
├── Expression.swift            (new, ~50 lines)
├── JaneStateCoordinator.swift  (new, ~80 lines)
├── VoiceStateMonitor.swift     (new, ~120 lines)
├── SpeechSynthesisObserver.swift (new, ~100 lines)
├── JaneFaceConfig.swift        (new, ~150 lines)
├── JaneFaceConfigWatcher.swift (new, ~80 lines)
├── NotchWindow.swift           (unchanged)
├── NotchPillContent.swift      (unchanged)
└── ... other files

~/.atlas/
├── jane-face.json              (new, user-editable config)
└── status.json                 (existing, drives severity)
```

---

## Blockers & Risks

### Known Blockers
None — all dependencies already in codebase.

### Risk: Voice Input Permission
- **Issue:** AVAudioEngine might require recording permission
- **Mitigation:** Request at app startup, fallback to VAD from Jane daemon
- **Timeline:** Handle in Phase 2

### Risk: Speech Rate Estimation
- **Issue:** AVSpeechSynthesizer doesn't expose word rate directly
- **Mitigation:** Estimate from utterance duration or use phoneme callback
- **Timeline:** Implement in Phase 3 with fallback

### Risk: Config File Conflicts
- **Issue:** User edits jane-face.json while HUD is running
- **Mitigation:** Use file locks, catch JSON parse errors gracefully
- **Timeline:** Handle in Phase 4

---

## Success Criteria

### v1.0 Launch Checklist
- [ ] All 6 animation states rendering correctly
- [ ] Voice input detection working (LISTENING state active)
- [ ] TTS output sync working (RESPONDING mouth movement)
- [ ] Config-driven appearance (jane-face.json controls face)
- [ ] Performance: <3% CPU at 50px idle
- [ ] Performance: <8% CPU in red alarm state
- [ ] Zero CPU spike on state changes
- [ ] No memory leaks over 1hr continuous use
- [ ] Scales correctly on Intel and Apple Silicon
- [ ] Code reviewed and merged to main
- [ ] Ready for Gary's testing

---

## Estimated Timeline

| Phase | Tasks | Days | Status |
|-------|-------|------|--------|
| 1 | State machine | 2-3 | 📋 Planned |
| 2 | Voice integration | 3-4 | 📋 Planned |
| 3 | Mouth animation | 1-2 | 📋 Planned |
| 4 | Config-driven | 1 | 📋 Planned |
| 5 | Polish & test | 2-3 | 📋 Planned |
| **Total** | **All** | **9-13** | **Ready to start** |

---

**Next Step:** Review design direction with Gary, then start Phase 1 implementation.
