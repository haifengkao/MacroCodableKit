import MacroToolkit
import Foundation
import MacroCodableKitShared
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

enum TaggedEnumMacroBase {

    // MARK: - Config

    struct Config {
        let tagKey: String
        let tagIdentifier: String       // camelCase Swift identifier for CodingKeys
        let paramsKey: String
        let paramsIdentifier: String    // camelCase Swift identifier for CodingKeys
        let caseStyle: CaseStyleTransformer
    }

    struct CaseStyleTransformer {
        let memberName: String

        func transform(_ caseName: String) -> String {
            guard let style = CaseStyle(rawValue: memberName) else { return caseName }
            return CaseConverter.format(caseName, to: style)
        }
    }

    // MARK: - Entry Point

    static func expansion(
        of _: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformancesToGenerate: Set<Conformance>,
        expectedConformances: Set<Conformance>,
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        let checker = ConformanceDiagnosticChecker(
            config: .init(replacementMacroName: [:])
        )
        try checker.verify(
            type: type,
            declaration: declaration,
            expectedConformances: expectedConformances,
            conformancesToGenerate: conformancesToGenerate
        )

        guard let enumDecl = Enum(declaration) else {
            context.diagnose(
                SimpleDiagnosticMessage
                    .error(
                        message: "'@\(MacroConfiguration.current.name)' can only be applied to an enum",
                        diagnosticID: MessageID(domain: MacroConfiguration.current.name, id: "requiresEnum")
                    )
                    .diagnose(at: declaration)
            )
            return []
        }

        guard let config = parseConfig(from: declaration.attributes) else {
            context.diagnose(
                SimpleDiagnosticMessage
                    .error(
                        message: "'@\(MacroConfiguration.current.name)' requires both '@CodedAt' and '@ContentAt'",
                        diagnosticID: MessageID(domain: MacroConfiguration.current.name, id: "missingAnnotations")
                    )
                    .diagnose(at: declaration)
            )
            return []
        }

        let accessModifier: AccessModifier? = enumDecl.isPublic ? .public : nil

        let rawCode = buildExtension(
            typeName: type.trimmedDescription,
            enumDecl: enumDecl,
            config: config,
            accessModifier: accessModifier,
            conformances: conformancesToGenerate
        )

        guard !rawCode.isEmpty else { return [] }

        let formatted: String
        do {
            formatted = try rawCode.swiftFormatted
        } catch {
            context.diagnose(
                CommonDiagnostic
                    .internalError(message: "Internal Error = \(error). Couldn't format code")
                    .diagnose(at: declaration)
            )
            return []
        }

        guard let extensionDecl = DeclSyntax(stringLiteral: formatted).as(ExtensionDeclSyntax.self) else {
            context.diagnose(
                CommonDiagnostic
                    .internalError(message: "Internal Error. Couldn't create extension from code = \(formatted)")
                    .diagnose(at: declaration)
            )
            return []
        }

        return [extensionDecl]
    }

    // MARK: - Config Parsing

    static func parseConfig(from attributes: AttributeListSyntax) -> Config? {
        guard
            let (tagKey, transformer) = parseCodedAt(from: attributes),
            let paramsKey = parseContentAt(from: attributes)
        else { return nil }

        return Config(
            tagKey: tagKey,
            tagIdentifier: snakeToCamel(tagKey),
            paramsKey: paramsKey,
            paramsIdentifier: snakeToCamel(paramsKey),
            caseStyle: transformer
        )
    }

    private static func parseCodedAt(
        from attributes: AttributeListSyntax
    ) -> (String, CaseStyleTransformer)? {
        guard
            let attr = attributes
                .compactMap({ $0.as(AttributeSyntax.self) })
                .first(where: { $0.attributeName.trimmedDescription == "CodedAt" }),
            case let .argumentList(args) = attr.arguments,
            let firstArg = args.first,
            let strLit = firstArg.expression.as(StringLiteralExprSyntax.self),
            let segment = strLit.segments.first?.as(StringSegmentSyntax.self)
        else { return nil }

        let tagKey = segment.content.text

        var styleName = "verbatim"
        if let styleArg = args.first(where: { $0.label?.text == "caseStyle" }),
           let member = styleArg.expression.as(MemberAccessExprSyntax.self) {
            styleName = member.declName.baseName.text
        }

        return (tagKey, CaseStyleTransformer(memberName: styleName))
    }

    private static func parseContentAt(from attributes: AttributeListSyntax) -> String? {
        guard
            let attr = attributes
                .compactMap({ $0.as(AttributeSyntax.self) })
                .first(where: { $0.attributeName.trimmedDescription == "ContentAt" }),
            case let .argumentList(args) = attr.arguments,
            let firstArg = args.first,
            let strLit = firstArg.expression.as(StringLiteralExprSyntax.self),
            let segment = strLit.segments.first?.as(StringSegmentSyntax.self)
        else { return nil }

        return segment.content.text
    }

