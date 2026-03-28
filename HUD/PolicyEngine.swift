import Foundation
import Observation

// MARK: - Interruption Level

enum InterruptionLevel: String, Codable, Comparable {
    case passive       // green — no expansion, just update status
    case active        // yellow — expand briefly
    case timeSensitive // red — expand, sound, Telegram
    case critical      // sos — stay expanded, repeated sound, never auto-dismiss

    /// Map to HUD severity string
    var severity: String {
        switch self {
        case .passive:       return "green"
        case .active:        return "yellow"
        case .timeSensitive: return "red"
        case .critical:      return "sos"
        }
    }

    /// Default priority score
    var defaultPriority: Int {
        switch self {
        case .passive:       return 10
        case .active:        return 50
        case .timeSensitive: return 100
        case .critical:      return 200
        }
    }

    /// Color name for status bar
    var colorName: String {
        switch self {
        case .passive:       return "green"
        case .active:        return "yellow"
        case .timeSensitive: return "red"
        case .critical:      return "red"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .passive:       return 0
        case .active:        return 1
        case .timeSensitive: return 2
        case .critical:      return 3
        }
    }

    static func < (lhs: InterruptionLevel, rhs: InterruptionLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    /// Parse from string, tolerating different formats
    static func from(_ string: String) -> InterruptionLevel? {
        switch string.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "") {
        case "passive":                    return .passive
        case "active":                     return .active
        case "timesensitive":              return .timeSensitive
        case "critical":                   return .critical
        // Also accept severity names
        case "green":                      return .passive
        case "yellow":                     return .active
        case "red":                        return .timeSensitive
        case "sos":                        return .critical
        default:                           return nil
        }
    }
}

// MARK: - Channel Policy

struct ChannelPolicy: Codable, Equatable {
    let source: String                  // "athena", "jane", "claude-code", "*"
    let policy: String                  // "allow", "mute", "summarize"
    let maxInterruptionLevel: String    // "passive", "active", "timeSensitive", "critical"
    let rateLimit: Int?                 // notifications per minute (nil = use default)

    /// Resolved max interruption level
    var resolvedMaxLevel: InterruptionLevel {
        InterruptionLevel.from(maxInterruptionLevel) ?? .critical
    }

    /// Whether this policy matches a given source
    func matches(_ sourceId: String) -> Bool {
        source == "*" || source == sourceId
    }
}

struct ChannelPoliciesFile: Codable {
    let channels: [ChannelPolicy]?
    let focusMode: FocusModeConfig?

    enum CodingKeys: String, CodingKey {
        case channels
        case focusMode = "focus_mode"
    }
}

struct FocusModeConfig: Codable, Equatable {
    let enabled: Bool
    let allowAbove: String   // only allow notifications above this level

    var resolvedLevel: InterruptionLevel {
        InterruptionLevel.from(allowAbove) ?? .timeSensitive
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case allowAbove = "allow_above"
    }
}

// MARK: - Focus Profiles (atlas#657)

/// A named focus profile that filters notifications by severity.
struct FocusProfile: Codable, Equatable {
    let name: String              // "work", "sleep", "personal"
    let allowedLevels: [String]   // ["red", "sos"] — severity names that get through
    let schedule: FocusSchedule?

    /// Check if a given interruption level is allowed through this profile.
    func allows(_ level: InterruptionLevel) -> Bool {
        allowedLevels.contains(level.severity)
    }

    // Predefined profiles
    static let work = FocusProfile(
        name: "work",
        allowedLevels: ["red", "sos"],
        schedule: FocusSchedule(start: "09:00", end: "17:00", days: ["mon", "tue", "wed", "thu", "fri"])
    )

    static let sleep = FocusProfile(
        name: "sleep",
        allowedLevels: ["sos"],
        schedule: FocusSchedule(start: "23:00", end: "07:00", days: nil)
    )

    static let personal = FocusProfile(
        name: "personal",
        allowedLevels: ["green", "yellow", "red", "sos"],
        schedule: FocusSchedule(start: "17:00", end: "23:00", days: nil)
    )

