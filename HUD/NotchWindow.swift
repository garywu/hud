import AppKit
import Observation
import SwiftUI

/// An invisible window that sits behind the notch area.
/// When the mouse hovers over the notch or any additional hover rect, it fires a callback to show the main panel.
/// Expands downward with a bounce animation when status changes.
class NotchWindow: NSPanel {
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var screenObserver: Any?
    private var statusObserver: Any?
    var onHover: (() -> Void)?
    /// Additional rects (in screen coordinates) that should also trigger hover.
    /// Each closure is called at check-time so the rect stays up-to-date.
    var additionalHoverRects: [() -> NSRect] = []
    /// Closure to check if the main panel is currently visible.
    /// When the panel is visible, the notch stays in hover-grown size.
    var isPanelVisible: (() -> Bool)?

    /// Detected notch dimensions (updated on screen change).
    private var notchWidth: CGFloat = 180
    private var notchHeight: CGFloat = 37

    /// Whether this window is in floating panel mode (no notch)
    private(set) var isFloatingMode = false

    /// Floating panel constants
    private static let floatingWidth: CGFloat = 265
    private static let floatingHeight: CGFloat = 37
    private static let floatingTopOffset: CGFloat = 4  // below menu bar

    /// Whether the notch is currently expanded (wider, for working state)
    private var isExpanded = false

    /// Debounce timer for collapsing — prevents rapid expand/collapse cycling
    private var collapseDebounceTimer: Timer?

    /// Auto-minimize timer — collapse after timeout even if still yellow/red
    private var autoMinimizeTimer: Timer?
    /// How long to stay expanded before auto-minimizing (seconds)
    private let yellowMinimizeDelay: TimeInterval = 300.0
    private let redMinimizeDelay: TimeInterval = 300.0
    /// Whether we've auto-minimized (reset when severity changes)
    private var isAutoMinimized = false
    private var lastSeverity: String = ""

    /// Whether the mouse is currently hovering over the notch
    private var isHovered = false
    /// The pill-shaped background view shown when expanded
    private let pillView = NotchPillView()

    /// SwiftUI content overlay shown inside the pill when expanded
    private var pillContentHost: NSHostingView<NotchPillContent>?

    init(onHover: @escaping () -> Void) {
        self.onHover = onHover

        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        hasShadow = false
        isOpaque = false
        animationBehavior = .none
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = false
        alphaValue = 1

        // Set up the pill view (always visible)
        if let cv = contentView {
            pillView.frame = cv.bounds
            pillView.autoresizingMask = [.width, .height]
            pillView.alphaValue = 1
            cv.addSubview(pillView)
            cv.wantsLayer = true
            cv.layer?.masksToBounds = false

            // SwiftUI content overlay inside the pill
            let hostView = NSHostingView(rootView: NotchPillContent())
            hostView.frame = cv.bounds
            hostView.autoresizingMask = [.width, .height]
            hostView.alphaValue = 1
            hostView.wantsLayer = true
            hostView.layer?.backgroundColor = .clear
            cv.addSubview(hostView)
            pillContentHost = hostView
        }

        // Accept file drags so hovering a dragged file over the notch opens the panel
        registerForDraggedTypes([.fileURL, .URL])

        detectGeometry()
        applyDisplayMode()
        positionAtNotch()
        orderFrontRegardless()
        setupTracking()
        observeScreenChanges()
        observeStatusChanges()
    }

    /// Determines and applies display mode based on config + hardware.
    private func applyDisplayMode() {
        let mode = StatusWatcher.shared.config.resolvedDisplayMode
        isFloatingMode = (mode == "floating")

        if isFloatingMode {
            // Floating panel: add shadow, make draggable, use rounded corners
            hasShadow = true
            isMovableByWindowBackground = true
            level = .floating
            // Remove .stationary so the window can be dragged
            collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
            pillView.isFloatingMode = true
        } else {
            hasShadow = false
            isMovableByWindowBackground = false
            level = .statusBar
            collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            pillView.isFloatingMode = false
        }
    }

