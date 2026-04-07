import Foundation
import MacroCodableKit
import XCTest

// MARK: - Types

@TaggedCodable
@CodedAt("type", caseStyle: .screamingSnakeCase)
@ContentAt("params")
private enum Command {
    case ping
    case fetch(url: String)
}

// Case A: @AllOfCodable with a single TaggedCodable property
@AllOfCodable
private struct EnvelopeAllOf {
    let command: Command
}

// Case B: plain @Codable (control group — expected to nest)
@Codable
private struct EnvelopeCodable {
    let command: Command
}

// MARK: - Tests

final class TaggedEnumFlattenTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    // Expected: {"params":{"url":"https://example.com"},"type":"FETCH"}
    // i.e. type + params are sibling keys at the top level
    func test_allOf_flattens_taggedEnum() throws {
        let value = EnvelopeAllOf(command: .fetch(url: "https://example.com"))
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)!

        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Should be flat — "type" and "params" at root, no extra nesting
        XCTAssertEqual(obj["type"] as? String, "FETCH",
                       "Expected 'type' as sibling key, got: \(json)")
        let params = obj["params"] as? [String: Any]
        XCTAssertEqual(params?["url"] as? String, "https://example.com",
                       "Expected 'params' as sibling key, got: \(json)")
        XCTAssertNil(obj["command"] as? [String: Any],
                     "Should NOT be nested object under 'command'")
    }

    // Control: @Codable nests under "command" key as expected
    func test_codable_nests_taggedEnum() throws {
        let value = EnvelopeCodable(command: .fetch(url: "https://example.com"))
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)!

        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Should be nested under "command"
        let nested = obj["command"] as? [String: Any]
        XCTAssertNotNil(nested, "Expected nesting under 'command', got: \(json)")
        XCTAssertEqual(nested?["type"] as? String, "FETCH")
    }
}
