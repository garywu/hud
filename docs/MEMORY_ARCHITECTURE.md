# Jane HUD Memory System — Three-Tier Architecture

**Status:** Design Document (pre-implementation)
**Target:** macOS HUD Application (Swift/SwiftUI)
**Scope:** Local SQLite database for voice/context integration

---

## Overview

Jane's memory system stores contextual information needed for voice responses, system awareness, and persistent knowledge. Three tiers provide hot/warm/cold access patterns optimized for real-time voice interaction and long-term learning.

```
┌─────────────────────────────────────────────────────────┐
│ Voice I/O Layer (Wispr Flow / Whisper + TTS)             │
│ Queries memory for context to shape responses            │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ Query Engine                                             │
│ • Fetch context for current task                        │
│ • Build response enrichment (tone, detail level)        │
│ • Update session on voice event                         │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│        Three-Tier SQLite Database                        │
│                                                          │
│ TIER 1: Recent (HOT)        — Active session context    │
│ TIER 2: Session (WARM)      — Historical sessions       │
│ TIER 3: Persistent (COLD)   — Learned facts, patterns   │
└──────────────────────────────────────────────────────────┘
```

---

## Database Schema

### Storage Location

```
~/.atlas/jane/memory.db              # Main SQLite database
~/.atlas/jane/memory-wal             # Write-ahead log (active safety)
~/.atlas/jane/memory-shm             # Shared memory index
```

**Permissions:** 0600 (user read/write only, encrypted at filesystem level via FileVault)

### Core Tables

#### Tier 1: Recent Context (HOT)

```sql
CREATE TABLE recent_context (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    type TEXT NOT NULL,                    -- 'task', 'interruption', 'focus', 'status'
    key TEXT NOT NULL,                     -- 'current_focus', 'last_command', etc.
    value TEXT NOT NULL,                   -- JSON-encoded, max 8KB
    metadata TEXT,                         -- Optional context (app name, URL, etc.)
    priority INTEGER DEFAULT 0,            -- 0=low, 1=normal, 2=high
    created_at INTEGER NOT NULL,           -- Unix timestamp
    updated_at INTEGER NOT NULL,
    expires_at INTEGER,                    -- TTL for auto-cleanup (TIER2 promotion)

    UNIQUE(session_id, type, key),
    FOREIGN KEY(session_id) REFERENCES sessions(id)
);

CREATE INDEX idx_recent_session ON recent_context(session_id);
CREATE INDEX idx_recent_expires ON recent_context(expires_at);
```

**Purpose:** In-session transient state (current focus app, open document, interruption reason, last voice query)

**Retention:** 30 minutes OR session end → moves to TIER 2

**Example rows:**
```
id: 'rc-001'
session_id: 'sess-2026-03-28-14', type: 'task', key: 'current_focus'
value: '{"app": "Cursor", "file": "memory.md", "since_seconds": 342}'
expires_at: 1743261600 (30min from now)

id: 'rc-002'
session_id: 'sess-2026-03-28-14', type: 'interruption', key: 'reason'
value: '{"type": "notification", "source": "Slack", "severity": "yellow"}'
```

---

#### Tier 2: Session History (WARM)

```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,                   -- 'sess-YYYY-MM-DD-HH'
    user_id TEXT NOT NULL,                 -- 'gary' (single user for now, multi-org later)
    started_at INTEGER NOT NULL,           -- Unix timestamp
    ended_at INTEGER,                      -- NULL if session active
    duration_minutes INTEGER,              -- Computed at session close

    -- Session summary
    autonomy_score REAL,                   -- 0–100, system liveness during session
    focus_app TEXT,                        -- Primary app used (Cursor, Terminal, etc.)
    interruptions_count INTEGER DEFAULT 0, -- Number of escalations/alerts
    voice_interactions_count INTEGER DEFAULT 0,

    -- Patterns
    mood_tag TEXT,                         -- 'focused', 'interrupted', 'exploratory', 'debugging'
    key_topics TEXT,                       -- JSON array: ["memory", "architecture", "voice"]
    decisions_made TEXT,                   -- JSON array of major decisions

    archived_at INTEGER,                   -- When promoted to TIER 3 (typically 24h later)
    PRIMARY KEY (id)
);

CREATE INDEX idx_sessions_archived ON sessions(archived_at);

-- Session observations (granular events)
CREATE TABLE session_observations (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    type TEXT NOT NULL,                    -- 'voice_input', 'escalation', 'decision', 'context_switch'
    data TEXT NOT NULL,                    -- JSON

    FOREIGN KEY(session_id) REFERENCES sessions(id)
);

CREATE INDEX idx_observation_session ON session_observations(session_id);
CREATE INDEX idx_observation_type ON session_observations(type);
```

