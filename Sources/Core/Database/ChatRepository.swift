import Foundation
import GRDB

public final class ChatRepository: Sendable {
    private let db: ChatDatabase

    public init(db: ChatDatabase) {
        self.db = db
    }

    /// Fetch all conversations sorted by most recent message, with pagination.
    public func fetchConversations(offset: Int = 0, limit: Int = 50) throws -> [ChatModel] {
        try db.dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    c.ROWID as id,
                    c.guid,
                    c.display_name,
                    c.service_name,
                    c.style,
                    (
                        SELECT MAX(m.ROWID)
                        FROM message m
                        INNER JOIN chat_message_join cmj2 ON cmj2.message_id = m.ROWID
                        WHERE cmj2.chat_id = c.ROWID
                    ) as last_message_id
                FROM chat c
                WHERE EXISTS (
                    SELECT 1 FROM chat_message_join cmj WHERE cmj.chat_id = c.ROWID
                )
                ORDER BY last_message_id DESC
                LIMIT ? OFFSET ?
                """, arguments: [limit, offset])

            return try rows.compactMap { row -> ChatModel? in
                let chatId: Int64 = row["id"]
                let participants = try self.fetchParticipants(chatId: chatId, db: db)
                let isGroup = participants.count > 1

                // Fetch last message
                var lastMessage: MessageModel? = nil
                if let lastMsgId: Int64 = row["last_message_id"] {
                    lastMessage = try self.fetchLastMessage(messageId: lastMsgId, chatId: chatId, db: db)
                }

                return ChatModel(
                    id: chatId,
                    guid: row["guid"],
                    displayName: row["display_name"],
                    participants: participants,
                    lastMessage: lastMessage,
                    isGroup: isGroup,
                    service: row["service_name"]
                )
            }
        }
    }

    /// Fetch a single chat by ID.
    public func fetchById(id: Int64) throws -> ChatModel? {
        try db.dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT
                    c.ROWID as id,
                    c.guid,
                    c.display_name,
                    c.service_name,
                    c.style
                FROM chat c
                WHERE c.ROWID = ?
                """, arguments: [id]) else {
                return nil
            }

            let participants = try self.fetchParticipants(chatId: id, db: db)
            return ChatModel(
                id: id,
                guid: row["guid"],
                displayName: row["display_name"],
                participants: participants,
                lastMessage: nil,
                isGroup: participants.count > 1,
                service: row["service_name"]
            )
        }
    }

    /// Fetch the chat GUID for a given chat ID.
    public func fetchGuid(chatId: Int64) throws -> String? {
        try db.dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT guid FROM chat WHERE ROWID = ?", arguments: [chatId])
        }
    }

    // MARK: - Private

    private func fetchParticipants(chatId: Int64, db: Database) throws -> [HandleModel] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT
                h.ROWID as id,
                h.id as address,
                h.service
            FROM handle h
            INNER JOIN chat_handle_join chj ON chj.handle_id = h.ROWID
            WHERE chj.chat_id = ?
            """, arguments: [chatId])

        return rows.map { row in
            HandleModel(
                id: row["id"],
                address: row["address"],
                service: row["service"]
            )
        }
    }

    private func fetchLastMessage(messageId: Int64, chatId: Int64, db: Database) throws -> MessageModel? {
        guard let row = try Row.fetchOne(db, sql: """
            SELECT
                m.ROWID as id,
                m.guid,
                m.text,
                m.handle_id,
                m.is_from_me,
                m.date,
                m.date_read,
                m.date_delivered,
                m.service,
                m.associated_message_type,
                m.associated_message_guid,
                m.item_type,
                m.group_title,
                m.attributedBody
            FROM message m
            WHERE m.ROWID = ?
            """, arguments: [messageId]) else {
            return nil
        }

        let rawText: String? = row["text"]
        let attributedBody: Data? = row["attributedBody"]
        let text = rawText ?? AttributedBodyParser.extractText(from: attributedBody)

        let rawDate: Int64 = row["date"] ?? 0
        let rawDateRead: Int64? = row["date_read"]
        let rawDateDelivered: Int64? = row["date_delivered"]

        return MessageModel(
            id: messageId,
            guid: row["guid"],
            text: text,
            chatId: chatId,
            handleId: row["handle_id"] ?? 0,
            isFromMe: (row["is_from_me"] as Int? ?? 0) != 0,
            date: DateTransformer.toUnixTimestamp(rawDate),
            dateRead: rawDateRead.flatMap { $0 != 0 ? DateTransformer.toUnixTimestamp($0) : nil },
            dateDelivered: rawDateDelivered.flatMap { $0 != 0 ? DateTransformer.toUnixTimestamp($0) : nil },
            service: row["service"],
            associatedMessageType: row["associated_message_type"] ?? 0,
            associatedMessageGuid: row["associated_message_guid"],
            itemType: row["item_type"] ?? 0,
            groupTitle: row["group_title"],
            attachments: nil
        )
    }
}
