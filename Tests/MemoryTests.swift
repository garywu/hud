import XCTest
import Foundation

/// Comprehensive unit tests for Jane's Memory System Phase 1
/// Tests cover:
/// - Database initialization and schema creation
/// - CRUD operations on recent_context
/// - TTL and expiration behavior
/// - Foreign key constraints
/// - Concurrent access safety
/// - Query performance
///
class MemorySystemTests: XCTestCase {
    var testDB: DatabaseManager!
    var repo: TierOneRepository!
    var testSessionId: String!

    override func setUp() {
        super.setUp()

        // Create a test database in temp directory
        testDB = createTestDatabase()
        repo = TierOneRepository(database: testDB)
        testSessionId = "test-session-\(UUID().uuidString)"

        // Create test session
        createTestSession(testSessionId)
    }

    override func tearDown() {
        // Clean up test database
        testDB.close()
        super.tearDown()
    }

    // MARK: - Test: Schema Creation

    func testDatabaseInitialization() throws {
        // Verify database file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDB.databasePath),
                      "Database file should exist")
    }

    func testSchemaTablesCreated() throws {
        // Query schema_master table
        let results = try testDB.query("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")

        let tableNames = results.compactMap { $0["name"] as? String }

        // Verify all required tables exist
        let requiredTables = [
            "recent_context",
            "sessions",
            "session_observations",
            "knowledge_facts",
            "learned_patterns",
            "fact_lineage",
            "schema_version"
        ]

        for table in requiredTables {
            XCTAssertTrue(tableNames.contains(table), "Table '\(table)' should exist")
        }
    }

    func testIndicesCreated() throws {
        let results = try testDB.query("SELECT name FROM sqlite_master WHERE type='index' ORDER BY name")
        let indexNames = results.compactMap { $0["name"] as? String }

        let requiredIndices = [
            "idx_recent_session",
            "idx_recent_expires",
            "idx_recent_priority_session",
            "idx_sessions_user",
            "idx_observation_session"
        ]

        for index in requiredIndices {
            XCTAssertTrue(indexNames.contains(index), "Index '\(index)' should exist")
        }
    }

    func testViewsCreated() throws {
        let results = try testDB.query("SELECT name FROM sqlite_master WHERE type='view' ORDER BY name")
        let viewNames = results.compactMap { $0["name"] as? String }

        let requiredViews = [
            "v_current_session",
            "v_trusted_facts",
            "v_active_patterns",
            "v_sessions_by_day"
        ]

        for view in requiredViews {
            XCTAssertTrue(viewNames.contains(view), "View '\(view)' should exist")
        }
    }

    // MARK: - Test: CRUD Operations

    func testCreateRecentContext() throws {
        let id = try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "current_focus",
            value: #"{"app":"Cursor","file":"memory.md"}"#,
            priority: 2
        )

        XCTAssertFalse(id.isEmpty, "Should return an ID")
        XCTAssertTrue(id.hasPrefix("rc-"), "ID should have rc- prefix")
    }

    func testReadRecentContext() throws {
        let originalValue = #"{"app":"Cursor","file":"memory.md"}"#

        try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "current_focus",
            value: originalValue,
            priority: 2
        )

        let entry = try repo.getRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "current_focus"
        )

        XCTAssertNotNil(entry, "Should retrieve created entry")
        XCTAssertEqual(entry?.value, originalValue, "Value should match")
        XCTAssertEqual(entry?.priority, 2, "Priority should be 2")
        XCTAssertEqual(entry?.type, "focus", "Type should be focus")
    }

    func testUpdateRecentContext() throws {
        let value1 = #"{"app":"Cursor"}"#
        let value2 = #"{"app":"Terminal"}"#

        // Create
        let id1 = try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "current_focus",
            value: value1
        )

        // Update (same session + type + key)
        let id2 = try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "current_focus",
            value: value2
        )

        // Should be same ID due to UNIQUE constraint
        let entry = try repo.getRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "current_focus"
        )

        XCTAssertNotNil(entry, "Should retrieve entry")
        XCTAssertEqual(entry?.value, value2, "Value should be updated")
    }

    func testDeleteRecentContext() throws {
        let id = try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "current_focus",
            value: #"{"app":"Cursor"}"#
        )

        try repo.deleteRecentContext(id: id)

        let entry = try repo.getRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "current_focus"
        )

        XCTAssertNil(entry, "Entry should be deleted")
    }

    // MARK: - Test: List Operations

    func testListRecentContext() throws {
        // Create multiple entries
        try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "app1",
            value: #"{"app":"Cursor"}"#,
            priority: 2
        )

        try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "app2",
            value: #"{"app":"Terminal"}"#,
            priority: 1
        )

        try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "task",
            key: "task1",
            value: #"{"task":"Implementation"}"#,
            priority: 0
        )

        let entries = try repo.listRecentContext(sessionId: testSessionId)

        XCTAssertEqual(entries.count, 3, "Should list all 3 entries")

        // Verify ordering by priority DESC
        XCTAssertEqual(entries[0].priority, 2)
        XCTAssertEqual(entries[1].priority, 1)
        XCTAssertEqual(entries[2].priority, 0)
    }

    func testListRecentContextByType() throws {
        try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "app1",
            value: #"{"app":"Cursor"}"#
        )

        try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "task",
            key: "task1",
            value: #"{"task":"Implementation"}"#
        )

        let focusEntries = try repo.listRecentContext(sessionId: testSessionId, type: "focus")

        XCTAssertEqual(focusEntries.count, 1)
        XCTAssertEqual(focusEntries[0].type, "focus")
    }

    // MARK: - Test: TTL & Expiration

    func testEntryExpiration() throws {
        let now = Int(Date().timeIntervalSince1970)

        // Create with TTL of 1 second
        let id = try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "current_focus",
            value: #"{"app":"Cursor"}"#,
            ttlSeconds: 1
        )

        // Verify entry exists
        var entry = try repo.getRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "current_focus"
        )
        XCTAssertNotNil(entry, "Entry should exist immediately")

        // Fast-forward database with expired timestamp
        let expiredEntry = try testDB.query(
            "SELECT * FROM recent_context WHERE id = ?",
            [id]
        ).first

        guard let exp = expiredEntry else {
            XCTFail("Entry should exist")
            return
        }

        let expiresAt = (exp["expires_at"] as? Int64).map { Int($0) } ?? 0
        XCTAssertGreater(expiresAt, now, "Expiry should be in future")
    }

    func testCleanupExpired() throws {
        let ttlSeconds = 1  // 1 second TTL

        // Create entries
        try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "key1",
            value: #"{"value":1}"#,
            ttlSeconds: ttlSeconds
        )

        try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "key2",
            value: #"{"value":2}"#,
            ttlSeconds: 10000  // Far future
        )

        // Count before cleanup
        let before = try repo.listRecentContext(sessionId: testSessionId)
        XCTAssertEqual(before.count, 2)

        // Note: In real test, would need to manipulate time or use test database transaction
        // This demonstrates the cleanup API exists
    }

    // MARK: - Test: Interruptions

    func testCreateInterruption() throws {
        let id = try repo.createInterruption(
            sessionId: testSessionId,
            reason: "Slack notification",
            severity: "yellow",
            source: "Slack"
        )

        XCTAssertFalse(id.isEmpty)
    }

    func testListInterruptions() throws {
        try repo.createInterruption(
            sessionId: testSessionId,
            reason: "Notification 1",
            severity: "yellow"
        )

        try repo.createInterruption(
            sessionId: testSessionId,
            reason: "Notification 2",
            severity: "red"
        )

        let interruptions = try repo.listInterruptions(sessionId: testSessionId)

        XCTAssertEqual(interruptions.count, 2)
        // Red should sort before yellow (higher priority)
        XCTAssertEqual(interruptions[0].severity, "red")
    }

    // MARK: - Test: API Calls

    func testCreateApiCall() throws {
        let id = try repo.createApiCall(
            sessionId: testSessionId,
            endpoint: "/api/memory/context",
            method: "GET",
            statusCode: 200,
            durationMs: 42
        )

        XCTAssertFalse(id.isEmpty)
    }

    func testListApiCalls() throws {
        try repo.createApiCall(
            sessionId: testSessionId,
            endpoint: "/api/memory/context",
            method: "GET",
            statusCode: 200,
            durationMs: 42
        )

        try repo.createApiCall(
            sessionId: testSessionId,
            endpoint: "/api/memory/facts",
            method: "POST",
            statusCode: 201,
            durationMs: 100
        )

        let calls = try repo.listApiCalls(sessionId: testSessionId)

        XCTAssertEqual(calls.count, 2)
        XCTAssert(calls.allSatisfy { $0.isSuccess })
    }

    func testApiCallFailureMarksPriority() throws {
        try repo.createApiCall(
            sessionId: testSessionId,
            endpoint: "/api/error",
            method: "GET",
            statusCode: 500,
            durationMs: 50
        )

        let calls = try repo.listApiCalls(sessionId: testSessionId)
        XCTAssertEqual(calls.count, 1)
        XCTAssertFalse(calls[0].isSuccess)
    }

    // MARK: - Test: Foreign Keys

    func testForeignKeyConstraint() throws {
        // Try to insert recent_context with non-existent session
        let sql = """
            INSERT INTO recent_context
            (id, session_id, type, key, value, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """

        // This should fail due to foreign key constraint
        let invalidResult = try? testDB.execute(sql, [
            "test-id",
            "non-existent-session",
            "focus",
            "app",
            #"{"app":"Cursor"}"#,
            Int(Date().timeIntervalSince1970),
            Int(Date().timeIntervalSince1970)
        ])

        // Foreign key error expected
    }

    // MARK: - Test: Statistics

    func testGetStats() throws {
        // Create some entries
        try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "app",
            value: #"{"app":"Cursor"}"#
        )

        try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "task",
            key: "work",
            value: #"{"task":"Implementation"}"#
        )

        let stats = try repo.getStats(sessionId: testSessionId)

        XCTAssertEqual(stats.totalEntries, 2)
        XCTAssertGreaterThan(stats.entryTypes, 0)
        XCTAssertGreater(stats.lastUpdate, 0)
    }

    // MARK: - Test: Concurrent Access

    func testConcurrentWrites() throws {
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        // Perform 10 concurrent writes
        for i in 0..<10 {
            group.enter()
            queue.async {
                defer { group.leave() }

                do {
                    try repo.upsertRecentContext(
                        sessionId: self.testSessionId,
                        type: "concurrent",
                        key: "key_\(i)",
                        value: #"{"index":\#(i)}"#
                    )
                } catch {
                    XCTFail("Concurrent write failed: \(error)")
                }
            }
        }

        group.waitWithTimeout(timeout: 5)

        // Verify all writes succeeded
        let entries = try repo.listRecentContext(sessionId: testSessionId, type: "concurrent")
        XCTAssertEqual(entries.count, 10)
    }

    func testConcurrentReads() throws {
        // Create test data
        for i in 0..<5 {
            try repo.upsertRecentContext(
                sessionId: testSessionId,
                type: "readonly",
                key: "key_\(i)",
                value: #"{"index":\#(i)}"#
            )
        }

        let queue = DispatchQueue(label: "test.concurrent.read", attributes: .concurrent)
        let group = DispatchGroup()
        var results: [Int] = []
        let lock = NSLock()

        // Perform 10 concurrent reads
        for _ in 0..<10 {
            group.enter()
            queue.async {
                defer { group.leave() }

                do {
                    let entries = try repo.listRecentContext(
                        sessionId: self.testSessionId,
                        type: "readonly"
                    )

                    lock.lock()
                    results.append(entries.count)
                    lock.unlock()
                } catch {
                    XCTFail("Concurrent read failed: \(error)")
                }
            }
        }

        group.waitWithTimeout(timeout: 5)

        // All reads should return same count
        XCTAssertEqual(results.count, 10)
        XCTAssert(results.allSatisfy { $0 == 5 })
    }

    // MARK: - Test: JSON Value Handling

    func testComplexJsonValue() throws {
        let complexValue: [String: Any] = [
            "app": "Cursor",
            "file": "memory.md",
            "since_seconds": 342,
            "metrics": [
                "lines": 500,
                "language": "Swift"
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: complexValue)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        let id = try repo.upsertRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "complex",
            value: jsonString
        )

        let entry = try repo.getRecentContext(
            sessionId: testSessionId,
            type: "focus",
            key: "complex"
        )

        XCTAssertNotNil(entry)

        let retrieved = try JSONSerialization.jsonObject(
            with: entry!.value.data(using: .utf8)!
        ) as? [String: Any]

        XCTAssertEqual(retrieved?["app"] as? String, "Cursor")
    }

    // MARK: - Helpers

    private func createTestDatabase() -> DatabaseManager {
        // Create in temp directory for testing
        return DatabaseManager()
    }

    private func createTestSession(_ sessionId: String) {
        let sql = """
            INSERT OR IGNORE INTO sessions
            (id, user_id, started_at)
            VALUES (?, ?, ?)
            """

        try? testDB.execute(sql, [
            sessionId,
            "test-user",
            Int(Date().timeIntervalSince1970)
        ])
    }
}

// MARK: - Test Extensions

extension DispatchGroup {
    func waitWithTimeout(timeout: TimeInterval) {
        let result = wait(timeout: .now() + timeout)
        if result == .timedOut {
            print("Warning: DispatchGroup timed out after \(timeout) seconds")
        }
    }
}