    /// All built-in profiles
    static let builtins: [FocusProfile] = [work, sleep, personal]
}

/// Schedule for automatic focus mode switching.
struct FocusSchedule: Codable, Equatable {
    let start: String    // "09:00" (HH:mm)
    let end: String      // "17:00" (HH:mm)
    let days: [String]?  // ["mon","tue","wed","thu","fri"] — nil = every day

    /// Parse an "HH:mm" string into (hour, minute).
    private static func parseTime(_ s: String) -> (hour: Int, minute: Int)? {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    /// Short weekday name for current day ("mon", "tue", etc.)
    private static func currentDayName() -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Calendar weekday: 1=Sun, 2=Mon, ...
        let names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        return names[weekday - 1]
    }

    /// Check if the current time falls within this schedule.
    func isActiveNow() -> Bool {
        // Check day filter
        if let days = days {
            let today = FocusSchedule.currentDayName()
            if !days.contains(today) { return false }
        }

        guard let startTime = FocusSchedule.parseTime(start),
              let endTime = FocusSchedule.parseTime(end) else { return false }

        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let nowMinutes = hour * 60 + minute
        let startMinutes = startTime.hour * 60 + startTime.minute
        let endMinutes = endTime.hour * 60 + endTime.minute

        if startMinutes <= endMinutes {
            // Same-day range (e.g., 09:00–17:00)
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        } else {
            // Overnight range (e.g., 23:00–07:00)
            return nowMinutes >= startMinutes || nowMinutes < endMinutes
        }
    }
}

// MARK: - Focus Manager

/// Manages focus profiles: persistence, activation, and scheduled auto-switching.
/// Lives alongside PolicyEngine and writes to ~/.atlas/hud-config.json.
@Observable
class FocusManager {
    static let shared = FocusManager()

    /// All available profiles (built-in + user-defined)
    var profiles: [FocusProfile] = FocusProfile.builtins

    /// Currently active profile name (nil = no focus filtering)
    var activeProfileName: String?

    /// Whether scheduled auto-switching is enabled
    var schedulingEnabled: Bool = true

    private var scheduleTimer: Timer?
    private let configPath = NSString("~/.atlas/hud-config.json").expandingTildeInPath

    // MARK: - Lifecycle

    init() {
        loadProfiles()
    }

