import Foundation
import GRDB

public final class AttachmentRepository: Sendable {
    private let db: ChatDatabase

    public init(db: ChatDatabase) {
        self.db = db
    }

    /// Fetch an attachment by its ROWID.
    public func fetchById(id: Int64) throws -> AttachmentModel? {
        try db.dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT
                    ROWID as id,
                    guid,
                    filename,
                    mime_type,
                    transfer_name,
                    total_bytes
                FROM attachment
                WHERE ROWID = ?
                """, arguments: [id]) else {
                return nil
            }

            return AttachmentModel(
                id: row["id"],
                guid: row["guid"],
                filename: row["filename"],
                mimeType: row["mime_type"],
                transferName: row["transfer_name"],
                totalBytes: row["total_bytes"] ?? 0
            )
        }
    }

    /// Fetch attachments for a message (used internally by MessageRepository).
    static func fetchForMessage(messageId: Int64, db: Database) throws -> [AttachmentModel] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT
                a.ROWID as id,
                a.guid,
                a.filename,
                a.mime_type,
                a.transfer_name,
                a.total_bytes
            FROM attachment a
            INNER JOIN message_attachment_join maj ON maj.attachment_id = a.ROWID
            WHERE maj.message_id = ?
            ORDER BY a.ROWID ASC
            """, arguments: [messageId])

        return rows.map { row in
            AttachmentModel(
                id: row["id"],
                guid: row["guid"],
                filename: row["filename"],
                mimeType: row["mime_type"],
                transferName: row["transfer_name"],
                totalBytes: row["total_bytes"] ?? 0
            )
        }
    }
}
