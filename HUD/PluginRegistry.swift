import Foundation
import Observation

// MARK: - Plugin Manifest Models

struct PluginManifest: Codable {
    let id: String
    let name: String
    let description: String
    let version: String?
    let author: String?
    let display: PluginDisplay?
    let schedule: PluginSchedule?
    let command: String?       // shell command to run on tick
    let config: [String: String]?
}

struct PluginDisplay: Codable {
    let renderer: String?      // "text" | "lcd"
    let presentation: String?  // "static" | "scroll" | "rsvp"
    let size: String?
    let priority: String?      // "passive" | "active"
}

struct PluginSchedule: Codable {
    let type: String           // "continuous" | "interval" | "event" | "manual"
    let interval: Double?      // seconds between ticks (for interval/continuous type)
    let event: String?         // event name to listen for
}

// MARK: - Plugin State

struct PluginState {
    var isRunning: Bool = false
    var lastTick: Date? = nil
    var lastOutput: String? = nil
    var tickCount: Int = 0
}

// MARK: - Plugin Registry

@Observable
class PluginRegistry {
    static let shared = PluginRegistry()

    var plugins: [PluginManifest] = []
    var activePlugin: String? = nil       // currently displaying plugin
    var pluginStates: [String: PluginState] = [:]

    private var pluginTimers: [String: Timer] = [:]
    private var rotationTimer: Timer? = nil

    private let pluginsDir = NSString("~/.atlas/plugins").expandingTildeInPath

    // MARK: - Discovery

    /// Scan ~/.atlas/plugins/*/manifest.json and load all found manifests.
    func loadPlugins() {
        let fm = FileManager.default
        plugins.removeAll()

        guard let entries = try? fm.contentsOfDirectory(atPath: pluginsDir) else {
            log("No plugins directory at \(pluginsDir)")
            return
        }

        for entry in entries {
            let manifestPath = (pluginsDir as NSString).appendingPathComponent("\(entry)/manifest.json")
            guard fm.fileExists(atPath: manifestPath),
                  let data = fm.contents(atPath: manifestPath) else { continue }

            do {
                let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
                plugins.append(manifest)
                // Initialize state if not present
                if pluginStates[manifest.id] == nil {
                    pluginStates[manifest.id] = PluginState()
                }
                log("Loaded plugin: \(manifest.id) (\(manifest.name))")
            } catch {
                log("Failed to decode \(manifestPath): \(error)")
            }
        }

        log("Loaded \(plugins.count) plugins")
    }

    // MARK: - Lifecycle

    /// Start a plugin's scheduled execution.
    func startPlugin(_ id: String) {
        guard let plugin = plugins.first(where: { $0.id == id }) else {
            log("Plugin not found: \(id)")
            return
        }

        // Stop existing timer if any
        stopPlugin(id)

        pluginStates[id]?.isRunning = true

        guard let schedule = plugin.schedule else {
            log("Plugin \(id) has no schedule — started in manual mode")
            return
        }

        let interval: Double
        switch schedule.type {
        case "continuous":
            interval = schedule.interval ?? 3.0
        case "interval":
            interval = schedule.interval ?? 10.0
        default:
            // "event" and "manual" don't get timers
            log("Plugin \(id) started (type=\(schedule.type), no timer)")
            return
        }

        // Fire immediately, then repeat
        tickPlugin(id)

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tickPlugin(id)
        }
        RunLoop.main.add(timer, forMode: .common)
        pluginTimers[id] = timer

        // Set as active if no other active plugin
        if activePlugin == nil {
            activePlugin = id
        }

