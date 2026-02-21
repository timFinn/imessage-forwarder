import Foundation

/// Extracts plain text from the `attributedBody` column in chat.db.
///
/// The `attributedBody` column stores an `NSAttributedString` archived in Apple's
/// typedstream format. This parser attempts to extract the plain text content.
public enum AttributedBodyParser {
    /// Extract plain text from an attributedBody blob.
    /// Returns nil if the data is nil or cannot be decoded.
    public static func extractText(from data: Data?) -> String? {
        guard let data = data, !data.isEmpty else { return nil }
        return TypedStreamDecoder.decodeString(from: data)
    }
}
