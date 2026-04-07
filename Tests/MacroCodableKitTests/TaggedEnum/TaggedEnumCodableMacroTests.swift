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
                @CodedAt("type", caseStyle: .screamingSnakeCase)
                @ContentAt("params")
                enum Shape\(sutSuffix) {
                    case circle
                    case rectangle(width: Double)
                    case polygon(sides: Int, name: String, color: String?)
                }
                """
            } expansion: {
                #"""
                enum Shape__testing__ {
                    case circle
                    case rectangle(width: Double)
                    case polygon(sides: Int, name: String, color: String?)
                }

                extension Shape__testing__: Decodable, Encodable {
                    private enum RectangleCodingKeys: String, CodingKey {
                        case width
                    }
                    private enum PolygonCodingKeys: String, CodingKey {
                        case sides
                        case name
                        case color
                    }
                    enum CodingKeys: String, CodingKey, CaseIterable, Sendable, Hashable {
                        case type
                        case params
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        let tag = try container.decode(String.self, forKey: .type)
                        switch tag {
                        case "CIRCLE":
                            self = .circle
                        case "RECTANGLE":
                            let params = try container.nestedContainer(keyedBy: RectangleCodingKeys.self, forKey: .params)
                            self = .rectangle(width: try params.decode(Double.self, forKey: .width))
                        case "POLYGON":
                            let params = try container.nestedContainer(keyedBy: PolygonCodingKeys.self, forKey: .params)
                            self = .polygon(sides: try params.decode(Int.self, forKey: .sides), name: try params.decode(String.self, forKey: .name), color: try params.decodeIfPresent(String.self, forKey: .color))
                            default:
                            throw DecodingError.dataCorrupted(
                                .init(codingPath: container.codingPath, debugDescription: "Unknown \(tag)")
                            )
                        }
                    }
                    func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        switch self {
                        case .circle:
                            try container.encode("CIRCLE", forKey: .type)
                        case let .rectangle(width):
                            try container.encode("RECTANGLE", forKey: .type)
                            var params = container.nestedContainer(keyedBy: RectangleCodingKeys.self, forKey: .params)
                            try params.encode(width, forKey: .width)
                        case let .polygon(sides, name, color):
                            try container.encode("POLYGON", forKey: .type)
                            var params = container.nestedContainer(keyedBy: PolygonCodingKeys.self, forKey: .params)
                            try params.encode(sides, forKey: .sides)
                            try params.encode(name, forKey: .name)
                            try params.encodeIfPresent(color, forKey: .color)
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
                @CodedAt("kind", caseStyle: .snakeCase)
                @ContentAt("data")
                enum Command\(sutSuffix) {
                    case sendMessage(text: String)
                }
                """
            } expansion: {
                #"""
                enum Command__testing__ {
                    case sendMessage(text: String)
                }

                extension Command__testing__: Decodable, Encodable {
                    private enum SendMessageCodingKeys: String, CodingKey {
                        case text
                    }
                    enum CodingKeys: String, CodingKey, CaseIterable, Sendable, Hashable {
                        case kind
                        case data
                    }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        let tag = try container.decode(String.self, forKey: .kind)
                        switch tag {
                        case "send_message":
                            let params = try container.nestedContainer(keyedBy: SendMessageCodingKeys.self, forKey: .data)
                            self = .sendMessage(text: try params.decode(String.self, forKey: .text))
                            default:
                            throw DecodingError.dataCorrupted(
                                .init(codingPath: container.codingPath, debugDescription: "Unknown \(tag)")
                            )
                        }
                    }
                    func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        switch self {
                        case let .sendMessage(text):
                            try container.encode("send_message", forKey: .kind)
                            var params = container.nestedContainer(keyedBy: SendMessageCodingKeys.self, forKey: .data)
                            try params.encode(text, forKey: .text)
                        }
                    }
                }
                """#
            }
        }
    }
}