    /// Start the schedule timer that checks every 60 seconds for auto-switching.
    func startScheduler() {
        loadProfiles()
        evaluateSchedule()
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.evaluateSchedule()
        }
    }

    func stopScheduler() {
        scheduleTimer?.invalidate()
        scheduleTimer = nil
    }

    // MARK: - Activation

    /// Manually activate a focus profile by name.
    /// Returns the activated profile, or nil if not found.
    @discardableResult
    func activate(_ name: String) -> FocusProfile? {
        guard let profile = profiles.first(where: { $0.name == name }) else {
            return nil
        }
        activeProfileName = name
        syncToPolicyEngine()
        persistFocusState()
        return profile
    }

    /// Deactivate focus mode (allow everything through).
    func deactivate() {
        activeProfileName = nil
        syncToPolicyEngine()
        persistFocusState()
    }

    /// Get the currently active profile (if any).
    var activeProfile: FocusProfile? {
        guard let name = activeProfileName else { return nil }
        return profiles.first { $0.name == name }
    }

    /// Check if a notification level is allowed under the current focus mode.
    /// Returns true if there is no active focus mode, or if the level is allowed.
    func isAllowed(_ level: InterruptionLevel) -> Bool {
        guard let profile = activeProfile else { return true }
        return profile.allows(level)
    }

    // MARK: - Profile Management

    /// Add or update a user-defined focus profile.
    func upsertProfile(_ profile: FocusProfile) {
        if let idx = profiles.firstIndex(where: { $0.name == profile.name }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
        persistProfiles()
    }

    /// Remove a user-defined profile by name. Built-in names can be overridden but not deleted.
    func removeProfile(_ name: String) {
        profiles.removeAll { $0.name == name }
        // Re-add built-in if it was one of the defaults
        if let builtin = FocusProfile.builtins.first(where: { $0.name == name }) {
            profiles.append(builtin)
        }
        if activeProfileName == name {
            deactivate()
        }
        persistProfiles()
    }

    // MARK: - Scheduling

    /// Evaluate all profile schedules and auto-switch if appropriate.
    /// Only runs when schedulingEnabled is true and no manual override is active.
    private func evaluateSchedule() {
        guard schedulingEnabled else { return }

        // Find the profile whose schedule matches right now
        for profile in profiles {
            guard let schedule = profile.schedule else { continue }
            if schedule.isActiveNow() {
                if activeProfileName != profile.name {
                    activeProfileName = profile.name
                    syncToPolicyEngine()
                    persistFocusState()
                    log("Auto-switched to focus mode: \(profile.name)")
                }
                return
            }
        }

        // No schedule matches — if currently active due to scheduling, deactivate
        // (We only auto-deactivate if the current profile has a schedule)
        if let current = activeProfile, current.schedule != nil {
            activeProfileName = nil
            syncToPolicyEngine()
            persistFocusState()
            log("Auto-deactivated focus mode (no schedule matches)")
        }
    }

    // MARK: - PolicyEngine Bridge

    /// Sync the current focus state into the legacy PolicyEngine.focusMode field.
    private func syncToPolicyEngine() {
        let engine = PolicyEngine.shared
        if let profile = activeProfile {
            // Determine the minimum allowed level for legacy compat
            let minLevel = minAllowedLevel(from: profile.allowedLevels)
            engine.focusMode = FocusModeConfig(enabled: true, allowAbove: minLevel)
        } else {
            engine.focusMode = nil
        }
    }

    /// Find the lowest severity in the allowed list (for legacy allow_above compat).
    private func minAllowedLevel(from levels: [String]) -> String {
        let order = ["green", "yellow", "red", "sos"]
        for level in order {
            if levels.contains(level) {
                return level
            }
        }
        return "sos"
    }

    // MARK: - Persistence

    /// Persist focus profiles to hud-config.json (merged with existing config).
    private func persistProfiles() {
        var config = readConfigDict()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? encoder.encode(profiles),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            config["focus_profiles"] = arr
        }
        writeConfigDict(config)
    }

    /// Persist just the active state (not profiles).
    private func persistFocusState() {
        var config = readConfigDict()
        if let name = activeProfileName {
            config["active_focus"] = name
        } else {
            config.removeValue(forKey: "active_focus")
        }
        config["focus_scheduling"] = schedulingEnabled
        writeConfigDict(config)
    }

    /// Load profiles and active state from hud-config.json.
    private func loadProfiles() {
        let config = readConfigDict()

        // Load custom profiles (merge with built-ins)
        if let arr = config["focus_profiles"] as? [[String: Any]],
           let data = try? JSONSerialization.data(withJSONObject: arr),
           let loaded = try? JSONDecoder().decode([FocusProfile].self, from: data) {
            // Start with built-ins, override with loaded
            var merged: [FocusProfile] = []
            var seen = Set<String>()
            for profile in loaded {
                merged.append(profile)
                seen.insert(profile.name)
            }
            for builtin in FocusProfile.builtins where !seen.contains(builtin.name) {
                merged.append(builtin)
            }
            profiles = merged
        }

        // Load active state
        activeProfileName = config["active_focus"] as? String
        schedulingEnabled = config["focus_scheduling"] as? Bool ?? true
    }

    // MARK: - Config I/O (merge-safe: preserves other keys in hud-config.json)

    private func readConfigDict() -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: configPath),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func writeConfigDict(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) else { return }
        let dir = (configPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
    }

    // MARK: - Logging

    private func log(_ msg: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] FocusManager: \(msg)\n"
        let logPath = NSString("~/.atlas/logs/hud-focus.log").expandingTildeInPath
        let dir = (logPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
        }
    }
}

// MARK: - Token Bucket Rate Limiter

class TokenBucketRateLimiter {
    struct Bucket {
        var tokens: Int
        var lastRefill: Date
    }