**Purpose:** Recently-closed sessions containing decisions, patterns, mood, focus history

**Retention:** 24 hours → moves to TIER 3 (archived)

**Example rows:**
```
sessions table:
id: 'sess-2026-03-28-14'
user_id: 'gary'
started_at: 1743256200 (2026-03-28 14:00 UTC)
ended_at: 1743259800 (2026-03-28 15:00 UTC)
duration_minutes: 60
autonomy_score: 87.5
focus_app: 'Cursor'
interruptions_count: 3
voice_interactions_count: 12
mood_tag: 'focused'
key_topics: '["memory", "sqlite", "voice", "hud"]'

session_observations table:
id: 'obs-001'
session_id: 'sess-2026-03-28-14'
timestamp: 1743256500
type: 'voice_input'
data: '{"query": "what did we decide about memory tiers", "response_tone": "clear", "duration_ms": 2400}'
```

---

#### Tier 3: Persistent Knowledge (COLD)

```sql
CREATE TABLE knowledge_facts (
    id TEXT PRIMARY KEY,
    fact_type TEXT NOT NULL,               -- 'technical', 'personal', 'project', 'decision'
    category TEXT NOT NULL,                -- e.g., 'memory-systems', 'gary-preferences', 'atlas-architecture'
    key TEXT NOT NULL,                     -- Unique within category
    value TEXT NOT NULL,                   -- JSON, can be large (up to 64KB)

    -- Confidence and decay
    confidence REAL DEFAULT 0.8,           -- 0–1, how confident are we in this fact
    last_reinforced_at INTEGER,            -- Unix timestamp of last observation confirming this
    reinforcement_count INTEGER DEFAULT 1, -- Number of times observed/confirmed

    created_at INTEGER NOT NULL,
    archived_at INTEGER,                   -- When moved from TIER 2

    UNIQUE(category, key)
);

CREATE INDEX idx_knowledge_category ON knowledge_facts(category);
CREATE INDEX idx_knowledge_confidence ON knowledge_facts(confidence DESC);

-- Learned patterns (e.g., time-of-day focus, app sequences)
CREATE TABLE learned_patterns (
    id TEXT PRIMARY KEY,
    pattern_type TEXT NOT NULL,            -- 'time_of_day', 'app_sequence', 'escalation_trigger', 'recovery'
    description TEXT NOT NULL,             -- Human-readable: "Usually focused 14:00-16:00"

    condition_json TEXT NOT NULL,          -- JSON filter: {"hour_range": [14, 16], "app": "Cursor"}
    action_json TEXT,                      -- Suggested action or response

    confidence REAL DEFAULT 0.7,
    occurrence_count INTEGER DEFAULT 1,
    last_observed_at INTEGER,

    enabled BOOLEAN DEFAULT 1
);

CREATE INDEX idx_pattern_type ON learned_patterns(pattern_type);
CREATE INDEX idx_pattern_enabled ON learned_patterns(enabled);

-- Fact lineage (how facts are built from observations)
CREATE TABLE fact_lineage (
    id TEXT PRIMARY KEY,
    fact_id TEXT NOT NULL,
    source_session_id TEXT,                -- Session where this fact originated
    source_observation_id TEXT,            -- Specific observation
    confidence_delta REAL,                 -- How much this source contributed

    FOREIGN KEY(fact_id) REFERENCES knowledge_facts(id)
);

CREATE INDEX idx_lineage_fact ON fact_lineage(fact_id);
```

**Purpose:** Long-lived learned facts, patterns, and decision history

**Retention:** Indefinite, with confidence decay