    // MARK: - Drag destination (treat drag-over like hover)

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onHover?()
        return .generic
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .generic
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return false
    }

    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Expand / Collapse

    private func observeStatusChanges() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NotchyNotchStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if !(self?.isExpanded ?? false) {
                self?.updateExpansionState()
            }
            else {
                self?.collapseDebounceTimer?.invalidate()
                self?.collapseDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                    guard let self, self.isExpanded else { return }
                    self.collapseDebounceTimer = nil
                    self.updateExpansionState()
                }
            }
        }
        // Also poll on a timer to catch status changes + resize bar
        var lastBarHeight: CGFloat = StatusBarLayout.height
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.updateExpansionState()
            // Reposition if status bar height changed
            let newHeight = StatusBarLayout.height
            if newHeight != lastBarHeight && !(self?.isExpanded ?? false) {
                lastBarHeight = newHeight
                self?.positionAtNotch()
            }
        }
    }

    private func updateExpansionState() {
        let currentState = NotchDisplayState.current
        let shouldExpand = currentState == .attention || currentState == .urgent || currentState == .sos
        let severity = StatusWatcher.shared.currentStatus.status

        // Reset auto-minimize if severity changed (new alert)
        if severity != lastSeverity {
            lastSeverity = severity
            isAutoMinimized = false
            autoMinimizeTimer?.invalidate()
            autoMinimizeTimer = nil
        }

        // Green/offline always collapse — reset autoMinimized flag
        if !shouldExpand {
            isAutoMinimized = false
        }

        if shouldExpand && !isExpanded && !isAutoMinimized {
            collapseDebounceTimer?.invalidate()
            collapseDebounceTimer = nil
            expandWithBounce()

            // Schedule auto-minimize (SOS never minimizes — stays until human acts)
            autoMinimizeTimer?.invalidate()
            if currentState != .sos {
                let delay = currentState == .urgent ? redMinimizeDelay : yellowMinimizeDelay
                autoMinimizeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    guard let self, self.isExpanded else { return }
                    self.isAutoMinimized = true
                    self.collapse()
                }
            }
        } else if !shouldExpand && isExpanded {
            guard collapseDebounceTimer == nil else { return }
            collapseDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.collapseDebounceTimer = nil
                if self.isExpanded {
                    self.collapse()
                    self.isAutoMinimized = false
                }
            }
        } else if shouldExpand && isExpanded {
            collapseDebounceTimer?.invalidate()
            collapseDebounceTimer = nil
        }
    }

    /// Layout from config — severity-driven, live-updating
    static var activeLayout: LayoutPreset {
        let severity = StatusWatcher.shared.currentStatus.status
        let config = StatusWatcher.shared.config
        return config.layoutForSeverity(severity)
    }
    static var avatarWidth: CGFloat {
        StatusWatcher.shared.config.avatar?.width ?? 50
    }

    private func expandWithBounce() {
        isExpanded = true

        if isFloatingMode {
            expandFloating()
            return
        }

        guard let screen = NSScreen.builtIn else { return }
        let screenFrame = screen.frame

        // U-shape: wider + drops below the notch
        let targetWidth: CGFloat = notchWidth + Self.activeLayout.leftEar + Self.activeLayout.rightEar
        let targetHeight: CGFloat = notchHeight + Self.activeLayout.bottomStrip
        // Position so the notch cutout aligns with the actual notch
        let notchLeft = screenFrame.midX - notchWidth / 2
        var targetFrame = NSRect(
            x: notchLeft - Self.activeLayout.leftEar,
            y: screenFrame.maxY - targetHeight,
            width: targetWidth,
            height: targetHeight
        )
        if isHovered {
            targetFrame = applyHoverGrow(to: targetFrame)
        }

        pillView.alphaValue = 1
        pillView.isUShape = true
        pillView.notchWidth = notchWidth
        pillView.notchHeight = notchHeight
        pillView.leftEarWidth = Self.activeLayout.leftEar
        pillView.rightEarWidth = Self.activeLayout.rightEar
        pillContentHost?.alphaValue = 1

        let startFrame = frame
        let startTime = CACurrentMediaTime()
        let duration: Double = 0.5

        let displayLink = CVDisplayLinkWrapper { [weak self] in
            guard let self else { return false }
            let elapsed = CACurrentMediaTime() - startTime
            let t = min(elapsed / duration, 1.0)

            let bounce = Self.bounceEase(t)

            let currentX = startFrame.origin.x + (targetFrame.origin.x - startFrame.origin.x) * bounce
            let currentY = startFrame.origin.y + (targetFrame.origin.y - startFrame.origin.y) * bounce
            let currentWidth = startFrame.width + (targetFrame.width - startFrame.width) * bounce
            let currentHeight = startFrame.height + (targetFrame.height - startFrame.height) * bounce

            DispatchQueue.main.async {
                self.setFrame(
                    NSRect(x: currentX, y: currentY, width: currentWidth, height: currentHeight),
                    display: true
                )
            }
            return t < 1.0
        }
        displayLink.start()
    }

    /// Expand in floating mode -- grows wider to show expanded content
    private func expandFloating() {
        guard let screen = NSScreen.builtIn ?? NSScreen.main else { return }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY

        let layout = Self.activeLayout
        let targetWidth: CGFloat = Self.floatingWidth + layout.leftEar + layout.rightEar
        let targetHeight: CGFloat = Self.floatingHeight + layout.bottomStrip
        let position = StatusWatcher.shared.config.resolvedFloatingPosition
        let x: CGFloat
        switch position {
        case "left":
            x = screenFrame.minX + 80
        case "right":
            x = screenFrame.maxX - targetWidth - 80
        default:
            x = screenFrame.midX - targetWidth / 2
        }
        let y = screenFrame.maxY - menuBarHeight - Self.floatingTopOffset - targetHeight

        var targetFrame = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
        if isHovered {
            targetFrame = applyHoverGrow(to: targetFrame)
        }

        pillView.alphaValue = 1
        pillView.isUShape = false  // floating mode never uses U-shape (no notch cutout)
        pillContentHost?.alphaValue = 1

        let startFrame = frame
        let startTime = CACurrentMediaTime()
        let duration: Double = 0.5

        let displayLink = CVDisplayLinkWrapper { [weak self] in
            guard let self else { return false }
            let elapsed = CACurrentMediaTime() - startTime
            let t = min(elapsed / duration, 1.0)
            let bounce = Self.bounceEase(t)
            let currentX = startFrame.origin.x + (targetFrame.origin.x - startFrame.origin.x) * bounce
            let currentY = startFrame.origin.y + (targetFrame.origin.y - startFrame.origin.y) * bounce
            let currentWidth = startFrame.width + (targetFrame.width - startFrame.width) * bounce
            let currentHeight = startFrame.height + (targetFrame.height - startFrame.height) * bounce
            DispatchQueue.main.async {
                self.setFrame(NSRect(x: currentX, y: currentY, width: currentWidth, height: currentHeight), display: true)
            }
            return t < 1.0
        }
        displayLink.start()
    }

    private func collapse() {
        isExpanded = false
        pillView.isUShape = false

        // Don't fade content to zero — keep dots visible in collapsed state
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            self.pillContentHost?.animator().alphaValue = 1
        }

        if isFloatingMode {
            collapseFloating()
            return
        }

        guard let screen = NSScreen.builtIn else { return }
        let screenFrame = screen.frame

        // Collapsed: wider than notch + bar below
        let totalHeight = notchHeight + StatusBarLayout.height
        var targetFrame = NSRect(
            x: screenFrame.midX - notchWidth / 2 - collapsedPadding,
            y: screenFrame.maxY - totalHeight,
            width: notchWidth + collapsedPadding * 2,
            height: totalHeight
        )
        if isHovered {
            targetFrame = applyHoverGrow(to: targetFrame)
        }

        let startFrame = frame
        let startTime = CACurrentMediaTime()
        let duration: Double = 0.3

        let displayLink = CVDisplayLinkWrapper { [weak self] in
            guard let self else { return false }
            let elapsed = CACurrentMediaTime() - startTime
            let t = min(elapsed / duration, 1.0)

            let ease = 1.0 - pow(1.0 - t, 3.0)

            let currentX = startFrame.origin.x + (targetFrame.origin.x - startFrame.origin.x) * ease
            let currentY = startFrame.origin.y + (targetFrame.origin.y - startFrame.origin.y) * ease
            let currentWidth = startFrame.width + (targetFrame.width - startFrame.width) * ease
            let currentHeight = startFrame.height + (targetFrame.height - startFrame.height) * ease

            DispatchQueue.main.async {
                self.setFrame(
                    NSRect(x: currentX, y: currentY, width: currentWidth, height: currentHeight),
                    display: true
                )
                if t >= 1.0 {
                    self.pillContentHost?.alphaValue = 1
                }
            }
            return t < 1.0
        }
        displayLink.start()
    }

    /// Collapse back to floating pill
    private func collapseFloating() {
        guard let screen = NSScreen.builtIn ?? NSScreen.main else { return }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY
        let totalHeight = Self.floatingHeight + StatusBarLayout.height
        let position = StatusWatcher.shared.config.resolvedFloatingPosition
        let x: CGFloat
        switch position {
        case "left":
            x = screenFrame.minX + 80
        case "right":
            x = screenFrame.maxX - Self.floatingWidth - 80
        default:
            x = screenFrame.midX - Self.floatingWidth / 2
        }
        let y = screenFrame.maxY - menuBarHeight - Self.floatingTopOffset - totalHeight
        var targetFrame = NSRect(x: x, y: y, width: Self.floatingWidth, height: totalHeight)
        if isHovered {
            targetFrame = applyHoverGrow(to: targetFrame)
        }

        let startFrame = frame
        let startTime = CACurrentMediaTime()
        let duration: Double = 0.3

        let displayLink = CVDisplayLinkWrapper { [weak self] in
            guard let self else { return false }
            let elapsed = CACurrentMediaTime() - startTime
            let t = min(elapsed / duration, 1.0)
            let ease = 1.0 - pow(1.0 - t, 3.0)
            let currentX = startFrame.origin.x + (targetFrame.origin.x - startFrame.origin.x) * ease
            let currentY = startFrame.origin.y + (targetFrame.origin.y - startFrame.origin.y) * ease
            let currentWidth = startFrame.width + (targetFrame.width - startFrame.width) * ease
            let currentHeight = startFrame.height + (targetFrame.height - startFrame.height) * ease
            DispatchQueue.main.async {
                self.setFrame(NSRect(x: currentX, y: currentY, width: currentWidth, height: currentHeight), display: true)
                if t >= 1.0 {
                    self.pillContentHost?.alphaValue = 1
                }
            }
            return t < 1.0
        }
        displayLink.start()
    }

    /// Spring / bounce easing -- overshoots then settles
    private static func bounceEase(_ t: Double) -> Double {
        let omega = 12.0
        let zeta = 0.4
        return 1.0 - exp(-zeta * omega * t) * cos(sqrt(1.0 - zeta * zeta) * omega * t)
    }

    // MARK: - Notch size detection

    /// Full geometry detection result, stored on the window instance.
    private(set) var geometry: NotchGeometry = .fallback

    private func detectGeometry() {
        geometry = NotchGeometry.detect()
        notchWidth = geometry.notchWidth
        notchHeight = geometry.notchHeight
        geometry.writeToFile()
    }

    // MARK: - Positioning

    private var collapsedPadding: CGFloat {
        StatusWatcher.shared.config.collapsedProfile.notch_overlap ?? 40
    }

    var currentStatusBarHeight: CGFloat { StatusBarLayout.height }
    var currentStatusBarMode: StatusBarLayout.Mode { StatusBarLayout.mode }

    private func positionAtNotch() {
        if isFloatingMode {
            positionFloating()
            return
        }
        guard let screen = NSScreen.builtIn else { return }
        let screenFrame = screen.frame
        let totalHeight = notchHeight + StatusBarLayout.height
        let x = screenFrame.midX - notchWidth / 2 - collapsedPadding
        let y = screenFrame.maxY - totalHeight
        setFrame(NSRect(x: x, y: y, width: notchWidth + collapsedPadding * 2, height: totalHeight), display: true)
    }

    private func positionFloating() {
        guard let screen = NSScreen.builtIn ?? NSScreen.main else { return }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY
        let totalHeight = Self.floatingHeight + StatusBarLayout.height
        let position = StatusWatcher.shared.config.resolvedFloatingPosition
        let x: CGFloat
        switch position {
        case "left":
            x = screenFrame.minX + 80
        case "right":
            x = screenFrame.maxX - Self.floatingWidth - 80
        default: // "center"
            x = screenFrame.midX - Self.floatingWidth / 2
        }
        let y = screenFrame.maxY - menuBarHeight - Self.floatingTopOffset - totalHeight
        setFrame(NSRect(x: x, y: y, width: Self.floatingWidth, height: totalHeight), display: true)
    }

    // MARK: - Mouse tracking

    private func setupTracking() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.checkMouse()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.checkMouse()
            return event
        }
    }

    private func checkMouse() {
        let mouseLocation = NSEvent.mouseLocation

        let hoverRect: NSRect
        if isFloatingMode {
            // In floating mode, hover zone is the window frame itself
            hoverRect = frame.insetBy(dx: -2, dy: -2)
        } else {
            guard let screen = NSScreen.builtIn else { return }
            let screenFrame = screen.frame
            let effectiveWidth = isExpanded ? notchWidth + 80 : notchWidth
            hoverRect = NSRect(
                x: screenFrame.midX - effectiveWidth / 2,
                y: screenFrame.maxY - notchHeight,
                width: effectiveWidth,
                height: notchHeight + 1
            )
        }

        let mouseInNotch = hoverRect.contains(mouseLocation)
        let mouseInAdditional = additionalHoverRects.contains { $0().contains(mouseLocation) }

        if mouseInNotch || mouseInAdditional {
            if !isHovered {
                isHovered = true
                hoverGrow()
            }
            onHover?()
            return
        }

        if isHovered {
            let panelShowing = isPanelVisible?() ?? false
            if !panelShowing {
                isHovered = false
                hoverShrink()
            }
        }
    }

    /// Called when the panel hides -- forces the notch back to normal size.
    func endHover() {
        guard isHovered else { return }
        isHovered = false
        hoverShrink()
    }

    // MARK: - Hover grow / shrink

    private static let hoverGrowX: CGFloat = 0 + NotchPillView.earRadius * 2
    private static let hoverGrowY: CGFloat = 2

    private func applyHoverGrow(to rect: NSRect) -> NSRect {
        NSRect(
            x: rect.origin.x - Self.hoverGrowX / 2,
            y: rect.origin.y - Self.hoverGrowY,
            width: rect.width + Self.hoverGrowX,
            height: rect.height + Self.hoverGrowY
        )
    }

    private func hoverGrow() {
        pillView.isHovered = true
        pillContentHost?.rootView = NotchPillContent(isHovering: true)
        setFrame(applyHoverGrow(to: frame), display: true)
    }

    private func hoverShrink() {
        pillView.isHovered = false
        pillContentHost?.rootView = NotchPillContent(isHovering: false)

        if isFloatingMode {
            // In floating mode, just reposition to collapsed floating size
            positionFloating()
            return
        }

        guard let screen = NSScreen.builtIn else { return }
        let screenFrame = screen.frame
        let baseWidth = isExpanded ? notchWidth + 80 : notchWidth
        let targetFrame = NSRect(
            x: screenFrame.midX - baseWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: baseWidth,
            height: notchHeight
        )
        setFrame(targetFrame, display: true)
    }

    // MARK: - Observers

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.detectGeometry()
            self?.applyDisplayMode()
            self?.positionAtNotch()
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - NotchGeometry

