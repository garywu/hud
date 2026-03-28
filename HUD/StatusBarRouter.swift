import SwiftUI

// MARK: - Status Bar Router

/// Routes a StatusBarConfig to the appropriate display engine.
/// Composes: mode (what) × renderer (how to draw) × presentation (how to cycle)
///
/// When an RSVP interruption is active, the router yields the display to the
/// urgent notification (plain text) and resumes RSVP once the interruption ends.
struct StatusBarRouter: View {
    let config: StatusBarConfig

    private var rsvpManager: RSVPInterruptionManager { .shared }

    var fallbackText: String {
        StatusWatcher.shared.currentStatus.banner
            ?? StatusWatcher.shared.currentStatus.message
    }

    private var displayText: String {
        config.text ?? fallbackText
    }

    private var lcdTheme: LCDTheme {
        LCDTheme(rawValue: config.color ?? "red") ?? .red
    }

    private var wpm: Int {
        Int(config.data?.first ?? 150)
    }

    var body: some View {
        // When RSVP is paused by an interruption, show the urgent notification instead
        if rsvpManager.shouldYieldDisplay && isRSVPConfig {
            interruptionOverlayView
        } else {
        switch config.resolvedMode {
        // Scanner-class modes (4pt, animated, no text)
        case .scanner:
            KITTScannerView(color: config.resolvedColor)
        case .histogram:
            HistogramView(data: config.data, size: config.resolvedSize, color: config.color != nil ? config.resolvedColor : nil)
        case .sparkline:
            SparklineView(data: config.data, color: config.resolvedColor)
        case .progress:
            ProgressBarView(progress: config.data?.first ?? 0.0, color: config.resolvedColor, size: config.resolvedSize)
        case .heatmap:
            HistogramView(data: config.data, size: config.resolvedSize, color: nil)

        // Content mode — compose renderer × presentation
        case .content:
            contentView
        }
        }  // end if/else rsvp interruption
    }

    // MARK: - RSVP Interruption

    /// Whether the current config is rendering an RSVP presentation
    private var isRSVPConfig: Bool {
        config.resolvedPresentation == .rsvp
    }

    /// View shown in place of RSVP when an interruption is active.
    /// Displays the urgent notification text with severity color.
    @ViewBuilder
    private var interruptionOverlayView: some View {
        let urgentText = StatusWatcher.shared.currentStatus.banner
            ?? StatusWatcher.shared.currentStatus.message
        let urgentColor: Color = {
            switch rsvpManager.activeInterruption?.level {
            case .critical:      return .red
            case .timeSensitive: return .red
            case .active:        return .yellow
            default:             return .white
            }
        }()
        PlainTextBarView(text: urgentText, size: config.resolvedSize, color: urgentColor)
    }

    // MARK: - Content: Renderer × Presentation

    @ViewBuilder
    private var contentView: some View {
        switch (config.resolvedRenderer, config.resolvedPresentation) {
        // Text renderer
        case (.text, .static):
            PlainTextBarView(text: displayText, size: config.resolvedSize, color: config.resolvedColor)
        case (.text, .scroll):
            PlainTextBarView(text: displayText, size: config.resolvedSize, color: config.resolvedColor)  // TODO: scrolling text view
        case (.text, .rsvp):
            RSVPBarView(text: displayText, size: config.resolvedSize, color: config.resolvedColor, wpm: wpm)

        // LCD renderer
        case (.lcd, .static):
            LCDGridView(text: displayText, size: config.resolvedSize, color: config.resolvedColor, theme: lcdTheme)
        case (.lcd, .scroll):
            LCDGridView(text: displayText, size: config.resolvedSize, color: config.resolvedColor, theme: lcdTheme)  // TODO: scrolling LCD
        case (.lcd, .rsvp):
            LCDRSVPView(text: displayText, size: config.resolvedSize, theme: lcdTheme, wpm: wpm)
        }
    }
}