**Example rows:**
```
knowledge_facts table:
id: 'kf-001'
fact_type: 'personal'
category: 'gary-preferences'
key: 'preferred_voice_tone'
value: '{"tone": "direct", "detail_level": "high", "accent": "minimal"}'
confidence: 0.92
reinforcement_count: 7
last_reinforced_at: 1743256800

learned_patterns table:
id: 'pat-001'
pattern_type: 'time_of_day'
description: 'Early morning (6-8am) = deep focus mode, minimize interruptions'
condition_json: '{"hour_range": [6, 8], "weekday": true}'
action_json: '{"suppress_notifications": true, "voice_tone": "brief", "max_response_duration_seconds": 30}'
confidence: 0.85
```

---

### Query Indices

```sql
-- Optimize voice context retrieval
CREATE INDEX idx_recent_priority_session ON recent_context(session_id, priority DESC, updated_at DESC);
CREATE INDEX idx_session_recent ON sessions(ended_at DESC) WHERE ended_at IS NOT NULL;
CREATE INDEX idx_knowledge_reinforced ON knowledge_facts(last_reinforced_at DESC) WHERE confidence > 0.7;
```

---

## Data Retention Policy

### Tier 1 → Tier 2 Promotion

**Trigger:** 30 minutes OR explicit session end

**Process:**
```
1. When session ends or timer fires:
   - Archive all recent_context rows for that session
   - Compute session summary (autonomy_score, key_topics, mood_tag)
   - Write to sessions table
   - Move detailed events to session_observations
   - TRUNCATE recent_context for expired rows
   - Compress: DELETE FROM recent_context WHERE expires_at < NOW()
```

**Code pattern:**
```swift
func promoteRecentToSession(sessionId: String) {
    let recentRows = db.query(
        "SELECT type, key, value FROM recent_context WHERE session_id = ? AND expires_at < NOW()",
        [sessionId]
    )

    // Compute summary from recentRows...
    let summary = computeSessionSummary(recentRows)

    db.insert("sessions", summary)
    db.delete("recent_context", "session_id = ? AND expires_at < NOW()", [sessionId])
}
```

### Tier 2 → Tier 3 Promotion

**Trigger:** 24 hours after session end

**Process:**
```
1. For each closed session older than 24h:
   - Extract insights from session_observations (recurring patterns, decisions)
   - Cross-reference with existing knowledge_facts
   - Create new facts with confidence ~0.7
   - Update existing facts' reinforcement_count if pattern observed again
   - Create fact_lineage rows linking observation → fact
   - Archive session: UPDATE sessions SET archived_at = NOW()
   - Move detailed observations to cold storage (archive table or separate DB)
```

### Confidence Decay (Cold Tier)

**Goal:** Facts that aren't reinforced lose confidence over time

```sql
-- Run daily
UPDATE knowledge_facts
SET confidence = confidence * 0.98
WHERE last_reinforced_at < datetime('now', '-7 days')
  AND confidence > 0.2;

-- Soft-delete very stale facts
UPDATE knowledge_facts
SET enabled = 0
WHERE confidence < 0.1
  AND last_reinforced_at < datetime('now', '-90 days');
```

### Cleanup Schedule

```
Every 30 minutes:
  - Promote expired recent_context to sessions

Every 6 hours:
  - Vacuum database (PRAGMA optimize)
  - Cleanup stale fact_lineage

Every 24 hours:
  - Promote old sessions to knowledge_facts
  - Apply confidence decay
  - Archive very old sessions to separate archive DB (optional)

Every 30 days:
  - Deep archive: Move sessions older than 90 days to read-only backup
  - Compress WAL log
```

---

## Voice Query Patterns

### Pattern 1: Context for Current Response

When voice input arrives, Jane enriches response with:

```swift
func enrichVoiceResponse(query: String) -> EnrichedContext {
    // 1. Get current session
    let currentSession = db.query(
        "SELECT id FROM sessions WHERE ended_at IS NULL ORDER BY started_at DESC LIMIT 1"
    ).first

    // 2. Fetch hot context (TIER 1)
    let hotContext = db.query(
        """
        SELECT key, value FROM recent_context
        WHERE session_id = ? AND type IN ('focus', 'task', 'interruption')
        ORDER BY priority DESC, updated_at DESC
        """,
        [currentSession.id]
    )

    // 3. Fetch warm context (TIER 2) - last session's mood/decisions
    let lastSession = db.query(
        "SELECT mood_tag, key_topics FROM sessions WHERE ended_at IS NOT NULL ORDER BY ended_at DESC LIMIT 1"
    ).first

    // 4. Fetch cold context (TIER 3) - voice tone preference, time-of-day patterns
    let voiceTone = db.query(
        "SELECT value FROM knowledge_facts WHERE category = 'gary-preferences' AND key = 'preferred_voice_tone' LIMIT 1"
    ).first

    let timeOfDayPattern = db.query(
        """
        SELECT action_json FROM learned_patterns
        WHERE pattern_type = 'time_of_day'
          AND json_extract(condition_json, '$.hour_range')
          AND enabled = 1
        LIMIT 1
        """
    ).first

    // 5. Assemble enriched context
    return EnrichedContext(
        hotState: parse(hotContext),
        lastSessionMood: lastSession?.mood_tag,
        voiceTone: parse(voiceTone?.value),
        timeOfDayGuidance: parse(timeOfDayPattern?.action_json)
    )
}
```

**Query cost:** ~3 DB operations, <50ms expected

---

### Pattern 2: Learning from Voice Interaction

After voice I/O completes, record what happened:

```swift
func recordVoiceInteraction(
    query: String,
    response: String,
    durationMs: Int,
    tone: String
) {
    let currentSession = getCurrentSession()

    // Tier 1: Update recent context
    db.insert("recent_context", [
        "id": UUID().uuidString,
        "session_id": currentSession.id,
        "type": "voice_event",
        "key": "last_query",
        "value": JSON.stringify([
            "query": query,
            "response": response,
            "tone": tone,
            "duration_ms": durationMs
        ]),
        "created_at": Int(Date().timeIntervalSince1970),
        "expires_at": Int(Date().addingTimeInterval(1800).timeIntervalSince1970) // 30min
    ])

    // Update session interaction count
    db.execute("UPDATE sessions SET voice_interactions_count = voice_interactions_count + 1 WHERE id = ?",
               [currentSession.id])

    // Tier 2: Record observation (warm storage)
    db.insert("session_observations", [
        "id": UUID().uuidString,
        "session_id": currentSession.id,
        "type": "voice_input",
        "timestamp": Int(Date().timeIntervalSince1970),
        "data": JSON.stringify([
            "query": query,
            "response_tone": tone,
            "duration_ms": durationMs,
            "category": inferCategory(query) // e.g., "memory", "debug", "question"
        ])
    ])
}
```

---

### Pattern 3: Building Learned Facts

Periodically (on session archive), extract patterns:

```swift
func extractAndLearnPatterns(session: Session) {
    let observations = db.query(
        "SELECT data, timestamp FROM session_observations WHERE session_id = ? ORDER BY timestamp ASC",
        [session.id]
    )

    // Pattern: Time-of-day focus
    let hourOfSession = Calendar.current.component(.hour, from: session.startedAt)
    if session.autonomyScore > 80 {
        db.upsert("learned_patterns", [
            "pattern_type": "time_of_day",
            "description": "High autonomy at \(hourOfSession):00",
            "condition_json": JSON.stringify(["hour_range": [hourOfSession - 1, hourOfSession + 1]]),
            "confidence": 0.75
        ])
    }

    // Pattern: App sequences
    let focusApp = session.focusApp
    let previousSession = db.query("SELECT focus_app FROM sessions WHERE ended_at < ? ORDER BY ended_at DESC LIMIT 1", [session.startedAt]).first

    if let prevApp = previousSession?.focusApp, prevApp != focusApp {
        db.upsert("learned_patterns", [
            "pattern_type": "app_sequence",
            "description": "\(prevApp) → \(focusApp)",
            "condition_json": JSON.stringify(["previous_app": prevApp]),
            "enabled": 1
        ])
    }

    // Pattern: Topic affinity
    let topics = observations
        .filter { extractCategory($0.data) == "question" }
        .map { extractTopic($0.data) }
        .grouped(by: { $0 })

    for (topic, instances) in topics {
        let existingFact = db.query(
            "SELECT id, reinforcement_count FROM knowledge_facts WHERE category = 'gary-interests' AND key = ?",
            [topic]
        ).first

        if let existing = existingFact {
            db.execute(
                "UPDATE knowledge_facts SET reinforcement_count = reinforcement_count + ?, last_reinforced_at = ? WHERE id = ?",
                [instances.count, Date().timeIntervalSince1970, existing.id]
            )
        } else {
            db.insert("knowledge_facts", [
                "id": UUID().uuidString,
                "fact_type": "personal",
                "category": "gary-interests",
                "key": topic,
                "value": JSON.stringify(["topic": topic, "instances": instances.count]),
                "confidence": 0.6,
                "created_at": Int(Date().timeIntervalSince1970)
            ])
        }
    }
}
```

