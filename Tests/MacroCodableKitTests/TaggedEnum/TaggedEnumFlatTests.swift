import Foundation
import Macro
import MacroCodableKit
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@TaggedCodable
@CodedAt("type", caseStyle: .snakeCase, keyStyle: .snakeCase)
private enum FlatEvent: Equatable {
    case ping
    case drawBox(boxLabel: String, retryCount: Int = 3, note: String?)
    @CaseTag("legacy")
    case renamed(container: String)
}

@Codable
private struct AbsentDefaults: Equatable {
    @AbsentDefault var count: Int = 7
    @AbsentDefault var names: [String] = []
}

final class TaggedEnumFlatTests: XCTestCase {
    private func encode(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    func test_flat_parameters_are_siblings_of_the_tag() throws {
        XCTAssertEqual(try encode(FlatEvent.ping), #"{"type":"ping"}"#)
        XCTAssertEqual(
            try encode(FlatEvent.drawBox(boxLabel: "a", retryCount: 1, note: nil)),
            #"{"box_label":"a","retry_count":1,"type":"draw_box"}"#
        )
    }

    func test_parameter_default_applies_only_when_key_is_absent() throws {
        let absent = Data(#"{"type":"draw_box","box_label":"a"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(FlatEvent.self, from: absent), .drawBox(boxLabel: "a", retryCount: 3, note: nil))
        let malformed = Data(#"{"type":"draw_box","box_label":"a","retry_count":"x"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(FlatEvent.self, from: malformed))
    }

    func test_case_tag_overrides_style_and_label_may_be_container() throws {
        XCTAssertEqual(try encode(FlatEvent.renamed(container: "c")), #"{"container":"c","type":"legacy"}"#)
        XCTAssertEqual(try JSONDecoder().decode(FlatEvent.self, from: Data(#"{"type":"legacy","container":"c"}"#.utf8)), .renamed(container: "c"))
    }

    func test_absent_default_uses_initializer_but_rejects_malformed() throws {
        XCTAssertEqual(try JSONDecoder().decode(AbsentDefaults.self, from: Data("{}".utf8)), AbsentDefaults())
        XCTAssertThrowsError(try JSONDecoder().decode(AbsentDefaults.self, from: Data(#"{"count":"x"}"#.utf8)))
    }

    private let macroSpecs: [String: MacroSpec] = [
        "TaggedCodable": MacroSpec(type: TaggedCodableMacro.self, conformances: ["Decodable", "Encodable"]),
        "CodedAt": MacroSpec(type: CodedAtMacro.self),
    ]

    func test_unlabeled_parameter_is_diagnosed() {
        assertMacroExpansion(
            """
            @TaggedCodable
            @CodedAt("type")
            enum Bad {
                case failed(Int)
            }
            """,
            expandedSource: """
            enum Bad {
                case failed(Int)
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Case 'failed' needs labels on its associated values: the label is the JSON key", line: 1, column: 1),
            ],
            macroSpecs: macroSpecs
        )
    }

    func test_tag_collision_is_diagnosed() {
        assertMacroExpansion(
            """
            @TaggedCodable
            @CodedAt("type")
            enum Bad {
                case a(type: Int)
            }
            """,
            expandedSource: """
            enum Bad {
                case a(type: Int)
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Case 'a' parameter 'type' collides with tag key 'type'", line: 1, column: 1),
            ],
            macroSpecs: macroSpecs
        )
    }
}
