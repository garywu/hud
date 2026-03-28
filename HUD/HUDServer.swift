import Foundation
import Network

// MARK: - HUD Server (localhost:7070)

/// Lightweight HTTP server exposing the Atlas HUD API.
/// Uses NWListener (Network framework) — no external dependencies.
final class HUDServer {
    static let shared = HUDServer()

    private var listener: NWListener?
    private var sseConnections: [UUID: NWConnection] = [:]
    let port: UInt16 = 7070

    // Channel policies
    private var channelPolicies: [[String: Any]] = []

    // MARK: - Lifecycle

    func start() {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        params.acceptLocalOnly = true

        do {
            listener = try NWListener(using: params)
        } catch {
            log("Failed to create listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.log("HTTP server listening on localhost:\(self?.port ?? 0)")
            case .failed(let error):
                self?.log("Listener failed: \(error)")
                self?.listener?.cancel()
            default:
                break
            }
        }

        listener?.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for (_, conn) in sseConnections {
            conn.cancel()
        }
        sseConnections.removeAll()
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveHTTPRequest(on: connection)
    }

    private func receiveHTTPRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, let data else {
                if isComplete || error != nil { connection.cancel() }
                return
            }

            guard let raw = String(data: data, encoding: .utf8) else {
                self.sendResponse(connection: connection, status: 400, body: ["error": "Invalid request"])
                return
            }