struct NotchGeometry {
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let leftEarAvailable: CGFloat   // total menu bar space left of notch
    let rightEarAvailable: CGFloat  // total status icon space right of notch
    let hasNotch: Bool              // whether a real notch was detected

    static let fallback = NotchGeometry(
        screenWidth: 1710, screenHeight: 1107,
        notchWidth: 180, notchHeight: 37,
        leftEarAvailable: 763, rightEarAvailable: 762,
        hasNotch: true
    )

    /// Quick check: does the current built-in screen have a notch?
    static var screenHasNotch: Bool {
        guard let screen = NSScreen.builtIn else { return false }
        if #available(macOS 12.0, *) {
            return screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        }
        return false
    }

    /// Detect screen and notch dimensions at runtime.
    static func detect() -> NotchGeometry {
        guard let screen = NSScreen.builtIn else { return .fallback }
        let frame = screen.frame

        var nw: CGFloat = 180
        var nh: CGFloat = 37
        var leftAvail: CGFloat = 0
        var rightAvail: CGFloat = 0
        var detected = false

        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            nw = right.minX - left.maxX
            nh = frame.maxY - min(left.minY, right.minY)
            leftAvail = left.width
            rightAvail = right.width
            detected = true
        } else {
            let menuBarHeight = frame.maxY - screen.visibleFrame.maxY
            nw = 180
            nh = max(menuBarHeight, 25)
            leftAvail = (frame.width - nw) / 2
            rightAvail = (frame.width - nw) / 2
        }

        return NotchGeometry(
            screenWidth: frame.width,
            screenHeight: frame.height,
            notchWidth: nw,
            notchHeight: nh,
            leftEarAvailable: leftAvail,
            rightEarAvailable: rightAvail,
            hasNotch: detected
        )
    }

    /// Write geometry to ~/.atlas/hud-geometry.json for other agents to read.
    func writeToFile() {
        let path = NSString("~/.atlas/hud-geometry.json").expandingTildeInPath
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let now = formatter.string(from: Date())

        let json: [String: Any] = [
            "screen": ["width": screenWidth, "height": screenHeight],
            "notch": ["width": notchWidth, "height": notchHeight],
            "available": ["left": leftEarAvailable, "right": rightEarAvailable],
            "hasNotch": hasNotch,
            "displayMode": StatusWatcher.shared.config.resolvedDisplayMode,
            "detected": now
        ]

        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

// MARK: - NSScreen helper

extension NSScreen {
    /// Returns the built-in display (the one with the notch), or the main screen as fallback.
    static var builtIn: NSScreen? {
        screens.first { screen in
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return CGDisplayIsBuiltin(id) != 0
        } ?? main
    }
}

// MARK: - Notch pill background view

/// A view that draws a rounded pill shape extending below the notch.
class NotchPillView: NSView {
    var isHovered: Bool = false {
        didSet {
            guard isHovered != oldValue else { return }
            needsDisplay = true
            needsLayout = true
        }
    }

    /// Whether in expanded U-shape mode
    var isUShape: Bool = false {
        didSet {
            guard isUShape != oldValue else { return }
            needsDisplay = true
            needsLayout = true
        }
    }

    /// Whether in floating panel mode (fully rounded, border, shadow)
    var isFloatingMode: Bool = false {
        didSet {
            guard isFloatingMode != oldValue else { return }
            updateFloatingAppearance()
            needsDisplay = true
            needsLayout = true
        }
    }

    /// The notch dimensions (set by NotchWindow)
    var notchWidth: CGFloat = 180
    var notchHeight: CGFloat = 37
    var leftEarWidth: CGFloat = 50
    var rightEarWidth: CGFloat = 50

    private let shapeLayer = CAShapeLayer()
    static let earRadius: CGFloat = 10

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.backgroundColor = .clear
        shapeLayer.fillColor = NSColor.black.cgColor
        layer?.addSublayer(shapeLayer)
    }

    private func updateFloatingAppearance() {
        if isFloatingMode {
            shapeLayer.strokeColor = NSColor.white.withAlphaComponent(0.12).cgColor
            shapeLayer.lineWidth = 0.5
            shapeLayer.shadowColor = NSColor.black.cgColor
            shapeLayer.shadowOpacity = 0.5
            shapeLayer.shadowOffset = CGSize(width: 0, height: -2)
            shapeLayer.shadowRadius = 8
            shapeLayer.fillColor = NSColor.black.withAlphaComponent(0.85).cgColor
        } else {
            shapeLayer.strokeColor = nil
            shapeLayer.lineWidth = 0
            shapeLayer.shadowOpacity = 0
            shapeLayer.fillColor = NSColor.black.cgColor
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateShape()
    }

    private func updateShape() {
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }

        let ear = Self.earRadius
        shapeLayer.frame = CGRect(x: 0, y: 0, width: w, height: h)

        let path = CGMutablePath()

        if isFloatingMode {
            // Floating mode: fully rounded rectangle on all corners
            let cr: CGFloat = 10
            let rect = CGRect(x: 0, y: 0, width: w, height: h)
            path.addRoundedRect(in: rect, cornerWidth: cr, cornerHeight: cr)
            shapeLayer.path = path
            return
        }

        if isUShape && h > notchHeight {
            let cr: CGFloat = 12
            let overlap: CGFloat = 3
            let leftEar = leftEarWidth + overlap
            let rightEar = rightEarWidth + overlap
            let notchTop = h
            let notchBottom = h - notchHeight
            let innerCr: CGFloat = 6

            path.move(to: CGPoint(x: 0, y: notchTop - cr))
            path.addQuadCurve(to: CGPoint(x: cr, y: notchTop), control: CGPoint(x: 0, y: notchTop))
            path.addLine(to: CGPoint(x: leftEar - innerCr, y: notchTop))
            path.addQuadCurve(to: CGPoint(x: leftEar, y: notchTop - innerCr), control: CGPoint(x: leftEar, y: notchTop))
            path.addLine(to: CGPoint(x: leftEar, y: notchBottom + innerCr))
            path.addQuadCurve(to: CGPoint(x: leftEar + innerCr, y: notchBottom), control: CGPoint(x: leftEar, y: notchBottom))
            path.addLine(to: CGPoint(x: w - rightEar - innerCr, y: notchBottom))
            path.addQuadCurve(to: CGPoint(x: w - rightEar, y: notchBottom + innerCr), control: CGPoint(x: w - rightEar, y: notchBottom))
            path.addLine(to: CGPoint(x: w - rightEar, y: notchTop - innerCr))
            path.addQuadCurve(to: CGPoint(x: w - rightEar + innerCr, y: notchTop), control: CGPoint(x: w - rightEar, y: notchTop))
            path.addLine(to: CGPoint(x: w - cr, y: notchTop))
            path.addQuadCurve(to: CGPoint(x: w, y: notchTop - cr), control: CGPoint(x: w, y: notchTop))
            path.addLine(to: CGPoint(x: w, y: cr))
            path.addQuadCurve(to: CGPoint(x: w - cr, y: 0), control: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: cr, y: 0))
            path.addQuadCurve(to: CGPoint(x: 0, y: cr), control: CGPoint(x: 0, y: 0))
            path.closeSubpath()

        } else if isHovered {
            let bodyLeft = ear
            let bodyRight = w - ear

            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: bodyLeft, y: ear),
                control: CGPoint(x: bodyLeft, y: 0)
            )
            path.addLine(to: CGPoint(x: bodyLeft, y: h))
            path.addLine(to: CGPoint(x: bodyRight, y: h))
            path.addLine(to: CGPoint(x: bodyRight, y: ear))
            path.addQuadCurve(
                to: CGPoint(x: w, y: 0),
                control: CGPoint(x: bodyRight, y: 0)
            )
        } else {
            let cr: CGFloat = 9.5
            path.move(to: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: w, y: cr))
            path.addQuadCurve(
                to: CGPoint(x: w - cr, y: 0),
                control: CGPoint(x: w, y: 0)
            )
            path.addLine(to: CGPoint(x: cr, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: cr),
                control: CGPoint(x: 0, y: 0)
            )
            path.closeSubpath()
        }

        shapeLayer.path = path
    }
}