        log("Plugin \(id) started with interval \(interval)s")
    }

    /// Stop a plugin's scheduled execution.
    func stopPlugin(_ id: String) {
        pluginTimers[id]?.invalidate()
        pluginTimers.removeValue(forKey: id)
        pluginStates[id]?.isRunning = false

        if activePlugin == id {
            // Rotate to next running plugin
            activePlugin = pluginStates.first(where: { $0.value.isRunning })?.key
        }

        log("Plugin \(id) stopped")
    }

    /// Execute one tick of a plugin (run its command).
    func tickPlugin(_ id: String) {
        guard let plugin = plugins.first(where: { $0.id == id }) else { return }

        // Determine what to run
        let command: String
        if let cmd = plugin.command {
            command = cmd
        } else {
            // Default: look for run.sh in the plugin directory
            let runScript = (pluginsDir as NSString).appendingPathComponent("\(id)/run.sh")
            guard FileManager.default.fileExists(atPath: runScript) else {
                log("Plugin \(id): no command and no run.sh found")
                return
            }
            command = "bash \(runScript)"
        }

        // Run asynchronously
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
            process.standardOutput = pipe
            process.standardError = pipe

            // Pass plugin config as env vars
            var env = ProcessInfo.processInfo.environment
            if let config = plugin.config {
                for (key, value) in config {
                    env["PLUGIN_\(key.uppercased())"] = value
                }
            }
            env["PLUGIN_ID"] = plugin.id
            env["PLUGIN_DIR"] = (self?.pluginsDir ?? "") + "/\(id)"
            process.environment = env

            do {
                try process.run()
                process.waitUntilExit()
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                DispatchQueue.main.async {
                    self?.pluginStates[id]?.lastTick = Date()
                    self?.pluginStates[id]?.lastOutput = output
                    self?.pluginStates[id]?.tickCount += 1
                }
            } catch {
                DispatchQueue.main.async {
                    self?.log("Plugin \(id) tick failed: \(error)")
                }
            }
        }
    }

    // MARK: - Rotation

    /// When multiple passive plugins are running, rotate which one is displayed.
    func startRotation(interval: Double = 10.0) {
        stopRotation()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.rotatePlugins()
        }
        if let timer = rotationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    /// Rotate to the next running passive plugin.
    func rotatePlugins() {
        let runningPassive = plugins.filter { plugin in
            guard pluginStates[plugin.id]?.isRunning == true else { return false }
            return plugin.display?.priority ?? "passive" == "passive"
        }

        guard runningPassive.count > 1 else { return }

        // Find current index and advance
        if let current = activePlugin,
           let currentIdx = runningPassive.firstIndex(where: { $0.id == current }) {
            let nextIdx = (currentIdx + 1) % runningPassive.count
            activePlugin = runningPassive[nextIdx].id
        } else {
            activePlugin = runningPassive.first?.id
        }

        log("Rotated to plugin: \(activePlugin ?? "none")")
    }

    // MARK: - Query

    /// List all running plugin IDs.
    var runningPlugins: [String] {
        pluginStates.filter { $0.value.isRunning }.map { $0.key }
    }

    /// Get manifest by ID.
    func plugin(byId id: String) -> PluginManifest? {
        plugins.first(where: { $0.id == id })
    }

    // MARK: - Install

    /// Install a plugin from a source directory into ~/.atlas/plugins/<id>/
    func installPlugin(from sourcePath: String) -> Bool {
        let fm = FileManager.default
        let manifestPath = (sourcePath as NSString).appendingPathComponent("manifest.json")

        guard fm.fileExists(atPath: manifestPath),
              let data = fm.contents(atPath: manifestPath),
              let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) else {
            log("Cannot install: no valid manifest.json in \(sourcePath)")
            return false
        }

        let destDir = (pluginsDir as NSString).appendingPathComponent(manifest.id)

        // Remove existing if present
        try? fm.removeItem(atPath: destDir)

        do {
            try fm.copyItem(atPath: sourcePath, toPath: destDir)
            log("Installed plugin \(manifest.id) from \(sourcePath)")
            loadPlugins()  // Refresh registry
            return true
        } catch {
            log("Install failed: \(error)")
            return false
        }
    }

    // MARK: - Logging

    private func log(_ msg: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] PluginRegistry: \(msg)\n"
        let logPath = NSString("~/.atlas/logs/plugin-registry.log").expandingTildeInPath
        let logDir = (logPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
        }
        NSLog("PluginRegistry: %@", msg)
    }
}
