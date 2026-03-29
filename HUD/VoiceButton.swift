import SwiftUI

/// Voice recording button for the HUD panel.
/// Shows recording status, elapsed time, and real-time RMS level visualization.
struct VoiceButton: View {
    @State private var voiceState = VoiceRecordingState()

    var body: some View {
        VStack(spacing: 8) {
            // Main record button
            Button(action: toggleRecording) {
                HStack(spacing: 8) {
                    Text(voiceState.recordingButtonLabel)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    // RMS level indicator (visual feedback)
                    rmsIndicator
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(buttonBackground)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())

            // Error message display
            if let error = voiceState.errorMessage {
                Text(error)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
    }

    private func toggleRecording() {
        if voiceState.isRecording {
            Task {
                await voiceState.stopRecording()
            }
        } else {
            Task {
                await voiceState.startRecording()
            }
        }
    }

    private var buttonBackground: some View {
        if voiceState.isRecording {
            // Recording: gradient from red to orange
            return AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.red.opacity(0.6),
                        Color.orange.opacity(0.5)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else {
            // Idle: subtle blue
            return AnyView(
                Color.blue.opacity(0.2)
            )
        }
    }

    private var rmsIndicator: some View {
        HStack(spacing: 2) {
            // 4-segment RMS level bar
            ForEach(0..<4, id: \.self) { i in
                let threshold = Float(i + 1) / 4.0
                let isActive = voiceState.rmsLevel >= threshold
                Rectangle()
                    .fill(isActive ? rmsColor : Color.white.opacity(0.2))
                    .frame(width: 3, height: 10)
                    .cornerRadius(1)
            }
        }
    }

    private var rmsColor: Color {
        let value = voiceState.rmsLevel
        if value < 0.33 {
            return .green
        } else if value < 0.66 {
            return .yellow
        } else {
            return .red
        }
    }
}

#Preview {
    VoiceButton()
        .padding()
        .background(Color.black)
}
