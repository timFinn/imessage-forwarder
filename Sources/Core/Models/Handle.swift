import Foundation

public struct HandleModel: Codable, Sendable, Identifiable {
    public let id: Int64
    public let address: String  // phone number or email
    public let service: String? // iMessage, SMS

    public init(id: Int64, address: String, service: String?) {
        self.id = id
        self.address = address
        self.service = service
    }
}
