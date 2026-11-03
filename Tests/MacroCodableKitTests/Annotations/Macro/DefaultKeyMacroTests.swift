import Macro
import SwiftSyntaxMacros
import MacroTesting
import XCTest

private let isRecording = false

final class DefaultKeyMacroTests: XCTestCase {
    private let macros: [String: SwiftSyntaxMacros.Macro.Type] = [
        "Codable": CodableMacro.self,
        "DefaultKey": DefaultKeyMacro.self,
        "DefaultValue": DefaultValueMacro.self,
    ]

    func testExpansion() {
        withMacroTesting(isRecording: isRecording, macros: macros) {
            assertMacro {
                """
                @Codable
                struct Pattern\(sutSuffix) {
                    @DefaultKey let include: String
                    @DefaultValue(malformed: .throwError) var exclude: [String] = []
                    var note: String?
                }
                """
            } expansion: {
                """
                struct Pattern__testing__ {
                    let include: String
                    var exclude: [String] = []
                    var note: String?
                }

                extension Pattern__testing__: Decodable, Encodable {
                    enum CodingKeys: String, CodingKey, CaseIterable, Sendable, Hashable {
                        case include
                        case exclude
                        case note
                    }
                    init(from decoder: Decoder) throws {
                        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
                            self.include = try container.decode(String.self, forKey: .include)
                            self.exclude = container.contains(.exclude) ? try container.decode([String].self, forKey: .exclude) : []
                            self.note = try container.decodeIfPresent(String.self, forKey: .note)
                        } else {
                            let container = try decoder.singleValueContainer()
                            self.include = try container.decode(String.self)
                            self.exclude = []
                            self.note = nil
                        }
                    }
                    func encode(to encoder: Encoder) throws {
                        if self.exclude == [] && self.note == nil {
                            var container = encoder.singleValueContainer()
                            try container.encode(self.include)
                            return
                        }
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encode(self.include, forKey: .include)
                        try container.encode(self.exclude, forKey: .exclude)
                        try container.encodeIfPresent(self.note, forKey: .note)
                    }
                }
                """
            }
        }
    }

    func testDefaultValueNeedsInitializer() {
        withMacroTesting(isRecording: isRecording, macros: macros) {
            assertMacro {
                """
                @Codable
                struct NoInitializer\(sutSuffix) {
                    @DefaultValue(malformed: .throwError) let a: Int
                }
                """
            } diagnostics: {
                """
                @Codable
                struct NoInitializer__testing__ {
                    @DefaultValue(malformed: .throwError) let a: Int
                    ┬───────────────────────────────────────────────
                    ╰─ 🛑 '@DefaultValue' without a provider requires a 'var' with an initial value
                }
                """
            }
        }
    }

    func testDiagnostics() {
        withMacroTesting(isRecording: isRecording, macros: macros) {
            assertMacro {
                """
                @Codable
                struct Two\(sutSuffix) {
                    @DefaultKey let a: String
                    @DefaultKey let b: String?
                }
                """
            } diagnostics: {
                """
                @Codable
                struct Two__testing__ {
                    @DefaultKey let a: String
                    @DefaultKey let b: String?
                    ┬─────────────────────────
                    ╰─ 🛑 Only one property can be '@DefaultKey'
                }
                """
            }
            assertMacro {
                """
                @Codable
                struct Required\(sutSuffix) {
                    @DefaultKey let a: String
                    let b: Int
                }
                """
            } diagnostics: {
                """
                @Codable
                struct Required__testing__ {
                    @DefaultKey let a: String
                    let b: Int
                    ┬─────────
                    ╰─ 🛑 '@DefaultKey' needs every other coded property to be Optional or '@DefaultValue'
                }
                """
            }
            assertMacro {
                """
                @Codable
                struct OptionalKey\(sutSuffix) {
                    @DefaultKey let a: String?
                }
                """
            } diagnostics: {
                """
                @Codable
                struct OptionalKey__testing__ {
                    @DefaultKey let a: String?
                    ┬─────────────────────────
                    ╰─ 🛑 '@DefaultKey' needs a non-optional property without '@CustomCoding', '@ValueStrategy' or '@DefaultValue'
                }
                """
            }
        }
    }
}
