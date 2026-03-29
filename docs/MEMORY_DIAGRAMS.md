# Jane Memory System — Visual Diagrams

## Three-Tier Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                     Voice I/O Layer                           │
│  (Wispr Flow / Whisper input → LLM → macOS TTS output)       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │  enrichVoiceResponse(query)    │
        │  Fetch context for current     │
        │  voice interaction             │
        └────────────────┬───────────────┘
                         │
        ┌────────────────┴───────────────┐
        │                                │
        ▼                                ▼
   ┌─────────────┐              ┌──────────────────┐
   │  TIER 1     │              │  TIER 2          │
   │  (HOT)      │              │  (WARM)          │
   │             │              │                  │
   │ RECENT      │              │  SESSIONS        │
   │ CONTEXT     │              │  OBSERVATIONS    │
   │             │              │                  │
   │ ~10ms       │              │  ~20ms           │
   │             │              │                  │
   │ ┌─────────┐ │              │ ┌──────────────┐ │
   │ │current_ │ │              │ │mood_tag      │ │
   │ │focus    │ │              │ │key_topics    │ │
   │ │         │ │              │ │autonomy_     │ │
   │ │last_cmd │ │              │ │score         │ │
   │ │         │ │              │ │              │ │
   │ │interrupt│ │              │ │voice_inter_  │ │
   │ │_reason  │ │              │ │action_count  │ │
   │ └─────────┘ │              │ └──────────────┘ │
   └─────────────┘              └──────────────────┘
        │                               │
        │        ┌──────────────────────┘
        │        │
        │        ▼
        │   ┌─────────────────────┐
        │   │  TIER 3             │
        │   │  (COLD)             │
        │   │                     │
        │   │  KNOWLEDGE FACTS    │
        │   │  LEARNED PATTERNS   │
        │   │  FACT LINEAGE       │
        │   │                     │
        │   │  ~50ms              │
        │   │                     │
        │   │ ┌─────────────────┐ │
        │   │ │preferred_voice_ │ │
        │   │ │tone: 0.92 conf  │ │
        │   │ │                 │ │
        │   │ │time_of_day:     │ │
        │   │ │6-8am = focus    │ │
        │   │ │0.85 conf        │ │
        │   │ │                 │ │
        │   │ │app_sequence:    │ │
        │   │ │Cursor→Terminal  │ │
        │   │ │0.72 conf        │ │
        │   │ └─────────────────┘ │
        │   └─────────────────────┘
        │        │
        └────────┼──────────────────────┐
                 │                      │
                 ▼                      ▼
        ┌──────────────────┐  ┌─────────────────┐
        │ Enrich LLM       │  │ Record to Memory│
        │ System Prompt    │  │ (Learning)      │
        │                  │  │                 │
        │ + voice_tone     │  │ recordVoiceInt()│
        │ + current_focus  │  │ updates TIER 1  │
        │ + time_of_day_   │  │ logs TIER 2     │
        │   guidance       │  │ learns TIER 3   │
        └─────────┬────────┘  └────────┬────────┘
                  │                    │
                  ▼                    │
        ┌──────────────────┐           │
        │ Call Claude API  │           │
        │ (with context)   │           │
        └─────────┬────────┘           │
                  │                    │
                  ▼                    │
        ┌──────────────────┐           │
        │ TTS Synthesis    │           │
        │ Play Response    │           │
        └──────────────────┘           │
                                       │
                                       ▼
                                ┌──────────────────┐
                                │ Database Updated │
                                │ (Voice event)    │
                                └──────────────────┘
```

## Data Promotion Flow (Retention Lifecycle)

```
TIER 1 (Hot Storage)               TIER 2 (Warm Storage)              TIER 3 (Cold Storage)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

recent_context                     sessions                           knowledge_facts
  ├─ type: 'focus'                  ├─ id: 'sess-YYYY-MM-DD-HH'        ├─ category: 'gary-preferences'
  ├─ key: 'current_focus'           ├─ started_at: timestamp           ├─ key: 'preferred_voice_tone'
  ├─ value: JSON (app, file)        ├─ ended_at: timestamp             ├─ value: JSON
  ├─ expires_at: NOW() + 30min       ├─ autonomy_score: 0-100           ├─ confidence: 0-1 (decays)
  └─ priority: 0-2                  ├─ mood_tag: 'focused'             └─ reinforcement_count: N
                                    ├─ key_topics: JSON array
     │                              ├─ decisions_made: JSON            learned_patterns
     │ 30 min expires/              │                                   ├─ pattern_type: 'time_of_day'
     │ session end                  └─ archived_at: NULL               ├─ condition_json: filters
     │                                                                   ├─ action_json: behavior
     ▼                              session_observations               ├─ confidence: 0-1

  DELETE after                      ├─ type: 'voice_input'             └─ enabled: boolean
  archiving to TIER 2               ├─ data: JSON (query, response)
                                    └─ timestamp: Unix timestamp        fact_lineage
                                                                        ├─ fact_id: references kf
     │                              │                                  ├─ source_session_id: link
     │                              │ 24 hours / session end            └─ confidence_delta: +0.1
     │ (TTL expires)                │
     │                              ▼
     │                            UPDATE sessions
     │                            SET archived_at = NOW()
     │                            WHERE ended_at < NOW() - 24h
     │
     ▼                              │
  INSERT INTO                       │
  session_observations             ▼
  (archive what was in           extractAndLearnPatterns()
   TIER 1 for this session)      ├─ Extract patterns from observations
                                 ├─ Update reinforcement counts
  DELETE FROM                    ├─ Create new facts (confidence 0.6–0.7)
  recent_context                 └─ Create fact_lineage rows
  WHERE expires_at < NOW()
                                    │
                                    ▼ (Ongoing)
                                 UPDATE knowledge_facts
                                 SET confidence *= 0.98
                                 WHERE last_reinforced_at < 7 days ago

                                    │
                                    │ (Month: soft-delete stale)
                                    ▼
                                 UPDATE knowledge_facts
                                 SET confidence = 0
                                 WHERE confidence < 0.1
                                   AND last_reinforced_at < 90 days
