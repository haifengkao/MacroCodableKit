//
//  DefaultValue.swift
//
//
//  Created by Mikhail Maslo on 01.10.23.
//

import MacroToolkit
import SwiftSyntax

struct DefaultValue {
    /// `nil` means the property's initial value is the default.
    let providerType: String?
    let throwsOnMalformed: Bool

    init?(_ attribute: Attribute) {
        guard attribute.name._baseSyntax.name.trimmedDescription == "\(Self.self)" else {
            return nil
        }
        let arguments = attribute.asMacroAttribute?.arguments ?? []
        providerType = arguments.first { $0.label == nil }?.expr._syntax.trimmedDescription
        throwsOnMalformed = arguments.first { $0.label == "malformed" }?.expr._syntax.trimmedDescription == ".throwError"
    }

    /// The expression a missing key decodes to, or `nil` when there's no initial value to use.
    func fallback(of variable: Variable) -> String? {
        if let providerType {
            return "\(providerType).defaultValue"
        }
        guard variable._syntax.bindingSpecifier.tokenKind == .keyword(.var) else { return nil }
        return variable._syntax.bindings.first?.initializer?.value.trimmedDescription
    }
}
