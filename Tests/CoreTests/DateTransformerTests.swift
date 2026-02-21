import XCTest
@testable import Core

final class DateTransformerTests: XCTestCase {

    func testNanosecondTimestamp() {
        // A nanosecond timestamp from a modern macOS chat.db
        // 2023-10-15 12:00:00 UTC in Apple nanoseconds
        let appleDate: Int64 = 719_668_800_000_000_000
        let unixTimestamp = DateTransformer.toUnixTimestamp(appleDate)

        // Apple epoch offset: 978307200 seconds
        // 719668800 seconds since Apple epoch + 978307200 = 1697976000 Unix
        let expected: TimeInterval = 719_668_800.0 + 978_307_200.0
        XCTAssertEqual(unixTimestamp, expected, accuracy: 1.0)
    }

    func testSecondTimestamp() {
        // An older-format seconds timestamp
        let appleDate: Int64 = 719_668_800
        let unixTimestamp = DateTransformer.toUnixTimestamp(appleDate)

        let expected: TimeInterval = 719_668_800.0 + 978_307_200.0
        XCTAssertEqual(unixTimestamp, expected, accuracy: 1.0)
    }

    func testZeroTimestamp() {
        let unixTimestamp = DateTransformer.toUnixTimestamp(0)
        // Zero Apple epoch = Unix 978307200 (2001-01-01)
        XCTAssertEqual(unixTimestamp, 978_307_200.0, accuracy: 0.001)
    }

    func testToDate() {
        let appleDate: Int64 = 0
        let date = DateTransformer.toDate(appleDate)
        // Should be 2001-01-01 00:00:00 UTC
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(calendar.component(.year, from: date), 2001)
        XCTAssertEqual(calendar.component(.month, from: date), 1)
        XCTAssertEqual(calendar.component(.day, from: date), 1)
    }

    func testRoundTrip() {
        let originalUnix: TimeInterval = 1_700_000_000.0 // Nov 2023
        let appleDate = DateTransformer.fromUnixTimestamp(originalUnix)
        let roundTripped = DateTransformer.toUnixTimestamp(appleDate)
        XCTAssertEqual(roundTripped, originalUnix, accuracy: 0.001)
    }

    func testFromDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000.0)
        let appleDate = DateTransformer.fromDate(date)
        let recovered = DateTransformer.toDate(appleDate)
        XCTAssertEqual(recovered.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testNanosecondThresholdBoundary() {
        // Value just below threshold — treated as seconds
        let belowThreshold: Int64 = 999_999_999_999
        let resultSeconds = DateTransformer.toUnixTimestamp(belowThreshold)

        // Value just above threshold — treated as nanoseconds
        let aboveThreshold: Int64 = 1_000_000_000_001
        let resultNanos = DateTransformer.toUnixTimestamp(aboveThreshold)

        // The seconds interpretation gives a much larger result
        XCTAssertGreaterThan(resultSeconds, resultNanos)
    }
}
