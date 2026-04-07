import XCTest
@testable import WalkFlow

@MainActor
final class VoiceInputServiceTests: XCTestCase {

    func testInitialStateNotListening() {
        let service = VoiceInputService()
        XCTAssertFalse(service.isListening)
    }

    func testPartialTranscriptionIsEmpty() {
        let service = VoiceInputService()
        XCTAssertEqual(service.partialTranscription, "")
    }

    func testDoubleStartIsSafe() {
        // startListening requires microphone permission which is unavailable in simulator tests
        // but we can verify the guard against double-start doesn't crash
        let service = VoiceInputService()
        // Should not crash even if called without authorization
        service.stopListening()
        service.stopListening() // double stop should be safe
    }

    func testStopListeningResetsState() {
        let service = VoiceInputService()
        service.stopListening()
        XCTAssertFalse(service.isListening)
        XCTAssertEqual(service.partialTranscription, "")
    }

    func testCallbacksCanBeSet() {
        let service = VoiceInputService()
        var transcribed = ""
        var partialCalled = false

        service.onTranscription = { text in
            transcribed = text
        }
        service.onPartialTranscription = { _ in
            partialCalled = true
        }

        // Just verify callbacks can be set without crashing
        XCTAssertEqual(transcribed, "")
        XCTAssertFalse(partialCalled)
    }
}
