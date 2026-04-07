import XCTest
@testable import WalkFlow

@MainActor
final class TaskOrchestratorTests: XCTestCase {

    func testInitialStateIsIdle() {
        let orchestrator = TaskOrchestrator()
        XCTAssertEqual(orchestrator.state, .idle)
    }

    func testSingleTapFromIdleStartsListening() {
        let orchestrator = TaskOrchestrator()
        orchestrator.handleSingleTap()
        XCTAssertEqual(orchestrator.state, .listening)
    }

    func testSingleTapFromListeningWithNoTextReturnsToIdle() {
        let orchestrator = TaskOrchestrator()
        orchestrator.handleSingleTap() // → listening
        orchestrator.handleSingleTap() // → idle (no text)
        XCTAssertEqual(orchestrator.state, .idle)
    }

    func testSingleTapFromListeningWithTextSendsToAgent() {
        let orchestrator = TaskOrchestrator()
        orchestrator.handleSingleTap() // → listening
        orchestrator.simulatePartialTranscription("メールを送って")
        orchestrator.handleSingleTap() // → sendingToAgent
        XCTAssertEqual(orchestrator.state, .sendingToAgent)
    }

    func testApprovalRequestedTransitionsToAwaitingApproval() {
        let orchestrator = TaskOrchestrator()
        orchestrator.state = .sendingToAgent
        let request = ApprovalRequest(id: "a1", description: "Send email", command: "email.send")
        orchestrator.handleApprovalRequested(request)
        XCTAssertEqual(orchestrator.state, .awaitingApproval(request))
    }

    func testNodFromAwaitingApprovalTransitionsToExecuting() {
        let orchestrator = TaskOrchestrator()
        let request = ApprovalRequest(id: "a1", description: "Send email", command: "email.send")
        orchestrator.state = .awaitingApproval(request)
        orchestrator.handleNod()
        XCTAssertEqual(orchestrator.state, .executing("Send email"))
    }

    func testShakeFromAwaitingApprovalTransitionsToListeningModification() {
        let orchestrator = TaskOrchestrator()
        let request = ApprovalRequest(id: "a1", description: "Send email", command: "email.send")
        orchestrator.state = .awaitingApproval(request)
        orchestrator.handleShake()
        XCTAssertEqual(orchestrator.state, .listeningModification)
    }

    func testSingleTapFromListeningModificationSendsSteer() {
        let orchestrator = TaskOrchestrator()
        orchestrator.state = .listeningModification
        orchestrator.simulatePartialTranscription("件名を変えて")
        orchestrator.handleSingleTap() // → sendingToAgent (steer)
        XCTAssertEqual(orchestrator.state, .sendingToAgent)
    }

    func testTaskCompleteTransition() {
        let orchestrator = TaskOrchestrator()
        orchestrator.state = .executing("Send email")
        orchestrator.handleTaskComplete()
        XCTAssertEqual(orchestrator.state, .taskComplete)
    }

    func testNodFromIdleIsIgnored() {
        let orchestrator = TaskOrchestrator()
        orchestrator.handleNod()
        XCTAssertEqual(orchestrator.state, .idle)
    }

    func testShakeFromIdleIsIgnored() {
        let orchestrator = TaskOrchestrator()
        orchestrator.handleShake()
        XCTAssertEqual(orchestrator.state, .idle)
    }

    func testNodFromListeningIsIgnored() {
        let orchestrator = TaskOrchestrator()
        orchestrator.state = .listening
        orchestrator.handleNod()
        XCTAssertEqual(orchestrator.state, .listening)
    }

    func testShakeFromListeningIsIgnored() {
        let orchestrator = TaskOrchestrator()
        orchestrator.state = .listening
        orchestrator.handleShake()
        XCTAssertEqual(orchestrator.state, .listening)
    }
}
