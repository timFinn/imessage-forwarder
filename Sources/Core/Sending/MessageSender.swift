import Foundation
import Vapor

/// High-level message sending that determines whether to use individual or group sending.
public final class MessageSender: Sendable {
    private let bridge: AppleScriptBridge
    private let chatRepo: ChatRepository
    private let logger: Logger

    public init(bridge: AppleScriptBridge, chatRepo: ChatRepository, logger: Logger) {
        self.bridge = bridge
        self.chatRepo = chatRepo
        self.logger = logger
    }

    /// Send a message based on a SendMessageRequest.
    /// If chatId is provided, checks whether it's a group or individual chat.
    /// If address is provided, sends directly to that address.
    public func send(_ request: SendMessageRequest) async throws {
        if let address = request.address, request.chatId == nil {
            // Direct send to an address
            logger.info("Sending message to \(address)")
            try await bridge.sendToIndividual(
                address: address,
                text: request.text,
                service: request.service ?? "iMessage"
            )
            return
        }

        guard let chatId = request.chatId else {
            throw MessageSendError.noRecipient
        }

        // Look up the chat to determine group vs individual
        guard let chat = try chatRepo.fetchById(id: chatId) else {
            throw MessageSendError.chatNotFound(chatId)
        }

        if chat.isGroup {
            // Group chat: send via chat GUID
            logger.info("Sending group message to chat \(chat.guid)")
            try await bridge.sendToGroup(chatGuid: chat.guid, text: request.text)
        } else {
            // Individual chat: send to the first (only) participant
            guard let participant = chat.participants.first else {
                throw MessageSendError.noParticipants(chatId)
            }
            logger.info("Sending individual message to \(participant.address)")
            try await bridge.sendToIndividual(
                address: participant.address,
                text: request.text,
                service: request.service ?? chat.service ?? "iMessage"
            )
        }
    }
}

public enum MessageSendError: Error, LocalizedError {
    case noRecipient
    case chatNotFound(Int64)
    case noParticipants(Int64)

    public var errorDescription: String? {
        switch self {
        case .noRecipient:
            return "Either chatId or address must be provided"
        case .chatNotFound(let id):
            return "Chat with ID \(id) not found"
        case .noParticipants(let id):
            return "Chat \(id) has no participants"
        }
    }
}
