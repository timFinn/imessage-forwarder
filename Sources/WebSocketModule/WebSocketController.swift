import Foundation
import Vapor
import Core

/// Handles WebSocket upgrade requests and message routing.
public struct WebSocketController: Sendable {
    private let manager: WebSocketManager
    private let sender: MessageSender
    private let authToken: String
    private let logger: Logger

    public init(manager: WebSocketManager, sender: MessageSender, authToken: String, logger: Logger) {
        self.manager = manager
        self.sender = sender
        self.authToken = authToken
        self.logger = logger
    }

    /// Register the WebSocket route.
    public func register(with app: Application) {
        app.webSocket("ws") { req, ws in
            await self.handleUpgrade(req: req, ws: ws)
        }
    }

    private func handleUpgrade(req: Request, ws: WebSocket) async {
        // Validate auth token from query parameter
        guard let token = req.query[String.self, at: "token"],
              token == authToken else {
            logger.warning("WebSocket connection rejected: invalid token")
            let event = WebSocketEvent(type: .error, error: "Invalid authentication token")
            if let data = try? JSONEncoder().encode(event),
               let text = String(data: data, encoding: .utf8) {
                ws.send(text, promise: nil)
            }
            try? await ws.close()
            return
        }

        let connectionId = UUID()
        await manager.add(ws, id: connectionId)

        // Send connection acknowledgment
        let connectedEvent = WebSocketEvent(type: .connected)
        await manager.send(connectedEvent, to: connectionId)

        // Handle incoming messages
        ws.onText { ws, text in
            await self.handleMessage(text, from: connectionId)
        }

        // Handle disconnect
        ws.onClose.whenComplete { _ in
            Task {
                await self.manager.remove(id: connectionId)
            }
        }
    }

    private func handleMessage(_ text: String, from connectionId: UUID) async {
        guard let data = text.data(using: .utf8),
              let event = try? JSONDecoder().decode(WebSocketEvent.self, from: data) else {
            let errorEvent = WebSocketEvent(type: .error, error: "Invalid message format")
            await manager.send(errorEvent, to: connectionId)
            return
        }

        switch event.type {
        case .sendMessage:
            guard case .sendRequest(let request) = event.data else {
                let errorEvent = WebSocketEvent(type: .sendMessageError, error: "Invalid send request")
                await manager.send(errorEvent, to: connectionId)
                return
            }

            do {
                try await sender.send(request)
                let successEvent = WebSocketEvent(type: .messageSent)
                await manager.send(successEvent, to: connectionId)
            } catch {
                let errorEvent = WebSocketEvent(type: .sendMessageError, error: error.localizedDescription)
                await manager.send(errorEvent, to: connectionId)
            }

        default:
            let errorEvent = WebSocketEvent(type: .error, error: "Unsupported event type: \(event.type.rawValue)")
            await manager.send(errorEvent, to: connectionId)
        }
    }
}
