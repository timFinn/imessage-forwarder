import Vapor
import Core
import WebSocketModule
import REST

public func configure(_ app: Application) async throws {
    // Load configuration
    let config = AppConfig()

    // Configure server
    app.http.server.configuration.port = config.port
    app.http.server.configuration.hostname = "0.0.0.0"

    // Serve static files from Public/
    let publicDir = app.directory.publicDirectory
    app.middleware.use(FileMiddleware(publicDirectory: publicDir))

    // Initialize database
    let chatDb: ChatDatabase
    do {
        chatDb = try ChatDatabase(path: config.chatDbPath)
        app.logger.info("Connected to chat.db at \(config.chatDbPath)")
    } catch {
        app.logger.critical("Failed to open chat.db: \(error.localizedDescription)")
        throw error
    }

    // Initialize repositories
    let messageRepo = MessageRepository(db: chatDb)
    let chatRepo = ChatRepository(db: chatDb)
    let attachmentRepo = AttachmentRepository(db: chatDb)

    // Initialize services
    let bridge = AppleScriptBridge()
    let sender = MessageSender(bridge: bridge, chatRepo: chatRepo, logger: app.logger)
    let wsManager = WebSocketManager(logger: app.logger)

    // Initialize and start the message poller
    let poller = MessagePoller(messageRepo: messageRepo, interval: config.pollInterval, logger: app.logger)
    await poller.onNewMessage { message in
        let event = WebSocketEvent(type: .newMessage, data: .message(message))
        Task {
            await wsManager.broadcast(event)
        }
    }

    // Start polling in background
    Task {
        await poller.start()
    }

    // Store poller for cleanup
    app.lifecycle.use(PollerLifecycle(poller: poller))

    // Register WebSocket route
    let wsController = WebSocketController(
        manager: wsManager,
        sender: sender,
        authToken: config.authToken,
        logger: app.logger
    )
    wsController.register(with: app)

    // Register REST routes with auth
    let authMiddleware = AuthMiddleware(token: config.authToken)
    let protected = app.grouped(authMiddleware)

    try protected.register(collection: ConversationController(chatRepo: chatRepo))
    try protected.register(collection: MessageController(messageRepo: messageRepo))
    try protected.register(collection: AttachmentController(attachmentRepo: attachmentRepo))
    try protected.register(collection: SendController(sender: sender))

    app.logger.info("iMessage Forwarder running on port \(config.port)")
}

/// Lifecycle handler to stop the poller on shutdown.
struct PollerLifecycle: LifecycleHandler {
    let poller: MessagePoller

    func shutdown(_ app: Application) {
        Task {
            await poller.stop()
        }
    }
}
