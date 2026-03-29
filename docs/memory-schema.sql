-- Jane HUD Memory System — SQLite Schema
-- Database: ~/.atlas/jane/memory.db
-- This file contains all DDL to bootstrap the database

-- ============================================================================
-- PRAGMA Configuration
-- ============================================================================

PRAGMA journal_mode = WAL;           -- Write-ahead logging for safety
PRAGMA synchronous = NORMAL;          -- Balance between speed and safety
PRAGMA cache_size = -64000;            -- 64MB cache
PRAGMA foreign_keys = ON;              -- Enforce foreign key constraints
PRAGMA temp_store = MEMORY;            -- Temp tables in memory
PRAGMA query_only = OFF;               -- Allow writes

-- ============================================================================
-- TIER 1: Recent Context (HOT)
-- ============================================================================

CREATE TABLE recent_context (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    type TEXT NOT NULL,              -- 'task', 'interruption', 'focus', 'status', 'voice_event'
    key TEXT NOT NULL,               -- Unique within session + type, e.g., 'current_focus'
    value TEXT NOT NULL,             -- JSON-encoded, max ~8KB
    metadata TEXT,                   -- Optional context (app name, URL, etc.)
    priority INTEGER DEFAULT 0,      -- 0=low, 1=normal, 2=high (sort by)
    created_at INTEGER NOT NULL,     -- Unix timestamp
    updated_at INTEGER NOT NULL,     -- Unix timestamp
    expires_at INTEGER,              -- Unix timestamp, NULL if no expiry

    UNIQUE(session_id, type, key),
    FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

CREATE INDEX idx_recent_session ON recent_context(session_id);
CREATE INDEX idx_recent_expires ON recent_context(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_recent_priority_session ON recent_context(
    session_id, priority DESC, updated_at DESC
);

-- ============================================================================
-- TIER 2: Sessions & Observations (WARM)
-- ============================================================================

CREATE TABLE sessions (
    id TEXT PRIMARY KEY,                  -- Format: 'sess-YYYY-MM-DD-HH' or UUID
    user_id TEXT NOT NULL,                -- 'gary' (single user for now)
    started_at INTEGER NOT NULL,          -- Unix timestamp
    ended_at INTEGER,                     -- NULL if session still active
    duration_minutes INTEGER,             -- Computed at session close

    -- Metrics
    autonomy_score REAL,                  -- 0–100, system liveness
    voice_interactions_count INTEGER DEFAULT 0,
    interruptions_count INTEGER DEFAULT 0,

    -- Summary
    focus_app TEXT,                       -- Primary app during session
    mood_tag TEXT,                        -- 'focused', 'interrupted', 'exploratory', 'debugging'
    key_topics TEXT,                      -- JSON array of strings: ["memory", "architecture"]
    decisions_made TEXT,                  -- JSON array of decisions/outcomes

    -- Lifecycle
    archived_at INTEGER,                  -- When promoted to TIER 3
    created_at INTEGER DEFAULT (cast(strftime('%s', 'now') as integer))
);

CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_active ON sessions(ended_at) WHERE ended_at IS NULL;
CREATE INDEX idx_sessions_archived ON sessions(archived_at) WHERE archived_at IS NOT NULL;
CREATE INDEX idx_sessions_recent ON sessions(ended_at DESC);

-- Granular observations within a session
CREATE TABLE session_observations (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    timestamp INTEGER NOT NULL,           -- Unix timestamp
    type TEXT NOT NULL,                   -- 'voice_input', 'escalation', 'decision', 'context_switch', 'pattern_match'
    data TEXT NOT NULL,                   -- JSON: {query, response_tone, duration_ms, category, etc.}

    FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

CREATE INDEX idx_observation_session ON session_observations(session_id);
CREATE INDEX idx_observation_type ON session_observations(type);
CREATE INDEX idx_observation_timestamp ON session_observations(timestamp DESC);

-- ============================================================================
-- TIER 3: Persistent Knowledge (COLD)
-- ============================================================================

-- Long-lived facts learned from session patterns
CREATE TABLE knowledge_facts (
    id TEXT PRIMARY KEY,
    fact_type TEXT NOT NULL,              -- 'technical', 'personal', 'project', 'decision', 'pattern'
    category TEXT NOT NULL,               -- e.g., 'gary-preferences', 'gary-interests', 'atlas-architecture'
    key TEXT NOT NULL,                    -- Unique within category

    value TEXT NOT NULL,                  -- JSON, can be up to ~64KB
    description TEXT,                     -- Human-readable summary

    -- Confidence & reinforcement
    confidence REAL DEFAULT 0.7,          -- 0–1, how sure we are (decays over time if not reinforced)
    reinforcement_count INTEGER DEFAULT 1, -- How many times observed/confirmed
    last_reinforced_at INTEGER,           -- Unix timestamp of last observation

    -- Lifecycle
    created_at INTEGER NOT NULL,          -- When fact was first created
    archived_at INTEGER,                  -- When promoted from TIER 2 session

    UNIQUE(category, key)
);

CREATE INDEX idx_knowledge_category ON knowledge_facts(category);
CREATE INDEX idx_knowledge_confidence ON knowledge_facts(confidence DESC) WHERE confidence > 0.3;
CREATE INDEX idx_knowledge_reinforced ON knowledge_facts(last_reinforced_at DESC);

-- Learned patterns (recurring behaviors, time-based, app sequences)
CREATE TABLE learned_patterns (
    id TEXT PRIMARY KEY,
    pattern_type TEXT NOT NULL,           -- 'time_of_day', 'app_sequence', 'escalation_trigger', 'recovery', 'focus_mode'
    description TEXT NOT NULL,            -- Human-readable: "Usually focused 14:00–16:00"

    condition_json TEXT NOT NULL,         -- JSON filter: {"hour_range": [14, 16], "app": "Cursor"}
    action_json TEXT,                     -- Suggested response: {"suppress_notifications": true, "voice_tone": "brief"}

    confidence REAL DEFAULT 0.7,          -- 0–1
    occurrence_count INTEGER DEFAULT 1,   -- How many times observed
    last_observed_at INTEGER,             -- Unix timestamp

    enabled BOOLEAN DEFAULT 1,            -- Soft-disable without deletion

    created_at INTEGER NOT NULL
);

CREATE INDEX idx_pattern_type ON learned_patterns(pattern_type);
CREATE INDEX idx_pattern_enabled ON learned_patterns(enabled) WHERE enabled = 1;
CREATE INDEX idx_pattern_confidence ON learned_patterns(confidence DESC) WHERE enabled = 1;

-- Lineage: how facts are built from raw observations
CREATE TABLE fact_lineage (
    id TEXT PRIMARY KEY,
    fact_id TEXT NOT NULL,
    source_session_id TEXT,               -- Which session generated this observation
    source_observation_id TEXT,           -- Which observation in session_observations
    confidence_delta REAL,                -- How much this source contributed to fact confidence

    created_at INTEGER DEFAULT (cast(strftime('%s', 'now') as integer)),

    FOREIGN KEY(fact_id) REFERENCES knowledge_facts(id) ON DELETE CASCADE,
    FOREIGN KEY(source_session_id) REFERENCES sessions(id) ON DELETE SET NULL,
    FOREIGN KEY(source_observation_id) REFERENCES session_observations(id) ON DELETE SET NULL
);

CREATE INDEX idx_lineage_fact ON fact_lineage(fact_id);
CREATE INDEX idx_lineage_session ON fact_lineage(source_session_id);

-- ============================================================================
-- Metadata & Versioning
-- ============================================================================

CREATE TABLE schema_version (
    version INTEGER PRIMARY KEY,
    created_at INTEGER,
    description TEXT
);

INSERT INTO schema_version (version, created_at, description)
VALUES (1, cast(strftime('%s', 'now') as integer), 'Initial: TIER1/TIER2/TIER3 schema');

-- ============================================================================
-- Views (Optional but Helpful)
-- ============================================================================

-- Current session context (for quick lookups)
CREATE VIEW v_current_session AS
SELECT
    s.id,
    s.started_at,
    s.autonomy_score,
    s.focus_app,
    s.mood_tag,
    s.voice_interactions_count,
    COUNT(DISTINCT so.id) as observation_count
FROM sessions s
LEFT JOIN session_observations so ON s.id = so.session_id
WHERE s.ended_at IS NULL
GROUP BY s.id
LIMIT 1;

-- High-confidence facts (ready to use in responses)
CREATE VIEW v_trusted_facts AS
SELECT
    category,
    key,
    value,
    confidence,
    reinforcement_count,
    description
FROM knowledge_facts
WHERE confidence > 0.75 AND (last_reinforced_at IS NULL OR last_reinforced_at > cast(strftime('%s', 'now', '-90 days') as integer))
ORDER BY confidence DESC;

-- Active learned patterns (enabled + recently observed)
CREATE VIEW v_active_patterns AS
SELECT
    id,
    pattern_type,
    description,
    condition_json,
    action_json,
    confidence,
    occurrence_count
FROM learned_patterns
WHERE enabled = 1 AND confidence > 0.6
ORDER BY occurrence_count DESC, last_observed_at DESC;

-- Sessions by day (for analytics)
CREATE VIEW v_sessions_by_day AS
SELECT
    date(datetime(started_at, 'unixepoch')) as day,
    COUNT(*) as session_count,
    AVG(duration_minutes) as avg_duration,
    AVG(autonomy_score) as avg_autonomy,
    COUNT(DISTINCT focus_app) as app_variety
FROM sessions
WHERE ended_at IS NOT NULL
GROUP BY day
ORDER BY day DESC;

-- ============================================================================
-- Initial Data Seed (Optional)
-- ============================================================================

-- Example: Default voice tone preference
INSERT OR IGNORE INTO knowledge_facts (
    id, fact_type, category, key, value, confidence, reinforcement_count, created_at
) VALUES (
    'kf-default-voice-tone',
    'personal',
    'gary-preferences',
    'preferred_voice_tone',
    '{"tone": "direct", "detail_level": "high", "accent": "minimal", "pacing": "natural"}',
    0.8,
    1,
    cast(strftime('%s', 'now') as integer)
);

-- Example: Suppress notifications pattern during deep work
INSERT OR IGNORE INTO learned_patterns (
    id, pattern_type, description, condition_json, action_json, confidence, enabled, created_at
) VALUES (
    'pat-early-morning-focus',
    'time_of_day',
    'Early morning (6–9am) = deep focus mode',
    '{"hour_range": [6, 9], "weekday": true}',
    '{"suppress_notifications": true, "voice_tone": "brief", "max_response_seconds": 30, "skip_small_talk": true}',
    0.7,
    1,
    cast(strftime('%s', 'now') as integer)
);

-- ============================================================================
-- Cleanup & Maintenance Procedures (as comments; implement in Swift)
-- ============================================================================

/*
-- Promote expired TIER 1 → TIER 2 (run every 30 minutes)
-- Archive observations before cleanup:
INSERT INTO session_observations (id, session_id, timestamp, type, data)
SELECT 'obs-' || lower(hex(randomblob(16))), session_id, created_at, 'recent_context_archived', value
FROM recent_context WHERE expires_at < cast(strftime('%s', 'now') as integer);

-- Delete expired recent_context
DELETE FROM recent_context WHERE expires_at < cast(strftime('%s', 'now') as integer);

-- Promote old sessions → TIER 3 (run every 24 hours)
-- See MEMORY_ARCHITECTURE.md for extractAndLearnPatterns() logic
-- Then:
UPDATE sessions SET archived_at = cast(strftime('%s', 'now') as integer)
WHERE ended_at IS NOT NULL AND archived_at IS NULL
  AND ended_at < cast(strftime('%s', 'now', '-24 hours') as integer);

-- Apply confidence decay (run every 7 days)
UPDATE knowledge_facts
SET confidence = confidence * 0.98
WHERE last_reinforced_at IS NOT NULL
  AND last_reinforced_at < cast(strftime('%s', 'now', '-7 days') as integer)
  AND confidence > 0.2;

-- Soft-delete very stale facts (run monthly)
UPDATE knowledge_facts
SET confidence = 0
WHERE confidence < 0.1 AND last_reinforced_at < cast(strftime('%s', 'now', '-90 days') as integer);

-- Vacuum & optimize (run every 6 hours)
PRAGMA optimize;
VACUUM;
*/
