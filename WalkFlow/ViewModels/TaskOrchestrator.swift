import Foundation
import PodStickKit

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
        podStick?.stop()
        voiceInput?.stopListening()
        speechOutput?.stop()
        Task {
            await openClawClient?.disconnect()
        }
    }

    private func setupPodStickKit() {
        let config = Configuration(
            tap: TapConfiguration(enableSilentPlayback: false)
        )
        let ps = PodStickKit(configuration: config)

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

        ps.tap.onSingleTap = { [weak self] in
            self?.handleSingleTap()
        }

        // motion.start()のみ使用してAudioSession競合を回避
        // tap.setup()はSilentAudioPlayer無しで手動呼出し
        AudioSessionCoordinator.switchToPlayback()
        ps.motion.start()
        ps.tap.setup()
        self.podStick = ps
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
