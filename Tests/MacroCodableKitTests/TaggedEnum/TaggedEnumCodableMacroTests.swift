import Macro
import MacroTesting
import XCTest

private let isRecording = false

final class TaggedEnumCodableMacroTests: XCTestCase {
    func test_basic() {
        withMacroTesting(
            isRecording: isRecording,
            macros: [
                "TaggedCodable": TaggedCodableMacro.self,
                "CodedAt": CodedAtMacro.self,
                "ContentAt": ContentAtMacro.self,
            ]
        ) {
            assertMacro {
                """
                @TaggedCodable
                @CodedAt("intent", caseStyle: .screamingSnakeCase)
                @ContentAt("intent_params")
                enum StepIntent\(sutSuffix) {
                    case scroll
                    case search(query: String)
                    case paginate(direction: String, scope: String, target: Int?)
                }
                """
            } expansion: {
                #"""
                enum StepIntent__testing__ {
                    case scroll
                    case search(query: String)
                    case paginate(direction: String, scope: String, target: Int?)
                }

                extension StepIntent__testing__: Decodable, Encodable {
                    private enum SearchCodingKeys: String, CodingKey {
                        case query
                    }
                    private enum PaginateCodingKeys: String, CodingKey {
                        case direction
                        case scope
                        case target
                    }
                    enum CodingKeys: String, CodingKey, CaseIterable, Sendable, Hashable {
                        case intent
                        case intentParams = "intent_params"
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        let tag = try container.decode(String.self, forKey: .intent)
                        switch tag {
                        case "SCROLL":
                            self = .scroll
                        case "SEARCH":
                            let params = try container.nestedContainer(keyedBy: SearchCodingKeys.self, forKey: .intentParams)
                            self = .search(query: try params.decode(String.self, forKey: .query))
                        case "PAGINATE":
                            let params = try container.nestedContainer(keyedBy: PaginateCodingKeys.self, forKey: .intentParams)
                            self = .paginate(direction: try params.decode(String.self, forKey: .direction), scope: try params.decode(String.self, forKey: .scope), target: try params.decodeIfPresent(Int.self, forKey: .target))
                            default:
                            throw DecodingError.dataCorrupted(
                                .init(codingPath: container.codingPath, debugDescription: "Unknown \(tag)")
                            )
                        }
                    }
                    func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        switch self {
                        case .scroll:
                            try container.encode("SCROLL", forKey: .intent)
                        case let .search(query):
                            try container.encode("SEARCH", forKey: .intent)
                            var params = container.nestedContainer(keyedBy: SearchCodingKeys.self, forKey: .intentParams)
                            try params.encode(query, forKey: .query)
                        case let .paginate(direction, scope, target):
                            try container.encode("PAGINATE", forKey: .intent)
                            var params = container.nestedContainer(keyedBy: PaginateCodingKeys.self, forKey: .intentParams)
                            try params.encode(direction, forKey: .direction)
                            try params.encode(scope, forKey: .scope)
                            try params.encodeIfPresent(target, forKey: .target)
                        }
                    }
                }
                """#
            }
        }
    }

    func test_customKeys() {
        withMacroTesting(
            isRecording: isRecording,
            macros: [
                "TaggedCodable": TaggedCodableMacro.self,
                "CodedAt": CodedAtMacro.self,
                "ContentAt": ContentAtMacro.self,
            ]
        ) {
            assertMacro {
                """
                @TaggedCodable
                @CodedAt("action", caseStyle: .snakeCase)
                @ContentAt("args")
                enum Cmd\(sutSuffix) {
                    case openItem(query: String)
                }
                """
            } expansion: {
                #"""
                enum Cmd__testing__ {
                    case openItem(query: String)
                }

                extension Cmd__testing__: Decodable, Encodable {
                    private enum OpenItemCodingKeys: String, CodingKey {
                        case query
                    }
                    enum CodingKeys: String, CodingKey, CaseIterable, Sendable, Hashable {
                        case action
                        case args
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        let tag = try container.decode(String.self, forKey: .action)
                        switch tag {
                        case "open_item":
                            let params = try container.nestedContainer(keyedBy: OpenItemCodingKeys.self, forKey: .args)
                            self = .openItem(query: try params.decode(String.self, forKey: .query))
                            default:
                            throw DecodingError.dataCorrupted(
                                .init(codingPath: container.codingPath, debugDescription: "Unknown \(tag)")
                            )
                        }
                    }
                    func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        switch self {
                        case let .openItem(query):
                            try container.encode("open_item", forKey: .action)
                            var params = container.nestedContainer(keyedBy: OpenItemCodingKeys.self, forKey: .args)
                            try params.encode(query, forKey: .query)
                        }
                    }
                }
                """#
            }
        }
    }
}
