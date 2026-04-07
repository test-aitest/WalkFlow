import Foundation

actor OpenClawClient {
    private(set) var isConnected = false
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var eventContinuation: AsyncStream<GatewayEvent>.Continuation?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var host: String = ""
    private var token: String = ""

    lazy var events: AsyncStream<GatewayEvent> = {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }()

    func connect(host: String, token: String) async throws {
        self.host = host
        self.token = token
        try await establishConnection()
    }

    func disconnect() {
        NSLog("[OpenClaw] Disconnecting")
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        eventContinuation?.finish()
    }

    func sendTask(_ text: String) async throws {
        let request = RPCRequest(method: "chat.send", params: ["text": text])
        try await send(request)
    }

    func approveAction(_ approvalId: String) async throws {
        let request = RPCRequest(
            method: "exec.approval.resolve",
            params: ["approvalId": approvalId, "resolution": "allow-once"]
        )
        try await send(request)
    }

    func denyAction(_ approvalId: String) async throws {
        let request = RPCRequest(
            method: "exec.approval.resolve",
            params: ["approvalId": approvalId, "resolution": "deny"]
        )
        try await send(request)
    }

    func steerSession(_ modification: String) async throws {
        let request = RPCRequest(method: "sessions.steer", params: ["text": modification])
        try await send(request)
    }

    // MARK: - Private

    private func establishConnection() async throws {
        guard let url = URL(string: host) else {
            NSLog("[OpenClaw] Invalid URL: \(host)")
            throw OpenClawError.invalidURL
        }

        NSLog("[OpenClaw] Connecting to \(url.absoluteString)")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)
        self.urlSession = session

        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let task = session.webSocketTask(with: urlRequest)
        self.webSocketTask = task
        task.resume()

        // Start receiving messages
        receiveMessages()

        // Wait for challenge, then send connect with password auth
        try await Task.sleep(for: .seconds(1))
        try await sendAuth()
    }

    private func sendAuth() async throws {
        // OpenClaw Gateway expects auth via connect frame with token
        let connectMessage: [String: Any] = [
            "type": "req",
            "id": UUID().uuidString,
            "method": "connect",
            "params": [
                "minProtocol": 3,
                "maxProtocol": 3,
                "client": [
                    "id": "cli",
                    "version": "1.0.0",
                    "platform": "ios",
                    "mode": "cli"
                ],
                "role": "operator",
                "scopes": ["operator.admin", "operator.approvals", "operator.pairing", "operator.read", "operator.talk.secrets", "operator.write"],
                "auth": [
                    "token": token,
                    "password": token
                ]
            ] as [String: Any]
        ]

        let data = try JSONSerialization.data(withJSONObject: connectMessage)
        guard let text = String(data: data, encoding: .utf8) else {
            throw OpenClawError.encodingFailed
        }

        NSLog("[OpenClaw] Sending auth connect frame")
        try await webSocketTask?.send(.string(text))

        // Wait briefly for hello-ok response
        try await Task.sleep(for: .seconds(2))

        if isConnected {
            NSLog("[OpenClaw] Authenticated successfully")
        } else {
            NSLog("[OpenClaw] Auth may still be pending, continuing...")
            // Still mark as connected to allow message flow
            isConnected = true
        }
    }

    private func receiveMessages() {
        guard let task = webSocketTask else { return }

        Task { [weak self] in
            while let self = self {
                do {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        NSLog("[OpenClaw] Received: \(String(text.prefix(300)))")
                        await self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            NSLog("[OpenClaw] Received data: \(String(text.prefix(300)))")
                            await self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    NSLog("[OpenClaw] Receive error: \(error)")
                    await self.handleDisconnect()
                    break
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        // Check for hello-ok response (successful auth)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let type = json["type"] as? String

            if type == "res" {
                let ok = json["ok"] as? Bool ?? false
                if ok {
                    isConnected = true
                    let payload = json["payload"] as? [String: Any]
                    let auth = payload?["auth"] as? [String: Any]
                    let scopes = auth?["scopes"] as? [String]
                    let role = auth?["role"] as? String
                    NSLog("[OpenClaw] Connected! role=\(role ?? "nil") scopes=\(scopes ?? [])")
                } else {
                    let error = json["error"] as? [String: Any]
                    NSLog("[OpenClaw] Auth error: \(error ?? [:])")
                }
                return
            }

            if type == "event" {
                let eventName = json["event"] as? String ?? ""
                // Handle challenge event
                if eventName == "connect.challenge" {
                    NSLog("[OpenClaw] Received challenge, auth pending")
                    return
                }
            }
        }

        // Parse as GatewayEvent
        if let event = try? JSONDecoder().decode(GatewayEvent.self, from: data) {
            eventContinuation?.yield(event)
        }
    }

    private func handleDisconnect() {
        isConnected = false
        webSocketTask = nil

        guard reconnectAttempts < maxReconnectAttempts else {
            NSLog("[OpenClaw] Max reconnect attempts reached")
            return
        }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        NSLog("[OpenClaw] Reconnecting in \(delay)s (attempt \(reconnectAttempts))")

        Task {
            try? await Task.sleep(for: .seconds(delay))
            try? await establishConnection()
        }
    }

    private func send(_ request: RPCRequest) async throws {
        guard let task = webSocketTask, isConnected else {
            NSLog("[OpenClaw] Cannot send - not connected")
            throw OpenClawError.notConnected
        }

        let data = try JSONEncoder().encode(request)
        guard let text = String(data: data, encoding: .utf8) else {
            throw OpenClawError.encodingFailed
        }

        NSLog("[OpenClaw] Sending: \(text)")
        try await task.send(.string(text))
    }
}

enum OpenClawError: Error {
    case invalidURL
    case notConnected
    case encodingFailed
}