            self.route(raw: raw, connection: connection)
        }
    }

    // MARK: - HTTP Parser + Router

    private func route(raw: String, connection: NWConnection) {
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, status: 400, body: ["error": "Empty request"])
            return
        }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: 400, body: ["error": "Malformed request line"])
            return
        }

        let method = parts[0]
        let path = parts[1]

        // Extract body (after blank line)
        let bodyData: Data? = {
            if let range = raw.range(of: "\r\n\r\n") {
                let bodyString = String(raw[range.upperBound...])
                return bodyString.isEmpty ? nil : bodyString.data(using: .utf8)
            }
            return nil
        }()

        // CORS headers for local dev tools
        let corsHeaders = "Access-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\n"

        // Handle OPTIONS preflight
        if method == "OPTIONS" {
            let response = "HTTP/1.1 204 No Content\r\n\(corsHeaders)\r\n"
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
                connection.cancel()
            }))
            return
        }

        switch (method, path) {
        case ("POST", "/notify"):
            handlePostNotify(body: bodyData, connection: connection)

        case ("GET", "/stream"):
            handleSSEStream(connection: connection)

        case ("GET", "/queue"):
            handleGetQueue(connection: connection)

        case ("GET", "/capabilities"):
            handleGetCapabilities(connection: connection)

        case ("PUT", "/config"):
            handlePutConfig(body: bodyData, connection: connection)

        case ("GET", "/focus"):
            handleGetFocus(connection: connection)

        case ("PUT", "/focus"):
            handlePutFocus(body: bodyData, connection: connection)

        case ("DELETE", "/focus"):
            handleDeleteFocus(connection: connection)

        case ("GET", "/focus/profiles"):
            handleGetFocusProfiles(connection: connection)

        case ("PUT", "/focus/profiles"):
            handlePutFocusProfile(body: bodyData, connection: connection)

        case ("GET", "/plugins"):
            handleGetPlugins(connection: connection)

        case ("GET", "/plugins/active"):
            handleGetActivePlugin(connection: connection)

        case ("GET", "/escalation"):
            handleGetEscalation(connection: connection)

        default:
            // Check for POST /acknowledge/:id
            if method == "POST" && path.hasPrefix("/acknowledge/") {
                let id = String(path.dropFirst("/acknowledge/".count))
                handleAcknowledge(id: id, connection: connection)
            }
            // Check for DELETE /notify/:id
            else if method == "DELETE" && path.hasPrefix("/notify/") {
                let id = String(path.dropFirst("/notify/".count))
                handleDeleteNotify(id: id, connection: connection)
            } else if method == "POST" && path.hasPrefix("/plugins/") && path.hasSuffix("/start") {
                let pluginId = String(path.dropFirst("/plugins/".count).dropLast("/start".count))
                handlePluginStart(id: pluginId, connection: connection)
            } else if method == "POST" && path.hasPrefix("/plugins/") && path.hasSuffix("/stop") {
                let pluginId = String(path.dropFirst("/plugins/".count).dropLast("/stop".count))
                handlePluginStop(id: pluginId, connection: connection)
            } else if method == "POST" && path == "/plugins/reload" {
                handlePluginReload(connection: connection)
            } else {
                sendResponse(connection: connection, status: 404, body: ["error": "Not found"])
            }
        }
    }

    // MARK: - POST /notify

    private func handlePostNotify(body: Data?, connection: NWConnection) {
        guard let body else {
            sendResponse(connection: connection, status: 400, body: ["error": "Missing request body"])
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            sendResponse(connection: connection, status: 400, body: ["error": "Invalid JSON"])
            return
        }

        let source = json["source"] as? String ?? "unknown"
        let level = json["level"] as? String ?? "green"
        let title = json["title"] as? String ?? ""
        let bodyText = json["body"] as? String ?? ""
        let renderer = json["renderer"] as? String
        let presentation = json["presentation"] as? String
        let size = json["size"] as? String
        let color = json["color"] as? String
        let ttl = json["ttl"] as? Int
        let data = json["data"] as? [Double]

        let id = UUID().uuidString

        // Map level to severity
        let severity: String
        switch level {
        case "critical", "error": severity = "red"
        case "warning", "active": severity = "yellow"
        case "info", "passive":   severity = "green"
        default:                  severity = "green"
        }

        // Build StatusBarConfig if renderer/presentation specified
        let statusBar: StatusBarConfig?
        if renderer != nil || presentation != nil || size != nil {
            let mode = renderer ?? "text"
            statusBar = StatusBarConfig(
                mode: mode == "lcd" ? "lcd" : "content",
                size: size,
                color: color,
                data: data,
                text: bodyText.isEmpty ? title : bodyText,
                renderer: renderer,
                presentation: presentation
            )
        } else {
            statusBar = nil
        }

        // Build banner text
        let bannerText = bodyText.isEmpty ? title : "\(title) — \(bodyText)"

        // Build slots from data if present
        var slots: [String: SlotData]? = nil
        if let data, !data.isEmpty {
            slots = ["wpm": SlotData(type: "metric", label: "WPM", value: "\(Int(data.first ?? 0))", trend: nil, state: nil, icon: nil)]
        }

        let message = QueuedMessage(
            id: id,
            source: source,
            severity: severity,
            priority: QueuedMessage.defaultPriority(for: severity),
            message: title,
            banner: bannerText,
            bannerStyle: presentation,
            slots: slots,
            created: ISO8601DateFormatter().string(from: Date()),
            ttl: ttl
        )

        // Inject into the queue
        DispatchQueue.main.async {
            MessageQueueManager.shared.queue.append(message)

            // Track for escalation (non-green only)
            EscalationEngine.shared.track(messageId: id, level: severity)

            // If statusBar config provided, push directly to StatusWatcher
            if let statusBar {
                let status = AtlasStatus(
                    status: severity,
                    source: source,
                    message: title,
                    banner: bannerText,
                    bannerStyle: presentation,
                    updated: ISO8601DateFormatter().string(from: Date()),
                    details: [],
                    slots: slots,
                    statusBar: statusBar
                )
                StatusWatcher.shared.currentStatus = status
            }

            // Broadcast SSE event
            self.broadcastSSE(event: "notification_added", data: [
                "id": id,
                "source": source,
                "level": level,
                "title": title
            ])
        }

        sendResponse(connection: connection, status: 200, body: [
            "accepted": true,
            "id": id,
            "reason": NSNull()
        ])
    }

    // MARK: - GET /stream (SSE)

    private func handleSSEStream(connection: NWConnection) {
        let headers = [
            "HTTP/1.1 200 OK",
            "Content-Type: text/event-stream",
            "Cache-Control: no-cache",
            "Connection: keep-alive",
            "Access-Control-Allow-Origin: *",
            "",
            ""
        ].joined(separator: "\r\n")

        connection.send(content: headers.data(using: .utf8), completion: .contentProcessed({ [weak self] error in
            guard error == nil else {
                connection.cancel()
                return
            }
            // Register for SSE
            let id = UUID()
            self?.sseConnections[id] = connection

            // Send initial event
            self?.sendSSE(to: connection, event: "connected", data: ["status": "ok"])

            // Monitor for disconnect
            connection.viabilityUpdateHandler = { [weak self] viable in
                if !viable {
                    self?.sseConnections.removeValue(forKey: id)
                    connection.cancel()
                }
            }
        }))
    }

    private func sendSSE(to connection: NWConnection, event: String, data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let message = "event: \(event)\ndata: \(jsonString)\n\n"
        connection.send(content: message.data(using: .utf8), completion: .contentProcessed({ _ in }))
    }

    private func broadcastSSE(event: String, data: [String: Any]) {
        for (id, connection) in sseConnections {
            guard connection.state == .ready else {
                sseConnections.removeValue(forKey: id)
                continue
            }
            sendSSE(to: connection, event: event, data: data)
        }
    }

    // MARK: - GET /queue

    private func handleGetQueue(connection: NWConnection) {
        DispatchQueue.main.async {
            let mgr = MessageQueueManager.shared
            let active = mgr.activeMessage
            let pending = mgr.queue.filter { $0.id != active?.id && !$0.isExpired }

            var activeDict: Any = NSNull()
            if let active {
                activeDict = self.messageToDict(active)
            }

            let pendingDicts = pending.map { self.messageToDict($0) }

            self.sendResponse(connection: connection, status: 200, body: [
                "active": activeDict,
                "pending": pendingDicts,
                "count": 1 + pending.count
            ])
        }
    }

    private func messageToDict(_ msg: QueuedMessage) -> [String: Any] {
        var dict: [String: Any] = [
            "id": msg.id,
            "source": msg.source,
            "severity": msg.severity,
            "priority": msg.priority,
            "message": msg.message,
            "created": msg.created
        ]
        if let banner = msg.banner { dict["banner"] = banner }
        if let ttl = msg.ttl { dict["ttl"] = ttl }
        return dict
    }

    // MARK: - DELETE /notify/:id

    private func handleDeleteNotify(id: String, connection: NWConnection) {
        DispatchQueue.main.async {
            let mgr = MessageQueueManager.shared
            let before = mgr.queue.count
            mgr.queue.removeAll { $0.id == id }
            let removed = mgr.queue.count < before

            // Stop escalation tracking on dismiss
            EscalationEngine.shared.untrack(id)

            if removed {
                self.broadcastSSE(event: "notification_expired", data: ["id": id, "reason": "dismissed"])
            }

            self.sendResponse(connection: connection, status: 200, body: [
                "dismissed": removed,
                "id": id
            ])
        }
    }

    // MARK: - GET /capabilities

    private func handleGetCapabilities(connection: NWConnection) {
        sendResponse(connection: connection, status: 200, body: [
            "renderers": ["text", "lcd"],
            "presentations": ["static", "scroll", "rsvp"],
            "sizes": ["xs", "small", "medium", "large", "xl"],
            "scanner_modes": ["scanner", "histogram", "sparkline", "progress", "heartbeat", "vu"],
            "lcd_themes": ["red", "green", "amber", "blue"],
            "display": ["cols": 88, "rows": 7]
        ])
    }

    // MARK: - PUT /config

    private func handlePutConfig(body: Data?, connection: NWConnection) {
        guard let body else {
            sendResponse(connection: connection, status: 400, body: ["error": "Missing request body"])
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let channels = json["channels"] as? [[String: Any]] else {
            sendResponse(connection: connection, status: 400, body: ["error": "Invalid config — expected { channels: [...] }"])
            return
        }

        channelPolicies = channels

        // Persist to ~/.atlas/hud-api-config.json
        let configPath = NSString("~/.atlas/hud-api-config.json").expandingTildeInPath
        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? data.write(to: URL(fileURLWithPath: configPath))
        }

        broadcastSSE(event: "config_updated", data: ["channels_count": channels.count])

        sendResponse(connection: connection, status: 200, body: [
            "accepted": true,
            "channels": channels.count
        ])
    }

    // MARK: - Plugin Endpoints

    private func handleGetPlugins(connection: NWConnection) {
        DispatchQueue.main.async {
            let registry = PluginRegistry.shared
            let pluginDicts: [[String: Any]] = registry.plugins.map { plugin in
                let state = registry.pluginStates[plugin.id]
                var dict: [String: Any] = [
                    "id": plugin.id,
                    "name": plugin.name,
                    "description": plugin.description,
                    "running": state?.isRunning ?? false,
                    "tick_count": state?.tickCount ?? 0
                ]
                if let version = plugin.version { dict["version"] = version }
                if let schedule = plugin.schedule { dict["schedule_type"] = schedule.type }
                if let lastTick = state?.lastTick {
                    dict["last_tick"] = ISO8601DateFormatter().string(from: lastTick)
                }
                return dict
            }

            self.sendResponse(connection: connection, status: 200, body: [
                "plugins": pluginDicts,
                "active": registry.activePlugin as Any,
                "count": registry.plugins.count
            ])
        }
    }

    private func handleGetActivePlugin(connection: NWConnection) {
        DispatchQueue.main.async {
            let registry = PluginRegistry.shared
            if let activeId = registry.activePlugin,
               let plugin = registry.plugin(byId: activeId) {
                let state = registry.pluginStates[activeId]
                self.sendResponse(connection: connection, status: 200, body: [
                    "id": plugin.id,
                    "name": plugin.name,
                    "running": state?.isRunning ?? false,
                    "tick_count": state?.tickCount ?? 0
                ])
            } else {
                self.sendResponse(connection: connection, status: 200, body: [
                    "active": NSNull()
                ])
            }
        }
    }

    private func handlePluginStart(id: String, connection: NWConnection) {
        DispatchQueue.main.async {
            let registry = PluginRegistry.shared
            guard registry.plugin(byId: id) != nil else {
                self.sendResponse(connection: connection, status: 404, body: [
                    "error": "Plugin not found: \(id)"
                ])
                return
            }
            registry.startPlugin(id)
            self.broadcastSSE(event: "plugin_started", data: ["id": id])
            self.sendResponse(connection: connection, status: 200, body: [
                "started": true,
                "id": id
            ])
        }
    }

    private func handlePluginStop(id: String, connection: NWConnection) {
        DispatchQueue.main.async {
            let registry = PluginRegistry.shared
            registry.stopPlugin(id)
            self.broadcastSSE(event: "plugin_stopped", data: ["id": id])
            self.sendResponse(connection: connection, status: 200, body: [
                "stopped": true,
                "id": id
            ])
        }
    }

    private func handlePluginReload(connection: NWConnection) {
        DispatchQueue.main.async {
            let registry = PluginRegistry.shared
            registry.loadPlugins()
            self.sendResponse(connection: connection, status: 200, body: [
                "reloaded": true,
                "count": registry.plugins.count
            ])
        }
    }

    // MARK: - POST /acknowledge/:id

    private func handleAcknowledge(id: String, connection: NWConnection) {
        DispatchQueue.main.async {
            let engine = EscalationEngine.shared
            let wasTracked = engine.trackedMessages[id] != nil
            engine.acknowledge(id)

            self.broadcastSSE(event: "acknowledged", data: ["id": id])

            self.sendResponse(connection: connection, status: 200, body: [
                "acknowledged": wasTracked,
                "id": id
            ])
        }
    }

    // MARK: - GET /escalation

    private func handleGetEscalation(connection: NWConnection) {
        DispatchQueue.main.async {
            let engine = EscalationEngine.shared
            let tracked: [[String: Any]] = engine.trackedMessages.map { id, msg in
                [
                    "id": id,
                    "original_level": msg.originalLevel,
                    "current_level": msg.currentLevel,
                    "arrived_at": ISO8601DateFormatter().string(from: msg.arrivedAt),
                    "acknowledged": msg.acknowledged,
                    "telegram_sent": msg.telegramSent,
                ]
            }

            let rules: [[String: Any]] = engine.rules.map { rule in
                [
                    "from": rule.fromLevel,
                    "to": rule.toLevel,
                    "after_seconds": rule.afterSeconds,
                ]
            }

            self.sendResponse(connection: connection, status: 200, body: [
                "tracked": tracked,
                "rules": rules,
                "active_count": engine.activeCount,
            ])
        }
    }

    // MARK: - Focus Mode Endpoints (atlas#657)

    /// GET /focus — current focus state
    private func handleGetFocus(connection: NWConnection) {
        DispatchQueue.main.async {
            let fm = FocusManager.shared
            var body: [String: Any] = [
                "scheduling_enabled": fm.schedulingEnabled
            ]
            if let profile = fm.activeProfile {
                body["active"] = [
                    "name": profile.name,
                    "allowed_levels": profile.allowedLevels
                ] as [String: Any]
            } else {
                body["active"] = NSNull()
            }
            self.sendResponse(connection: connection, status: 200, body: body)
        }
    }

    /// PUT /focus — activate a focus profile: { "name": "work" } or { "scheduling": true/false }
    private func handlePutFocus(body: Data?, connection: NWConnection) {
        guard let body else {
            sendResponse(connection: connection, status: 400, body: ["error": "Missing request body"])
            return
        }
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            sendResponse(connection: connection, status: 400, body: ["error": "Invalid JSON"])
            return
        }

        DispatchQueue.main.async {
            let fm = FocusManager.shared

            // Toggle scheduling if requested
            if let scheduling = json["scheduling"] as? Bool {
                fm.schedulingEnabled = scheduling
            }

            // Activate a profile by name
            if let name = json["name"] as? String {
                if let profile = fm.activate(name) {
                    self.broadcastSSE(event: "focus_changed", data: [
                        "name": profile.name,
                        "allowed_levels": profile.allowedLevels
                    ])
                    self.sendResponse(connection: connection, status: 200, body: [
                        "activated": true,
                        "name": profile.name,
                        "allowed_levels": profile.allowedLevels
                    ])
                } else {
                    self.sendResponse(connection: connection, status: 404, body: [
                        "error": "Focus profile not found: \(name)",
                        "available": fm.profiles.map { $0.name }
                    ])
                }
            } else {
                // No name — just toggled scheduling
                self.sendResponse(connection: connection, status: 200, body: [
                    "scheduling_enabled": fm.schedulingEnabled
                ])
            }
        }
    }

    /// DELETE /focus — deactivate focus mode
    private func handleDeleteFocus(connection: NWConnection) {
        DispatchQueue.main.async {
            let fm = FocusManager.shared
            fm.deactivate()
            self.broadcastSSE(event: "focus_changed", data: ["name": NSNull()])
            self.sendResponse(connection: connection, status: 200, body: [
                "deactivated": true
            ])
        }
    }

    /// GET /focus/profiles — list all available profiles
    private func handleGetFocusProfiles(connection: NWConnection) {
        DispatchQueue.main.async {
            let fm = FocusManager.shared
            let profileDicts: [[String: Any]] = fm.profiles.map { p in
                var dict: [String: Any] = [
                    "name": p.name,
                    "allowed_levels": p.allowedLevels,
                    "active": p.name == fm.activeProfileName
                ]
                if let schedule = p.schedule {
                    dict["schedule"] = [
                        "start": schedule.start,
                        "end": schedule.end,
                        "days": schedule.days as Any
                    ]
                }
                return dict
            }
            self.sendResponse(connection: connection, status: 200, body: [
                "profiles": profileDicts,
                "active": fm.activeProfileName as Any,
                "scheduling_enabled": fm.schedulingEnabled
            ])
        }
    }

    /// PUT /focus/profiles — add/update a custom profile
    private func handlePutFocusProfile(body: Data?, connection: NWConnection) {
        guard let body else {
            sendResponse(connection: connection, status: 400, body: ["error": "Missing request body"])
            return
        }
        guard let profile = try? JSONDecoder().decode(FocusProfile.self, from: body) else {
            sendResponse(connection: connection, status: 400, body: [
                "error": "Invalid profile — expected { name, allowedLevels, schedule? }"
            ])
            return
        }

        DispatchQueue.main.async {
            FocusManager.shared.upsertProfile(profile)
            self.broadcastSSE(event: "focus_profile_updated", data: ["name": profile.name])
            self.sendResponse(connection: connection, status: 200, body: [
                "saved": true,
                "name": profile.name,
                "allowed_levels": profile.allowedLevels
            ])
        }
    }

    // MARK: - HTTP Response Helper

    private func sendResponse(connection: NWConnection, status: Int, body: [String: Any]) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 204: statusText = "No Content"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default:  statusText = "Unknown"
        }

        let jsonData = (try? JSONSerialization.data(withJSONObject: body, options: .sortedKeys)) ?? Data()

        let headers = [
            "HTTP/1.1 \(status) \(statusText)",
            "Content-Type: application/json",
            "Content-Length: \(jsonData.count)",
            "Access-Control-Allow-Origin: *",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        var responseData = headers.data(using: .utf8)!
        responseData.append(jsonData)

        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    // MARK: - Logging

    private func log(_ msg: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] HUDServer: \(msg)\n"
        let logPath = NSString("~/.atlas/logs/hud-server.log").expandingTildeInPath
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            let dir = (logPath as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
        }
        NSLog("HUDServer: %@", msg)
    }
}
