import Foundation
import Vapor
import Core

/// Manages WebSocket connections and broadcasts events to all connected clients.
public actor WebSocketManager {
    private var connections: [UUID: WebSocket] = [:]
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    /// Add a new WebSocket connection.
    public func add(_ ws: WebSocket, id: UUID) {
        connections[id] = ws
        logger.info("WebSocket connected: \(id). Total: \(connections.count)")
    }

    /// Remove a WebSocket connection.
    public func remove(id: UUID) {
        connections.removeValue(forKey: id)
        logger.info("WebSocket disconnected: \(id). Total: \(connections.count)")
    }

    /// Broadcast an event to all connected clients.
    public func broadcast(_ event: WebSocketEvent) {
        guard let data = try? JSONEncoder().encode(event),
              let text = String(data: data, encoding: .utf8) else {
            logger.error("Failed to encode WebSocket event")
            return
        }

        for (id, ws) in connections {
            ws.send(text, promise: nil)
            _ = id // suppress unused warning
        }
    }

    /// Send an event to a specific client.
    public func send(_ event: WebSocketEvent, to id: UUID) {
        guard let ws = connections[id] else { return }
        guard let data = try? JSONEncoder().encode(event),
              let text = String(data: data, encoding: .utf8) else { return }
        ws.send(text, promise: nil)
    }

    /// Current number of connections.
    public var connectionCount: Int {
        connections.count
    }
}