// MARK: - Notch display state

enum NotchDisplayState: Equatable {
    case offline     // gray — not running
    case nominal     // green — all clear
    case attention   // yellow — something noteworthy
    case urgent      // red — Jane is alarmed but handling it
    case sos         // white/pulsing — dead stop, needs human NOW

    /// Derives state from StatusWatcher
    static var current: NotchDisplayState {
        SessionStore.shared.notchDisplayState
    }
}

// MARK: - Notch pill SwiftUI content

struct NotchPillContent: View {
    var isHovering: Bool = false
    private var displayState: NotchDisplayState { .current }
    private var statusWatcher: StatusWatcher { StatusWatcher.shared }
    private var isExpanded: Bool { displayState == .attention || displayState == .urgent }

    /// Resolved status bar config — from status.json or defaults based on layout mode
    private var currentBarConfig: StatusBarConfig {
        // If status.json provides a statusBar config, use it
        if let config = statusWatcher.currentStatus.statusBar {
            return config
        }
        // Otherwise, derive from the legacy StatusBarLayout mode
        switch StatusBarLayout.mode {
        case .thin:
            return StatusBarConfig(mode: "histogram", size: "small", color: nil, data: nil, text: nil, renderer: nil, presentation: nil)
        case .medium:
            let text = statusWatcher.currentStatus.banner ?? statusWatcher.currentStatus.message
            return StatusBarConfig(mode: "content", size: "medium", color: "red", data: nil, text: text, renderer: "text", presentation: "static")
        case .thick:
            let text = statusWatcher.currentStatus.banner ?? statusWatcher.currentStatus.message
            return StatusBarConfig(mode: "content", size: "large", color: "red", data: nil, text: text, renderer: "lcd", presentation: "static")
        }
    }

