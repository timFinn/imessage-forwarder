import Foundation

public struct WebSocketEvent: Codable, Sendable {
    public let type: EventType
    public let data: EventData?
    public let error: String?

    public init(type: EventType, data: EventData? = nil, error: String? = nil) {
        self.type = type
        self.data = data
        self.error = error
    }

    public enum EventType: String, Codable, Sendable {
        case connected
        case newMessage
        case sendMessage
        case messageSent
        case sendMessageError
        case error
    }

    public enum EventData: Codable, Sendable {
        case message(MessageModel)
        case sendRequest(SendMessageRequest)
        case empty

        enum CodingKeys: String, CodingKey {
            case message
            case sendRequest
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .message(let msg):
                try container.encode(msg)
            case .sendRequest(let req):
                try container.encode(req)
            case .empty:
                try container.encodeNil()
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let msg = try? container.decode(MessageModel.self) {
                self = .message(msg)
            } else if let req = try? container.decode(SendMessageRequest.self) {
                self = .sendRequest(req)
            } else {
                self = .empty
            }
        }
    }
}

public struct SendMessageRequest: Codable, Sendable {
    public let chatId: Int64?
    public let address: String?
    public let text: String
    public let service: String?

    public init(chatId: Int64? = nil, address: String? = nil, text: String, service: String? = nil) {
        self.chatId = chatId
        self.address = address
        self.text = text
        self.service = service
    }
}