```

## Database Schema Relationships

```
┌─────────────────────────────┐
│      sessions               │  (TIER 2: Session metadata)
├─────────────────────────────┤
│ id (PK)                     │
│ user_id                     │
│ started_at                  │
│ ended_at                    │ ◄─┐
│ duration_minutes            │   │
│ autonomy_score              │   │
│ mood_tag                    │   │
│ key_topics (JSON)           │   │
│ decisions_made (JSON)       │   │
│ archived_at                 │   │
└────────────────┬────────────┘   │
                 │                │ FK
                 │                │
          ┌──────┴──────┐         │
          │ (1:many)    │         │
          ▼             ▼         │
┌──────────────────────────────┐ │
│ session_observations         │ │
├──────────────────────────────┤ │
│ id (PK)                      │ │
│ session_id (FK) ────────────────┘
│ timestamp                    │
│ type (voice_input, etc.)     │
│ data (JSON)                  │
└──────────────────────────────┘
         │
         │ (also FK to)
         ▼
┌──────────────────────────────┐
│ recent_context               │  (TIER 1: Current session state)
├──────────────────────────────┤
│ id (PK)                      │
│ session_id (FK)              │
│ type                         │
│ key                          │
│ value (JSON)                 │
│ priority                     │
│ expires_at (TTL)             │
└──────────────────────────────┘


┌──────────────────────────────┐
│ knowledge_facts              │  (TIER 3: Learned facts)
├──────────────────────────────┤
│ id (PK)                      │
│ category                     │
│ key                          │
│ value (JSON, large)          │
│ confidence (0–1)             │
│ reinforcement_count          │
│ last_reinforced_at           │
└────────────────┬─────────────┘
                 │
          ┌──────┴──────┐
          │ (1:many)    │
          ▼
┌──────────────────────────────┐
│ fact_lineage                 │  (How facts learned)
├──────────────────────────────┤
│ id (PK)                      │
│ fact_id (FK) ────────────────►
│ source_session_id (FK) ──────►
│ source_observation_id (FK) ──►
│ confidence_delta             │
└──────────────────────────────┘

┌──────────────────────────────┐
│ learned_patterns             │  (TIER 3: Recurring behaviors)
├──────────────────────────────┤
│ id (PK)                      │
│ pattern_type                 │
│ condition_json (when)        │
│ action_json (what to do)     │
│ confidence (0–1)             │
│ occurrence_count             │
│ last_observed_at             │
│ enabled (soft-delete)        │
└──────────────────────────────┘
```

## Voice Query Path (Latency Breakdown)

```
User speaks (0ms)
    │
    ▼
Whisper transcribe (500–2000ms, out-of-band)
    │
    ▼
enrichVoiceResponse(query) ◄──── Memory queries begin (0ms)
    │
    ├─ Query TIER 1 (recent_context)           ~5ms
    │  └─ SELECT FROM recent_context
    │     WHERE session_id = ? AND type IN (...)
    │     ORDER BY priority DESC
    │
    ├─ Query TIER 2 (sessions + mood)          ~10ms
    │  └─ SELECT mood_tag, key_topics
    │     FROM sessions
    │     WHERE ended_at IS NULL
    │     ORDER BY started_at DESC LIMIT 1
    │
    └─ Query TIER 3 (voice tone + patterns)    ~15ms
       ├─ SELECT value FROM knowledge_facts
       │  WHERE category = 'gary-preferences'
       │  AND confidence > 0.7
       │
       └─ SELECT action_json FROM learned_patterns
          WHERE pattern_type = 'time_of_day'
          AND enabled = 1
    │
    ▼ (Total memory queries: ~30ms)
Assemble EnrichedContext (~5ms)
    │
    ▼
Build system prompt with context (~2ms)
    │
    ▼
Call Claude API with enriched prompt (2000–5000ms, network-bound)
    │
    ▼
TTS Synthesis (500–2000ms, out-of-band)
    │
    ▼
recordVoiceInteraction() ◄──── Memory update begins (0ms)
    │
    ├─ INSERT recent_context                   ~3ms
    ├─ UPDATE session interaction count         ~2ms
    └─ INSERT session_observations              ~2ms
    │
    ▼ (Total memory writes: ~7ms)
