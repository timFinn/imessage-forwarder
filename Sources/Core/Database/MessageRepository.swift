import Foundation
import GRDB

public final class MessageRepository: Sendable {
    private let db: ChatDatabase

    public init(db: ChatDatabase) {
        self.db = db
    }

    /// Fetch messages with ROWID greater than the given watermark.
    /// Used by the poller to detect new messages.
    public func fetchSince(rowId: Int64) throws -> [MessageModel] {
        try db.dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    m.ROWID as id,
                    m.guid,
                    m.text,
                    cmj.chat_id,
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
                LEFT JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
                WHERE m.ROWID > ?
                ORDER BY m.ROWID ASC
                """, arguments: [rowId])

            return try rows.map { row in
                try self.messageFromRow(row, db: db)
            }
        }
    }

    /// Fetch messages for a specific chat, with cursor-based pagination.
    /// `before` is a ROWID — fetch messages with ROWID < before.
    public func fetchByChat(chatId: Int64, before: Int64? = nil, limit: Int = 50) throws -> [MessageModel] {
        try db.dbQueue.read { db in
            var sql = """
                SELECT
                    m.ROWID as id,
                    m.guid,
                    m.text,
                    cmj.chat_id,
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
                INNER JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
                WHERE cmj.chat_id = ?
                """
            var arguments: [DatabaseValueConvertible] = [chatId]

            if let before = before {
                sql += " AND m.ROWID < ?"
                arguments.append(before)
            }

            sql += " ORDER BY m.ROWID DESC LIMIT ?"
            arguments.append(limit)

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return try rows.map { row in
                try self.messageFromRow(row, db: db)
            }.reversed() // Return in chronological order
        }
    }

    /// Get the current maximum ROWID in the message table.
    public func maxRowId() throws -> Int64 {
        try db.dbQueue.read { db in
            try Int64.fetchOne(db, sql: "SELECT MAX(ROWID) FROM message") ?? 0
        }
    }

    /// Fetch a single message by ROWID.
    public func fetchById(id: Int64) throws -> MessageModel? {
        try db.dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT
                    m.ROWID as id,
                    m.guid,
                    m.text,
                    cmj.chat_id,
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
                LEFT JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
                WHERE m.ROWID = ?
                """, arguments: [id]) else {
                return nil
            }
            return try self.messageFromRow(row, db: db)
        }
    }

    // MARK: - Private

    private func messageFromRow(_ row: Row, db: Database) throws -> MessageModel {
        let id: Int64 = row["id"]
        let rawText: String? = row["text"]
        let attributedBody: Data? = row["attributedBody"]

        // Resolve text: prefer `text` column, fall back to attributedBody decoding
        let text = rawText ?? AttributedBodyParser.extractText(from: attributedBody)

        // Fetch attachments for this message
        let attachments = try AttachmentRepository.fetchForMessage(messageId: id, db: db)

        let rawDate: Int64 = row["date"] ?? 0
        let rawDateRead: Int64? = row["date_read"]
        let rawDateDelivered: Int64? = row["date_delivered"]

        return MessageModel(
            id: id,
            guid: row["guid"],
            text: text,
            chatId: row["chat_id"],
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
            attachments: attachments.isEmpty ? nil : attachments
        )
    }
}
