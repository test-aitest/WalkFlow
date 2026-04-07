import Foundation

// MARK: - RPC Request (Client → Server)

struct RPCRequest: Codable, Sendable {
    let type: String
    let id: String
    let method: String
    let params: [String: String]

    init(id: String = UUID().uuidString, method: String, params: [String: String] = [:]) {
        self.type = "req"
        self.id = id
        self.method = method
        self.params = params
    }
}

// MARK: - RPC Response (Server → Client)

struct RPCResponse: Codable, Sendable {
    let type: String
    let id: String
    let ok: Bool
    let payload: ResponsePayload?
    let error: ResponseError?

    struct ResponsePayload: Codable, Sendable {
        let sessionId: String?
        let status: String?
        let deviceToken: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
            self.status = try container.decodeIfPresent(String.self, forKey: .status)
            self.deviceToken = try container.decodeIfPresent(String.self, forKey: .deviceToken)
        }

        private enum CodingKeys: String, CodingKey {
            case sessionId, status, deviceToken
        }
    }

    struct ResponseError: Codable, Sendable {
        let type: String
        let message: String
    }
}

// MARK: - Gateway Event (Server → Client push)

struct GatewayEvent: Codable, Sendable {
    let type: String
    let event: String
    let payload: EventPayload

    struct EventPayload: Codable, Sendable {
        // Approval request fields
        let id: String?
        let description: String?
        let command: String?

        // Session message fields
        let role: String?
        let content: String?
    }

    var approvalRequest: ApprovalRequest? {
        guard event == "exec.approval.requested",
              let id = payload.id,
              let description = payload.description,
              let command = payload.command else {
            return nil
        }
        return ApprovalRequest(id: id, description: description, command: command)
    }

    var sessionMessage: SessionMessage? {
        guard event == "session.message",
              let role = payload.role,
              let content = payload.content else {
            return nil
        }
        return SessionMessage(role: role, content: content)
    }
}

// MARK: - Session Message

struct SessionMessage: Equatable, Sendable {
    let role: String
    let content: String
}

// MARK: - Connect Params (Client → Server handshake)

struct ConnectParams: Codable, Sendable {
    let role: String
    let auth: Auth
    let caps: [String]

    struct Auth: Codable, Sendable {
        let token: String
    }

    init(token: String, capabilities: [String] = ["voice"]) {
        self.role = "node"
        self.auth = Auth(token: token)
        self.caps = capabilities
    }
}
