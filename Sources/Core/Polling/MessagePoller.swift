import Foundation
import Vapor

/// Polls chat.db for new messages at a configurable interval.
/// Uses a ROWID watermark to track which messages have been seen.
public actor MessagePoller {
    private let messageRepo: MessageRepository
    private let interval: TimeInterval
    private var watermark: Int64
    private var subscribers: [@Sendable (MessageModel) -> Void] = []
    private var isRunning = false
    private let logger: Logger

    public init(messageRepo: MessageRepository, interval: TimeInterval = 1.5, logger: Logger) {
        self.messageRepo = messageRepo
        self.interval = interval
        self.watermark = 0
        self.logger = logger
    }

    /// Register a callback to be notified of new messages.
    public func onNewMessage(_ handler: @escaping @Sendable (MessageModel) -> Void) {
        subscribers.append(handler)
    }

    /// Start polling. Sets watermark to current max ROWID so we only forward new messages.
    public func start() async {
        guard !isRunning else { return }
        isRunning = true

        do {
            watermark = try messageRepo.maxRowId()
            logger.info("MessagePoller started. Watermark: \(watermark)")
        } catch {
            logger.error("Failed to get initial watermark: \(error)")
            return
        }

        while isRunning {
            try? await Task.sleep(for: .seconds(interval))
            guard isRunning else { break }
            await poll()
        }
    }

    /// Stop polling.
    public func stop() {
        isRunning = false
        logger.info("MessagePoller stopped")
    }

    private func poll() async {
        do {
            let newMessages = try messageRepo.fetchSince(rowId: watermark)
            for message in newMessages {
                if message.id > watermark {
                    watermark = message.id
                }
                for subscriber in subscribers {
                    subscriber(message)
                }
            }
            if !newMessages.isEmpty {
                logger.debug("Polled \(newMessages.count) new message(s). Watermark: \(watermark)")
            }
        } catch {
            logger.error("Poll error: \(error)")
        }
    }
}
