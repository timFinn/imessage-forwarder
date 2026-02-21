import Vapor
import Core

public struct MessageController: RouteCollection {
    private let messageRepo: MessageRepository

    public init(messageRepo: MessageRepository) {
        self.messageRepo = messageRepo
    }

    public func boot(routes: any RoutesBuilder) throws {
        let messages = routes.grouped("api", "conversations", ":chatId", "messages")
        messages.get(use: list)
    }

    /// GET /api/conversations/:chatId/messages?before=&limit=50
    /// Cursor-paginated: `before` is a ROWID, returns messages older than that.
    private func list(req: Request) async throws -> Response {
        guard let chatIdStr = req.parameters.get("chatId"),
              let chatId = Int64(chatIdStr) else {
            throw Abort(.badRequest, reason: "Invalid chat ID")
        }

        let before = try? req.query.get(Int64.self, at: "before")
        let limit = min((try? req.query.get(Int.self, at: "limit")) ?? 50, 100)

        let messages = try messageRepo.fetchByChat(chatId: chatId, before: before, limit: limit)

        let response = Response(status: .ok)
        try response.content.encode(messages, as: .json)
        return response
    }
}