    private var buckets: [String: Bucket] = [:]
    let maxTokens: Int
    let refillRate: Int   // tokens per minute

    init(maxTokens: Int = 10, refillRate: Int = 5) {
        self.maxTokens = maxTokens
        self.refillRate = refillRate
    }

    /// Try to consume a token for the given source.
    /// Returns true if allowed, false if rate-limited.
    func tryConsume(source: String) -> Bool {
        refill(source: source)
        guard var bucket = buckets[source] else {
            // First use — create bucket with max-1 tokens (consumed one)
            buckets[source] = Bucket(tokens: maxTokens - 1, lastRefill: Date())
            return true
        }
        if bucket.tokens > 0 {
            bucket.tokens -= 1
            buckets[source] = bucket
            return true
        }
        return false
    }

    /// Refill tokens based on elapsed time
    private func refill(source: String) {
        guard var bucket = buckets[source] else { return }
        let elapsed = Date().timeIntervalSince(bucket.lastRefill)
        let newTokens = Int(elapsed / 60.0 * Double(refillRate))
        if newTokens > 0 {
            bucket.tokens = min(maxTokens, bucket.tokens + newTokens)
            bucket.lastRefill = Date()
            buckets[source] = bucket
        }
    }

    /// Override rate limit for a specific source
    func setCustomRate(source: String, maxTokens: Int, refillRate: Int) {
        // Custom rates are handled at the PolicyEngine level
        // by creating per-source limiters. This is a convenience placeholder.
    }

    /// Reset a source bucket (e.g., when policy changes)
    func reset(source: String) {
        buckets.removeValue(forKey: source)
    }

    /// Reset all buckets
    func resetAll() {
        buckets.removeAll()
    }
}

// MARK: - Notification Request & Result

struct NotificationRequest {
    let id: String
    let source: String
    let level: InterruptionLevel
    let title: String
    let body: String?
    let renderer: String?       // "text" | "lcd"
    let presentation: String?   // "static" | "scroll" | "rsvp"
    let size: String?
    let color: String?
    let data: [Double]?
    let ttl: TimeInterval?      // seconds until auto-expire
    let groupId: String?        // for grouping related notifications
    let collapseId: String?     // replaces existing with same collapseId

    init(
        id: String = UUID().uuidString,
        source: String,
        level: InterruptionLevel,
        title: String,
        body: String? = nil,
        renderer: String? = nil,
        presentation: String? = nil,
        size: String? = nil,
        color: String? = nil,
        data: [Double]? = nil,
        ttl: TimeInterval? = nil,
        groupId: String? = nil,
        collapseId: String? = nil
    ) {
        self.id = id
        self.source = source
        self.level = level
        self.title = title
        self.body = body
        self.renderer = renderer
        self.presentation = presentation
        self.size = size
        self.color = color
        self.data = data
        self.ttl = ttl
        self.groupId = groupId
        self.collapseId = collapseId
    }
}

struct NotificationResult {
    let accepted: Bool
    let reason: String?         // "rate_limited", "muted", "focus_mode", "level_capped", etc.
    let notificationId: String?

    static func accepted(id: String) -> NotificationResult {
        NotificationResult(accepted: true, reason: nil, notificationId: id)
    }

    static func rejected(_ reason: String) -> NotificationResult {
        NotificationResult(accepted: false, reason: reason, notificationId: nil)
    }
}

// MARK: - Policy Engine

@Observable
class PolicyEngine {
    static let shared = PolicyEngine()

    var channels: [ChannelPolicy] = []
    var focusMode: FocusModeConfig?
    var rateLimiter = TokenBucketRateLimiter()

    /// Per-source rate limiters (for custom rate limits)
    private var customLimiters: [String: TokenBucketRateLimiter] = [:]

    private var configMonitor: DispatchSourceFileSystemObject?
    private let configPath = NSString("~/.atlas/hud-config.json").expandingTildeInPath

    // MARK: - Initialization

    init() {
        loadPolicies()
    }

