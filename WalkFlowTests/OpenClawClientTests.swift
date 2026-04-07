import XCTest
@testable import WalkFlow

final class OpenClawClientTests: XCTestCase {

    // MARK: - Message Construction Tests

    func testSendTaskConstructsCorrectRPC() throws {
        let request = RPCRequest(id: "test-id", method: "chat.send", params: ["text": "メールを送って"])

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["type"] as? String, "req")
        XCTAssertEqual(json["method"] as? String, "chat.send")
        let params = json["params"] as? [String: String]
        XCTAssertEqual(params?["text"], "メールを送って")
    }

    func testApproveActionConstructsCorrectRPC() throws {
        let request = RPCRequest(
            id: "test-id",
            method: "exec.approval.resolve",
            params: ["approvalId": "approval-123", "resolution": "allow-once"]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["method"] as? String, "exec.approval.resolve")
        let params = json["params"] as? [String: String]
        XCTAssertEqual(params?["approvalId"], "approval-123")
        XCTAssertEqual(params?["resolution"], "allow-once")
    }

    func testDenyActionConstructsCorrectRPC() throws {
        let request = RPCRequest(
            id: "test-id",
            method: "exec.approval.resolve",
            params: ["approvalId": "approval-456", "resolution": "deny"]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let params = json["params"] as? [String: String]
        XCTAssertEqual(params?["resolution"], "deny")
    }

    func testSteerSessionConstructsCorrectRPC() throws {
        let request = RPCRequest(
            id: "test-id",
            method: "sessions.steer",
            params: ["text": "件名を変えて"]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["method"] as? String, "sessions.steer")
        let params = json["params"] as? [String: String]
        XCTAssertEqual(params?["text"], "件名を変えて")
    }

    // MARK: - Event Parsing Tests

    func testParseApprovalRequestedEvent() throws {
        let json = """
        {"type":"event","event":"exec.approval.requested","payload":{"id":"a1","description":"Send email","command":"email.send"}}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(GatewayEvent.self, from: json)
        let approval = try XCTUnwrap(event.approvalRequest)
        XCTAssertEqual(approval.id, "a1")
        XCTAssertEqual(approval.description, "Send email")
    }

    func testParseSessionMessageEvent() throws {
        let json = """
        {"type":"event","event":"session.message","payload":{"role":"assistant","content":"完了しました"}}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(GatewayEvent.self, from: json)
        let message = try XCTUnwrap(event.sessionMessage)
        XCTAssertEqual(message.role, "assistant")
        XCTAssertEqual(message.content, "完了しました")
    }

    func testParseTickEvent() throws {
        let json = """
        {"type":"event","event":"tick","payload":{}}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(GatewayEvent.self, from: json)
        XCTAssertEqual(event.event, "tick")
        XCTAssertNil(event.approvalRequest)
        XCTAssertNil(event.sessionMessage)
    }

    // MARK: - Connection State Tests

    func testOpenClawClientInitialState() async {
        let client = OpenClawClient()
        let connected = await client.isConnected
        XCTAssertFalse(connected)
    }
}
