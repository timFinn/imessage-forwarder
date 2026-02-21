import Vapor
import Core

public struct ConversationController: RouteCollection {
    private let chatRepo: ChatRepository

    public init(chatRepo: ChatRepository) {
        self.chatRepo = chatRepo
    }

    public func boot(routes: any RoutesBuilder) throws {
        let conversations = routes.grouped("api", "conversations")
        conversations.get(use: list)
        conversations.get(":id", use: getById)
    }

    /// GET /api/conversations?offset=0&limit=50
    private func list(req: Request) async throws -> Response {
        let offset = (try? req.query.get(Int.self, at: "offset")) ?? 0
        let limit = min((try? req.query.get(Int.self, at: "limit")) ?? 50, 100)

        let conversations = try chatRepo.fetchConversations(offset: offset, limit: limit)

        let response = Response(status: .ok)
        try response.content.encode(conversations, as: .json)
        return response
    }

    /// GET /api/conversations/:id
    private func getById(req: Request) async throws -> Response {
        guard let idStr = req.parameters.get("id"),
              let id = Int64(idStr) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID")
        }

        guard let chat = try chatRepo.fetchById(id: id) else {
            throw Abort(.notFound, reason: "Conversation not found")
        }

        let response = Response(status: .ok)
        try response.content.encode(chat, as: .json)
        return response
    }
}
