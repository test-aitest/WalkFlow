import AVFoundation

enum AudioSessionCoordinator {
    static func switchToPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            NSLog("[WalkFlow] AudioSession playback error: \(error)")
        }
    }

    static func switchToRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [
                .defaultToSpeaker, .allowBluetooth
            ])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            NSLog("[WalkFlow] AudioSession recording error: \(error)")
        }
    }

    static func switchToVoiceRecognition() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [
                .defaultToSpeaker, .allowBluetooth
            ])
            try session.setActive(true)
        } catch {
            NSLog("[WalkFlow] AudioSession voiceRecognition error: \(error)")
        }
    }
}
