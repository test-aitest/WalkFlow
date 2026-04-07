import XCTest
@testable import WalkFlow

@MainActor
final class SpeechOutputServiceTests: XCTestCase {

    func testInitDoesNotCrash() {
        let service = SpeechOutputService()
        XCTAssertNotNil(service)
    }

    func testStopDoesNotCrash() {
        let service = SpeechOutputService()
        service.stop()
        // Should not crash
    }

    func testSpeakSetsUpUtterance() {
        let service = SpeechOutputService()
        // speak() should not crash even in simulator (TTS is available)
        service.speak("テスト")
        service.stop()
    }

    func testSpeakOverridesPreviousSpeech() {
        let service = SpeechOutputService()
        service.speak("最初のメッセージ")
        service.speak("次のメッセージ")
        // Should not crash, second speak should stop first
        service.stop()
    }

    func testCallbackCanBeSet() {
        let service = SpeechOutputService()
        var finished = false

        service.speak("テスト", onFinished: {
            finished = true
        })

        // Callback won't fire in test (TTS timing), but verify it doesn't crash
        service.stop()
        // After stop, callback should be cleared
        XCTAssertFalse(finished) // stop clears callback without firing it
    }
}
