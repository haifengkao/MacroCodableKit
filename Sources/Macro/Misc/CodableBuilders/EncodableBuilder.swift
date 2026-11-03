//
//  DefaultCodableBuilders.EncodableBuilder.swift
//
//
//  Created by Mikhail Maslo on 07.10.23.
//

import MacroToolkit

struct EncodableBuilder: CodeBuildable {
    struct BuildingData {
        struct Item {
            let identifier: String
            let function: String
        }

        let accessModifier: AccessModifier?
        let strategy: CodableStrategy
        let items: [Item]
        var defaultKey: DefaultKeyPlan?
    }

    private let buildingData: BuildingData

    init(buildingData: BuildingData) {
        self.buildingData = buildingData
    }

    func build() -> String {
        DeclarationBuilder(accessModifier: buildingData.accessModifier, signature: "func encode(to encoder: Encoder) throws") {
            if let defaultKey = buildingData.defaultKey, buildingData.strategy == .codingKeys {
                let condition = defaultKey.fallbacks.map { "self.\($0.identifier) == \($0.value)" }.joined(separator: " && ")
                "if \(condition.isEmpty ? "true" : condition) {"
                "var container = encoder.singleValueContainer()"
                "try container.encode(self.\(defaultKey.identifier))"
                "return"
                "}"
                "var container = encoder.container(keyedBy: CodingKeys.self)"
                buildingData.items.map { item in item.function }
            } else if buildingData.items.isEmpty {
                ""
            } else {
                switch buildingData.strategy {
                case .singleValue:
                    ""
                case .codingKeys:
                    "var container = encoder.container(keyedBy: CodingKeys.self)"
                }

                buildingData.items
                    .map { item in
                        item.function
                    }
            }
        }.build()
    }
}
