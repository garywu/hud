import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var notchWindow: NotchWindow?
    private var panelWindow: NSPanel?
    private var panelContentHost: NSHostingView<PanelContentView>?
    private let sessionStore = SessionStore.shared
    private var hoverHideTimer: Timer?
    private var hoverGlobalMonitor: Any?
    private var hoverLocalMonitor: Any?
    private var hotkeyMonitor: Any?
    private var globalShortcutMonitor: Any?
    private var preferencesWindow: NSWindow?
    /// Whether the panel was opened via notch hover (vs status item click)
    private var panelOpenedViaHover = false
    private let hoverMargin: CGFloat = 15
    private let hoverHideDelay: TimeInterval = 0.06

    // MARK: - Status bar size cycle order
    private let sizeCycle: [StatusBarSize] = [.xs, .small, .medium, .large, .xl]
    // MARK: - Display mode cycle order
    private let modeCycle = ["scanner", "lcd", "text"]
    // MARK: - LCD theme cycle order
    private let themeCycle = ["red", "green", "amber", "blue"]
    // MARK: - Focus mode cycle order
    private let focusCycle: [String?] = [nil, "work", "sleep", "personal"]
    // MARK: - Mute state
    private var isMuted = false

    private var replaceNotch: Bool {
        get {
            if UserDefaults.standard.object(forKey: "replaceNotch") == nil { return true }
            return UserDefaults.standard.bool(forKey: "replaceNotch")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "replaceNotch")
        }
    }

    private func log(_ msg: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] \(msg)\n"
        let logPath = NSString("~/.atlas/logs/hud-app.log").expandingTildeInPath
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
        }
        NSLog("AtlasHUD: %@", msg)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("=== HUD LAUNCH ===")
        log("replaceNotch=\(replaceNotch)")

        // Start watching ~/.atlas/status.json + queue + theme
        StatusWatcher.shared.startWatching()
        log("StatusWatcher started")
        MessageQueueManager.shared.startWatching()
        log("MessageQueue started")
        ContextGaugePlugin.shared.startWatching()
        AppMenuDetector.shared.startWatching()
        ThemeEngine.shared.startWatching()
        JaneClient.shared.startPolling()
        HUDServer.shared.start()
        log("All watchers started (HUDServer on port 7070)")
        EscalationEngine.shared.startMonitoring()
        log("EscalationEngine started")
        PluginRegistry.shared.loadPlugins()
        log("PluginRegistry loaded \(PluginRegistry.shared.plugins.count) plugins")

        setupStatusItem()
        log("Status item setup")
        setupPanel()
        log("Panel setup")
        if replaceNotch {
            setupNotchWindow()
            log("Notch window setup — frame=\(notchWindow?.frame ?? .zero)")
        } else {
            log("Notch window SKIPPED (replaceNotch=false)")
        }
        setupHotkey()
        log("Hotkey setup — launch complete")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.hexagongrid", accessibilityDescription: "Atlas HUD")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let hostView = NSHostingView(rootView: PanelContentView())
        hostView.frame = panel.contentView!.bounds
        hostView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostView)
        panelContentHost = hostView

        self.panelWindow = panel

        // When the panel hides, clean up hover tracking
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard let self, !(self.panelWindow?.isVisible ?? false) else { return }
            self.notchWindow?.endHover()
            self.panelOpenedViaHover = false
            self.stopHoverTracking()
        }
    }

    private func setupNotchWindow() {
        notchWindow = NotchWindow { [weak self] in
            self?.notchHovered()
        }
        notchWindow?.isPanelVisible = { [weak self] in
            self?.panelWindow?.isVisible ?? false
        }
    }

    private func setupHotkey() {
        // Global monitor: backtick = keyCode 50
        hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 50,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.function).isEmpty
            else { return }
            DispatchQueue.main.async { self?.togglePanel() }
        }

        // Ctrl+Shift keyboard shortcuts
        globalShortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.control), flags.contains(.shift) else { return }
            // Strip ctrl+shift to check no other modifiers (except function which some keyboards add)
            let extra = flags.subtracting([.control, .shift, .function])
            guard extra.isEmpty else { return }

            guard let key = event.charactersIgnoringModifiers?.lowercased() else { return }
            DispatchQueue.main.async {
                switch key {
                case "h": self?.toggleHUDVisibility()
                case "n": self?.cycleNextPlugin()
                case "p": self?.cyclePreviousPlugin()
                case "s": self?.cycleStatusBarSize()
                case "d": self?.cycleDisplayMode()
                case "t": self?.cycleLCDTheme()
                case "f": self?.cycleFocusMode()
                case "m": self?.toggleMute()
                default: break
                }
            }
        }
    }

    // MARK: - Keyboard Shortcut Actions

    private func toggleHUDVisibility() {
        log("Shortcut: toggle HUD visibility")
        togglePanel()
    }

    private func cycleNextPlugin() {
        let registry = PluginRegistry.shared
        let running = registry.plugins.filter { registry.pluginStates[$0.id]?.isRunning == true }
        guard running.count > 1, let current = registry.activePlugin else {
            // If no active or only one, activate first
            if let first = registry.plugins.first {
                registry.activePlugin = first.id
            }
            return
        }
        if let idx = running.firstIndex(where: { $0.id == current }) {
            let next = (idx + 1) % running.count
            registry.activePlugin = running[next].id
        }
        log("Shortcut: next plugin -> \(registry.activePlugin ?? "none")")
    }

    private func cyclePreviousPlugin() {
        let registry = PluginRegistry.shared
        let running = registry.plugins.filter { registry.pluginStates[$0.id]?.isRunning == true }
        guard running.count > 1, let current = registry.activePlugin else { return }
        if let idx = running.firstIndex(where: { $0.id == current }) {
            let prev = (idx - 1 + running.count) % running.count
            registry.activePlugin = running[prev].id
        }
        log("Shortcut: prev plugin -> \(registry.activePlugin ?? "none")")
    }

    private func cycleStatusBarSize() {
        let prefs = HUDPreferences.shared
        if let idx = sizeCycle.firstIndex(of: prefs.statusBarSize) {
            prefs.statusBarSize = sizeCycle[(idx + 1) % sizeCycle.count]
        } else {
            prefs.statusBarSize = .xs
        }
        prefs.save()
        log("Shortcut: size -> \(prefs.statusBarSize.rawValue)")
    }

    private func cycleDisplayMode() {
        let prefs = HUDPreferences.shared
        if let idx = modeCycle.firstIndex(of: prefs.displayMode) {
            prefs.displayMode = modeCycle[(idx + 1) % modeCycle.count]
        } else {
            prefs.displayMode = "scanner"
        }
        prefs.save()
        log("Shortcut: display mode -> \(prefs.displayMode)")
    }

    private func cycleLCDTheme() {
        let prefs = HUDPreferences.shared
        if let idx = themeCycle.firstIndex(of: prefs.lcdTheme) {
            prefs.lcdTheme = themeCycle[(idx + 1) % themeCycle.count]
        } else {
            prefs.lcdTheme = "red"
        }
        prefs.save()
        log("Shortcut: LCD theme -> \(prefs.lcdTheme)")
    }

    private func cycleFocusMode() {
        let fm = FocusManager.shared
        let currentName = fm.activeProfileName
        if let idx = focusCycle.firstIndex(of: currentName) {
            let next = focusCycle[(idx + 1) % focusCycle.count]
            if let name = next {
                fm.activate(name)
            } else {
                fm.deactivate()
            }
        } else {
            fm.deactivate()
        }
        log("Shortcut: focus -> \(fm.activeProfileName ?? "off")")
    }

    private func toggleMute() {
        isMuted.toggle()
        let engine = PolicyEngine.shared
        if isMuted {
            // Set all channels to mute
            engine.channels = [ChannelPolicy(source: "*", policy: "mute", maxInterruptionLevel: "critical", rateLimit: nil)]
        } else {
            // Restore to allow-all
            engine.channels = [ChannelPolicy(source: "*", policy: "allow", maxInterruptionLevel: "critical", rateLimit: nil)]
        }
        log("Shortcut: mute -> \(isMuted)")
    }

    private func notchHovered() {
        guard !(panelWindow?.isVisible ?? false) else { return }
        showPanelBelowNotch()
        panelOpenedViaHover = true
        startHoverTracking()
    }

    private func showPanelBelowNotch() {
        guard let panel = panelWindow else { return }
        let panelWidth: CGFloat = 340

        if let nw = notchWindow, nw.isFloatingMode {
            // Position below the floating pill
            let nwFrame = nw.frame
            let x = nwFrame.midX - panelWidth / 2
            let y = nwFrame.minY - 120 - 4
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: 120), display: true)
        } else {
            guard let screen = NSScreen.builtIn else { return }
            let screenFrame = screen.frame
            let x = screenFrame.midX - panelWidth / 2
            let y = screenFrame.maxY - 50 - 120  // below notch area
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: 120), display: true)
        }
        panel.orderFrontRegardless()
    }

    // MARK: - Hover-to-hide tracking

    private func startHoverTracking() {
        stopHoverTracking()
        hoverGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.checkHoverBounds()
        }
        hoverLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.checkHoverBounds()
            return event
        }
    }

    private func stopHoverTracking() {
        hoverHideTimer?.invalidate()
        hoverHideTimer = nil
        if let monitor = hoverGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            hoverGlobalMonitor = nil
        }
        if let monitor = hoverLocalMonitor {
            NSEvent.removeMonitor(monitor)
            hoverLocalMonitor = nil
        }
    }

    private func checkHoverBounds() {
        guard let panel = panelWindow, panel.isVisible, panelOpenedViaHover, sessionStore.isPinned == false else {
            cancelHoverHide()
            return
        }

        let mouse = NSEvent.mouseLocation
        let inNotch = notchWindow?.frame.insetBy(dx: -hoverMargin, dy: -hoverMargin).contains(mouse) ?? false
        let inPanel = panel.frame.insetBy(dx: -hoverMargin, dy: -hoverMargin).contains(mouse)

        if inNotch || inPanel {
            cancelHoverHide()
        } else {
            scheduleHoverHide()
        }
    }

    private func scheduleHoverHide() {
        guard hoverHideTimer == nil else { return }
        hoverHideTimer = Timer.scheduledTimer(withTimeInterval: hoverHideDelay, repeats: false) { [weak self] _ in
            guard let self, let panel = self.panelWindow else { return }
            let mouse = NSEvent.mouseLocation
            let inNotch = self.notchWindow?.frame.insetBy(dx: -self.hoverMargin, dy: -self.hoverMargin).contains(mouse) ?? false
            let inPanel = panel.frame.insetBy(dx: -self.hoverMargin, dy: -self.hoverMargin).contains(mouse)
            if !inNotch && !inPanel {
                panel.orderOut(nil)
                self.notchWindow?.endHover()
                self.panelOpenedViaHover = false
                self.stopHoverTracking()
            }
        }
    }

    private func cancelHoverHide() {
        hoverHideTimer?.invalidate()
        hoverHideTimer = nil
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        showContextMenu()
    }

    private func togglePanel() {
        guard let panel = panelWindow else { return }
        if panel.isVisible {
            panel.orderOut(nil)
            notchWindow?.endHover()
            panelOpenedViaHover = false
            stopHoverTracking()
        } else {
            panelOpenedViaHover = false
            showPanelBelowStatusItem()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        // Current status display
        let status = StatusWatcher.shared.currentStatus
        let statusEmoji: String
        switch status.status {
        case "green": statusEmoji = "🟢"
        case "yellow": statusEmoji = "🟡"
        case "red": statusEmoji = "🔴"
        default: statusEmoji = "⚪"
        }
        let statusItem = NSMenuItem(title: "\(statusEmoji) \(status.source.uppercased()): \(status.message)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        // Notch toggle
        let notchItem = NSMenuItem(
            title: "Show in Notch",
            action: #selector(toggleReplaceNotch),
            keyEquivalent: ""
        )
        notchItem.target = self
        notchItem.state = replaceNotch ? .on : .off
        menu.addItem(notchItem)

        // Window mode submenu (auto / notch / floating)
        let windowModeMenu = NSMenu()
        let currentWindowMode = StatusWatcher.shared.config.display_mode ?? "auto"
        for mode in ["auto", "notch", "floating"] {
            let label: String
            switch mode {
            case "auto": label = "Auto (notch if available)"
            case "notch": label = "Notch Only"
            case "floating": label = "Floating Panel"
            default: label = mode.capitalized
            }
            let item = NSMenuItem(title: label, action: #selector(selectWindowMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = (currentWindowMode == mode) ? .on : .off
            windowModeMenu.addItem(item)
        }
        let windowModeItem = NSMenuItem(title: "Window Mode", action: nil, keyEquivalent: "")
        windowModeItem.submenu = windowModeMenu
        menu.addItem(windowModeItem)

        // Floating position submenu
        let floatPosMenu = NSMenu()
        let currentFloatPos = StatusWatcher.shared.config.floating_position ?? "center"
        for pos in ["left", "center", "right"] {
            let item = NSMenuItem(title: pos.capitalized, action: #selector(selectFloatingPosition(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pos
            item.state = (currentFloatPos == pos) ? .on : .off
            floatPosMenu.addItem(item)
        }
        let floatPosItem = NSMenuItem(title: "Floating Position", action: nil, keyEquivalent: "")
        floatPosItem.submenu = floatPosMenu
        // Only show floating position when in floating mode
        floatPosItem.isHidden = (StatusWatcher.shared.config.resolvedDisplayMode != "floating")
        menu.addItem(floatPosItem)

        menu.addItem(.separator())

        // Plugin submenu
        let pluginMenu = NSMenu()
        let registry = PluginRegistry.shared
        if registry.plugins.isEmpty {
            let noneItem = NSMenuItem(title: "No plugins installed", action: nil, keyEquivalent: "")
            noneItem.isEnabled = false
            pluginMenu.addItem(noneItem)
        } else {
            for plugin in registry.plugins {
                let item = NSMenuItem(title: plugin.name, action: #selector(activatePlugin(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = plugin.id
                item.state = (registry.activePlugin == plugin.id) ? .on : .off
                pluginMenu.addItem(item)
            }
        }
        let pluginItem = NSMenuItem(title: "Plugins", action: nil, keyEquivalent: "")
        pluginItem.submenu = pluginMenu
        menu.addItem(pluginItem)

        // Display mode submenu
        let displayMenu = NSMenu()
        let prefs = HUDPreferences.shared
        for mode in modeCycle {
            let item = NSMenuItem(title: mode.capitalized, action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = (prefs.displayMode == mode) ? .on : .off
            displayMenu.addItem(item)
        }
        let displayItem = NSMenuItem(title: "Display Mode", action: nil, keyEquivalent: "")
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        // Size submenu
        let sizeMenu = NSMenu()
        let sizeLabels = ["XS", "S", "M", "L", "XL"]
        for (i, size) in sizeCycle.enumerated() {
            let item = NSMenuItem(title: sizeLabels[i], action: #selector(selectSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = size.rawValue
            item.state = (prefs.statusBarSize == size) ? .on : .off
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        // Theme submenu
        let themeMenu = NSMenu()
        for theme in themeCycle {
            let item = NSMenuItem(title: theme.capitalized, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme
            item.state = (prefs.lcdTheme == theme) ? .on : .off
            themeMenu.addItem(item)
        }
        let themeItem = NSMenuItem(title: "LCD Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        // Focus mode submenu
        let focusMenu = NSMenu()
        let fm = FocusManager.shared
        let offItem = NSMenuItem(title: "Off", action: #selector(selectFocusMode(_:)), keyEquivalent: "")
        offItem.target = self
        offItem.representedObject = "" as NSString
        offItem.state = (fm.activeProfileName == nil) ? .on : .off
        focusMenu.addItem(offItem)
        for name in ["work", "sleep", "personal"] {
            let item = NSMenuItem(title: name.capitalized, action: #selector(selectFocusMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name as NSString
            item.state = (fm.activeProfileName == name) ? .on : .off
            focusMenu.addItem(item)
        }
        let focusItem = NSMenuItem(title: "Focus Mode", action: nil, keyEquivalent: "")
        focusItem.submenu = focusMenu
        menu.addItem(focusItem)

        // Mute toggle
        let muteItem = NSMenuItem(
            title: isMuted ? "Unmute Notifications" : "Mute Notifications",
            action: #selector(muteMenuAction),
            keyEquivalent: ""
        )
        muteItem.target = self
        menu.addItem(muteItem)

        menu.addItem(.separator())

        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Atlas HUD",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        self.statusItem.menu = menu
        self.statusItem.button?.performClick(nil)
        self.statusItem.menu = nil
    }

    // MARK: - Context Menu Actions

    @objc private func toggleReplaceNotch() {
        replaceNotch = !replaceNotch
        if replaceNotch {
            setupNotchWindow()
        } else {
            notchWindow?.orderOut(nil)
            notchWindow = nil
        }
    }

    @objc private func selectWindowMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String else { return }
        updateHUDConfigField("display_mode", value: mode)
        log("Menu: window mode -> \(mode)")
        // Recreate the notch/floating window with new mode
        if replaceNotch {
            notchWindow?.orderOut(nil)
            notchWindow = nil
            setupNotchWindow()
        }
    }

    @objc private func selectFloatingPosition(_ sender: NSMenuItem) {
        guard let pos = sender.representedObject as? String else { return }
        updateHUDConfigField("floating_position", value: pos)
        log("Menu: floating position -> \(pos)")
        // Reposition if currently in floating mode
        if notchWindow?.isFloatingMode == true {
            notchWindow?.orderOut(nil)
            notchWindow = nil
            setupNotchWindow()
        }
    }

    /// Update a single field in ~/.atlas/hud-config.json (merge-safe)
    private func updateHUDConfigField(_ key: String, value: String) {
        let path = NSString("~/.atlas/hud-config.json").expandingTildeInPath
        var dict: [String: Any] = [:]
        if let data = FileManager.default.contents(atPath: path),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict = existing
        }
        dict[key] = value
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @objc private func activatePlugin(_ sender: NSMenuItem) {
        guard let pluginId = sender.representedObject as? String else { return }
        let registry = PluginRegistry.shared
        if registry.pluginStates[pluginId]?.isRunning != true {
            registry.startPlugin(pluginId)
        }
        registry.activePlugin = pluginId
        log("Menu: activated plugin \(pluginId)")
    }

    @objc private func selectDisplayMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String else { return }
        HUDPreferences.shared.displayMode = mode
        HUDPreferences.shared.save()
        log("Menu: display mode -> \(mode)")
    }

    @objc private func selectSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let size = StatusBarSize(rawValue: raw) else { return }
        HUDPreferences.shared.statusBarSize = size
        HUDPreferences.shared.save()
        log("Menu: size -> \(raw)")
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let theme = sender.representedObject as? String else { return }
        HUDPreferences.shared.lcdTheme = theme
        HUDPreferences.shared.save()
        log("Menu: LCD theme -> \(theme)")
    }

    @objc private func selectFocusMode(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? NSString else { return }
        let fm = FocusManager.shared
        if name.length == 0 {
            fm.deactivate()
        } else {
            fm.activate(name as String)
        }
        log("Menu: focus -> \(fm.activeProfileName ?? "off")")
    }

    @objc private func muteMenuAction() {
        toggleMute()
    }

    @objc private func openPreferences() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let prefsView = PreferencesView()
        let hostingController = NSHostingController(rootView: prefsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Atlas HUD Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 480))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow = window
    }

    private func showPanelBelowStatusItem() {
        guard let panel = panelWindow else { return }
        if let button = statusItem.button,
           let window = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = window.convertToScreen(buttonRect)
            let panelWidth: CGFloat = 340
            let x = screenRect.midX - panelWidth / 2
            let y = screenRect.minY - 120 - 4
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: 120), display: true)
            panel.orderFrontRegardless()
        }
    }
}
