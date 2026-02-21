import Foundation
import GRDB

public final class ChatDatabase: Sendable {
    public let dbQueue: DatabaseQueue

    public init(path: String) throws {
        // Verify the file exists before attempting to open
        guard FileManager.default.fileExists(atPath: path) else {
            throw ChatDatabaseError.databaseNotFound(path: path)
        }

        // Check readability — if this fails, it's likely a Full Disk Access issue
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw ChatDatabaseError.fullDiskAccessRequired
        }

        var config = Configuration()
        config.readonly = true
        // WAL mode allows concurrent reads while Messages.app writes
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        do {
            dbQueue = try DatabaseQueue(path: path, configuration: config)
        } catch {
            // If we can see the file but can't open it, Full Disk Access is likely missing
            throw ChatDatabaseError.fullDiskAccessRequired
        }

        // Verify we can actually read from the database
        do {
            _ = try dbQueue.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM message")
            }
        } catch {
            throw ChatDatabaseError.fullDiskAccessRequired
        }
    }
}

public enum ChatDatabaseError: Error, LocalizedError {
    case databaseNotFound(path: String)
    case fullDiskAccessRequired

    public var errorDescription: String? {
        switch self {
        case .databaseNotFound(let path):
            return "chat.db not found at \(path). Make sure Messages.app has been used at least once."
        case .fullDiskAccessRequired:
            return """
            Cannot read chat.db. Full Disk Access is required.
            Grant it in System Settings > Privacy & Security > Full Disk Access for this application.
            """
        }
    }
}
