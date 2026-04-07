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
                @CodedAt("kind", caseStyle: .screamingSnakeCase)
                @ContentAt("details")
                enum StepIntent\(sutSuffix) {
                    case ping
                    case message(text: String)
                    case move(axis: String, unit: String, amount: Int?)
                }
                """
            } expansion: {
                #"""
                enum StepIntent__testing__ {
                    case ping
                    case message(text: String)
                    case move(axis: String, unit: String, amount: Int?)
                }

                extension StepIntent__testing__: Decodable, Encodable {
                    private enum MessageCodingKeys: String, CodingKey {
                        case text
                    }
                    private enum MoveCodingKeys: String, CodingKey {
                        case axis
                        case unit
                        case amount
                    }
                    enum CodingKeys: String, CodingKey, CaseIterable, Sendable, Hashable {
                        case kind
                        case details = "details"
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        let tag = try container.decode(String.self, forKey: .kind)
                        switch tag {
                        case "PING":
                            self = .ping
                        case "MESSAGE":
                            let params = try container.nestedContainer(keyedBy: MessageCodingKeys.self, forKey: .details)
                            self = .message(text: try params.decode(String.self, forKey: .text))
                        case "MOVE":
                            let params = try container.nestedContainer(keyedBy: MoveCodingKeys.self, forKey: .details)
                            self = .move(axis: try params.decode(String.self, forKey: .axis), unit: try params.decode(String.self, forKey: .unit), amount: try params.decodeIfPresent(Int.self, forKey: .amount))
                            default:
                            throw DecodingError.dataCorrupted(
                                .init(codingPath: container.codingPath, debugDescription: "Unknown \(tag)")
                            )
                        }
                    }
                    func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        switch self {
                        case .ping:
                            try container.encode("PING", forKey: .kind)
                        case let .message(text):
                            try container.encode("MESSAGE", forKey: .kind)
                            var params = container.nestedContainer(keyedBy: MessageCodingKeys.self, forKey: .details)
                            try params.encode(text, forKey: .text)
                        case let .move(axis, unit, amount):
                            try container.encode("MOVE", forKey: .kind)
                            var params = container.nestedContainer(keyedBy: MoveCodingKeys.self, forKey: .details)
                            try params.encode(axis, forKey: .axis)
                            try params.encode(unit, forKey: .unit)
                            try params.encodeIfPresent(amount, forKey: .amount)
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
                    case note(text: String)
                }
                """
            } expansion: {
                #"""
                enum Cmd__testing__ {
                    case note(text: String)
                }

                extension Cmd__testing__: Decodable, Encodable {
                    private enum NoteCodingKeys: String, CodingKey {
                        case text
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
                            let params = try container.nestedContainer(keyedBy: NoteCodingKeys.self, forKey: .args)
                            self = .note(text: try params.decode(String.self, forKey: .text))
                            default:
                            throw DecodingError.dataCorrupted(
                                .init(codingPath: container.codingPath, debugDescription: "Unknown \(tag)")
                            )
                        }
                    }
                    func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        switch self {
                        case let .note(text):
                            try container.encode("open_item", forKey: .action)
                            var params = container.nestedContainer(keyedBy: NoteCodingKeys.self, forKey: .args)
                            try params.encode(text, forKey: .text)
                        }
                    }
                }
                """#
            }
        }
    }
}
