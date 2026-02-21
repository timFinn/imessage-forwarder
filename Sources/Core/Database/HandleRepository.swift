import Foundation
import GRDB

public final class HandleRepository: Sendable {
    private let db: ChatDatabase

    public init(db: ChatDatabase) {
        self.db = db
    }

    /// Fetch a handle by its ROWID.
    public func fetchById(id: Int64) throws -> HandleModel? {
        try db.dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT ROWID as id, id as address, service
                FROM handle
                WHERE ROWID = ?
                """, arguments: [id]) else {
                return nil
            }

            return HandleModel(
                id: row["id"],
                address: row["address"],
                service: row["service"]
            )
        }
    }

    /// Fetch a handle by address (phone number or email).
    public func fetchByAddress(_ address: String) throws -> HandleModel? {
        try db.dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT ROWID as id, id as address, service
                FROM handle
                WHERE id = ?
                """, arguments: [address]) else {
                return nil
            }

            return HandleModel(
                id: row["id"],
                address: row["address"],
                service: row["service"]
            )
        }
    }
}
