import XCTest
@testable import WalkFlow

final class OpenClawMessageTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - RPCRequest

    func testRPCRequestEncoding() throws {
        let request = RPCRequest(
            id: "test-uuid",
            method: "chat.send",
            params: ["text": "メールを送って"]
        )

        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["type"] as? String, "req")
        XCTAssertEqual(json["id"] as? String, "test-uuid")
        XCTAssertEqual(json["method"] as? String, "chat.send")

        let params = json["params"] as? [String: Any]
        XCTAssertEqual(params?["text"] as? String, "メールを送って")
    }

    // MARK: - RPCResponse

    func testRPCResponseDecodingSuccess() throws {
        let json = """
        {"type":"res","id":"abc-123","ok":true,"payload":{"sessionId":"sess-1","status":"active"}}
        """.data(using: .utf8)!

        let response = try decoder.decode(RPCResponse.self, from: json)
        XCTAssertEqual(response.id, "abc-123")
        XCTAssertTrue(response.ok)
        XCTAssertNotNil(response.payload)
        XCTAssertNil(response.error)
    }

    func testRPCResponseDecodingError() throws {
        let json = """
        {"type":"res","id":"abc-456","ok":false,"error":{"type":"AUTH_FAILED","message":"Invalid token"}}
        """.data(using: .utf8)!

        let response = try decoder.decode(RPCResponse.self, from: json)
        XCTAssertEqual(response.id, "abc-456")
        XCTAssertFalse(response.ok)
        XCTAssertNil(response.payload)
        XCTAssertEqual(response.error?.type, "AUTH_FAILED")
        XCTAssertEqual(response.error?.message, "Invalid token")
    }

    // MARK: - GatewayEvent

    func testGatewayEventDecodingApprovalRequested() throws {
        let json = """
        {
            "type": "event",
            "event": "exec.approval.requested",
            "payload": {
                "id": "approval-789",
                "description": "Send email to user@example.com",
                "command": "email.send"
            }
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(GatewayEvent.self, from: json)
        XCTAssertEqual(event.event, "exec.approval.requested")

        let approval = try XCTUnwrap(event.approvalRequest)
        XCTAssertEqual(approval.id, "approval-789")
        XCTAssertEqual(approval.description, "Send email to user@example.com")
        XCTAssertEqual(approval.command, "email.send")
    }

    func testGatewayEventDecodingSessionMessage() throws {
        let json = """
        {
            "type": "event",
            "event": "session.message",
            "payload": {
                "role": "assistant",
                "content": "メールを送信しました。"
            }
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(GatewayEvent.self, from: json)
        XCTAssertEqual(event.event, "session.message")

        let message = try XCTUnwrap(event.sessionMessage)
        XCTAssertEqual(message.role, "assistant")
        XCTAssertEqual(message.content, "メールを送信しました。")
    }

    // MARK: - ConnectParams

    func testConnectParamsEncoding() throws {
        let params = ConnectParams(
            token: "my-gateway-token",
            capabilities: ["voice", "location"]
        )

        let data = try encoder.encode(params)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["role"] as? String, "node")

        let auth = json["auth"] as? [String: Any]
        XCTAssertEqual(auth?["token"] as? String, "my-gateway-token")

        let caps = json["caps"] as? [String]
        XCTAssertEqual(caps, ["voice", "location"])
    }
}
