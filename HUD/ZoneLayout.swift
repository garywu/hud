import SwiftUI

// MARK: - Zone Model

enum ZoneAnchor {
    case leftTop, rightTop, bottom
}

enum ZoneSizePolicy {
    case fixed(CGFloat)        // exact width/height
    case fill                  // takes remaining space
    case proportional(CGFloat) // fraction of available
}

struct ZoneDefinition {
    let name: String
    let anchor: ZoneAnchor
    let widthPolicy: ZoneSizePolicy
    let heightPolicy: ZoneSizePolicy
    let visible: Bool
    let contentType: String  // "avatar", "panels", "status", "ticker"
}

// MARK: - Layout Solver

struct ResolvedLayout: Equatable {
    let avatarFrame: CGRect
    let panelsFrame: CGRect?   // nil if no room
    let statusFrame: CGRect
    let tickerFrame: CGRect
    let totalFrame: CGRect

    static func solve(
        notchWidth: CGFloat,
        notchHeight: CGFloat,
        leftEar: CGFloat,
        rightEar: CGFloat,
        bottomStrip: CGFloat,
        avatarWidth: CGFloat
    ) -> ResolvedLayout {
        let totalWidth = leftEar + notchWidth + rightEar
        let totalHeight = notchHeight + bottomStrip

        // Avatar: fixed width, full height of left ear
        let avatarFrame = CGRect(x: 0, y: 0, width: avatarWidth, height: totalHeight)

        // Panels: fill remaining left ear space, top zone only
        let panelsWidth = leftEar - avatarWidth
        let panelsFrame = panelsWidth > 20
            ? CGRect(x: avatarWidth, y: bottomStrip, width: panelsWidth, height: notchHeight)
            : nil

        // Status: right ear, top zone only
        let statusFrame = CGRect(
            x: leftEar + notchWidth, y: bottomStrip,
            width: rightEar, height: notchHeight
        )

        // Ticker: full width, bottom strip
        let tickerFrame = CGRect(x: 0, y: 0, width: totalWidth, height: bottomStrip)

        let totalFrame = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)

        return ResolvedLayout(
            avatarFrame: avatarFrame,
            panelsFrame: panelsFrame,
            statusFrame: statusFrame,
            tickerFrame: tickerFrame,
            totalFrame: totalFrame
        )
    }
}
