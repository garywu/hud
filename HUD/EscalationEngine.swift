import Foundation
import Observation

// MARK: - Escalation Engine

/// Monitors unacknowledged notifications and escalates their severity over time.
///
/// Rules (from atlas#656):
///   yellow -> red    after 5 minutes  (300s)
///   red    -> sos    after 15 minutes (900s)
///   sos    -> Telegram alert after 1 minute (60s)
///
/// Writes escalated levels to ~/.atlas/status.json and triggers jane-notify.sh
/// for the final Telegram escalation.
@Observable
class EscalationEngine {
    static let shared = EscalationEngine()

    // MARK: - Types

    struct EscalationRule: Codable, Equatable {
        let fromLevel: String     // "yellow", "red", "sos"
        let toLevel: String       // "red", "sos", "telegram"
        let afterSeconds: Int     // threshold in seconds
    }

    struct TrackedMessage {
        let originalLevel: String
        var currentLevel: String
        var arrivedAt: Date
        var lastEscalatedAt: Date
        var acknowledged: Bool
        var telegramSent: Bool
    }

    // MARK: - State

    var rules: [EscalationRule] = [
        EscalationRule(fromLevel: "yellow", toLevel: "red", afterSeconds: 300),
        EscalationRule(fromLevel: "red", toLevel: "sos", afterSeconds: 900),
        EscalationRule(fromLevel: "sos", toLevel: "telegram", afterSeconds: 60),
    ]

    /// Messages being tracked for escalation, keyed by message ID.
    var trackedMessages: [String: TrackedMessage] = [:]

    /// Count of currently tracked (unacknowledged) messages.
    var activeCount: Int {
        trackedMessages.values.filter { !$0.acknowledged }.count
    }

    private var monitorTimer: Timer?
    private let checkInterval: TimeInterval = 30.0

    private let statusPath = NSString("~/.atlas/status.json").expandingTildeInPath
    private let logPath = NSString("~/.atlas/logs/escalation.log").expandingTildeInPath
    private let notifyScriptPath = NSString("~/.atlas/bin/jane-notify.sh").expandingTildeInPath

    // MARK: - Lifecycle

    func startMonitoring() {
        log("Escalation engine started — \(rules.count) rules, check interval \(Int(checkInterval))s")

        // Ingest any existing queue messages on startup
        ingestCurrentQueue()

        // Timer every 30 seconds: check tracked messages
        monitorTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        log("Escalation engine stopped")
    }

    // MARK: - Tracking

    /// Begin tracking a message for escalation.
    /// Called when a new notification arrives via the queue.
    func track(messageId: String, level: String) {
        // Only track non-green levels
        guard level != "green" else { return }
        // Don't re-track already tracked messages
        guard trackedMessages[messageId] == nil else { return }

        let now = Date()
        trackedMessages[messageId] = TrackedMessage(
            originalLevel: level,
            currentLevel: level,
            arrivedAt: now,
            lastEscalatedAt: now,
            acknowledged: false,
            telegramSent: false
        )
        log("Tracking \(messageId) at level=\(level)")
    }

    /// Mark a message as acknowledged, stopping further escalation.
    func acknowledge(_ messageId: String) {
        guard var msg = trackedMessages[messageId] else { return }
        msg.acknowledged = true
        trackedMessages[messageId] = msg
        log("Acknowledged \(messageId) — escalation stopped")
    }

    /// Stop tracking a message entirely (e.g., when dismissed or expired).
    func untrack(_ messageId: String) {
        if trackedMessages.removeValue(forKey: messageId) != nil {
            log("Untracked \(messageId)")
        }
    }

    // MARK: - Escalation Tick

    /// Evaluate all tracked messages against escalation rules.
    private func tick() {
        let now = Date()
        var escalated = false

        for (id, var msg) in trackedMessages {
            guard !msg.acknowledged else { continue }

            let elapsed = now.timeIntervalSince(msg.arrivedAt)

            // Find the applicable rule for the current level
            guard let rule = rules.first(where: { $0.fromLevel == msg.currentLevel }) else {
                continue
            }

            if elapsed >= Double(rule.afterSeconds) {
                if rule.toLevel == "telegram" {
                    // Final escalation: send Telegram alert
                    if !msg.telegramSent {
                        sendTelegramAlert(messageId: id, message: msg)
                        msg.telegramSent = true
                        trackedMessages[id] = msg
                        log("TELEGRAM ALERT for \(id) — unacknowledged \(Int(elapsed))s at level=\(msg.currentLevel)")
                    }
                } else {
                    // Escalate severity
                    let oldLevel = msg.currentLevel
                    msg.currentLevel = rule.toLevel
                    msg.lastEscalatedAt = now
                    // Reset arrivedAt so the next rule's timer starts from escalation
                    msg.arrivedAt = now
                    trackedMessages[id] = msg
                    escalated = true
                    log("ESCALATED \(id): \(oldLevel) -> \(rule.toLevel) after \(rule.afterSeconds)s")

                    // Update the queue message severity
                    escalateInQueue(messageId: id, newLevel: rule.toLevel)
                    // Update status.json if this is the active message
                    updateStatusIfActive(messageId: id, newLevel: rule.toLevel)
                }
            }
        }

        if escalated {
            // Broadcast SSE event for any listening clients
            broadcastEscalationEvent()
        }
    }

