# Jane Memory System — Quick Reference

**Document:** MEMORY_ARCHITECTURE.md (read for full design)

---

## Three Tiers at a Glance

| Tier | Name | Table(s) | Lifetime | Access Speed | Use Case |
|------|------|----------|----------|--------------|----------|
| **1** | Recent (HOT) | `recent_context` | 30 min | ~10ms | Current focus, active interruptions |
| **2** | Session (WARM) | `sessions`, `session_observations` | 24h | ~20ms | Last meeting, decisions, mood |
| **3** | Persistent (COLD) | `knowledge_facts`, `learned_patterns`, `fact_lineage` | ∞ (decay) | ~50ms | Voice tone preference, time-of-day patterns |

---

## Voice Query Flow (Fastest Path)

```
Query arrives → enrichVoiceResponse() → Select from 3 tiers → Assemble context
    ↓                                        ↓
  Wispr                              TIER1 (10ms)
                                     TIER2 (20ms)
                                     TIER3 (30ms)
                                     ↓
                                  Total ~50ms
                                     ↓
                               Send to Claude
```

---

## Key Tables

### TIER 1: recent_context
```
┌─ type: 'focus', 'task', 'interruption', 'status'
├─ key: 'current_focus', 'last_command'
├─ value: JSON (max 8KB)
├─ priority: 0–2 (high sorts first)
└─ expires_at: TTL, 30min default
```

**Example:** What app is Gary in right now?
```sql
SELECT value FROM recent_context
WHERE type = 'focus' AND expires_at > NOW()
ORDER BY updated_at DESC LIMIT 1;
```

### TIER 2: sessions + session_observations
```
sessions:
├─ id: 'sess-YYYY-MM-DD-HH'
├─ autonomy_score: 0–100
├─ mood_tag: 'focused', 'interrupted', 'exploratory'
└─ key_topics: JSON array

session_observations:
├─ type: 'voice_input', 'escalation', 'decision'
└─ data: JSON with details
```

**Example:** What's Gary's mood right now?
```sql
SELECT mood_tag FROM sessions
WHERE ended_at IS NULL ORDER BY started_at DESC LIMIT 1;
```

### TIER 3: knowledge_facts + learned_patterns
```
knowledge_facts:
├─ category: 'gary-preferences', 'gary-interests', 'technical'
├─ key: 'preferred_voice_tone'
├─ confidence: 0–1 (decay if not reinforced)
└─ value: JSON

learned_patterns:
├─ pattern_type: 'time_of_day', 'app_sequence', 'escalation_trigger'
├─ condition_json: When to apply
└─ action_json: What to do
```

**Example:** What voice tone should I use?
```sql
SELECT value FROM knowledge_facts
WHERE category = 'gary-preferences' AND key = 'preferred_voice_tone'
AND confidence > 0.7 LIMIT 1;
```

---

## Retention & Promotion Schedule

```
TIER 1 (30 min)
    ├─ Hot: Actively used
    └─ Expires → TIER 2 (session_observations)

TIER 2 (24 hours)
    ├─ Warm: Session closed, observations intact
    └─ Archived → TIER 3 (knowledge_facts, learned_patterns)

TIER 3 (infinite)
    ├─ Cold: Learned facts, patterns
    └─ Decay: Confidence -= 2% per 7 days if not reinforced
```

**Automatic processes:**
- **Every 30 min:** Promote expired TIER 1 → TIER 2
- **Every 6h:** Vacuum, cleanup old lineage
- **Every 24h:** Promote sessions → TIER 3, apply confidence decay

---

## Voice Integration (High-Level)

```swift
// 1. Memory enriches LLM context
let context = memoryDB.enrichVoiceResponse(userQuery)

// 2. Build system prompt with context
let systemPrompt = """
You are Jane, Gary's AI companion...
Tone preference: \(context.voiceTone)
Current focus: \(context.hotState.currentFocus)
Time-of-day guidance: \(context.timeOfDayGuidance)
"""

// 3. Call Claude
let response = await claudeAPI.message(systemPrompt, userQuery)

// 4. Speak response
await tts.synthesize(response)

// 5. Record for learning
memoryDB.recordVoiceInteraction(query, response, durationMs: ...)
```

---

## Storage

```
~/.atlas/jane/
├── memory.db       (SQLite, 0600, FileVault encrypted)
├── memory-wal      (write-ahead log)
├── memory-shm      (shared memory)
└── backups/
    └── memory-YYYY-MM-DD.db.bak (daily)
```

**Entitlements needed:**
```xml
<key>com.apple.security.files.home-relative-read-write</key>
<array><string>.atlas/jane/</string></array>
```

---

## Query Performance Targets

- **Hot context (TIER 1):** < 10ms (in-memory-like)
- **Warm context (TIER 2):** < 20ms (single session lookup)
- **Cold context (TIER 3):** < 50ms (full-table scans on small set)
- **Combined:** < 100ms p99 from voice input to LLM enrichment ready

**Indices to hit these:**
```sql
CREATE INDEX idx_recent_priority_session ON recent_context(session_id, priority DESC, updated_at DESC);
CREATE INDEX idx_session_recent ON sessions(ended_at DESC);
CREATE INDEX idx_knowledge_confidence ON knowledge_facts(confidence DESC);
```

---

## Example: "What was my focus yesterday?"

```swift
let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
let sessions = memoryDB.query("""
    SELECT focus_app, autonomy_score, mood_tag, duration_minutes
    FROM sessions
    WHERE date(started_at, 'unixepoch') = date(?, 'unixepoch')
    ORDER BY started_at DESC
    """, [Int(yesterday.timeIntervalSince1970)])

// Returns: [
//   {focus_app: "Cursor", autonomy_score: 92, mood_tag: "focused", duration_minutes: 240},
//   {focus_app: "Terminal", autonomy_score: 78, mood_tag: "debugging", duration_minutes: 45}
// ]
```

---

## Implementation Phases

| Phase | What | Effort | Duration |
|-------|------|--------|----------|
| **1** | SQLite wrapper, TIER 1, schema | 20–30h | 1 week |
| **2** | TIER 2, TIER 3, voice integration | 25–35h | 1 week |
| **3** | Encryption, retention, monitoring | 20–25h | 1 week |
| **Total** | | **65–90h** | **2–3 weeks** |

**Parallelizable:** Phase 1 & 2 can overlap. Phase 3 is polish.

---

## Success Metrics

1. Memory query latency < 100ms p99
2. Voice responses reference prior context > 80% of the time
3. Extracted patterns match actual behavior > 85% accuracy
4. Zero data loss over 1-month trial
5. Database size < 500MB for 2+ months usage

---

## Dependencies & Tools

**Required:**
- Swift 5.9+ (macOS 13+)
- SQLite3 (built-in macOS)
- Claude API / API Mom
- Whisper/Wispr (transcription)
- macOS Speech Synthesis (TTS)

**Optional (Phase 3+):**
- SQLCipher (encryption)
- Keychain (key storage)

---

## Security Checklist

- [x] File permissions: 0600 (~/.atlas/jane/*)
- [x] FileVault coverage: lives in home directory
- [ ] Encryption: Phase 2+ (SQLCipher)
- [ ] Data minimization: Don't store raw audio
- [ ] Keychain integration: Phase 2+ for encryption keys
- [ ] Backup strategy: Daily backups to ~/.atlas/jane/backups/

---

**For full architecture, design decisions, and code examples, see MEMORY_ARCHITECTURE.md**