---

## Integration with Voice System

### Voice Input Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. User speaks to Jane (Wispr Flow audio input)         │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 2. Transcribe (Whisper/Wispr)                           │
│    Result: query string                                 │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 3. Query Memory for Context                             │
│    enrichVoiceResponse(query) → EnrichedContext         │
│    • Recent focus (TIER 1)                              │
│    • Last session mood (TIER 2)                         │
│    • Voice tone preference (TIER 3)                     │
│    • Time-of-day pattern (TIER 3)                       │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 4. LLM Inference                                        │
│    Message = {                                          │
│      system: base_prompt +                              │
│              context.tone +                             │
│              context.current_focus,                     │
│      user: query                                        │
│    }                                                    │
│    Call Claude/API Mom with enriched context           │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 5. Generate & Synthesize (TTS)                          │
│    Response → macOS Speech Synthesis                    │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 6. Record Interaction to Memory (recordVoiceInteraction)│
│    • Update recent_context                             │
│    • Log to session_observations                        │
│    • Later: extract patterns on session archive        │
└─────────────────────────────────────────────────────────┘
```

### Pseudo-Code Integration

```swift
class VoiceHandler {
    let memoryDB = MemoryDatabase()

    func handleVoiceInput(audioData: Data) async {
        // 1. Transcribe
        let query = try await whisperAPI.transcribe(audioData)

        // 2. Enrich from memory
        let context = memoryDB.enrichVoiceResponse(query)

        // 3. Call LLM with enriched system prompt
        let systemPrompt = buildSystemPrompt(
            basePrompt: "You are Jane, Gary's AI companion...",
            tone: context.voiceTone,
            currentFocus: context.hotState.currentFocus,
            timeOfDayGuidance: context.timeOfDayGuidance
        )

        let response = try await claudeAPI.complete(
            system: systemPrompt,
            user: query
        )

        // 4. Synthesize
        let audio = try macOSSpeechSynthesis.synthesize(response)
        audioOutput.play(audio)

        // 5. Record for learning
        let durationMs = Int(audioData.count / 16000 * 1000) // rough estimate
        memoryDB.recordVoiceInteraction(
            query: query,
            response: response,
            durationMs: durationMs,
            tone: context.voiceTone["tone"] ?? "neutral"
        )
    }
}
```

---

## Security & Encryption

### Filesystem Sandbox

```
~/.atlas/jane/
├── memory.db           (SQLite, 0600)
├── memory-wal          (write-ahead log, 0600)
├── memory-shm          (shared memory, 0600)
└── backups/
    └── memory-YYYY-MM-DD.db.bak (daily, 0600)
```

**FileVault Integration:**
- Directory lives in user home (`~/.atlas/`) — covered by macOS FileVault encryption
- Database file permissions: 0600 (user read/write only)
- Consider adding column-level encryption for sensitive fields later (SQLCipher)

### Sensitive Data Handling

**Fields to encrypt (phase 2):**
- `voice_input` transcriptions (contains spoken text)
- `user_queries` (Personally Identifiable Information)
- `decision_context` (strategic/private decision notes)

**Approach:**
```swift
// Phase 2: Add SQLCipher integration
// import SQLCipher
let db = try Database(path: dbPath)
try db.execute("PRAGMA key = '\(encryptionKey)'")  // Key from Keychain
```

### Data Minimization

**What NOT to store:**
- Raw voice audio (transcribe, discard audio immediately)
- Full LLM responses (store only summary/category)
- Sensitive credentials (use 1Password integration, store only reference)
- Personal health/financial data (outside scope initially)

---

## Storage Strategy: MacOS Sandbox

### App Sandbox Entitlements

```xml
<!-- AtlasHUD.entitlements -->
<dict>
    <!-- File access -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.home-relative-read-write</key>
    <array>
        <string>.atlas/jane/</string>
    </array>

    <!-- Network: needed for API Mom, Claude calls -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Microphone: for voice input -->
    <key>com.apple.security.device.microphone</key>
    <true/>
