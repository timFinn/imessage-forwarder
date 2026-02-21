import Vapor

/// Validates Bearer token authentication for REST API routes.
public struct AuthMiddleware: AsyncMiddleware {
    private let validToken: String

    public init(token: String) {
        self.validToken = token
    }

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let authorization = request.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Missing authorization header")
        }

        guard authorization.token == validToken else {
            throw Abort(.unauthorized, reason: "Invalid authentication token")
        }

        return try await next.respond(to: request)
    }
}
