import Observation
import SwiftUI

struct PanelContentView: View {
    let statusWatcher = StatusWatcher.shared
    let janeClient = JaneClient.shared

    private var queueManager: MessageQueueManager { MessageQueueManager.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text(statusWatcher.currentStatus.source.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                // Jane connection indicator
                if janeClient.isConnected {
                    Text("LIVE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }
                // Queue count badge
                if queueManager.queue.filter({ !$0.isExpired }).count > 1 {
                    Text("\(queueManager.queue.filter { !$0.isExpired }.count) msgs")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                Text(timeAgo)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }

            Text(statusWatcher.currentStatus.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(3)

            // Jane live data section
            if janeClient.isConnected, janeClient.janeContext != nil {
                Divider()
                    .background(Color.white.opacity(0.15))

                janeDataSection
            }

            // Voice recording button
            Divider()
                .background(Color.white.opacity(0.15))
            VoiceButton()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.9))
    }

    // MARK: - Jane live data

    @ViewBuilder
    private var janeDataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Health row: critical + warning counts
            HStack(spacing: 12) {
                if janeClient.criticalCount > 0 {
                    Label("\(janeClient.criticalCount) critical", systemImage: "exclamationmark.octagon.fill")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                } else {
                    Label("0 critical", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.green.opacity(0.7))
                }

                if janeClient.warningCount > 0 {
                    Label("\(janeClient.warningCount) warn", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }

                if janeClient.unresolvedCount > 0 {
                    Label("\(janeClient.unresolvedCount) unresolved", systemImage: "tray.full.fill")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange.opacity(0.8))
                }

                Spacer()
            }

            // Autonomy score
            if let score = janeClient.latestAutonomyScore {
                HStack(spacing: 6) {
                    Text("Autonomy")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    autonomyBar(score: score)
                    Text(String(format: "%.0f%%", score * 100))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(autonomyColor(score: score))
                }
            }

            // Last session summary
            if let summary = janeClient.lastSessionSummary {
                Text(summary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
            }
        }
    }

    private func autonomyBar(score: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(autonomyColor(score: score))
                    .frame(width: geo.size.width * min(max(score, 0), 1), height: 4)
            }
        }
        .frame(width: 60, height: 4)
    }

    private func autonomyColor(score: Double) -> Color {
        if score >= 0.7 { return .green }
        if score >= 0.4 { return .yellow }
        return .orange
    }

    var statusColor: Color {
        switch statusWatcher.currentStatus.status {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }

    var timeAgo: String {
        // Simple time display
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: statusWatcher.currentStatus.updated) else {
            return ""
        }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds/60)m ago" }
        return "\(seconds/3600)h ago"
    }
}
