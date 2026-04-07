import Speech
import AVFoundation

@MainActor
final class VoiceInputService {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    private(set) var isListening = false
    private(set) var partialTranscription = ""

    var onTranscription: ((String) -> Void)?
    var onPartialTranscription: ((String) -> Void)?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startListening() {
        guard !isListening else { return }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            NSLog("[VoiceInput] SpeechRecognizer not available")
            return
        }

        stopListening()

        AudioSessionCoordinator.switchToVoiceRecognition()

        let engine = AVAudioEngine()
        self.audioEngine = engine

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 else {
            NSLog("[VoiceInput] Invalid format, retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.retryStartListening()
            }
            return
        }

        beginRecording(engine: engine, inputNode: inputNode, format: recordingFormat, request: recognitionRequest, recognizer: speechRecognizer)
    }

    private func retryStartListening() {
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        let engine = AVAudioEngine()
        self.audioEngine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionRequest = request
        request.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0 else {
            NSLog("[VoiceInput] Still invalid format")
            return
        }

        beginRecording(engine: engine, inputNode: inputNode, format: format, request: request, recognizer: speechRecognizer)
    }

    private func beginRecording(engine: AVAudioEngine, inputNode: AVAudioNode, format: AVAudioFormat, request: SFSpeechAudioBufferRecognitionRequest, recognizer: SFSpeechRecognizer) {
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let error {
                NSLog("[VoiceInput] Recognition error: \(error.localizedDescription)")
                return
            }
            guard let self, let result else { return }

            let text = result.bestTranscription.formattedString
            Task { @MainActor in
                self.partialTranscription = text
                self.onPartialTranscription?(text)
            }
        }

        engine.prepare()
        do {
            try engine.start()
            isListening = true
            partialTranscription = ""
            NSLog("[VoiceInput] Listening started")
        } catch {
            NSLog("[VoiceInput] Engine start failed: \(error)")
            stopListening()
        }
    }

    func stopListening() {
        let finalText = partialTranscription

        if let engine = audioEngine, engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        partialTranscription = ""

        AudioSessionCoordinator.switchToPlayback()

        if !finalText.isEmpty {
            onTranscription?(finalText)
        }
    }
}
