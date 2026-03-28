import Foundation
import Observation

// MARK: - Queued Message

struct QueuedMessage: Codable, Equatable, Identifiable {
    let id: String
    let source: String           // "athena" | "jane" | session id
    let severity: String         // "green" | "yellow" | "red"
    let priority: Int            // 0-100, higher = more important
    let message: String          // hover panel text
    let banner: String?          // ticker text
    let bannerStyle: String?     // animation theme
    let slots: [String: SlotData]?
    let created: String          // ISO 8601
    let ttl: Int?                // seconds until auto-expire (nil = no expiry)

    /// Source priority: system > observer > session
    var sourcePriority: Int {
        switch source {
        case "athena": return 30
        case "jane":   return 20
        default:       return 10  // Claude Code sessions
        }
    }

    /// Composite sort score: severity priority + source priority
    var sortScore: Int {
        priority + sourcePriority
    }

    var isExpired: Bool {
        guard let ttl = ttl else { return false }
        let formatter = ISO8601DateFormatter()
        guard let createdDate = formatter.date(from: created) else { return false }
        return Date().timeIntervalSince(createdDate) > Double(ttl)
    }

    /// Convenience: severity as a numeric priority
    static func defaultPriority(for severity: String) -> Int {
        switch severity {
        case "red":    return 100
        case "yellow": return 50
        case "green":  return 10
        default:       return 0
        }
    }
}

struct SlotData: Codable, Equatable {
    let type: String      // "metric" | "agent_status" | "text_label" | "countdown"
    let label: String
    let value: String
    let trend: String?    // "up" | "down" | "flat"
    let state: String?    // "active" | "idle" | "error"
    let icon: String?
}

// MARK: - Queue File

struct StatusQueue: Codable, Equatable {
    var messages: [QueuedMessage]
}

// MARK: - Message Queue Manager

@Observable
class MessageQueueManager {
    static let shared = MessageQueueManager()

    var queue: [QueuedMessage] = []
    var activeMessage: QueuedMessage?

    private var queueMonitor: DispatchSourceFileSystemObject?
    private var pruneTimer: Timer?
    private var rotationTimer: Timer?
    private var rotationIndex: Int = 0

    private let queuePath = NSString("~/.atlas/status-queue.json").expandingTildeInPath
    // Also watch legacy status.json for backward compat
    private let legacyPath = NSString("~/.atlas/status.json").expandingTildeInPath

    /// Rotation interval for same-priority messages (seconds)
    var rotationInterval: TimeInterval = 5.0

    func startWatching() {
        readQueue()
        resolveActive()

        // Watch queue file
        watchFile(path: queuePath) { [weak self] in
            self?.readQueue()
            self?.resolveActive()
        }

        // Watch legacy status.json — convert to queue entry
        watchFile(path: legacyPath) { [weak self] in
            self?.ingestLegacyStatus()
        }

        // Prune expired messages every 5 seconds
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.pruneExpired()
        }

        // Rotate same-priority messages
        rotationTimer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { [weak self] _ in
            self?.rotateIfNeeded()
        }
    }

    // MARK: - Queue Resolution

    /// Minimum time a message must be displayed before being replaced (seconds)
    private let minDisplayTime: TimeInterval = 3.0
    private var lastSwitchTime: Date = .distantPast

    /// Determine which message should be displayed
    private func resolveActive() {
        // Sort by score descending, then by creation time (newer first)
        let sorted = queue
            .filter { !$0.isExpired }
            .sorted { a, b in
                if a.sortScore != b.sortScore { return a.sortScore > b.sortScore }
                return a.created > b.created
            }

        let newActive = sorted.first

        // Don't replace current message if it hasn't been shown long enough
        // (unless new message is higher priority)
        if let current = activeMessage, let new = newActive,
           new.id != current.id,
           new.sortScore <= current.sortScore,
           Date().timeIntervalSince(lastSwitchTime) < minDisplayTime {
            return
        }

        if newActive != activeMessage {
            activeMessage = newActive
            lastSwitchTime = Date()
            // Push to StatusWatcher for the rest of the HUD to consume
            syncToStatusWatcher()
        }
    }

    /// Rotate among messages with the same top score
    private func rotateIfNeeded() {
        let live = queue.filter { !$0.isExpired }
        guard live.count > 1 else { return }

        let topScore = live.map(\.sortScore).max() ?? 0
        let topMessages = live.filter { $0.sortScore == topScore }
        guard topMessages.count > 1 else { return }

        rotationIndex = (rotationIndex + 1) % topMessages.count
        activeMessage = topMessages[rotationIndex]
        syncToStatusWatcher()
    }

    /// Push the active message to StatusWatcher so existing HUD code works
    private func syncToStatusWatcher() {
        guard let msg = activeMessage else {
            StatusWatcher.shared.currentStatus = AtlasStatus(
                status: "green", source: "jane",
                message: "No messages", updated: ISO8601DateFormatter().string(from: Date()),
                details: []
            )
            return
        }
        StatusWatcher.shared.currentStatus = AtlasStatus(
            status: msg.severity,
            source: msg.source,
            message: msg.message,
            banner: msg.banner,
            bannerStyle: msg.bannerStyle,
            updated: msg.created,
            details: [],
            slots: msg.slots
        )
    }

    // MARK: - Queue I/O

    private func readQueue() {
        guard let data = FileManager.default.contents(atPath: queuePath),
              let parsed = try? JSONDecoder().decode(StatusQueue.self, from: data) else {
            return
        }
        queue = parsed.messages
    }

    /// Convert legacy status.json writes into queue entries
    private func ingestLegacyStatus() {
        guard let data = FileManager.default.contents(atPath: legacyPath),
              let status = try? JSONDecoder().decode(AtlasStatus.self, from: data) else {
            return
        }

        // Create a queue message from legacy status
        let msg = QueuedMessage(
            id: "\(status.source)-legacy",
            source: status.source,
            severity: status.status,
            priority: QueuedMessage.defaultPriority(for: status.status),
            message: status.message,
            banner: status.banner,
            bannerStyle: status.bannerStyle,
            slots: nil,
            created: status.updated,
            ttl: status.status == "green" ? nil : 300  // non-green expire in 5min
        )

        // Replace any existing legacy message from same source
        queue.removeAll { $0.id == msg.id }
        queue.append(msg)
        resolveActive()
    }

    /// Remove expired messages
    private func pruneExpired() {
        let before = queue.count
        queue.removeAll { $0.isExpired }
        if queue.count != before {
            resolveActive()
            writeQueue()
        }
    }

    private func writeQueue() {
        let q = StatusQueue(messages: queue)
        guard let data = try? JSONEncoder().encode(q) else { return }
        try? data.write(to: URL(fileURLWithPath: queuePath))
    }

    // MARK: - File Watching

    private func watchFile(path: String, handler: @escaping () -> Void) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            // File doesn't exist yet — create it and retry
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: "{}".data(using: .utf8))
                let fd2 = open(path, O_EVTONLY)
                guard fd2 >= 0 else { return }
                setupMonitor(fd: fd2, handler: handler)
            }
            return
        }
        setupMonitor(fd: fd, handler: handler)
    }

    private func setupMonitor(fd: Int32, handler: @escaping () -> Void) {
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )
        source.setEventHandler { handler() }
        source.setCancelHandler { close(fd) }
        source.resume()
        // Store reference (simplified — in production track multiple monitors)
        queueMonitor = source
    }
}
