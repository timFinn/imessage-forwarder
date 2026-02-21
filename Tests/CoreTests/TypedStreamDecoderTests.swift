import XCTest
@testable import Core

final class TypedStreamDecoderTests: XCTestCase {

    func testDecodeEmptyData() {
        let result = TypedStreamDecoder.decodeString(from: Data())
        XCTAssertNil(result)
    }

    func testDecodeTooShort() {
        let result = TypedStreamDecoder.decodeString(from: Data([0x01, 0x02]))
        XCTAssertNil(result)
    }

    func testDecodeStringWithLengthPrefix() {
        // Simulate a simple case: class marker followed by length-prefixed string
        var data = Data()
        data.append(contentsOf: Array("NSString".utf8))
        // Some padding bytes (type info)
        data.append(contentsOf: [0x00, 0x01, 0x02])
        // Length-prefixed string: length=5, "Hello"
        data.append(5)
        data.append(contentsOf: Array("Hello".utf8))

        let result = TypedStreamDecoder.decodeString(from: data)
        XCTAssertEqual(result, "Hello")
    }

    func testDecodeStringWithNSMutableString() {
        var data = Data()
        data.append(contentsOf: Array("NSMutableString".utf8))
        data.append(contentsOf: [0x00])
        data.append(11)
        data.append(contentsOf: Array("Hello World".utf8))

        let result = TypedStreamDecoder.decodeString(from: data)
        XCTAssertEqual(result, "Hello World")
    }

    func testHeuristicFallback() {
        // No class marker, but contains a length-prefixed string embedded
        var data = Data()
        data.append(contentsOf: [0x04, 0x01, 0x00, 0xFF, 0x84])
        // Embedded length-prefixed string
        data.append(12)
        data.append(contentsOf: Array("Test message".utf8))
        data.append(contentsOf: [0x00, 0x00, 0x01])

        let result = TypedStreamDecoder.decodeString(from: data)
        XCTAssertEqual(result, "Test message")
    }

    func testAttributedBodyParser() {
        let result = AttributedBodyParser.extractText(from: nil)
        XCTAssertNil(result)

        let emptyResult = AttributedBodyParser.extractText(from: Data())
        XCTAssertNil(emptyResult)
    }
}
