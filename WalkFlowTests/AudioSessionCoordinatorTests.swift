import XCTest
import AVFoundation
@testable import WalkFlow

final class AudioSessionCoordinatorTests: XCTestCase {

    func testSwitchToPlayback() {
        AudioSessionCoordinator.switchToPlayback()
        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .playback)
    }

    func testSwitchToRecording() {
        AudioSessionCoordinator.switchToRecording()
        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .playAndRecord)
    }

    func testSwitchToVoiceRecognition() {
        AudioSessionCoordinator.switchToVoiceRecognition()
        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .playAndRecord)
    }

    func testModeSwitchingDoesNotThrow() {
        AudioSessionCoordinator.switchToPlayback()
        AudioSessionCoordinator.switchToRecording()
        AudioSessionCoordinator.switchToVoiceRecognition()
        AudioSessionCoordinator.switchToPlayback()
        // If we reach here without crashing, the test passes
    }
}
