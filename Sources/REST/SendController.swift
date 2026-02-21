import Vapor
import Core

public struct SendController: RouteCollection {
    private let sender: MessageSender

    public init(sender: MessageSender) {
        self.sender = sender
    }

    public func boot(routes: any RoutesBuilder) throws {
        routes.post("api", "send", use: send)
    }

    /// POST /api/send
    /// Body: { "chatId": 123, "text": "Hello" } or { "address": "+1234567890", "text": "Hello" }
    private func send(req: Request) async throws -> Response {
        let request = try req.content.decode(SendMessageRequest.self)

        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Message text cannot be empty")
        }

        guard request.chatId != nil || request.address != nil else {
            throw Abort(.badRequest, reason: "Either chatId or address must be provided")
        }

        try await sender.send(request)

        let response = Response(status: .ok)
        try response.content.encode(["status": "sent"], as: .json)
        return response
    }
}