    // MARK: - Queue Integration

    /// Ingest currently queued messages on startup so we track them.
    private func ingestCurrentQueue() {
        let mgr = MessageQueueManager.shared
        for msg in mgr.queue where !msg.isExpired {
            track(messageId: msg.id, level: msg.severity)
        }
    }

    /// Update a message's severity in the MessageQueue.
    private func escalateInQueue(messageId: String, newLevel: String) {
        let mgr = MessageQueueManager.shared
        guard let idx = mgr.queue.firstIndex(where: { $0.id == messageId }) else { return }

        let old = mgr.queue[idx]
        let updated = QueuedMessage(
            id: old.id,
            source: old.source,
            severity: newLevel,
            priority: QueuedMessage.defaultPriority(for: newLevel),
            message: old.message,
            banner: old.banner,
            bannerStyle: old.bannerStyle,
            slots: old.slots,
            created: old.created,
            ttl: newLevel == "sos" ? nil : old.ttl  // sos never expires
        )
        mgr.queue[idx] = updated
    }

    /// If the escalated message is the active one, push updated severity to status.json.
    private func updateStatusIfActive(messageId: String, newLevel: String) {
        let mgr = MessageQueueManager.shared
        guard let active = mgr.activeMessage, active.id == messageId else { return }

        let current = StatusWatcher.shared.currentStatus
        let updated = AtlasStatus(
            status: newLevel,
            source: current.source,
            message: current.message,
            banner: current.banner,
            bannerStyle: current.bannerStyle,
            updated: ISO8601DateFormatter().string(from: Date()),
            details: current.details,
            slots: current.slots,
            statusBar: current.statusBar
        )
        StatusWatcher.shared.currentStatus = updated

        // Also persist to disk
        writeStatus(updated)
    }

    private func writeStatus(_ status: AtlasStatus) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(status) else { return }
        try? data.write(to: URL(fileURLWithPath: statusPath), options: .atomic)
    }

    // MARK: - Telegram Alert

    /// Execute jane-notify.sh to send a Telegram alert for an SOS-level escalation.
    private func sendTelegramAlert(messageId: String, message: TrackedMessage) {
        let scriptPath = notifyScriptPath

        // If the script doesn't exist, fall back to writing a request file
        if !FileManager.default.isExecutableFile(atPath: scriptPath) {
            writeTelegramFallback(messageId: messageId, message: message)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            scriptPath,
            "ESCALATION: Message \(messageId) unacknowledged at SOS level"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if process.terminationStatus == 0 {
                log("Telegram alert sent for \(messageId)")
            } else {
                log("Telegram alert FAILED for \(messageId) — exit \(process.terminationStatus): \(output)")
            }
        } catch {
            log("Telegram alert ERROR for \(messageId): \(error)")
            writeTelegramFallback(messageId: messageId, message: message)
        }
    }

    /// Fallback: write a JSON file that another process can pick up.
    private func writeTelegramFallback(messageId: String, message: TrackedMessage) {
        let outboxPath = NSString("~/.atlas/outbox/").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: outboxPath, withIntermediateDirectories: true)

        let alert: [String: Any] = [
            "type": "escalation_alert",
            "message_id": messageId,
            "level": message.currentLevel,
            "original_level": message.originalLevel,
            "unacknowledged_since": ISO8601DateFormatter().string(from: message.arrivedAt),
            "created": ISO8601DateFormatter().string(from: Date()),
        ]

        let filePath = (outboxPath as NSString).appendingPathComponent("escalation-\(messageId).json")
        if let data = try? JSONSerialization.data(withJSONObject: alert, options: .prettyPrinted) {
            try? data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
            log("Telegram fallback written to \(filePath)")
        }
    }

    // MARK: - SSE Broadcast

    private func broadcastEscalationEvent() {
        // Trigger a re-read of the queue so the HUD updates immediately
        MessageQueueManager.shared.startWatching()
    }

    // MARK: - Logging

    private func log(_ msg: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] EscalationEngine: \(msg)\n"
        let logDir = (logPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
        }
        NSLog("EscalationEngine: %@", msg)
    }
}