    private static func snakeToCamel(_ key: String) -> String {
        let parts = key.split(separator: "_")
        guard let first = parts.first else { return key }
        return String(first) + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    // MARK: - Code Generation

    private static func buildExtension(
        typeName: String,
        enumDecl: Enum,
        config: Config,
        accessModifier: AccessModifier?,
        conformances: Set<Conformance>
    ) -> String {
        guard !conformances.isEmpty else { return "" }

        let conformanceList = conformances.map(\.rawValue).sorted().joined(separator: ", ")
        let access = accessModifier.map { "\($0.rawValue) " } ?? ""

        var lines: [String] = []
        lines.append("extension \(typeName): \(conformanceList) {")

        // Per-case CodingKeys for cases with associated values
        for enumCase in enumDecl.cases {
            guard case let .associatedValue(params) = enumCase.value else { continue }
            let name = perCaseCodingKeysName(enumCase.identifier)
            lines.append("private enum \(name): String, CodingKey {")
            for param in params where param.label != nil {
                lines.append("case \(param.label!)")
            }
            lines.append("}")
        }

        // Outer CodingKeys
        let tagId = config.tagIdentifier
        let tagRaw = tagId != config.tagKey ? " = \"\(config.tagKey)\"" : ""
        let paramsId = config.paramsIdentifier
        let paramsRaw = paramsId != config.paramsKey ? " = \"\(config.paramsKey)\"" : ""

        lines.append("\(access)enum CodingKeys: String, CodingKey, CaseIterable, Sendable, Hashable {")
        lines.append("case \(tagId)\(tagRaw)")
        lines.append("case \(paramsId)\(paramsRaw)")
        lines.append("}")

        // init(from:)
        if conformances.contains(.Decodable) {
            lines += buildDecoder(enumDecl: enumDecl, config: config, tagId: tagId, paramsId: paramsId, access: access)
        }

        // encode(to:)
        if conformances.contains(.Encodable) {
            lines += buildEncoder(enumDecl: enumDecl, config: config, tagId: tagId, paramsId: paramsId, access: access)
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private static func buildDecoder(
        enumDecl: Enum,
        config: Config,
        tagId: String,
        paramsId: String,
        access: String
    ) -> [String] {
        var lines: [String] = []
        lines.append("\(access)init(from decoder: Decoder) throws {")
        lines.append("let container = try decoder.container(keyedBy: CodingKeys.self)")
        lines.append("let tag = try container.decode(String.self, forKey: .\(tagId))")
        lines.append("switch tag {")

        for enumCase in enumDecl.cases {
            let tagValue = config.caseStyle.transform(enumCase.identifier)
            lines.append("case \"\(tagValue)\":")

            switch enumCase.value {
            case nil:
                lines.append("self = .\(enumCase.identifier)")

            case .associatedValue(let params):
                let keysType = perCaseCodingKeysName(enumCase.identifier)
                lines.append("let params = try container.nestedContainer(keyedBy: \(keysType).self, forKey: .\(paramsId))")
                let argList = params.compactMap { p -> String? in
                    guard let label = p.label else { return nil }
                    let typeName = p.type.typeDescription(preservingOptional: false)
                    let fn = p.type.isOptional ? "decodeIfPresent" : "decode"
                    return "\(label): try params.\(fn)(\(typeName), forKey: .\(label))"
                }.joined(separator: ", ")
                lines.append("self = .\(enumCase.identifier)(\(argList))")

            default:
                break
            }
        }

        lines.append("default:")
        lines.append(
            "throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: \"Unknown \\(tag)\"))"
        )
        lines.append("}")
        lines.append("}")
        return lines
    }

    private static func buildEncoder(
        enumDecl: Enum,
        config: Config,
        tagId: String,
        paramsId: String,
        access: String
    ) -> [String] {
        var lines: [String] = []
        lines.append("\(access)func encode(to encoder: Encoder) throws {")
        lines.append("var container = encoder.container(keyedBy: CodingKeys.self)")
        lines.append("switch self {")

        for enumCase in enumDecl.cases {
            let tagValue = config.caseStyle.transform(enumCase.identifier)

            switch enumCase.value {
            case nil:
                lines.append("case .\(enumCase.identifier):")
                lines.append("try container.encode(\"\(tagValue)\", forKey: .\(tagId))")

            case .associatedValue(let params):
                let keysType = perCaseCodingKeysName(enumCase.identifier)
                let bindings = params.compactMap(\.label).joined(separator: ", ")
                lines.append("case let .\(enumCase.identifier)(\(bindings)):")
                lines.append("try container.encode(\"\(tagValue)\", forKey: .\(tagId))")
                lines.append("var params = container.nestedContainer(keyedBy: \(keysType).self, forKey: .\(paramsId))")
                for param in params {
                    guard let label = param.label else { continue }
                    let fn = param.type.isOptional ? "encodeIfPresent" : "encode"
                    lines.append("try params.\(fn)(\(label), forKey: .\(label))")
                }

            default:
                break
            }
        }

        lines.append("}")
        lines.append("}")
        return lines
    }

    private static func perCaseCodingKeysName(_ caseName: String) -> String {
        caseName.prefix(1).uppercased() + caseName.dropFirst() + "CodingKeys"
    }
}
