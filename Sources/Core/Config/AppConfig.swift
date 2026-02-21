import Foundation

public struct AppConfig: Sendable {
    public let authToken: String
    public let port: Int
    public let pollInterval: TimeInterval
    public let chatDbPath: String

    public init(
        authToken: String? = nil,
        port: Int? = nil,
        pollInterval: TimeInterval? = nil,
        chatDbPath: String? = nil
    ) {
        guard let token = authToken ?? ProcessInfo.processInfo.environment["IMESSAGE_AUTH_TOKEN"],
              !token.isEmpty else {
            fatalError("IMESSAGE_AUTH_TOKEN environment variable is required")
        }
        self.authToken = token

        if let portStr = ProcessInfo.processInfo.environment["IMESSAGE_PORT"],
           let envPort = Int(portStr) {
            self.port = port ?? envPort
        } else {
            self.port = port ?? 8080
        }

        if let intervalStr = ProcessInfo.processInfo.environment["IMESSAGE_POLL_INTERVAL"],
           let envInterval = TimeInterval(intervalStr) {
            self.pollInterval = pollInterval ?? envInterval
        } else {
            self.pollInterval = pollInterval ?? 1.5
        }

        let defaultPath = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Messages/chat.db")
        self.chatDbPath = chatDbPath
            ?? ProcessInfo.processInfo.environment["IMESSAGE_CHAT_DB_PATH"]
            ?? defaultPath
    }
}
