import Foundation

/// Decodes Apple's typedstream binary format used in `attributedBody` blobs.
///
/// typedstream is an old NeXTSTEP serialization format. The `attributedBody` column in chat.db
/// contains an NSAttributedString archived in this format. We only need to extract the plain
/// text (NSString) content, not the attributes.
///
/// Format reference: adapted from patterns in imessage-exporter and reverse engineering.
public enum TypedStreamDecoder {
    /// Extract plain text string(s) from a typedstream blob.
    /// Returns nil if the data cannot be decoded.
    public static func decodeString(from data: Data) -> String? {
        guard data.count > 4 else { return nil }

        // typedstream magic: "streamtyped" or starts with specific bytes
        // The format has a header, then serialized objects.
        // We use a heuristic approach: scan for NSString/NSMutableString data.

        var results: [String] = []
        let bytes = [UInt8](data)
        var i = 0

        while i < bytes.count {
            // Look for string length markers followed by valid UTF-8 text.
            // NSString contents in typedstream are typically preceded by a length byte
            // or a length marker, then raw UTF-8 bytes.

            // Strategy 1: Look for the "NSString" or "NSMutableString" class markers
            if let match = findClassMarker(in: bytes, at: i) {
                i = match.nextIndex
                // After the class info, look for string data
                if let (str, nextIdx) = extractString(from: bytes, startingAt: i) {
                    if !str.isEmpty {
                        results.append(str)
                    }
                    i = nextIdx
                    continue
                }
            }

            i += 1
        }

        // If class-marker approach didn't work, try the simpler heuristic
        if results.isEmpty {
            if let text = extractByHeuristic(from: bytes) {
                return text
            }
        }

        return results.isEmpty ? nil : results.joined()
    }

    private struct ClassMatch {
        let nextIndex: Int
    }

    private static func findClassMarker(in bytes: [UInt8], at offset: Int) -> ClassMatch? {
        let markers: [[UInt8]] = [
            Array("NSString".utf8),
            Array("NSMutableString".utf8),
            Array("NSAttributedString".utf8),
            Array("NSMutableAttributedString".utf8),
        ]

        for marker in markers {
            if offset + marker.count <= bytes.count {
                let slice = Array(bytes[offset..<offset + marker.count])
                if slice == marker {
                    return ClassMatch(nextIndex: offset + marker.count)
                }
            }
        }
        return nil
    }

    private static func extractString(from bytes: [UInt8], startingAt offset: Int) -> (String, Int)? {
        var i = offset

        // Skip past type info bytes (typically a few bytes of metadata)
        // Look for a length-prefixed string within the next ~20 bytes
        let searchLimit = min(i + 30, bytes.count)
        while i < searchLimit {
            // Check if this byte could be a string length
            let potentialLength = Int(bytes[i])
            if potentialLength > 0 && potentialLength < 10000 && i + 1 + potentialLength <= bytes.count {
                let strBytes = Array(bytes[i + 1 ..< i + 1 + potentialLength])
                if let str = String(bytes: strBytes, encoding: .utf8),
                   str.allSatisfy({ !$0.isASCII || !($0.asciiValue.map({ $0 < 32 && $0 != 10 && $0 != 13 }) ?? false) || $0 == "\n" || $0 == "\r" }) {
                    // Validate it looks like real text (has printable chars)
                    let printableCount = str.filter { $0.isPrintableOrWhitespace }.count
                    if printableCount > str.count / 2 {
                        return (str, i + 1 + potentialLength)
                    }
                }
            }

            // Check for 2-byte length (big-endian)
            if i + 2 < bytes.count {
                let potentialLength2 = (Int(bytes[i]) << 8) | Int(bytes[i + 1])
                if potentialLength2 > 0 && potentialLength2 < 100000 && i + 2 + potentialLength2 <= bytes.count {
                    let strBytes = Array(bytes[i + 2 ..< i + 2 + potentialLength2])
                    if let str = String(bytes: strBytes, encoding: .utf8) {
                        let printableCount = str.filter { $0.isPrintableOrWhitespace }.count
                        if printableCount > str.count / 2 && potentialLength2 > 1 {
                            return (str, i + 2 + potentialLength2)
                        }
                    }
                }
            }

            i += 1
        }
        return nil
    }

    /// Heuristic fallback: scan the entire blob for the longest run of valid UTF-8 text.
    /// The actual message text is typically the longest string in the blob.
    private static func extractByHeuristic(from bytes: [UInt8]) -> String? {
        var bestString: String?
        var bestLength = 0
        var i = 0

        while i < bytes.count {
            // Look for a byte that could be a string length
            let b = bytes[i]
            if b > 0 {
                let length = Int(b)
                if length > 1 && length < 10000 && i + 1 + length <= bytes.count {
                    let strBytes = Array(bytes[i + 1 ..< i + 1 + length])
                    if let str = String(bytes: strBytes, encoding: .utf8) {
                        let printableCount = str.filter { $0.isPrintableOrWhitespace }.count
                        if printableCount > str.count / 2 && length > bestLength && length > 1 {
                            bestString = str
                            bestLength = length
                        }
                    }
                }
            }
            i += 1
        }

        return bestString
    }
}

private extension Character {
    var isPrintableOrWhitespace: Bool {
        !isASCII || self == " " || self == "\n" || self == "\r" || self == "\t" ||
        (asciiValue.map { $0 >= 32 && $0 < 127 } ?? true)
    }
}
