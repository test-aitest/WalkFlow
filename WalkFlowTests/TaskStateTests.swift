import XCTest
@testable import WalkFlow

final class TaskStateTests: XCTestCase {
    func testInitialStateIsIdle() {
        let state = TaskState.idle
        XCTAssertEqual(state, .idle)
    }

    func testStatesAreDistinguishable() {
        let states: [TaskState] = [
            .idle,
            .listening,
            .sendingToAgent,
            .awaitingApproval(ApprovalRequest(id: "1", description: "test", command: "echo")),
            .listeningModification,
            .executing("sending email"),
            .taskComplete,
            .error("something went wrong")
        ]

        for i in states.indices {
            for j in states.indices where i != j {
                XCTAssertNotEqual(states[i], states[j], "\(states[i]) should not equal \(states[j])")
            }
        }
    }

    func testAwaitingApprovalHoldsAssociatedValue() {
        let request = ApprovalRequest(id: "req-123", description: "Send email to John", command: "email.send")
        let state = TaskState.awaitingApproval(request)

        if case .awaitingApproval(let r) = state {
            XCTAssertEqual(r.id, "req-123")
            XCTAssertEqual(r.description, "Send email to John")
            XCTAssertEqual(r.command, "email.send")
        } else {
            XCTFail("Expected awaitingApproval state")
        }
    }

    func testExecutingHoldsActionName() {
        let state = TaskState.executing("Slack message")
        if case .executing(let name) = state {
            XCTAssertEqual(name, "Slack message")
        } else {
            XCTFail("Expected executing state")
        }
    }

    func testErrorHoldsMessage() {
        let state = TaskState.error("Connection failed")
        if case .error(let msg) = state {
            XCTAssertEqual(msg, "Connection failed")
        } else {
            XCTFail("Expected error state")
        }
    }
}
