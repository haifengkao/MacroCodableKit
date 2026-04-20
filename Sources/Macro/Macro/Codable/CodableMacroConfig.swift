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

    init(caseStyle: CaseStyleTransformer = CaseStyleTransformer(memberName: "verbatim")) {
        self.caseStyle = caseStyle
    }

    init(node: AttributeSyntax) {
        guard case let .argumentList(args) = node.arguments else {
            self.init()
            return
        }

        if let styleArg = args.first(where: { $0.label?.text == "caseStyle" }),
           let member = styleArg.expression.as(MemberAccessExprSyntax.self) {
            self.init(caseStyle: CaseStyleTransformer(memberName: member.declName.baseName.text))
        } else {
            self.init()
        }
    }
}