    /// Start watching config for policy changes
    func startWatching() {
        loadPolicies()
        let fd = open(configPath, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in self?.loadPolicies() }
        source.setCancelHandler { close(fd) }
        source.resume()
        configMonitor = source
    }

    // MARK: - Submit Notification

    /// Submit a notification through the policy engine.
    /// Returns whether the notification was accepted and queued.
    func submit(_ request: NotificationRequest) -> NotificationResult {
        // 1. Check channel policy — is this source allowed?
        let policy = findPolicy(for: request.source)

        if policy?.policy == "mute" {
            return .rejected("muted")
        }

        // 2. Check interruption level cap
        if let policy = policy {
            if request.level > policy.resolvedMaxLevel {
                // Downgrade level to max allowed, don't reject
                // Actually: the spec says maxInterruptionLevel caps it,
                // so we clamp rather than reject
            }
        }

        let effectiveLevel = clampLevel(request.level, policy: policy)

        // 3. Check focus mode (profile-based filtering — atlas#657)
        if !FocusManager.shared.isAllowed(effectiveLevel) {
            return .rejected("focus_mode")
        }
        // Legacy fallback: also check inline focusMode config
        if let focus = focusMode, focus.enabled {
            if effectiveLevel < focus.resolvedLevel {
                return .rejected("focus_mode")
            }
        }

        // 4. Check rate limit
        let limiter = limiterForSource(request.source, policy: policy)
        if !limiter.tryConsume(source: request.source) {
            return .rejected("rate_limited")
        }

        // 5. Build queue message and status bar config
        let queueMessage = buildQueueMessage(from: request, level: effectiveLevel)
        let statusConfig = buildStatusBarConfig(from: request, level: effectiveLevel)

        // 6. Handle collapse (replace existing with same collapseId)
        if let collapseId = request.collapseId {
            removeFromQueue(collapseId: collapseId)
        }

        // 7. Interrupt RSVP if a higher-priority notification preempts
        let rsvpManager = RSVPInterruptionManager.shared
        if rsvpManager.isRSVPActive && !rsvpManager.isPaused && effectiveLevel >= .timeSensitive {
            let interruptionTTL = request.ttl ?? defaultTTL(for: effectiveLevel).map { TimeInterval($0) }
            rsvpManager.interrupt(
                notificationId: request.id,
                level: effectiveLevel,
                ttl: interruptionTTL
            )
        }

        // 8. Write to queue and status files
        enqueue(queueMessage)
        writeStatus(from: request, level: effectiveLevel, statusBar: statusConfig)

        return .accepted(id: request.id)
    }

    // MARK: - Policy Resolution

    /// Find the most specific policy for a source.
    /// Exact match wins over wildcard.
    private func findPolicy(for source: String) -> ChannelPolicy? {
        // Exact match first
        if let exact = channels.first(where: { $0.source == source }) {
            return exact
        }
        // Wildcard fallback
        return channels.first(where: { $0.source == "*" })
    }

    /// Clamp the interruption level to the policy maximum
    private func clampLevel(_ level: InterruptionLevel, policy: ChannelPolicy?) -> InterruptionLevel {
        guard let policy = policy else { return level }
        let maxLevel = policy.resolvedMaxLevel
        return level > maxLevel ? maxLevel : level
    }

    /// Get the rate limiter for a source, respecting custom rate limits
    private func limiterForSource(_ source: String, policy: ChannelPolicy?) -> TokenBucketRateLimiter {
        if let customRate = policy?.rateLimit {
            if customLimiters[source] == nil {
                customLimiters[source] = TokenBucketRateLimiter(
                    maxTokens: customRate * 2,  // burst = 2x rate
                    refillRate: customRate
                )
            }
            return customLimiters[source]!
        }
        return rateLimiter
    }

    // MARK: - Message Building

