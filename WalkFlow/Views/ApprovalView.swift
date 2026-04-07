import SwiftUI

struct ApprovalView: View {
    let description: String
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)

                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
            }

            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Label("うなずいて承認", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                Label("首を振って修正", systemImage: "xmark.circle")
                    .foregroundStyle(.red)
            }
            .font(.caption)

            Spacer()
        }
        .onAppear {
            isPulsing = true
        }
    }
}
