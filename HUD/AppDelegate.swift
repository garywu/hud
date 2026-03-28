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
    /// Whether the panel was opened via notch hover (vs status item click)
    private var panelOpenedViaHover = false
    private let hoverMargin: CGFloat = 15
    private let hoverHideDelay: TimeInterval = 0.06

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
    }

    private func notchHovered() {
        guard !(panelWindow?.isVisible ?? false) else { return }
        showPanelBelowNotch()
        panelOpenedViaHover = true
        startHoverTracking()
    }

    private func showPanelBelowNotch() {
        guard let screen = NSScreen.builtIn, let panel = panelWindow else { return }
        let screenFrame = screen.frame
        let panelWidth: CGFloat = 340
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.maxY - 50 - 120  // below notch area
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: 120), display: true)
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

        let notchItem = NSMenuItem(
            title: "Show in notch...",
            action: #selector(toggleReplaceNotch),
            keyEquivalent: ""
        )
        notchItem.target = self
        notchItem.state = replaceNotch ? .on : .off
        menu.addItem(notchItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Atlas HUD",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleReplaceNotch() {
        replaceNotch = !replaceNotch
        if replaceNotch {
            setupNotchWindow()
        } else {
            notchWindow?.orderOut(nil)
            notchWindow = nil
        }
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
