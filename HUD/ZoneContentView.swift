import SwiftUI

// MARK: - Zone-driven HUD content

struct ZoneContentView: View {
    let layout: ResolvedLayout
    let status: AtlasStatus
    let config: HUDConfig

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Avatar zone
            AvatarZone()
                .frame(width: layout.avatarFrame.width, height: layout.avatarFrame.height)
                .offset(x: layout.avatarFrame.origin.x, y: 0)

            // Panels zone (if visible)
            if let panelsFrame = layout.panelsFrame {
                PanelsZone(status: status)
                    .frame(width: panelsFrame.width, height: panelsFrame.height)
                    .offset(x: panelsFrame.origin.x, y: panelsFrame.origin.y)
            }

            // Status zone
            StatusZone(status: status)
                .frame(width: layout.statusFrame.width, height: layout.statusFrame.height)
                .offset(x: layout.statusFrame.origin.x, y: layout.statusFrame.origin.y)

            // Ticker zone
            TickerZone(status: status)
                .frame(width: layout.tickerFrame.width, height: layout.tickerFrame.height)
                .offset(x: layout.tickerFrame.origin.x, y: layout.tickerFrame.origin.y)
        }
        .frame(width: layout.totalFrame.width, height: layout.totalFrame.height)
    }
}

// MARK: - Individual Zone Views

struct AvatarZone: View {
    var body: some View {
        Image("face")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            ))
    }
}

struct PanelsZone: View {
    let status: AtlasStatus

    private let minColumnWidth: CGFloat = 60

    var body: some View {
        let slots = status.slots ?? [:]
        let sortedSlots = slots.sorted(by: { $0.key < $1.key })

        if sortedSlots.isEmpty {
            // Fallback: basic info when no slots are provided
            basicInfoView
        } else {
            GeometryReader { geo in
                let columnCount = max(1, Int(geo.size.width / minColumnWidth))
                let visibleSlots = Array(sortedSlots.prefix(columnCount))

                HStack(spacing: 2) {
                    ForEach(visibleSlots, id: \.key) { _, slot in
                        PanelColumnView(slot: slot, color: severityColor)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    private var basicInfoView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(status.source.uppercased())
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundColor(severityColor.opacity(0.7))
            Text(statusLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(severityColor)
            Text(timeAgo(from: status.updated))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.leading, 4)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var severityColor: Color {
        switch status.status {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }

    private var statusLabel: String {
        switch status.status {
        case "red": return "ALERT"
        case "yellow": return "WATCH"
        case "green": return "OK"
        default: return "OFF"
        }
    }

    private func timeAgo(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds/60)m" }
        return "\(seconds/3600)h"
    }
}

struct StatusZone: View {
    let status: AtlasStatus

    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(severityColor)
                .frame(width: 10, height: 10)
                .shadow(color: severityColor.opacity(0.8), radius: status.status == "red" ? 5 : 2)
                .overlay(
                    Circle()
                        .stroke(severityColor.opacity(0.3), lineWidth: 1)
                        .frame(width: 16, height: 16)
                )
            Text(timeAgo(from: status.updated))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(severityColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var severityColor: Color {
        switch status.status {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }

    private func timeAgo(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds/60)m" }
        return "\(seconds/3600)h"
    }
}

struct TickerZone: View {
    let status: AtlasStatus

    var body: some View {
        if let banner = status.banner, !banner.isEmpty {
            BannerView(
                text: banner,
                ledColor: severityColor,
                speed: status.status == "red" ? 70 : 45,
                style: status.bannerStyle ?? "scroll"
            )
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
    }

    private var severityColor: Color {
        switch status.status {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }
}
