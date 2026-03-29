import Foundation
import os

/// VoiceContextManager - Integrates voice transcription with memory enrichment
///
/// Responsibilities:
/// - Query TIER 1 memory for recent context before/after transcription
/// - Enrich voice transcriptions with context summaries
/// - Store voice interactions in recent_interruptions
/// - Extract and display context hints in UI
///
/// Usage:
/// ```swift
/// let manager = VoiceContextManager()
/// let enriched = await manager.enrichTranscription(
///     transcript: "remind me to call Gary",
///     sessionId: "session-123"
/// )
/// // Result: "remind me to call Gary. Context: Recently discussed project deadline with Gary at 2:45pm"
/// ```
class VoiceContextManager {
    private let logger = Logger(subsystem: "com.atlas.hud.voice", category: "VoiceContextManager")
    private let repository: TierOneRepository
    private let db: DatabaseManager

    // MARK: - Initialization

    init(database: DatabaseManager = .shared) {
        self.db = database
        self.repository = TierOneRepository(database: database)
        self.logger.info("VoiceContextManager initialized")
    }

    // MARK: - Context Enrichment

    /// Queries recent context and returns a summary for UI display
    /// Used to show "Based on your call with Gary 5 min ago..." in the UI
    ///
    /// - Parameter sessionId: Current session identifier
    /// - Returns: Context summary string or nil if no relevant context
    func getContextSummary(sessionId: String) -> String? {
        do {
            let entries = try repository.listRecentContext(
                sessionId: sessionId,
                limit: 10
            )

            // Filter for high-priority, recent entries
            let now = Int(Date().timeIntervalSince1970)
            let recentThreshold = now - 300  // Last 5 minutes
            let highPriority = entries.filter {
                ($0.expiresAt ?? 0) > now &&
                ($0.updatedAt >= recentThreshold || $0.priority > 1)
            }

            guard !highPriority.isEmpty else { return nil }

            // Extract summary from top 3 entries
            var summary = "Based on"
            var parts: [String] = []

            for (idx, entry) in highPriority.prefix(3).enumerated() {
                if idx > 0 { summary += ";" }

                let ageMinutes = (now - entry.updatedAt) / 60
                let ageStr = ageMinutes < 1 ? "just now" : "\(ageMinutes)m ago"

                switch entry.type {
                case "interruption":
                    if let metadata = entry.metadata {
                        parts.append("\(metadata) \(ageStr)")
                    }
                case "task":
                    if let value = extractTitle(from: entry.value) {
                        parts.append("task: \(value) \(ageStr)")
                    }
                case "focus":
                    if let value = extractTitle(from: entry.value) {
                        parts.append("working on: \(value) \(ageStr)")
                    }
                default:
                    break
                }
            }

            guard !parts.isEmpty else { return nil }
            return summary + " " + parts.joined(separator: ", ")
        } catch {
            logger.error("Failed to get context summary: \(error.localizedDescription)")
            return nil
        }
    }

    /// Enriches a voice transcription with context
    /// After WhisperKit returns transcription, call this to add memory context
    ///
    /// - Parameters:
    ///   - transcript: Raw transcription from WhisperKit
    ///   - sessionId: Current session identifier
    /// - Returns: Enriched transcript with context appended
    func enrichTranscription(transcript: String, sessionId: String) -> String {
        do {
            // Query recent context (last 30 minutes)
            let recentContext = try repository.listRecentContext(
                sessionId: sessionId,
                limit: 15
            )

            // Extract mood, topics, recent people
            let mood = extractMood(from: recentContext)
            let topics = extractTopics(from: recentContext)
            let people = extractPeople(from: recentContext)

            // Store the voice interaction
            try repository.upsertRecentContext(
                sessionId: sessionId,
                type: "voice_event",
                key: "transcription_\(UUID().uuidString.prefix(8))",
                value: transcript,
                metadata: "voice_input",
                priority: 2,  // High priority
                ttlSeconds: 1800
            )

            logger.info("Stored voice interaction: \(transcript.prefix(50))...")

            // Build enrichment context
            var enrichment = ""
            if !topics.isEmpty {
                enrichment += "Topics: \(topics.joined(separator: ", ")). "
            }
            if !people.isEmpty {
                enrichment += "People: \(people.joined(separator: ", ")). "
            }
            if let m = mood, !m.isEmpty {
                enrichment += "Mood: \(m). "
            }

            if enrichment.isEmpty {
                return transcript
            }

            return "User said: '\(transcript)'. Context: \(enrichment)"
        } catch {
            logger.error("Failed to enrich transcription: \(error.localizedDescription)")
            // Return unmodified transcript on error
            return transcript
        }
    }

