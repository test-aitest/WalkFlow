import SwiftUI

struct ListeningView: View {
    let transcription: String
    var onTap: (() -> Void)?
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)

                Circle()
                    .fill(.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)

                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
            }

            if transcription.isEmpty {
                Text("聞いています...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                Text(transcription)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Text("タップで確定")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            isAnimating = true
        }
    }
}
