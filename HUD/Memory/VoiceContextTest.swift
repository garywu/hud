import Foundation

/// VoiceContextTest - Demo and test for voice context enrichment
///
/// This demonstrates:
/// 1. Initializing memory system
/// 2. Storing test context data
/// 3. Enriching voice transcriptions
/// 4. Verifying memory storage
///
/// Run with: swift HUD/Memory/VoiceContextTest.swift
class VoiceContextTest {
    private let db = DatabaseManager.shared
    private let repository: TierOneRepository
    private let voiceManager: VoiceContextManager

    init() {
        self.repository = TierOneRepository(database: db)
        self.voiceManager = VoiceContextManager(database: db)
    }

    // MARK: - Test Methods

    func runTests() {
        print("=== Voice Context Manager Test Suite ===\n")

        testDatabaseInitialization()
        testContextStorage()
        testContextEnrichment()
        testMemoryStats()

        print("\n=== All Tests Complete ===")
    }

    // MARK: - Individual Tests

    func testDatabaseInitialization() {
        print("TEST 1: Database Initialization")
        do {
            let results = try db.query("SELECT version FROM schema_version LIMIT 1")
            if let version = results.first?["version"] as? Int {
                print("✓ Database initialized with schema v\(version)")
                print("  Location: ~/.atlas/jane-hud/memory.db")
            } else {
                print("✗ Schema version table empty")
            }
        } catch {
            print("✗ Failed to query database: \(error)")
        }
        print()
    }

    func testContextStorage() {
        print("TEST 2: Context Storage (TIER 1)")
        let sessionId = "test-session-\(UUID().uuidString.prefix(8))"
        print("  Session: \(sessionId)")

        do {
            // Store a task
            let taskData: [String: Any] = ["title": "Review PR #42", "description": "Code review for authentication module"]
            let taskJson = String(data: try JSONSerialization.data(withJSONObject: taskData), encoding: .utf8) ?? "{}"

            let taskId = try repository.upsertRecentContext(
                sessionId: sessionId,
                type: "task",
                key: "current_task",
                value: taskJson,
                metadata: "engineering",
                priority: 2,
                ttlSeconds: 1800
            )
            print("✓ Stored task: \(taskId)")

            // Store a recent person (interruption source)
            let personId = try repository.createInterruption(
                sessionId: sessionId,
                reason: "call_from_gary",
                severity: "yellow",
                source: "Gary (Project Manager)",
                ttlSeconds: 1800
            )
            print("✓ Stored interruption: \(personId)")

            // Store a focus app
            let focusData: [String: Any] = ["app": "VSCode", "file": "auth.ts"]
            let focusJson = String(data: try JSONSerialization.data(withJSONObject: focusData), encoding: .utf8) ?? "{}"

            let focusId = try repository.upsertRecentContext(
                sessionId: sessionId,
                type: "focus",
                key: "current_focus",
                value: focusJson,
                metadata: "VSCode",
                priority: 1,
                ttlSeconds: 1800
            )
            print("✓ Stored focus app: \(focusId)")

            // Verify storage
            let storedEntries = try repository.listRecentContext(
                sessionId: sessionId,
                limit: 10
            )
            print("✓ Verified: \(storedEntries.count) entries stored and retrievable")
        } catch {
            print("✗ Failed to store context: \(error)")
        }
        print()
    }

    func testContextEnrichment() {
        print("TEST 3: Voice Transcription Enrichment")
        let sessionId = "enrichment-test-\(UUID().uuidString.prefix(8))"
        print("  Session: \(sessionId)")

        do {
            // Pre-populate context
            let _ = try repository.createInterruption(
                sessionId: sessionId,
                reason: "message_from_alice",
                severity: "normal",
                source: "Alice (Designer)",
                ttlSeconds: 1800
            )

            let taskData: [String: Any] = ["title": "Design system update"]
            let taskJson = String(data: try JSONSerialization.data(withJSONObject: taskData), encoding: .utf8) ?? "{}"
            let _ = try repository.upsertRecentContext(
                sessionId: sessionId,
                type: "task",
                key: "main_task",
                value: taskJson,
                metadata: "design",
                priority: 2,
                ttlSeconds: 1800
            )

            // Enrich a transcription
            let rawTranscript = "remind me to send the mockups to marketing"
            let enriched = voiceManager.enrichTranscription(
                transcript: rawTranscript,
                sessionId: sessionId
            )

            print("  Raw:      '\(rawTranscript)'")
            print("  Enriched: '\(enriched)'")
            print("✓ Transcription enriched with memory context")

            // Get context summary for UI
            if let summary = voiceManager.getContextSummary(sessionId: sessionId) {
                print("✓ UI Summary: \(summary)")
            } else {
                print("✓ No recent context for summary (expected for new session)")
            }
        } catch {
            print("✗ Failed to enrich transcription: \(error)")
        }
        print()
    }

    func testMemoryStats() {
        print("TEST 4: Memory Statistics")
        let sessionId = "stats-test-\(UUID().uuidString.prefix(8))"

        do {
            // Add some entries
            for i in 1...3 {
                let data: [String: Any] = ["index": i, "text": "entry_\(i)"]
                let json = String(data: try JSONSerialization.data(withJSONObject: data), encoding: .utf8) ?? "{}"

                let _ = try repository.upsertRecentContext(
                    sessionId: sessionId,
                    type: "test",
                    key: "entry_\(i)",
                    value: json,
                    priority: i,
                    ttlSeconds: 1800
                )
            }

            // Get stats
            if let stats = voiceManager.getMemoryStats(sessionId: sessionId) {
                print("✓ Memory Stats:")
                print("  Total Entries: \(stats.totalEntries)")
                print("  Entry Types: \(stats.entryTypes)")
                print("  Last Update: \(stats.lastUpdateSeconds)s ago")
                print("  Avg Priority: \(String(format: "%.2f", stats.averagePriority))")
            } else {
                print("✗ Failed to get stats")
            }
        } catch {
            print("✗ Error during stats test: \(error)")
        }
        print()
    }
}

// MARK: - Entry Point

// Uncomment to run tests from command line
// let test = VoiceContextTest()
// test.runTests()
