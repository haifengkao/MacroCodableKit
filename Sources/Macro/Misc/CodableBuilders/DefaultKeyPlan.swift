//
//  DefaultKeyPlan.swift
//

import MacroToolkit
import SwiftDiagnostics
import SwiftSyntax

/// The `@DefaultKey` property of a struct and the value every other coded
/// property takes when the encoded form is that property's value alone.
struct DefaultKeyPlan {
    struct Fallback {
        let identifier: String
        let value: String
    }

    let identifier: String
    let typeName: String
    let fallbacks: [Fallback]

    static func verify(instance: Instance) throws -> DefaultKeyPlan? {
        var defaultKeys: [(variable: Variable, identifier: String, type: Type)] = []
        var others: [(variable: Variable, identifier: String, type: Type, attributes: Variable.AllKnownAttributes)] = []
        for member in instance.members {
            guard
                let variable = member.asVariable,
                !variable.isStatic,
                variable.isStoredProperty,
                let binding = variable.bindings.first,
                let identifier = binding.identifier,
                let type = binding.type
            else {
                continue
            }
            let attributes = variable.knownAttributes()
            guard attributes[.omitCoding] == nil else { continue }
            if attributes[.defaultKey] != nil {
                defaultKeys.append((variable, identifier, type))
            } else {
                others.append((variable, identifier, type, attributes))
            }
        }

        guard let defaultKey = defaultKeys.first else { return nil }
        guard defaultKeys.count == 1 else {
            throw diagnose("Only one property can be '@DefaultKey'", id: "defaultKeyCount", at: defaultKeys[1].variable)
        }
        let ownAttributes = defaultKey.variable.knownAttributes()
        guard
            ownAttributes[.customCoding] == nil,
            ownAttributes[.valueStrategy] == nil,
            ownAttributes[.defaultValue] == nil,
            !defaultKey.type.isOptional
        else {
            throw diagnose(
                "'@DefaultKey' needs a non-optional property without '@CustomCoding', '@ValueStrategy' or '@DefaultValue'",
                id: "defaultKeyProperty",
                at: defaultKey.variable
            )
        }

        let fallbacks = try others.map { other -> Fallback in
            if let defaultValue = other.attributes[.defaultValue]?.first as? DefaultValue,
               other.attributes[.valueStrategy] == nil,
               let fallback = defaultValue.fallback(of: other.variable)
            {
                return Fallback(identifier: other.identifier, value: fallback)
            }
            if other.type.isOptional, other.attributes.isEmpty || other.attributes.keys.allSatisfy({ $0 == .codingKey }) {
                return Fallback(identifier: other.identifier, value: "nil")
            }
            throw diagnose(
                "'@DefaultKey' needs every other coded property to be Optional or '@DefaultValue'",
                id: "defaultKeyOthers",
                at: other.variable
            )
        }

        return DefaultKeyPlan(
            identifier: defaultKey.identifier,
            typeName: defaultKey.type.typeDescription(preservingOptional: false),
            fallbacks: fallbacks
        )
    }

    private static func diagnose(_ message: String, id: String, at variable: Variable) -> Error {
        MacroConfiguration.current.context.diagnose(
            SimpleDiagnosticMessage
                .error(message: message, diagnosticID: MessageID(domain: MacroConfiguration.current.name, id: id))
                .diagnose(at: variable._syntax)
        )
        return CommonError.diagnosticError
    }
}
