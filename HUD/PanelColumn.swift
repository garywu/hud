import SwiftUI

// MARK: - Panel Column Router

struct PanelColumnView: View {
    let slot: SlotData
    let color: Color

    var body: some View {
        switch slot.type {
        case "metric":
            MetricPanel(slot: slot, color: color)
        case "agent_status":
            AgentStatusPanel(slot: slot, color: color)
        case "countdown":
            CountdownPanel(slot: slot, color: color)
        case "gauge":
            GaugePanel(slot: slot, color: color)
        default:
            TextLabelPanel(slot: slot, color: color)
        }
    }
}

// MARK: - Metric Panel

struct MetricPanel: View {
    let slot: SlotData
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(slot.value)
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
            Text(slot.label.uppercased())
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(color.opacity(0.5))
            if let trend = slot.trend {
                Text(trend == "up" ? "\u{25B2}" : trend == "down" ? "\u{25BC}" : "\u{2014}")
                    .font(.system(size: 8))
                    .foregroundColor(trend == "up" ? .green : trend == "down" ? .red : .gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Agent Status Panel

struct AgentStatusPanel: View {
    let slot: SlotData
    let color: Color

    private var stateColor: Color {
        switch slot.state {
        case "active": return .green
        case "error": return .red
        case "idle": return .gray
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            if let icon = slot.icon {
                Text(icon)
                    .font(.system(size: 14))
            }
            Text(slot.label.uppercased())
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.7))
                .lineLimit(1)
            Circle()
                .fill(stateColor)
                .frame(width: 6, height: 6)
                .shadow(color: stateColor.opacity(0.6), radius: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Countdown Panel

struct CountdownPanel: View {
    let slot: SlotData
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(slot.label.uppercased())
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(color.opacity(0.5))
            Text(slot.value)
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Gauge Panel (progress bar with percentage)

struct GaugePanel: View {
    let slot: SlotData
    let color: Color

    private var percent: Double {
        // Parse "27%" -> 0.27
        let raw = slot.value.replacingOccurrences(of: "%", with: "")
        return (Double(raw) ?? 0) / 100.0
    }

    private var gaugeColor: Color {
        switch slot.state {
        case "error": return .red
        case "active": return .yellow
        default:
            if percent >= 0.85 { return .red }
            if percent >= 0.65 { return .yellow }
            return .green
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            // Percentage value
            Text(slot.value)
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundColor(gaugeColor)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(gaugeColor)
                        .frame(width: geo.size.width * min(max(percent, 0), 1), height: 4)
                        .shadow(color: gaugeColor.opacity(0.5), radius: percent >= 0.85 ? 3 : 1)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 4)

            // Label (e.g., "CTX 45K/200K")
            Text(slot.label.uppercased())
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(color.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Trend arrow
            if let trend = slot.trend {
                Text(trend == "up" ? "\u{25B2}" : trend == "down" ? "\u{25BC}" : "\u{2014}")
                    .font(.system(size: 7))
                    .foregroundColor(trend == "up" ? gaugeColor : trend == "down" ? .green : .gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Text Label Panel (default fallback)

struct TextLabelPanel: View {
    let slot: SlotData
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(slot.label.uppercased())
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(color.opacity(0.5))
            Text(slot.value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