Response speaking (1–10 seconds)
    │
    ▼ (User hears Jane speaking)
Later: Session archive → TIER 2 promotion → TIER 3 learning (async)
```

## Confidence Decay Over Time (TIER 3 Lifecycle)

```
Initial learning (Confidence = 0.8)
│
├─ 7 days: No observation  → -2% → 0.784
├─ 14 days: No observation → -2% → 0.768
├─ 21 days: No observation → -2% → 0.753
├─ 30 days: Reinforced     ─→ Reset to 0.85 (high reinforcement)
├─ 60 days: No observation → -2% × 4 → 0.833
│
├─ 90 days: No observation → -2% × 12 → 0.697
├─ 180 days: No observation → -2% × 24 → 0.567
│ (Below threshold for response use)
│
└─ 270 days: Soft-delete (confidence < 0.1)
  UPDATE knowledge_facts SET confidence = 0
  WHERE confidence < 0.1 AND last_reinforced_at < 90 days

Reinforcement boost (each observation):
├─ confidence_delta += 0.05 per observation (capped at 0.95)
├─ reinforcement_count += 1
└─ last_reinforced_at = NOW()

Query: "Is fact_X trusted?"
└─ Only return if confidence > 0.75 AND last_reinforced_at > 7 days ago
   (prevents stale knowledge from being confident)
```

## Memory Storage Layout (File System)

```
~/.atlas/
├── jane/
│   ├── memory.db              ◄─── Main SQLite database (0600 perms)
│   │   ├── TIER 1: recent_context (30 min lifetime)
│   │   ├── TIER 2: sessions, session_observations (24h lifetime)
│   │   └── TIER 3: knowledge_facts, learned_patterns, fact_lineage (infinite)
│   │
│   ├── memory-wal             ◄─── Write-ahead log (crash safety)
│   ├── memory-shm             ◄─── Shared memory index
│   │
│   └── backups/
│       ├── memory-2026-03-28.db.bak
│       ├── memory-2026-03-27.db.bak
│       └── memory-2026-03-26.db.bak  ◄─── Daily rotated backups
│
├── status.json                ◄─── HUD status (separate from memory)
├── status-queue.json          ◄─--- Notification queue
├── hud-config.json
├── logs/
│   └── hud-app.log
└── plugins/
    └── ...
```

## Session Lifecycle

```
Session Creation:
  ┌─────────────┐
  │ New Session │
  └──────┬──────┘
         │ INSERT sessions (started_at = NOW(), ended_at = NULL)
         ▼
     ┌───────────────────┐
     │ Active Session    │ ◄──── User working
     │ (ended_at = NULL) │ ◄──── TIER 1 populated with focus, interruptions
     └─────────┬─────────┘
               │
               │ 30min mark OR session close
               ▼
         ┌──────────────────────┐
         │ Promote Recent→       │
         │ session_observations  │
         │ COMPUTE SUMMARY       │
         │ • mood_tag            │
         │ • autonomy_score      │
         │ • key_topics          │
         └─────────┬─────────────┘
                   │
                   ▼
        ┌────────────────────────┐
        │ Close Session          │
        │ UPDATE sessions SET    │
        │ ended_at = NOW(),      │
        │ duration_minutes = ... │
        └─────────┬──────────────┘
                  │
                  │ (24h later, async job)
                  ▼
         ┌───────────────────────┐
         │ Archive to TIER 3     │
         │ extractAndLearnPatterns()
         │ • Update reinforcements
         │ • Create new facts
         │ • Create lineage
         │ archived_at = NOW()   │
         └───────────────────────┘
```

## Multi-Tier Query Example

**Question:** "Should I be in quiet mode right now?"

```
  enrichVoiceResponse("should I be in quiet mode?")
      │
      ├─ TIER 1: Check recent interruptions
      │  SELECT COUNT(*) FROM recent_context
      │  WHERE type = 'interruption' AND expires_at > NOW()
      │  Result: 0 interruptions recent → no urgent quiet mode
      │
      ├─ TIER 2: Check today's interruptions
      │  SELECT interruptions_count FROM sessions
      │  WHERE DATE(started_at) = TODAY() AND ended_at IS NOT NULL
      │  Result: 3 interruptions today → moderate stress
      │
      ├─ TIER 3: Check patterns
      │  SELECT action_json FROM learned_patterns
      │  WHERE pattern_type = 'escalation_trigger'
      │    AND json_extract(action_json, '$.suppress_notifications') = 1
      │    AND confidence > 0.75
      │  Result: 1 pattern match → "quiet mode" action
      │
      └─ Enrich LLM prompt with:
         • Current: No recent interruptions
         • Today: High interruption count
         • Pattern: Learned to enable quiet mode when stressed
         • Recommendation: YES, enable quiet mode
         │
         ▼ Claude responds:
         "You've had 3 interruptions today. Based on your
          patterns, quiet mode would help you focus. Enable
          it for the next 2 hours?"
```

---

**All diagrams are reference material. Full implementation details in MEMORY_ARCHITECTURE.md.**
