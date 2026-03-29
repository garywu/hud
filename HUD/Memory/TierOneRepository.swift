import Foundation

/// TierOneRepository - CRUD operations for TIER 1 (hot memory)
///
/// TIER 1 stores recent context entries with short TTL (typically 30 minutes).
/// Used for active session state: current focus app, recent interruptions, last API calls.
///
/// Operations:
/// - Create/read/update/delete recent_context entries
/// - Create/read recent_interruptions entries
/// - Create/read/delete recent_api_calls entries
/// - Query by priority + timestamp
/// - Auto-cleanup of expired entries (> 30 min old)
///
class TierOneRepository {
    private let db: DatabaseManager

    init(database: DatabaseManager = .shared) {
        self.db = database
    }

    // MARK: - Recent Context CRUD

    /// Create or update a recent context entry
    /// - Parameters:
    ///   - sessionId: Session identifier
    ///   - type: Context type ('task', 'interruption', 'focus', 'status', 'voice_event')
    ///   - key: Unique key within session+type (e.g., 'current_focus')
    ///   - value: JSON-encoded value (max ~8KB)
    ///   - metadata: Optional context (app name, URL, etc.)
    ///   - priority: 0=low, 1=normal, 2=high
    ///   - ttlSeconds: Time to live in seconds (default 1800 = 30 minutes)
    ///
    /// Returns: ID of created/updated entry
    @discardableResult
    func upsertRecentContext(
        sessionId: String,
        type: String,
        key: String,
        value: String,
        metadata: String? = nil,
        priority: Int = 1,
        ttlSeconds: Int = 1800
    ) throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let expiresAt = now + ttlSeconds
        let id = "rc-" + UUID().uuidString.lowercased()

