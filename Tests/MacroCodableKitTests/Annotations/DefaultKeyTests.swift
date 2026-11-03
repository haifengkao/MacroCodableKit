import Foundation
import MacroCodableKit
import XCTest

@Codable(caseStyle: .snakeCase, strict: true)
private struct Pattern: Equatable {
    @DefaultKey let include: String
    @AbsentDefault var exclude: [String] = []
    var note: String?

    init(include: String, exclude: [String] = [], note: String? = nil) {
        self.include = include
        self.exclude = exclude
        self.note = note
    }
}

@Codable(validated: true)
private struct Positive: Equatable {
    @DefaultKey let value: Int
    var label: String?

    func validate() throws {
        guard value > 0 else { throw CocoaError(.coderInvalidValue) }
    }
}

final class DefaultKeyTests: XCTestCase {
    private func encode(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private func decode<T: Decodable>(_: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    func test_bare_value_is_the_default_key() throws {
        XCTAssertEqual(try decode([Pattern].self, #"["^/$"]"#), [Pattern(include: "^/$")])
    }

    func test_object_is_the_full_form() throws {
        XCTAssertEqual(
            try decode(Pattern.self, #"{"include":"^/a","exclude":["^/b"],"note":"n"}"#),
            Pattern(include: "^/a", exclude: ["^/b"], note: "n")
        )
        XCTAssertEqual(try decode(Pattern.self, #"{"include":"^/a"}"#), Pattern(include: "^/a"))
    }

    func test_encodes_bare_value_only_when_others_are_default() throws {
        XCTAssertEqual(try encode(Pattern(include: "^/$")), #""^/$""#)
        XCTAssertEqual(try encode(Pattern(include: "^/a", exclude: ["^/b"])), #"{"exclude":["^/b"],"include":"^/a"}"#)
        XCTAssertEqual(try encode(Pattern(include: "^/a", note: "n")), #"{"exclude":[],"include":"^/a","note":"n"}"#)
    }

    func test_object_form_keeps_its_own_errors() {
        XCTAssertThrowsError(try decode(Pattern.self, #"{"exclude":["^/b"]}"#))
        XCTAssertThrowsError(try decode(Pattern.self, #"{"include":"^/a","exclude":"^/b"}"#))
        XCTAssertThrowsError(try decode(Pattern.self, #"{"include":"^/a","extra":1}"#))
        XCTAssertThrowsError(try decode(Pattern.self, "1"))
    }

    func test_validation_runs_for_both_forms() throws {
        XCTAssertEqual(try decode(Positive.self, "3"), Positive(value: 3))
        XCTAssertThrowsError(try decode(Positive.self, "0"))
        XCTAssertThrowsError(try decode(Positive.self, #"{"value":0}"#))
    }
}