    var body: some View {
        GeometryReader { geo in
            if isExpanded && geo.size.height > 40 {
                expandedLayout(geo: geo)
            } else {
                collapsedLayout
            }
        }
        .background(Color.clear)
        .onChange(of: displayState) { _, _ in
            NotificationCenter.default.post(name: .NotchyNotchStatusChanged, object: nil)
        }
    }

    // MARK: - Collapsed (green/offline)

    private var collapsedProfile: CollapsedConfig {
        StatusWatcher.shared.config.collapsedProfile
    }

    private var collapsedLayout: some View {
        let p = collapsedProfile
        let w = p.indicator_width ?? 30
        let h = p.indicator_height ?? 28
        let r = p.corner_radius ?? 8
        let pad = p.edge_padding ?? 2

        return VStack(spacing: 0) {
            // Top zone: indicators (fills notch height)
            HStack {
                if p.left?.visible != false {
                    collapsedLeftContent
                        .frame(width: w, height: h)
                        .clipShape(RoundedRectangle(cornerRadius: r))
                        .shadow(color: statusCircleColor.opacity(0.5), radius: 2)
                        .padding(.leading, pad)
                }
                Spacer()
                if p.right?.visible != false {
                    collapsedRightContent
                        .frame(width: w, height: h)
                        .clipShape(RoundedRectangle(cornerRadius: r))
                        .padding(.trailing, pad)
                }
            }
            .frame(maxHeight: .infinity)

            // Bottom zone: status bar (routed through StatusBarRouter)
            StatusBarRouter(config: currentBarConfig)
                .frame(height: StatusBarLayout.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Left content — swappable via config
    @ViewBuilder
    private var collapsedLeftContent: some View {
        switch collapsedProfile.left?.type {
        case "severity":
            statusCircleColor
        default: // "avatar"
            Image("face")
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }

    // Right content — swappable via config
    @ViewBuilder
    private var collapsedRightContent: some View {
        switch collapsedProfile.right?.type {
        case "avatar":
            Image("face")
                .resizable()
                .aspectRatio(contentMode: .fill)
        default: // "severity"
            statusCircleColor
        }
    }

    // MARK: - Expanded U-shape (yellow/red)

    private func expandedLayout(geo: GeometryProxy) -> some View {
        let totalW = geo.size.width
        let totalH = geo.size.height
        let layout = NotchWindow.activeLayout
        let bottomH: CGFloat = layout.bottomStrip
        let leftEarW = layout.leftEar
        let rightEarW = layout.rightEar
        let topH = totalH - bottomH

        return ZStack(alignment: .top) {
            // Top row: left monitor + gap + right monitor
            HStack(spacing: 0) {
                // LEFT EAR — avatar + info columns
                HStack(spacing: 0) {
                    leftMonitor
                        .frame(width: NotchWindow.avatarWidth, height: totalH)

                    if leftEarW > NotchWindow.avatarWidth + 10 {
                        leftInfoPanel
                            .frame(width: leftEarW - NotchWindow.avatarWidth, height: topH)
                    }
                }

                Spacer()

                // RIGHT EAR — status indicator
                VStack(spacing: 0) {
                    rightMonitor
                        .frame(width: rightEarW, height: topH)
                    Spacer()
                        .frame(width: rightEarW, height: bottomH)
                }
            }

            // BOTTOM TICKER — right of avatar, below notch
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: NotchWindow.avatarWidth)

                    if let banner = statusWatcher.currentStatus.banner, !banner.isEmpty {
                        Text(banner)
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundColor(statusCircleColor)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 8)
                            .padding(.top, 6)
                            .padding(.bottom, 4)
                    } else {
                        Text(statusWatcher.currentStatus.message)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(statusCircleColor)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 8)
                            .padding(.top, 6)
                            .padding(.bottom, 4)
                    }
                }
            }
        }
        .frame(width: totalW, height: totalH)
    }

    // MARK: - Left Monitor (avatar)

    private var leftMonitor: some View {
        ZStack {
            Image("face")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            statusCircleColor
                .opacity(isUrgent ? 0.25 : 0.08)
                .blendMode(.overlay)

            Canvas { context, size in
                let lineSpacing: CGFloat = 3
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(.black.opacity(0.15)))
                    y += lineSpacing
                }
            }
            .allowsHitTesting(false)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
        )
        .shadow(color: statusCircleColor.opacity(isUrgent ? 0.8 : 0.3), radius: isUrgent ? 5 : 2)
        .scaleEffect(isUrgent ? 1.05 : 1.0)
        .animation(
            isUrgent
                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                : .default,
            value: isUrgent
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isUrgent: Bool { displayState == .urgent }

    // MARK: - Left Info Panel (columns next to avatar)

    private var leftInfoPanel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(statusWatcher.currentStatus.source.uppercased())
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundColor(statusCircleColor.opacity(0.7))

            Text(statusLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(statusCircleColor)

            Text(timeAgo)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.leading, 4)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusLabel: String {
        switch displayState {
        case .sos:       return "SOS"
        case .urgent:    return "ALERT"
        case .attention: return "WATCH"
        case .nominal:   return "OK"
        case .offline:   return "OFF"
        }
    }

    // MARK: - Right Monitor (severity + time)

    private var rightMonitor: some View {
        VStack(spacing: 2) {
            Text(severityIcon)
                .font(.system(size: 16))
                .shadow(color: statusCircleColor.opacity(0.6), radius: 3)
            Text(timeAgo)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(statusCircleColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shared Components

    private var jewel: some View {
        Circle()
            .fill(statusCircleColor)
            .frame(width: 8, height: 8)
            .shadow(color: statusCircleColor.opacity(0.8), radius: 3)
            .shadow(color: statusCircleColor.opacity(0.4), radius: 6)
            .overlay(
                Circle()
                    .stroke(statusCircleColor.opacity(0.5), lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .opacity(displayState == .urgent ? 1 : 0)
                    .scaleEffect(displayState == .urgent ? 1.3 : 1.0)
                    .animation(
                        displayState == .urgent
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: displayState
                    )
            )
    }

    private var statusCircleColor: Color {
        switch statusWatcher.currentStatus.status {
        case "sos": return .white
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }

    private var severityIcon: String {
        switch displayState {
        case .sos: return "🆘"
        case .urgent: return "🔴"
        case .attention: return "⚠️"
        case .nominal: return "✅"
        case .offline: return "⬛"
        }
    }

    private var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: statusWatcher.currentStatus.updated) else { return "" }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds/60)m" }
        return "\(seconds/3600)h"
    }
}

// MARK: - CVDisplayLink wrapper for smooth animation

class CVDisplayLinkWrapper {
    private var displayLink: CVDisplayLink?
    private let callback: () -> Bool
    private var stopped = false

    init(callback: @escaping () -> Bool) {
        self.callback = callback
    }

    func start() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink else { return }

        let opaqueWrapper = Unmanaged.passRetained(self)
        CVDisplayLinkSetOutputCallback(displayLink, { (_, _, _, _, _, userInfo) -> CVReturn in
            guard let userInfo else { return kCVReturnError }
            let wrapper = Unmanaged<CVDisplayLinkWrapper>.fromOpaque(userInfo).takeUnretainedValue()
            guard !wrapper.stopped else { return kCVReturnSuccess }
            let keepRunning = wrapper.callback()
            if !keepRunning {
                wrapper.stopped = true
                if let link = wrapper.displayLink {
                    CVDisplayLinkStop(link)
                }
                DispatchQueue.main.async {
                    wrapper.displayLink = nil
                    Unmanaged<CVDisplayLinkWrapper>.fromOpaque(userInfo).release()
                }
            }
            return kCVReturnSuccess
        }, opaqueWrapper.toOpaque())

        CVDisplayLinkStart(displayLink)
    }

    func stop() {
        stopped = true
        guard let displayLink else { return }
        CVDisplayLinkStop(displayLink)
        self.displayLink = nil
    }
}
