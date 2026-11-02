//
//  CodableMacroConfig.swift
//
//
//  Created by OpenAI Codex on 20.04.26.
//

import Foundation
import MacroCodableKitShared
import SwiftSyntax

struct CodableMacroConfig {
    struct CaseStyleTransformer {
        let memberName: String

        func transform(_ propertyName: String) -> String {
            guard let style = CaseStyle(rawValue: memberName) else { return propertyName }
            return CaseConverter.format(propertyName, to: style)
        }
    }

    let caseStyle: CaseStyleTransformer
    let isStrict: Bool
    let isValidated: Bool

    init(
        caseStyle: CaseStyleTransformer = CaseStyleTransformer(memberName: "verbatim"),
        isStrict: Bool = false,
        isValidated: Bool = false
    ) {
        self.caseStyle = caseStyle
        self.isStrict = isStrict
        self.isValidated = isValidated
    }

    static func isEnabled(_ label: String, in args: LabeledExprListSyntax) -> Bool {
        args.first { $0.label?.text == label }?.expression.as(BooleanLiteralExprSyntax.self)?.literal.tokenKind == .keyword(.true)
    }

    init(node: AttributeSyntax) {
        guard case let .argumentList(args) = node.arguments else {
            self.init()
            return
        }

        let member = args.first { $0.label?.text == "caseStyle" }?.expression.as(MemberAccessExprSyntax.self)
        self.init(
            caseStyle: CaseStyleTransformer(memberName: member?.declName.baseName.text ?? "verbatim"),
            isStrict: Self.isEnabled("strict", in: args),
            isValidated: Self.isEnabled("validated", in: args)
        )
    }
}
