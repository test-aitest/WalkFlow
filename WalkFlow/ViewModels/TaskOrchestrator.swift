import Foundation
import PodStickKit
import MediaPlayer
import UIKit

@MainActor
@Observable
final class TaskOrchestrator {
    var state: TaskState = .idle
    private(set) var currentTranscription = ""
    private(set) var lastAgentMessage = ""

    private var podStick: PodStickKit?
    private var voiceInput: VoiceInputService?
    private var speechOutput: SpeechOutputService?
    private var openClawClient: OpenClawClient?
    private var currentApprovalId: String?
    private var eventTask: Task<Void, Never>?

    // MARK: - Setup

    func setup() {
        setupPodStickKit()
        setupVoiceInput()
        setupSpeechOutput()
        connectToOpenClaw()
    }

    func teardown() {
        eventTask?.cancel()
        eventTask = nil
        podStick?.motion.stop()
        voiceInput?.stopListening()
        speechOutput?.stop()

        let center = MPRemoteCommandCenter.shared()
        center.togglePlayPauseCommand.removeTarget(nil)
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)

        Task {
            await openClawClient?.disconnect()
        }
    }

    private func setupPodStickKit() {
        let ps = PodStickKit()

        // HandsFreeRecipeと同じパターン: 不要なdetectorを除去
        ps.motion.removeGestureDetector(named: "headbang")
        ps.motion.removeGestureDetector(named: "pitchBoost")

        if let nodDetector = ps.motion.gestureDetectors.compactMap({ $0 as? NodDetector }).first {
            nodDetector.onNod = { [weak self] in
                self?.handleNod()
            }
        }

        if let shakeDetector = ps.motion.gestureDetectors.compactMap({ $0 as? HeadShakeDetector }).first {
            shakeDetector.onShake = { [weak self] in
                self?.handleShake()
            }
        }

        // HandsFreeRecipeと同じ: motion.start()のみ（tap.setup()は使わない）
        // ps.start() は tap.setup() も呼びSilentAudioPlayerがAudioSessionと競合する
        ps.motion.start()

        self.podStick = ps

        // タップ検出はMPRemoteCommandCenterで直接セットアップ
        setupRemoteTap()
    }

    private func setupRemoteTap() {
        let center = MPRemoteCommandCenter.shared()

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSingleTap()
            }
            return .success
        }

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSingleTap()
            }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSingleTap()
            }
            return .success
        }

        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    private func setupVoiceInput() {
        let voice = VoiceInputService()
        voice.onPartialTranscription = { [weak self] text in
            self?.currentTranscription = text
        }
        voice.onTranscription = { [weak self] text in
            self?.handleFinalTranscription(text)
        }
        self.voiceInput = voice
    }

    private func setupSpeechOutput() {
        self.speechOutput = SpeechOutputService()
    }

    private func connectToOpenClaw() {
        let client = OpenClawClient()
        self.openClawClient = client

        Task {
            do {
                try await client.connect(
                    host: Config.openClawGatewayURL,
                    token: Config.openClawGatewayToken
                )
                await listenForEvents(client)
            } catch {
                NSLog("[WalkFlow] OpenClaw connection failed: \(error)")
                state = .error("OpenClawに接続できません。サービスが起動しているか確認してください。")
            }
        }
    }

    private func listenForEvents(_ client: OpenClawClient) async {
        let events = await client.events
        eventTask = Task { [weak self] in
            for await event in events {
                await self?.handleEvent(event)
            }
        }
    }

    // MARK: - Gesture Handlers

    func handleSingleTap() {
        switch state {
        case .idle:
            state = .listening
            currentTranscription = ""
            Task {
                let authorized = await voiceInput?.requestAuthorization() ?? false
                if authorized {
                    voiceInput?.startListening()
                } else {
                    state = .idle
                }
            }

        case .listening:
            voiceInput?.stopListening()
            if currentTranscription.isEmpty {
                state = .idle
            } else {
                let text = currentTranscription
                state = .sendingToAgent
                sendToAgent(text)
            }

        case .listeningModification:
            voiceInput?.stopListening()
            if currentTranscription.isEmpty {
                state = .idle
            } else {
                let text = currentTranscription
                state = .sendingToAgent
                steerAgent(text)
            }

        default:
            break
        }
    }

    func handleNod() {
        guard case .awaitingApproval(let request) = state else { return }
        state = .executing(request.description)
        currentApprovalId = request.id

        Task {
            try? await openClawClient?.approveAction(request.id)
        }
    }

    func handleShake() {
        guard case .awaitingApproval = state else { return }
        state = .listeningModification
        currentTranscription = ""
        speechOutput?.speak("修正内容をどうぞ") { [weak self] in
            Task {
                let authorized = await self?.voiceInput?.requestAuthorization() ?? false
                if authorized {
                    self?.voiceInput?.startListening()
                }
            }
        }
    }

    // MARK: - Event Handling

    func handleApprovalRequested(_ request: ApprovalRequest) {
        state = .awaitingApproval(request)
        speechOutput?.speak("\(request.description)を実行します。よろしいですか？")
    }

    func handleTaskComplete() {
        state = .taskComplete
        speechOutput?.speak("タスクが完了しました")
        Task {
            try? await Task.sleep(for: .seconds(3))
            self.state = .idle
        }
    }

    private func handleEvent(_ event: GatewayEvent) {
        switch event.event {
        case "exec.approval.requested":
            if let request = event.approvalRequest {
                handleApprovalRequested(request)
            }
        case "session.message":
            if let message = event.sessionMessage {
                lastAgentMessage = message.content
                if message.content.contains("完了") || message.content.contains("done") {
                    handleTaskComplete()
                }
            }
        default:
            break
        }
    }

    // MARK: - Agent Communication

    private func sendToAgent(_ text: String) {
        Task {
            try? await openClawClient?.sendTask(text)
        }
    }

    private func steerAgent(_ text: String) {
        Task {
            try? await openClawClient?.steerSession(text)
        }
    }

    // MARK: - Test Helpers

    func simulatePartialTranscription(_ text: String) {
        currentTranscription = text
    }

    private func handleFinalTranscription(_ text: String) {
        // Final transcription from VoiceInputService when stopListening is called
        // Already handled in handleSingleTap
    }
}