</dict>
```

### Database Location Rationale

**Why `~/.atlas/jane/` (not Application Support)?**
- `.atlas/` is the established data dir for Atlas ecosystem
- User home provides broader file access for future features
- Easier to share with shell scripts, CLI tools, other apps
- Backup-friendly (standard home backup includes `~/`)

**Alternative (sandboxed):**
```
~/Library/Application Support/com.atlas.HUD/jane/memory.db
```
Less convenient but more sandbox-compliant.

---

## Estimated Implementation Effort

### Phase 1: Core Infrastructure (20–30 hours)

- [ ] SQLite wrapper in Swift (10h)
  - CRUD operations
  - Connection pooling
  - Error handling

- [ ] Schema creation & migrations (5h)
  - CREATE TABLE statements
  - Index creation
  - Version tracking

- [ ] Tier 1 (Recent) implementation (8h)
  - `recent_context` table operations
  - TTL management
  - 30-minute promotion flow

- [ ] Testing & validation (5h)
  - Unit tests for schema
  - Integration test: write/read cycle
  - Concurrent access test

### Phase 2: Tier 2 & 3 + Voice Integration (25–35 hours)

- [ ] Session management (6h)
  - `sessions` table CRUD
  - `session_observations` logging
  - Session summary computation

- [ ] Knowledge learning (8h)
  - `knowledge_facts` table operations
  - `learned_patterns` extraction
  - Confidence decay logic

- [ ] Voice integration (12h)
  - `enrichVoiceResponse()` function
  - `recordVoiceInteraction()` logging
  - System prompt enrichment
  - Voice context in LLM calls

- [ ] Testing (5h)
  - Voice-to-memory flow tests
  - Pattern extraction validation
  - Query performance benchmarks

### Phase 3: Advanced Features (20–25 hours)

- [ ] Data retention & cleanup (6h)
  - Promotion scheduler
  - Garbage collection
  - Archival strategy

- [ ] Encryption (SQLCipher) (8h)
  - Keychain integration
  - Key rotation
  - Migration from unencrypted DB

- [ ] UI/Monitoring (6h)
  - Memory stats display (in HUD panel)
  - Database health checks
  - Debug query interface

- [ ] Documentation & tooling (5h)
  - Query examples
  - Migration scripts
  - Admin utilities (reset, export, backup)

### Total Estimate: 65–90 hours

**Timeline:** ~2–3 sprints (2 weeks @ 20h/week)

**Parallelizable:** Phase 1 & early Phase 2 can overlap; Phase 3 is dependent.

---

## Success Metrics

1. **Voice latency:** Memory queries < 100ms p99
2. **Context richness:** Voice responses reference appropriate prior context in >80% of cases
3. **Learning accuracy:** Extracted patterns match actual Gary behavior (e.g., time-of-day focus > 85% accuracy)
4. **Data freshness:** Hot tier (TIER 1) always fresh; warm tier (TIER 2) < 24h old
5. **Storage efficiency:** Database stays < 500MB for 2+ months of continuous use
6. **Reliability:** Zero data loss over 1-month trial (backups + WAL)

---

## Future Enhancements

- **Multi-session queries:** "What did we decide last week about memory?"
- **Cross-device sync:** Replicate facts to iOS Jane app
- **Confidence-aware responses:** "I'm 85% sure you prefer..."
- **Memory timeline UI:** Browse session history in HUD panel
- **Fact export:** Export learned patterns to brain/Research/ markdown
- **Differential learning:** Only learn patterns that deviate from baseline
- **Uncertainty quantification:** Show confidence ranges in voice responses

---

## References

- **MemGPT:** Long-context memory system for LLMs (Patel et al., 2023)
- **SQLite PRAGMA optimize:** Database performance tuning
- **Jane Protocol:** `~/.claude/CLAUDE.md` (notification channels, Telegram integration)
- **HUD Architecture:** `/Users/admin/Work/atlas/apps/hud/AtlasHUD/` (existing Swift code)
- **macOS App Sandbox:** Apple Security Framework documentation
- **Whisper/Wispr:** OpenAI transcription, Wispr Flow for local inference

