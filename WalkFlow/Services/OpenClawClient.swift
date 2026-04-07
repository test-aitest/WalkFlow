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
        config.timeoutIntervalForResource = 300
        let session = URLSession(configuration: config)
        self.urlSession = session

        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 30

        let task = session.webSocketTask(with: urlRequest)
        self.webSocketTask = task
        task.resume()

        // Wait for connection to actually establish by doing a ping
        do {
            try await task.sendPing()
            isConnected = true
            reconnectAttempts = 0
            NSLog("[OpenClaw] Connected successfully")
            receiveMessages()
        } catch {
            NSLog("[OpenClaw] Connection failed: \(error)")
            isConnected = false
            throw error
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
                        NSLog("[OpenClaw] Received: \(String(text.prefix(200)))")
                        await self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            NSLog("[OpenClaw] Received data: \(String(text.prefix(200)))")
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
