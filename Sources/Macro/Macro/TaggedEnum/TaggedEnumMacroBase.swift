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
        /// nil = internally tagged: associated values are siblings of the tag.
        let paramsKey: String?
        let paramsIdentifier: String?   // camelCase Swift identifier for CodingKeys
        let caseStyle: CaseStyleTransformer
        let keyStyle: CaseStyleTransformer
        let isStrict: Bool
        let isValidated: Bool
    }

    /// Per-case data that only the raw syntax exposes.
    struct CaseAnnotations {
        var tags: [String: String] = [:]
        var defaults: [String: [String: String]] = [:]

        init(_ declaration: some DeclGroupSyntax) {
            for member in declaration.memberBlock.members {
                guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
                let tag = caseDecl.attributes
                    .compactMap { $0.as(AttributeSyntax.self) }
                    .first { $0.attributeName.trimmedDescription == "CaseTag" }
                    .flatMap { TaggedEnumMacroBase.firstStringArgument(of: $0) }
                for element in caseDecl.elements {
                    if let tag { tags[element.name.text] = tag }
                    for param in element.parameterClause?.parameters ?? [] {
                        guard let label = param.firstName?.text, let value = param.defaultValue?.value else { continue }
                        defaults[element.name.text, default: [:]][label] = value.trimmedDescription
                    }
                }
            }
        }

        func tag(of enumCase: String, config: Config) -> String {
            tags[enumCase] ?? config.caseStyle.transform(enumCase)
        }
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
                        message: "'@\(MacroConfiguration.current.name)' requires '@CodedAt'",
                        diagnosticID: MessageID(domain: MacroConfiguration.current.name, id: "missingAnnotations")
                    )
                    .diagnose(at: declaration)
            )
            return []
        }

        guard verifyCases(enumDecl, config: config, declaration: declaration, in: context) else { return [] }

        let accessModifier: AccessModifier? = enumDecl.isPublic ? .public : nil

        let rawCode = buildExtension(
            typeName: type.trimmedDescription,
            enumDecl: enumDecl,
            config: config,
            annotations: CaseAnnotations(declaration),
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

    // MARK: - Verification

    private static func verifyCases(
        _ enumDecl: Enum,
        config: Config,
        declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) -> Bool {
        var isValid = true
        func fail(_ message: String, id: String) {
            isValid = false
            context.diagnose(
                SimpleDiagnosticMessage
                    .error(message: message, diagnosticID: MessageID(domain: MacroConfiguration.current.name, id: id))
                    .diagnose(at: declaration)
            )
        }
        for enumCase in enumDecl.cases {
            guard case let .associatedValue(params) = enumCase.value else { continue }
            if config.paramsKey != nil, params.count == 1, params[0].label == nil { continue }
            if params.contains(where: { $0.label == nil }) {
                fail("Case '\(enumCase.identifier)' needs labels on its associated values: the label is the JSON key", id: "unlabeledParameter")
            }
            if config.paramsKey == nil {
                for label in params.compactMap(\.label) where config.keyStyle.transform(label) == config.tagKey || label == config.tagIdentifier {
                    fail("Case '\(enumCase.identifier)' parameter '\(label)' collides with tag key '\(config.tagKey)'", id: "tagCollision")
                }
            }
        }
        return isValid
    }

    // MARK: - Config Parsing

    static func parseConfig(from attributes: AttributeListSyntax) -> Config? {
        guard
            let (tagKey, transformer, keyStyle, isStrict, isValidated) = parseCodedAt(from: attributes)
        else { return nil }
        let paramsKey = parseContentAt(from: attributes)

        return Config(
            tagKey: tagKey,
            tagIdentifier: snakeToCamel(tagKey),
            paramsKey: paramsKey,
            paramsIdentifier: paramsKey.map(snakeToCamel),
            caseStyle: transformer,
            keyStyle: keyStyle,
            isStrict: isStrict,
            isValidated: isValidated
        )
    }

    private static func parseCodedAt(
        from attributes: AttributeListSyntax
    ) -> (String, CaseStyleTransformer, CaseStyleTransformer, Bool, Bool)? {
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

        func style(_ label: String) -> CaseStyleTransformer {
            let member = args.first { $0.label?.text == label }?.expression.as(MemberAccessExprSyntax.self)
            return CaseStyleTransformer(memberName: member?.declName.baseName.text ?? "verbatim")
        }

        return (
            tagKey,
            style("caseStyle"),
            style("keyStyle"),
            CodableMacroConfig.isEnabled("strict", in: args),
            CodableMacroConfig.isEnabled("validated", in: args)
        )
    }

    private static func parseContentAt(from attributes: AttributeListSyntax) -> String? {
        attributes
            .compactMap { $0.as(AttributeSyntax.self) }
            .first { $0.attributeName.trimmedDescription == "ContentAt" }
            .flatMap { firstStringArgument(of: $0) }
    }

    fileprivate static func firstStringArgument(of attribute: AttributeSyntax) -> String? {
        guard
            case let .argumentList(args) = attribute.arguments,
            let strLit = args.first?.expression.as(StringLiteralExprSyntax.self),
            let segment = strLit.segments.first?.as(StringSegmentSyntax.self)
        else { return nil }

        return segment.content.text
    }

    private static func keyRawValue(_ label: String, config: Config) -> String {
        let key = config.keyStyle.transform(label)
        return key == label ? "" : " = \"\(key)\""
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
        annotations: CaseAnnotations,
        accessModifier: AccessModifier?,
        conformances: Set<Conformance>
    ) -> String {
        guard !conformances.isEmpty else { return "" }

        let conformanceList = conformances.map(\.rawValue).sorted().joined(separator: ", ")
        let access = accessModifier.map { "\($0.rawValue) " } ?? ""

        var lines: [String] = []
        lines.append("extension \(typeName): \(conformanceList) {")

        // Per-case CodingKeys for cases with associated values
        if config.paramsKey != nil {
            for enumCase in enumDecl.cases {
                guard case let .associatedValue(params) = enumCase.value, directPayload(params) == nil else { continue }
                let name = perCaseCodingKeysName(enumCase.identifier)
                lines.append("private enum \(name): String, CodingKey\(config.isStrict ? ", CaseIterable" : "") {")
                for param in params where param.label != nil {
                    lines.append("case \(param.label!)\(keyRawValue(param.label!, config: config))")
                }
                lines.append("}")
            }
        }

        // Outer CodingKeys
        let tagId = config.tagIdentifier
        let tagRaw = tagId != config.tagKey ? " = \"\(config.tagKey)\"" : ""

        lines.append("\(access)enum CodingKeys: String, CodingKey, CaseIterable, Sendable, Hashable {")
        lines.append("case \(tagId)\(tagRaw)")
        if let paramsId = config.paramsIdentifier, let paramsKey = config.paramsKey {
            lines.append("case \(paramsId)\(paramsId != paramsKey ? " = \"\(paramsKey)\"" : "")")
        } else {
            // Internally tagged: every parameter label of every case shares the tag's container.
            var seen = Set<String>()
            for enumCase in enumDecl.cases {
                guard case let .associatedValue(params) = enumCase.value else { continue }
                for label in params.compactMap(\.label) where seen.insert(label).inserted {
                    lines.append("case \(label)\(keyRawValue(label, config: config))")
                }
            }
        }
        lines.append("}")

        // init(from:)
        if conformances.contains(.Decodable) {
            lines += buildDecoder(enumDecl: enumDecl, config: config, annotations: annotations, access: access)
        }

        // encode(to:)
        if conformances.contains(.Encodable) {
            lines += buildEncoder(enumDecl: enumDecl, config: config, annotations: annotations, access: access)
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private static func buildDecoder(
        enumDecl: Enum,
        config: Config,
        annotations: CaseAnnotations,
        access: String
    ) -> [String] {
        var lines: [String] = []
        lines.append("\(access)init(from decoder: Decoder) throws {")
        lines.append("let container = try decoder.container(keyedBy: CodingKeys.self)")
        lines.append("let tag = try container.decode(String.self, forKey: .\(config.tagIdentifier))")
        lines.append("switch tag {")

        for enumCase in enumDecl.cases {
            lines.append("case \"\(annotations.tag(of: enumCase.identifier, config: config))\":")

            switch enumCase.value {
            case nil:
                if config.isStrict { lines.append(rejectUnknownKeys(in: "decoder", allowed: [".\(config.tagIdentifier)"])) }
                lines.append("self = .\(enumCase.identifier)")

            case .associatedValue(let params):
                if let payload = directPayload(params), let paramsId = config.paramsIdentifier {
                    if config.isStrict { lines.append(rejectUnknownKeys(in: "decoder", allowed: [".\(config.tagIdentifier)", ".\(paramsId)"])) }
                    let typeName = payload.type.typeDescription(preservingOptional: false)
                    let fn = payload.type.isOptional ? "decodeIfPresent" : "decode"
                    lines.append("self = .\(enumCase.identifier)(try container.\(fn)(\(typeName), forKey: .\(paramsId)))")
                    continue
                }
                var source = "container"
                let labels = params.compactMap(\.label)
                if let paramsId = config.paramsIdentifier {
                    let keysType = perCaseCodingKeysName(enumCase.identifier)
                    source = "params"
                    lines.append("let params = try container.nestedContainer(keyedBy: \(keysType).self, forKey: .\(paramsId))")
                    if config.isStrict {
                        lines.append(rejectUnknownKeys(in: "decoder", allowed: [".\(config.tagIdentifier)", ".\(paramsId)"]))
                        lines.append(
                            "try StrictDecoding.rejectUnknownKeys(in: container.superDecoder(forKey: .\(paramsId)), allowed: \(keysType).allCases)"
                        )
                    }
                } else if config.isStrict {
                    lines.append(rejectUnknownKeys(in: "decoder", allowed: ([config.tagIdentifier] + labels).map { ".\($0)" }))
                }
                let argList = params.compactMap { p -> String? in
                    guard let label = p.label else { return nil }
                    let typeName = p.type.typeDescription(preservingOptional: false)
                    if let defaultValue = annotations.defaults[enumCase.identifier]?[label] {
                        return "\(label): try \(source).decodeIfPresent(\(typeName), forKey: .\(label)) ?? \(defaultValue)"
                    }
                    let fn = p.type.isOptional ? "decodeIfPresent" : "decode"
                    return "\(label): try \(source).\(fn)(\(typeName), forKey: .\(label))"
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
        if config.isValidated { lines.append("try validate()") }
        lines.append("}")
        return lines
    }

    private static func buildEncoder(
        enumDecl: Enum,
        config: Config,
        annotations: CaseAnnotations,
        access: String
    ) -> [String] {
        // Flat parameter labels become local bindings next to the container, so it must not share a name with them.
        let container = config.paramsKey == nil ? "taggedContainer" : "container"
        var lines: [String] = []
        lines.append("\(access)func encode(to encoder: Encoder) throws {")
        lines.append("var \(container) = encoder.container(keyedBy: CodingKeys.self)")
        lines.append("switch self {")

        for enumCase in enumDecl.cases {
            let tagValue = annotations.tag(of: enumCase.identifier, config: config)
            let writeTag = "try \(container).encode(\"\(tagValue)\", forKey: .\(config.tagIdentifier))"

            switch enumCase.value {
            case nil:
                lines.append("case .\(enumCase.identifier):")
                lines.append(writeTag)

            case .associatedValue(let params):
                if let payload = directPayload(params), let paramsId = config.paramsIdentifier {
                    lines.append("case let .\(enumCase.identifier)(payload):")
                    lines.append(writeTag)
                    let fn = payload.type.isOptional ? "encodeIfPresent" : "encode"
                    lines.append("try \(container).\(fn)(payload, forKey: .\(paramsId))")
                    continue
                }
                let bindings = params.compactMap(\.label).joined(separator: ", ")
                lines.append("case let .\(enumCase.identifier)(\(bindings)):")
                lines.append(writeTag)
                var target = container
                if let paramsId = config.paramsIdentifier {
                    let keysType = perCaseCodingKeysName(enumCase.identifier)
                    target = "params"
                    lines.append("var params = \(container).nestedContainer(keyedBy: \(keysType).self, forKey: .\(paramsId))")
                }
                for param in params {
                    guard let label = param.label else { continue }
                    let fn = param.type.isOptional ? "encodeIfPresent" : "encode"
                    lines.append("try \(target).\(fn)(\(label), forKey: .\(label))")
                }

            default:
                break
            }
        }

        lines.append("}")
        lines.append("}")
        return lines
    }

    /// The value of a case with one unlabeled associated value, which is stored directly at the content key.
    private static func directPayload(_ params: [EnumCaseAssociatedValueParameter]) -> EnumCaseAssociatedValueParameter? {
        params.count == 1 && params[0].label == nil ? params[0] : nil
    }

    private static func rejectUnknownKeys(in decoder: String, allowed: [String]) -> String {
        "try StrictDecoding.rejectUnknownKeys(in: \(decoder), allowed: [\(allowed.map { "CodingKeys\($0)" }.joined(separator: ", "))])"
    }

    private static func perCaseCodingKeysName(_ caseName: String) -> String {
        caseName.prefix(1).uppercased() + caseName.dropFirst() + "CodingKeys"
    }
}