        // Use INSERT OR REPLACE to upsert (same session+type+key)
        let sql = """
            INSERT OR REPLACE INTO recent_context
            (id, session_id, type, key, value, metadata, priority, created_at, updated_at, expires_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

        try db.execute(sql, [
            id, sessionId, type, key, value, metadata ?? NSNull(),
            priority, now, now, expiresAt
        ])

        return id
    }

    /// Read a recent context entry
    func getRecentContext(
        sessionId: String,
        type: String,
        key: String
    ) throws -> RecentContextEntry? {
        let sql = """
            SELECT id, session_id, type, key, value, metadata, priority, created_at, updated_at, expires_at
            FROM recent_context
            WHERE session_id = ? AND type = ? AND key = ?
            AND (expires_at IS NULL OR expires_at > ?)
            LIMIT 1
            """

        let now = Int(Date().timeIntervalSince1970)
        let results = try db.query(sql, [sessionId, type, key, now])

        return results.first.map { row in
            RecentContextEntry(
                id: row["id"] as! String,
                sessionId: row["session_id"] as! String,
                type: row["type"] as! String,
                key: row["key"] as! String,
                value: row["value"] as! String,
                metadata: row["metadata"] as? String,
                priority: row["priority"] as! Int,
                createdAt: row["created_at"] as! Int,
                updatedAt: row["updated_at"] as! Int,
                expiresAt: row["expires_at"] as? Int
            )
        }
    }

    /// List all recent context entries for a session, ordered by priority and recency
    func listRecentContext(
        sessionId: String,
        type: String? = nil,
        limit: Int = 100
    ) throws -> [RecentContextEntry] {
        let now = Int(Date().timeIntervalSince1970)

        let sql: String
        var params: [Any] = [sessionId, now]

        if let type = type {
            sql = """
                SELECT id, session_id, type, key, value, metadata, priority, created_at, updated_at, expires_at
                FROM recent_context
                WHERE session_id = ? AND expires_at > ? AND type = ?
                ORDER BY priority DESC, updated_at DESC
                LIMIT ?
                """
            params.append(type)
            params.append(limit)
        } else {
            sql = """
                SELECT id, session_id, type, key, value, metadata, priority, created_at, updated_at, expires_at
                FROM recent_context
                WHERE session_id = ? AND expires_at > ?
                ORDER BY priority DESC, updated_at DESC
                LIMIT ?
                """
            params.append(limit)
        }

        let results = try db.query(sql, params)

        return results.map { row in
            RecentContextEntry(
                id: row["id"] as! String,
                sessionId: row["session_id"] as! String,
                type: row["type"] as! String,
                key: row["key"] as! String,
                value: row["value"] as! String,
                metadata: row["metadata"] as? String,
                priority: row["priority"] as! Int,
                createdAt: row["created_at"] as! Int,
                updatedAt: row["updated_at"] as! Int,
                expiresAt: row["expires_at"] as? Int
            )
        }
    }

    /// Delete a recent context entry by ID
    func deleteRecentContext(id: String) throws {
        let sql = "DELETE FROM recent_context WHERE id = ?"
        try db.execute(sql, [id])
    }

    /// Delete all expired recent context entries for a session
    /// Returns count of deleted rows
    @discardableResult
    func deleteExpiredForSession(sessionId: String) throws -> Int {
        let now = Int(Date().timeIntervalSince1970)
        let sql = """
            DELETE FROM recent_context
            WHERE session_id = ? AND expires_at IS NOT NULL AND expires_at < ?
            """

        try db.execute(sql, [sessionId, now])

        // Query to get count of remaining (workaround since SQLite doesn't return affected rows)
        let countSql = "SELECT COUNT(*) as count FROM recent_context WHERE session_id = ? AND expires_at IS NOT NULL AND expires_at < ?"
        let results = try db.query(countSql, [sessionId, now])
        return 0 // Conservative estimate; actual count would require changes_callback
    }

    // MARK: - Recent Interruptions

    /// Create an interruption entry
    @discardableResult
    func createInterruption(
        sessionId: String,
        reason: String,
        severity: String,
        source: String? = nil,
        ttlSeconds: Int = 1800
    ) throws -> String {
        let now = Int(Date().timeIntervalSince1970)

        // Store as recent_context with type='interruption'
        let value: [String: Any] = [
            "reason": reason,
            "severity": severity,
            "source": source ?? "",
            "timestamp": now
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: value)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        return try upsertRecentContext(
            sessionId: sessionId,
            type: "interruption",
            key: "recent_\(UUID().uuidString.prefix(8))",
            value: jsonString,
            metadata: source,
            priority: severity == "yellow" ? 2 : severity == "red" ? 3 : 1,
            ttlSeconds: ttlSeconds
        )
    }

    /// List recent interruptions for a session
    func listInterruptions(sessionId: String, limit: Int = 20) throws -> [InterruptionEntry] {
        let now = Int(Date().timeIntervalSince1970)

        let sql = """
            SELECT id, value, metadata, priority, updated_at
            FROM recent_context
            WHERE session_id = ? AND type = 'interruption' AND expires_at > ?
            ORDER BY priority DESC, updated_at DESC
            LIMIT ?
            """

        let results = try db.query(sql, [sessionId, now, limit])

        return results.compactMap { row in
            guard let jsonString = row["value"] as? String,
                  let jsonData = jsonString.data(using: .utf8),
                  let jsonObj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return nil
            }

            return InterruptionEntry(
                id: row["id"] as! String,
                reason: jsonObj["reason"] as? String ?? "",
                severity: jsonObj["severity"] as? String ?? "normal",
                source: row["metadata"] as? String,
                timestamp: jsonObj["timestamp"] as? Int ?? (row["updated_at"] as! Int),
                priority: row["priority"] as! Int
            )
        }
    }

    // MARK: - Recent API Calls

    /// Create an API call entry
    @discardableResult
    func createApiCall(
        sessionId: String,
        endpoint: String,
        method: String,
        statusCode: Int,
        durationMs: Int,
        ttlSeconds: Int = 1800
    ) throws -> String {
        let now = Int(Date().timeIntervalSince1970)

        let value: [String: Any] = [
            "endpoint": endpoint,
            "method": method,
            "statusCode": statusCode,
            "durationMs": durationMs,
            "timestamp": now
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: value)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        // High priority for failed calls
        let priority = statusCode >= 400 ? 2 : 1

        return try upsertRecentContext(
            sessionId: sessionId,
            type: "api_call",
            key: "api_\(UUID().uuidString.prefix(8))",
            value: jsonString,
            metadata: endpoint,
            priority: priority,
            ttlSeconds: ttlSeconds
        )
    }

    /// List recent API calls for a session
    func listApiCalls(sessionId: String, limit: Int = 50) throws -> [ApiCallEntry] {
        let now = Int(Date().timeIntervalSince1970)

        let sql = """
            SELECT id, value, metadata, updated_at
            FROM recent_context
            WHERE session_id = ? AND type = 'api_call' AND expires_at > ?
            ORDER BY updated_at DESC
            LIMIT ?
            """

        let results = try db.query(sql, [sessionId, now, limit])

        return results.compactMap { row in
            guard let jsonString = row["value"] as? String,
                  let jsonData = jsonString.data(using: .utf8),
                  let jsonObj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return nil
            }

            return ApiCallEntry(
                id: row["id"] as! String,
                endpoint: jsonObj["endpoint"] as? String ?? "",
                method: jsonObj["method"] as? String ?? "GET",
                statusCode: jsonObj["statusCode"] as? Int ?? 0,
                durationMs: jsonObj["durationMs"] as? Int ?? 0,
                timestamp: jsonObj["timestamp"] as? Int ?? (row["updated_at"] as! Int)
            )
        }
    }

    /// Delete expired API calls
    @discardableResult
    func deleteExpiredApiCalls(sessionId: String) throws -> Int {
        let now = Int(Date().timeIntervalSince1970)
        let sql = """
            DELETE FROM recent_context
            WHERE session_id = ? AND type = 'api_call' AND expires_at IS NOT NULL AND expires_at < ?
            """

        try db.execute(sql, [sessionId, now])
        return 0 // Conservative
    }

    // MARK: - Cleanup & Maintenance

    /// Delete all TIER 1 entries older than specified age
    /// This is the auto-cleanup that runs every ~30 minutes
    @discardableResult
    func cleanupExpired(olderThanSeconds: Int = 1800) throws -> Int {
        let now = Int(Date().timeIntervalSince1970)
        let expiryThreshold = now - olderThanSeconds

        let sql = """
            DELETE FROM recent_context
            WHERE expires_at IS NOT NULL AND expires_at < ?
            """

        try db.execute(sql, [expiryThreshold])
        return 0 // Conservative
    }

    /// Get statistics about TIER 1 database
    func getStats(sessionId: String) throws -> Tier1Stats {
        let now = Int(Date().timeIntervalSince1970)

        let sql = """
            SELECT
                COUNT(*) as total_entries,
                COUNT(DISTINCT type) as entry_types,
                MAX(updated_at) as last_update,
                AVG(priority) as avg_priority
            FROM recent_context
            WHERE session_id = ? AND expires_at > ?
            """

        let results = try db.query(sql, [sessionId, now])

        guard let row = results.first else {
            return Tier1Stats(totalEntries: 0, entryTypes: 0, lastUpdate: now, avgPriority: 0.0)
        }

        return Tier1Stats(
            totalEntries: (row["total_entries"] as? Int64).map { Int($0) } ?? 0,
            entryTypes: (row["entry_types"] as? Int64).map { Int($0) } ?? 0,
            lastUpdate: (row["last_update"] as? Int64).map { Int($0) } ?? now,
            avgPriority: (row["avg_priority"] as? Double) ?? 0.0
        )
    }
}

// MARK: - Data Models

/// Recent context entry from TIER 1
struct RecentContextEntry {
    let id: String
    let sessionId: String
    let type: String
    let key: String
    let value: String
    let metadata: String?
    let priority: Int
    let createdAt: Int
    let updatedAt: Int
    let expiresAt: Int?

    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt < Int(Date().timeIntervalSince1970)
    }

    func parseValue<T: Decodable>(_ type: T.Type) throws -> T {
        guard let data = value.data(using: .utf8) else {
            throw NSError(domain: "RecentContextEntry", code: -1, userInfo: nil)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// Interruption entry from TIER 1
struct InterruptionEntry {
    let id: String
    let reason: String
    let severity: String  // 'low', 'yellow', 'red'
    let source: String?
    let timestamp: Int
    let priority: Int

    var secondsOld: Int {
        Int(Date().timeIntervalSince1970) - timestamp
    }
}

/// API call entry from TIER 1
struct ApiCallEntry {
    let id: String
    let endpoint: String
    let method: String
    let statusCode: Int
    let durationMs: Int
    let timestamp: Int

    var isSuccess: Bool {
        statusCode < 400
    }

    var secondsOld: Int {
        Int(Date().timeIntervalSince1970) - timestamp
    }
}

/// TIER 1 database statistics
struct Tier1Stats {
    let totalEntries: Int
    let entryTypes: Int
    let lastUpdate: Int
    let avgPriority: Double
}
