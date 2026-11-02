import Foundation
import MacroCodableKit
import XCTest

@Codable(caseStyle: .snakeCase, strict: true)
private struct StrictBox: Equatable {
    let boxWidth: Int
    let boxLabel: String?
}

@Codable(validated: true)
private struct ValidatedBox: Equatable {
    let width: Int

    func validate() throws {
        guard width >= 0 else { throw BoxError.negative }
    }
}

private enum BoxError: Error {
    case negative
}

@TaggedCodable
@CodedAt("name", caseStyle: .screamingSnakeCase, strict: true)
private enum StrictFlat: Equatable {
    case stop
    case paint(color: String, shade: Int?)
}

@TaggedCodable
@CodedAt("type", caseStyle: .snakeCase, strict: true)
@ContentAt("data")
private enum StrictNested: Equatable {
    case stop
    case paint(color: String)
}

private struct Payload: Codable, Equatable {
    let width: Int
}

@TaggedCodable
@CodedAt("type", caseStyle: .snakeCase, strict: true, validated: true)
@ContentAt("data")
private enum Direct: Equatable {
    case stop
    case box(Payload)
    case maybe(Payload?)

    func validate() throws {
        if case let .box(payload) = self, payload.width < 0 { throw BoxError.negative }
    }
}

final class StrictDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func encode(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    func test_strict_struct_rejects_unknown_keys_and_missing_required_keys() throws {
        XCTAssertEqual(try decode(StrictBox.self, #"{"box_width":1}"#), StrictBox(boxWidth: 1, boxLabel: nil))
        XCTAssertEqual(try decode(StrictBox.self, #"{"box_width":1,"box_label":null}"#), StrictBox(boxWidth: 1, boxLabel: nil))
        XCTAssertThrowsError(try decode(StrictBox.self, #"{"box_width":1,"extra":2}"#))
        XCTAssertThrowsError(try decode(StrictBox.self, #"{"box_label":"a"}"#))
    }

    func test_strict_flat_allows_only_the_keys_of_the_decoded_case() throws {
        XCTAssertEqual(try decode(StrictFlat.self, #"{"name":"STOP"}"#), .stop)
        XCTAssertEqual(try decode(StrictFlat.self, #"{"name":"PAINT","color":"r"}"#), .paint(color: "r", shade: nil))
        XCTAssertThrowsError(try decode(StrictFlat.self, #"{"name":"STOP","color":"r"}"#))
        XCTAssertThrowsError(try decode(StrictFlat.self, #"{"name":"PAINT","color":"r","extra":1}"#))
        XCTAssertThrowsError(try decode(StrictFlat.self, #"{"name":"OTHER"}"#))
    }

    func test_strict_nested_checks_both_levels() throws {
        XCTAssertEqual(try decode(StrictNested.self, #"{"type":"paint","data":{"color":"r"}}"#), .paint(color: "r"))
        XCTAssertThrowsError(try decode(StrictNested.self, #"{"type":"paint","data":{"color":"r"},"extra":1}"#))
        XCTAssertThrowsError(try decode(StrictNested.self, #"{"type":"paint","data":{"color":"r","extra":1}}"#))
        XCTAssertThrowsError(try decode(StrictNested.self, #"{"type":"stop","data":{}}"#))
    }

    func test_validated_runs_after_decoding() throws {
        XCTAssertEqual(try decode(ValidatedBox.self, #"{"width":1}"#), ValidatedBox(width: 1))
        XCTAssertThrowsError(try decode(ValidatedBox.self, #"{"width":-1}"#)) { XCTAssertTrue($0 is BoxError) }
        XCTAssertThrowsError(try decode(Direct.self, #"{"type":"box","data":{"width":-1}}"#)) { XCTAssertTrue($0 is BoxError) }
    }

    func test_one_unlabeled_value_is_stored_directly_at_the_content_key() throws {
        XCTAssertEqual(try encode(Direct.box(Payload(width: 1))), #"{"data":{"width":1},"type":"box"}"#)
        XCTAssertEqual(try decode(Direct.self, #"{"type":"box","data":{"width":1}}"#), .box(Payload(width: 1)))
        XCTAssertEqual(try decode(Direct.self, #"{"type":"stop"}"#), .stop)
        XCTAssertEqual(try decode(Direct.self, #"{"type":"maybe"}"#), .maybe(nil))
        XCTAssertThrowsError(try decode(Direct.self, #"{"type":"box"}"#))
        XCTAssertThrowsError(try decode(Direct.self, #"{"type":"box","data":{"width":1},"extra":1}"#))
    }
}
