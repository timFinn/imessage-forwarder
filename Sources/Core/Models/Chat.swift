import Foundation

public struct ChatModel: Codable, Sendable, Identifiable {
    public let id: Int64
    public let guid: String
    public let displayName: String?
    public let participants: [HandleModel]
    public let lastMessage: MessageModel?
    public let isGroup: Bool
    public let service: String?

    public init(
        id: Int64,
        guid: String,
        displayName: String?,
        participants: [HandleModel],
        lastMessage: MessageModel?,
        isGroup: Bool,
        service: String?
    ) {
        self.id = id
        self.guid = guid
        self.displayName = displayName
        self.participants = participants
        self.lastMessage = lastMessage
        self.isGroup = isGroup
        self.service = service
    }
}