    private func buildQueueMessage(from request: NotificationRequest, level: InterruptionLevel) -> QueuedMessage {
        let bannerText = request.body ?? request.title

        return QueuedMessage(
            id: request.collapseId ?? request.id,
            source: request.source,
            severity: level.severity,
            priority: level.defaultPriority,
            message: request.title + (request.body.map { "\n\($0)" } ?? ""),
            banner: bannerText,
            bannerStyle: request.presentation,
            slots: nil,
            created: ISO8601DateFormatter().string(from: Date()),
            ttl: request.ttl.map { Int($0) }
                ?? (level == .critical ? nil : defaultTTL(for: level))
        )
    }

    private func buildStatusBarConfig(from request: NotificationRequest, level: InterruptionLevel) -> StatusBarConfig {
        // If the request specifies display preferences, use them
        let mode: String
        if request.renderer != nil || request.presentation != nil {
            mode = "content"
        } else {
            // Default: scanner for passive, content for everything else
            mode = level == .passive ? "scanner" : "content"
        }

        return StatusBarConfig(
            mode: mode,
            size: request.size ?? (level == .critical ? "large" : "medium"),
            color: request.color ?? level.colorName,
            data: request.data,
            text: request.body ?? request.title,
            renderer: request.renderer,
            presentation: request.presentation ?? (level >= .timeSensitive ? "scroll" : "static")
        )
    }

    /// Default TTL per level (seconds)
    private func defaultTTL(for level: InterruptionLevel) -> Int? {
        switch level {
        case .passive:       return 120    // 2 min
        case .active:        return 300    // 5 min
        case .timeSensitive: return 600    // 10 min
        case .critical:      return nil    // never auto-expire
        }
    }

    // MARK: - Queue I/O

    private let queuePath = NSString("~/.atlas/status-queue.json").expandingTildeInPath
    private let statusPath = NSString("~/.atlas/status.json").expandingTildeInPath

    private func enqueue(_ message: QueuedMessage) {
        var queue = readQueue()
        // Remove existing with same id (for collapse behavior)
        queue.messages.removeAll { $0.id == message.id }
        queue.messages.append(message)
        writeQueue(queue)
    }

    private func removeFromQueue(collapseId: String) {
        var queue = readQueue()
        queue.messages.removeAll { $0.id == collapseId }
        writeQueue(queue)
    }

    private func readQueue() -> StatusQueue {
        guard let data = FileManager.default.contents(atPath: queuePath),
              let parsed = try? JSONDecoder().decode(StatusQueue.self, from: data) else {
            return StatusQueue(messages: [])
        }
        return parsed
    }

    private func writeQueue(_ queue: StatusQueue) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(queue) else { return }
        try? data.write(to: URL(fileURLWithPath: queuePath), options: .atomic)
    }

    private func writeStatus(from request: NotificationRequest, level: InterruptionLevel, statusBar: StatusBarConfig) {
        let status = AtlasStatus(
            status: level.severity,
            source: request.source,
            message: request.title,
            banner: request.body ?? request.title,
            bannerStyle: request.presentation,
            updated: ISO8601DateFormatter().string(from: Date()),
            details: [],
            slots: nil,
            statusBar: statusBar
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(status) else { return }
        try? data.write(to: URL(fileURLWithPath: statusPath), options: .atomic)
    }

    // MARK: - Config Loading

    private func loadPolicies() {
        guard let data = FileManager.default.contents(atPath: configPath),
              let config = try? JSONDecoder().decode(ChannelPoliciesFile.self, from: data) else {
            // No config or parse error — use permissive defaults
            channels = [
                ChannelPolicy(source: "*", policy: "allow", maxInterruptionLevel: "critical", rateLimit: nil)
            ]
            focusMode = nil
            return
        }
        channels = config.channels ?? [
            ChannelPolicy(source: "*", policy: "allow", maxInterruptionLevel: "critical", rateLimit: nil)
        ]
        focusMode = config.focusMode

        // Rebuild custom limiters for sources with custom rates
        customLimiters.removeAll()
        for channel in channels {
            if let rate = channel.rateLimit {
                customLimiters[channel.source] = TokenBucketRateLimiter(
                    maxTokens: rate * 2,
                    refillRate: rate
                )
            }
        }

        // Reload focus profiles when config changes (atlas#657)
        FocusManager.shared.startScheduler()
    }
}
