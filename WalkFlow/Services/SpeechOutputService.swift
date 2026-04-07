import AVFoundation

@MainActor
final class SpeechOutputService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var onFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, onFinished: (() -> Void)? = nil) {
        synthesizer.stopSpeaking(at: .immediate)
        self.onFinished = onFinished

        AudioSessionCoordinator.switchToPlayback()

        let utterance = AVSpeechUtterance(string: text)
        if let voice = AVSpeechSynthesisVoice(language: "ja-JP") {
            utterance.voice = voice
        }
        utterance.rate = 0.45
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        onFinished = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onFinished?()
            self?.onFinished = nil
        }
    }
}
