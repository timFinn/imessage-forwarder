import Foundation

public struct MessageModel: Codable, Sendable, Identifiable {
    public let id: Int64
    public let guid: String
    public let text: String?
    public let chatId: Int64?
    public let handleId: Int64
    public let isFromMe: Bool
    public let date: TimeInterval  // Unix timestamp
    public let dateRead: TimeInterval?
    public let dateDelivered: TimeInterval?
    public let service: String?
    public let associatedMessageType: Int
    public let associatedMessageGuid: String?
    public let itemType: Int
    public let groupTitle: String?
    public let attachments: [AttachmentModel]?

    public init(
        id: Int64,
        guid: String,
        text: String?,
        chatId: Int64?,
        handleId: Int64,
        isFromMe: Bool,
        date: TimeInterval,
        dateRead: TimeInterval?,
        dateDelivered: TimeInterval?,
        service: String?,
        associatedMessageType: Int,
        associatedMessageGuid: String?,
        itemType: Int,
        groupTitle: String?,
        attachments: [AttachmentModel]?
    ) {
        self.id = id
        self.guid = guid
        self.text = text
        self.chatId = chatId
        self.handleId = handleId
        self.isFromMe = isFromMe
        self.date = date
        self.dateRead = dateRead
        self.dateDelivered = dateDelivered
        self.service = service
        self.associatedMessageType = associatedMessageType
        self.associatedMessageGuid = associatedMessageGuid
        self.itemType = itemType
        self.groupTitle = groupTitle
        self.attachments = attachments
    }

    /// Whether this is a regular text message (not a tapback, group event, etc.)
    public var isRegularMessage: Bool {
        associatedMessageType == 0 && itemType == 0
    }

    /// Whether this is a tapback/reaction (associated_message_type 2000-2005)
    public var isTapback: Bool {
        (2000...2005).contains(associatedMessageType)
    }

    /// Whether this is a group event (item_type == 1)
    public var isGroupEvent: Bool {
        itemType == 1
    }

    /// Human-readable tapback description
    public var tapbackDescription: String? {
        switch associatedMessageType {
        case 2000: return "loved"
        case 2001: return "liked"
        case 2002: return "disliked"
        case 2003: return "laughed at"
        case 2004: return "emphasized"
        case 2005: return "questioned"
        default: return nil
        }
    }
}
