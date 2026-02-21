import Foundation

public struct AttachmentModel: Codable, Sendable, Identifiable {
    public let id: Int64
    public let guid: String
    public let filename: String?
    public let mimeType: String?
    public let transferName: String?
    public let totalBytes: Int64

    public init(
        id: Int64,
        guid: String,
        filename: String?,
        mimeType: String?,
        transferName: String?,
        totalBytes: Int64
    ) {
        self.id = id
        self.guid = guid
        self.filename = filename
        self.mimeType = mimeType
        self.transferName = transferName
        self.totalBytes = totalBytes
    }

    /// Resolve the full filesystem path for this attachment.
    /// chat.db stores paths with `~` which needs expansion.
    public var resolvedPath: String? {
        guard let filename = filename else { return nil }
        return (filename as NSString).expandingTildeInPath
    }

    /// Whether this attachment is an image type
    public var isImage: Bool {
        guard let mime = mimeType else { return false }
        return mime.hasPrefix("image/")
    }

    /// Whether this attachment is a video type
    public var isVideo: Bool {
        guard let mime = mimeType else { return false }
        return mime.hasPrefix("video/")
    }
}
