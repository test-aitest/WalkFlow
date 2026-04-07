import SwiftUI

struct TaskFlowView: View {
    @State private var orchestrator = TaskOrchestrator()

    var body: some View {
        Group {
            switch orchestrator.state {
            case .idle:
                idleView

            case .listening:
                ListeningView(transcription: orchestrator.currentTranscription, onTap: { orchestrator.handleSingleTap() })

            case .sendingToAgent:
                progressView(title: "AIに送信中...")

            case .awaitingApproval(let request):
                ApprovalView(description: request.description)

            case .listeningModification:
                ListeningView(transcription: orchestrator.currentTranscription, onTap: { orchestrator.handleSingleTap() })

            case .executing(let action):
                progressView(title: "実行中: \(action)")

            case .taskComplete:
                completeView

            case .error(let message):
                errorView(message: message)
            }
        }
        .onAppear {
            orchestrator.setup()
        }
        .onDisappear {
            orchestrator.teardown()
        }
    }

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "airpodspro")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("WalkFlow")
                .font(.title.bold())

            Text("タップで開始")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            orchestrator.handleSingleTap()
        }
    }

    private func progressView(title: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(2)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var completeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("完了")
                .font(.title.bold())

            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }
}