    /// Store a voice interaction as an interruption (for high-priority events)
    /// Use for voice commands that trigger significant actions
    ///
    /// - Parameters:
    ///   - sessionId: Current session identifier
    ///   - transcript: What the user said
    ///   - isHighPriority: If true, marks as 'yellow' severity; else 'normal'
    func recordVoiceInterruption(
        sessionId: String,
        transcript: String,
        isHighPriority: Bool = false
    ) {
        do {
            let severity = isHighPriority ? "yellow" : "normal"
            try repository.createInterruption(
                sessionId: sessionId,
                reason: "voice_command",
                severity: severity,
                source: "voice_input",
                ttlSeconds: 3600  // 1 hour TTL for interruptions
            )

            logger.info("Recorded voice interruption: \(severity)")
        } catch {
            logger.error("Failed to record voice interruption: \(error.localizedDescription)")
        }
    }

    /// Query database statistics for debugging
    func getMemoryStats(sessionId: String) -> MemoryStats? {
        do {
            let stats = try repository.getStats(sessionId: sessionId)
            let now = Int(Date().timeIntervalSince1970)
            let lastUpdateSeconds = now - stats.lastUpdate

            return MemoryStats(
                totalEntries: stats.totalEntries,
                entryTypes: stats.entryTypes,
                lastUpdateSeconds: lastUpdateSeconds,
                averagePriority: stats.avgPriority
            )
        } catch {
            logger.error("Failed to get memory stats: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private Helper Methods

    /// Extract mood from recent context entries
    private func extractMood(from entries: [RecentContextEntry]) -> String? {
        let moodEntries = entries.filter { $0.type == "mood" }
        guard let first = moodEntries.first else { return nil }

        return extractTitle(from: first.value)
    }

    /// Extract topics from recent context entries
    private func extractTopics(from entries: [RecentContextEntry]) -> [String] {
        let topicEntries = entries.filter { $0.type == "topic" || $0.type == "task" }

        return topicEntries.compactMap { entry in
            extractTitle(from: entry.value)
        }.prefix(3).map { String($0) }
    }

    /// Extract people names from recent context entries
    private func extractPeople(from entries: [RecentContextEntry]) -> [String] {
        let peopleEntries = entries.filter { $0.type == "person" || $0.metadata != nil }

        return peopleEntries.compactMap { entry in
            entry.metadata ?? extractTitle(from: entry.value)
        }.prefix(3).map { String($0) }
    }

    /// Parse JSON string and extract title/name field
    private func extractTitle(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // If not JSON, return first 50 chars
            let trimmed = jsonString.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(50))
        }

        // Try common field names
        for key in ["title", "name", "text", "value", "description"] {
            if let value = json[key] as? String, !value.isEmpty {
                return value.prefix(50).description
            }
        }

        // Fallback: stringify the JSON
        let keys = json.keys.prefix(2).joined(separator: ", ")
        return keys.isEmpty ? nil : keys
    }
}

// MARK: - Data Models

struct MemoryStats {
    let totalEntries: Int
    let entryTypes: Int
    let lastUpdateSeconds: Int
    let averagePriority: Double
}
