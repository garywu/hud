import Foundation
import SQLite3

/// DatabaseManager - Main coordinator for Jane's memory SQLite database
///
/// Responsibilities:
/// - Initialize SQLite database at ~/.atlas/jane/memory.db
/// - Execute schema DDL on first launch
/// - Configure SQLite pragmas for safety and performance
/// - Provide thread-safe database access
/// - Handle graceful connection closure on app exit
///
class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.atlas.jane.memory.db", attributes: .concurrent)
    private let databasePath: String
    private let databaseDirectory: String

    // MARK: - Initialization

    private init() {
        // Setup database directory: ~/.atlas/jane/
        let homeDirectory = NSHomeDirectory()
        self.databaseDirectory = (homeDirectory as NSString).appendingPathComponent(".atlas/jane")
        self.databasePath = (databaseDirectory as NSString).appendingPathComponent("memory.db")

        // Initialize on creation
        do {
            try setupDatabase()
        } catch {
            print("FATAL: Failed to initialize database: \(error)")
            // In production, would escalate to error handler
        }
    }

    // MARK: - Setup & Configuration

    /// Create directory structure and initialize database
    private func setupDatabase() throws {
        // Create ~/.atlas/jane directory if needed
        try FileManager.default.createDirectory(
            atPath: databaseDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )

        // Set permissions to 0600 (user read/write only)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: databaseDirectory
        )

        // Open or create database
        let openResult = sqlite3_open(databasePath.cString(using: .utf8), &db)
        guard openResult == SQLITE_OK else {
            throw DatabaseError.cannotOpenDatabase(sqlite3_errmsg(db).map { String(cString: $0) } ?? "Unknown error")
        }

        guard let db = db else {
            throw DatabaseError.databaseNotInitialized
        }

        // Configure pragmas for safety and performance
        try configurePragmas(db)

        // Create schema if needed
        try createSchema(db)

        // Set file permissions to 0600
        try setSecureFilePermissions()
    }

    /// Configure SQLite pragmas for optimal performance and safety
    private func configurePragmas(_ db: OpaquePointer) throws {
        let pragmas = [
            "PRAGMA journal_mode = WAL;",           // Write-ahead logging for safety
            "PRAGMA synchronous = NORMAL;",          // Balance speed and safety
            "PRAGMA cache_size = -64000;",           // 64MB cache
            "PRAGMA foreign_keys = ON;",             // Enforce foreign key constraints
            "PRAGMA temp_store = MEMORY;",           // Temp tables in memory
            "PRAGMA query_only = OFF;",              // Allow writes
            "PRAGMA busy_timeout = 5000;"            // 5 second timeout for locks
        ]

        for pragma in pragmas {
            var errorMessage: UnsafeMutablePointer<CChar>?
            let result = sqlite3_exec(db, pragma, nil, nil, &errorMessage)

            if result != SQLITE_OK {
                let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
                sqlite3_free(errorMessage)
                throw DatabaseError.pragmaError(pragma, message)
            }
        }
    }

    /// Create database schema from DDL
    private func createSchema(_ db: OpaquePointer) throws {
        let schema = Self.schemaDDL()

        // Split into individual statements (semicolon-separated)
        let statements = schema.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }

        for statement in statements {
            guard !statement.isEmpty else { continue }

            let fullStatement = statement + ";"
            var errorMessage: UnsafeMutablePointer<CChar>?
            let result = sqlite3_exec(db, fullStatement, nil, nil, &errorMessage)

            if result != SQLITE_OK {
                let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
                sqlite3_free(errorMessage)

                // If table already exists, continue; other errors are fatal
                if !message.contains("already exists") {
                    throw DatabaseError.schemaError(message)
                }
            }
        }

        // Verify schema version table
        try verifySchemaVersion(db)
    }

    /// Verify schema version and ensure schema is complete
    private func verifySchemaVersion(_ db: OpaquePointer) throws {
        var statement: OpaquePointer?
        let query = "SELECT version FROM schema_version ORDER BY version DESC LIMIT 1"

        let prepResult = sqlite3_prepare_v2(db, query, -1, &statement, nil)
        guard prepResult == SQLITE_OK else {
            throw DatabaseError.queryError(query)
        }

        defer { sqlite3_finalize(statement) }

        // If we can't query version, table doesn't exist yet - create it
        if sqlite3_step(statement) != SQLITE_ROW {
            let versionInsert = """
                INSERT INTO schema_version (version, created_at, description)
                VALUES (1, cast(strftime('%s', 'now') as integer), 'Initial: TIER1/TIER2/TIER3 schema');
                """

            var errorMessage: UnsafeMutablePointer<CChar>?
            let result = sqlite3_exec(db, versionInsert, nil, nil, &errorMessage)

            if result != SQLITE_OK {
                let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
                sqlite3_free(errorMessage)
                throw DatabaseError.schemaError("Failed to insert schema version: \(message)")
            }
        }
    }

    /// Set file permissions to 0600 for security
    private func setSecureFilePermissions() throws {
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.complete,
            .posixPermissions: 0o600
        ]

        try FileManager.default.setAttributes(attributes, ofItemAtPath: databasePath)

        // Also set for WAL and SHM files if they exist
        for suffix in ["-wal", "-shm"] {
            let walPath = databasePath + suffix
            if FileManager.default.fileExists(atPath: walPath) {
                try? FileManager.default.setAttributes(attributes, ofItemAtPath: walPath)
            }
        }
    }

    // MARK: - Database Access

    /// Execute a raw SQL statement (for writes)
    func execute(_ sql: String, _ parameters: [Any] = []) throws {
        try queue.sync(flags: .barrier) {
            guard let db = db else {
                throw DatabaseError.databaseNotInitialized
            }

            var statement: OpaquePointer?
            let prepResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            guard prepResult == SQLITE_OK else {
                throw DatabaseError.queryError(sql)
            }

            defer { sqlite3_finalize(statement) }

            // Bind parameters
            for (index, param) in parameters.enumerated() {
                let bindResult = bindParameter(statement, index: Int32(index + 1), value: param)
                if bindResult != SQLITE_OK {
                    throw DatabaseError.parameterError("Failed to bind parameter at index \(index)")
                }
            }

            // Execute
            let stepResult = sqlite3_step(statement)
            guard stepResult == SQLITE_DONE else {
                throw DatabaseError.executionError(sqlite3_errmsg(db).map { String(cString: $0) } ?? "Unknown error")
            }
        }
    }

    /// Query with results
    func query(_ sql: String, _ parameters: [Any] = []) throws -> [[String: Any]] {
        var results: [[String: Any]] = []

        try queue.sync {
            guard let db = db else {
                throw DatabaseError.databaseNotInitialized
            }

            var statement: OpaquePointer?
            let prepResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            guard prepResult == SQLITE_OK else {
                throw DatabaseError.queryError(sql)
            }

            defer { sqlite3_finalize(statement) }

            // Bind parameters
            for (index, param) in parameters.enumerated() {
                let bindResult = bindParameter(statement, index: Int32(index + 1), value: param)
                if bindResult != SQLITE_OK {
                    throw DatabaseError.parameterError("Failed to bind parameter at index \(index)")
                }
            }

            // Fetch all rows
            while sqlite3_step(statement) == SQLITE_ROW {
                let row = try extractRow(statement)
                results.append(row)
            }
        }

        return results
    }

    /// Query single value
    func queryScalar(_ sql: String, _ parameters: [Any] = []) throws -> Any? {
        let results = try query(sql, parameters)
        guard let first = results.first else { return nil }
        guard let firstValue = first.values.first else { return nil }
        return firstValue
    }

    // MARK: - Helper Methods

    private func bindParameter(_ statement: OpaquePointer?, index: Int32, value: Any) -> Int32 {
        guard let statement = statement else { return SQLITE_ERROR }

        switch value {
        case let int as Int:
            return sqlite3_bind_int64(statement, index, Int64(int))
        case let int as Int64:
            return sqlite3_bind_int64(statement, index, int)
        case let double as Double:
            return sqlite3_bind_double(statement, index, double)
        case let string as String:
            // Use sqlite3_bind_text with UTF-8 encoding
            // SQLite will copy the string data internally
            let utf8 = string.utf8
            let buffer = [UInt8](utf8)
            if buffer.isEmpty {
                return sqlite3_bind_text(statement, index, "", 0, SQLITE_STATIC)
            }
            return buffer.withUnsafeBytes { bytes in
                sqlite3_bind_text(statement, index, bytes.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(buffer.count), SQLITE_TRANSIENT)
            }
        case let data as Data:
            return data.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
            }
        case is NSNull:
            return sqlite3_bind_null(statement, index)
        default:
            // Try to convert to string
            let stringValue = String(describing: value)
            let utf8 = stringValue.utf8
            let buffer = [UInt8](utf8)
            if buffer.isEmpty {
                return sqlite3_bind_text(statement, index, "", 0, SQLITE_STATIC)
            }
            return buffer.withUnsafeBytes { bytes in
                sqlite3_bind_text(statement, index, bytes.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(buffer.count), SQLITE_TRANSIENT)
            }
        }
    }

    private func extractRow(_ statement: OpaquePointer?) throws -> [String: Any] {
        guard let statement = statement else { throw DatabaseError.databaseNotInitialized }

        var row: [String: Any] = [:]
        let columnCount = sqlite3_column_count(statement)

        for i in 0..<columnCount {
            let columnName = String(cString: sqlite3_column_name(statement, i))
            let columnType = sqlite3_column_type(statement, i)

            let value: Any
            switch columnType {
            case SQLITE_INTEGER:
                value = sqlite3_column_int64(statement, i)
            case SQLITE_FLOAT:
                value = sqlite3_column_double(statement, i)
            case SQLITE_TEXT:
                value = String(cString: sqlite3_column_text(statement, i))
            case SQLITE_BLOB:
                let data = sqlite3_column_blob(statement, i)
                let size = sqlite3_column_bytes(statement, i)
                value = Data(bytes: data!, count: Int(size))
            case SQLITE_NULL:
                value = NSNull()
            default:
                value = NSNull()
            }

            row[columnName] = value
        }

        return row
    }

    // MARK: - Lifecycle

    /// Close database connection gracefully
    func close() {
        queue.sync(flags: .barrier) {
            if let db = db {
                sqlite3_close(db)
                self.db = nil
            }
        }
    }

    deinit {
        close()
    }

    // MARK: - Schema DDL

    /// Full SQLite schema for Jane's memory system
    private static func schemaDDL() -> String {
        return """
        -- ============================================================================
        -- PRAGMA Configuration
        -- ============================================================================

        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        PRAGMA cache_size = -64000;
        PRAGMA foreign_keys = ON;
        PRAGMA temp_store = MEMORY;
        PRAGMA query_only = OFF;

        -- ============================================================================
        -- TIER 1: Recent Context (HOT)
        -- ============================================================================

        CREATE TABLE IF NOT EXISTS recent_context (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            type TEXT NOT NULL,
            key TEXT NOT NULL,
            value TEXT NOT NULL,
            metadata TEXT,
            priority INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            expires_at INTEGER,

            UNIQUE(session_id, type, key),
            FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_recent_session ON recent_context(session_id);
        CREATE INDEX IF NOT EXISTS idx_recent_expires ON recent_context(expires_at) WHERE expires_at IS NOT NULL;
        CREATE INDEX IF NOT EXISTS idx_recent_priority_session ON recent_context(session_id, priority DESC, updated_at DESC);

        -- ============================================================================
        -- TIER 2: Sessions & Observations (WARM)
        -- ============================================================================

        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            duration_minutes INTEGER,

            autonomy_score REAL,
            voice_interactions_count INTEGER DEFAULT 0,
            interruptions_count INTEGER DEFAULT 0,

            focus_app TEXT,
            mood_tag TEXT,
            key_topics TEXT,
            decisions_made TEXT,

            archived_at INTEGER,
            created_at INTEGER DEFAULT (cast(strftime('%s', 'now') as integer))
        );

        CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
        CREATE INDEX IF NOT EXISTS idx_sessions_active ON sessions(ended_at) WHERE ended_at IS NULL;
        CREATE INDEX IF NOT EXISTS idx_sessions_archived ON sessions(archived_at) WHERE archived_at IS NOT NULL;
        CREATE INDEX IF NOT EXISTS idx_sessions_recent ON sessions(ended_at DESC);

        CREATE TABLE IF NOT EXISTS session_observations (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            type TEXT NOT NULL,
            data TEXT NOT NULL,

            FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_observation_session ON session_observations(session_id);
        CREATE INDEX IF NOT EXISTS idx_observation_type ON session_observations(type);
        CREATE INDEX IF NOT EXISTS idx_observation_timestamp ON session_observations(timestamp DESC);

        -- ============================================================================
        -- TIER 3: Persistent Knowledge (COLD)
        -- ============================================================================

        CREATE TABLE IF NOT EXISTS knowledge_facts (
            id TEXT PRIMARY KEY,
            fact_type TEXT NOT NULL,
            category TEXT NOT NULL,
            key TEXT NOT NULL,

            value TEXT NOT NULL,
            description TEXT,

            confidence REAL DEFAULT 0.7,
            reinforcement_count INTEGER DEFAULT 1,
            last_reinforced_at INTEGER,

            created_at INTEGER NOT NULL,
            archived_at INTEGER,

            UNIQUE(category, key)
        );

        CREATE INDEX IF NOT EXISTS idx_knowledge_category ON knowledge_facts(category);
        CREATE INDEX IF NOT EXISTS idx_knowledge_confidence ON knowledge_facts(confidence DESC) WHERE confidence > 0.3;
        CREATE INDEX IF NOT EXISTS idx_knowledge_reinforced ON knowledge_facts(last_reinforced_at DESC);

        CREATE TABLE IF NOT EXISTS learned_patterns (
            id TEXT PRIMARY KEY,
            pattern_type TEXT NOT NULL,
            description TEXT NOT NULL,

            condition_json TEXT NOT NULL,
            action_json TEXT,

            confidence REAL DEFAULT 0.7,
            occurrence_count INTEGER DEFAULT 1,
            last_observed_at INTEGER,

            enabled BOOLEAN DEFAULT 1,

            created_at INTEGER NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_pattern_type ON learned_patterns(pattern_type);
        CREATE INDEX IF NOT EXISTS idx_pattern_enabled ON learned_patterns(enabled) WHERE enabled = 1;
        CREATE INDEX IF NOT EXISTS idx_pattern_confidence ON learned_patterns(confidence DESC) WHERE enabled = 1;

        CREATE TABLE IF NOT EXISTS fact_lineage (
            id TEXT PRIMARY KEY,
            fact_id TEXT NOT NULL,
            source_session_id TEXT,
            source_observation_id TEXT,
            confidence_delta REAL,

            created_at INTEGER DEFAULT (cast(strftime('%s', 'now') as integer)),

            FOREIGN KEY(fact_id) REFERENCES knowledge_facts(id) ON DELETE CASCADE,
            FOREIGN KEY(source_session_id) REFERENCES sessions(id) ON DELETE SET NULL,
            FOREIGN KEY(source_observation_id) REFERENCES session_observations(id) ON DELETE SET NULL
        );

        CREATE INDEX IF NOT EXISTS idx_lineage_fact ON fact_lineage(fact_id);
        CREATE INDEX IF NOT EXISTS idx_lineage_session ON fact_lineage(source_session_id);

        -- ============================================================================
        -- Metadata & Versioning
        -- ============================================================================

        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER PRIMARY KEY,
            created_at INTEGER,
            description TEXT
        );

        -- ============================================================================
        -- Views (Optional but Helpful)
        -- ============================================================================

        CREATE VIEW IF NOT EXISTS v_current_session AS
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

        CREATE VIEW IF NOT EXISTS v_trusted_facts AS
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

        CREATE VIEW IF NOT EXISTS v_active_patterns AS
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

        CREATE VIEW IF NOT EXISTS v_sessions_by_day AS
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
        """
    }
}

// MARK: - Error Handling

enum DatabaseError: LocalizedError {
    case cannotOpenDatabase(String)
    case databaseNotInitialized
    case pragmaError(String, String)
    case schemaError(String)
    case queryError(String)
    case parameterError(String)
    case executionError(String)
    case filePermissionError(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpenDatabase(let msg):
            return "Cannot open database: \(msg)"
        case .databaseNotInitialized:
            return "Database not initialized"
        case .pragmaError(let pragma, let msg):
            return "Pragma error in '\(pragma)': \(msg)"
        case .schemaError(let msg):
            return "Schema error: \(msg)"
        case .queryError(let sql):
            return "Query error in: \(sql)"
        case .parameterError(let msg):
            return "Parameter error: \(msg)"
        case .executionError(let msg):
            return "Execution error: \(msg)"
        case .filePermissionError(let msg):
            return "File permission error: \(msg)"
        }
    }
}
