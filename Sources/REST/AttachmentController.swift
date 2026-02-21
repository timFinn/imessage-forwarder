import Vapor
import Core

public struct AttachmentController: RouteCollection {
    private let attachmentRepo: AttachmentRepository
    private let allowedBasePath: String

    public init(attachmentRepo: AttachmentRepository) {
        self.attachmentRepo = attachmentRepo
        self.allowedBasePath = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Messages/Attachments")
    }

    public func boot(routes: any RoutesBuilder) throws {
        let attachments = routes.grouped("api", "attachments")
        attachments.get(":id", use: stream)
    }

    /// GET /api/attachments/:id
    /// Streams the attachment file with proper MIME type.
    /// Includes path traversal protection.
    private func stream(req: Request) async throws -> Response {
        guard let idStr = req.parameters.get("id"),
              let id = Int64(idStr) else {
            throw Abort(.badRequest, reason: "Invalid attachment ID")
        }

        guard let attachment = try attachmentRepo.fetchById(id: id) else {
            throw Abort(.notFound, reason: "Attachment not found")
        }

        guard let resolvedPath = attachment.resolvedPath else {
            throw Abort(.notFound, reason: "Attachment has no file path")
        }

        // Path traversal protection: ensure resolved path is within allowed directory
        let canonicalPath = (resolvedPath as NSString).standardizingPath
        guard canonicalPath.hasPrefix(allowedBasePath) else {
            req.logger.warning("Path traversal attempt blocked: \(resolvedPath)")
            throw Abort(.forbidden, reason: "Access denied")
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: canonicalPath) else {
            throw Abort(.notFound, reason: "Attachment file not found (may have been purged by macOS)")
        }

        // Stream the file
        let response = req.fileio.streamFile(at: canonicalPath)

        // Set content type if known
        if let mimeType = attachment.mimeType {
            response.headers.contentType = HTTPMediaType(
                type: String(mimeType.split(separator: "/").first ?? "application"),
                subType: String(mimeType.split(separator: "/").last ?? "octet-stream")
            )
        }

        return response
    }
}
