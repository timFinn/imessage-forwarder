import Foundation

public enum DateTransformer {
    /// Apple's Core Data epoch: 2001-01-01 00:00:00 UTC
    /// The offset from Unix epoch (1970-01-01) to Apple epoch (2001-01-01) in seconds.
    private static let appleEpochOffset: TimeInterval = 978307200

    /// Threshold to distinguish seconds from nanoseconds.
    /// Values above this are nanoseconds (post-High Sierra chat.db format).
    /// 1e12 ≈ year 33658 in seconds, so any real timestamp in seconds will be below this.
    private static let nanosecondThreshold: Int64 = 1_000_000_000_000

    /// Convert a chat.db `date` column value to a Unix timestamp (seconds since 1970).
    public static func toUnixTimestamp(_ appleDate: Int64) -> TimeInterval {
        let seconds: TimeInterval
        if abs(appleDate) > nanosecondThreshold {
            // Nanoseconds since 2001-01-01 (macOS High Sierra+)
            seconds = TimeInterval(appleDate) / 1_000_000_000.0
        } else {
            // Seconds since 2001-01-01 (older macOS)
            seconds = TimeInterval(appleDate)
        }
        return seconds + appleEpochOffset
    }

    /// Convert a chat.db `date` column value to a `Date`.
    public static func toDate(_ appleDate: Int64) -> Date {
        Date(timeIntervalSince1970: toUnixTimestamp(appleDate))
    }

    /// Convert a Unix timestamp to an Apple epoch value (nanoseconds since 2001-01-01).
    public static func fromUnixTimestamp(_ unixTimestamp: TimeInterval) -> Int64 {
        let appleSeconds = unixTimestamp - appleEpochOffset
        return Int64(appleSeconds * 1_000_000_000)
    }

    /// Convert a `Date` to an Apple epoch value (nanoseconds since 2001-01-01).
    public static func fromDate(_ date: Date) -> Int64 {
        fromUnixTimestamp(date.timeIntervalSince1970)
    }
}
