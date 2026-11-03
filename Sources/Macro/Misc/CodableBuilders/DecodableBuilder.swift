//
//  DecodableBuilder.swift
//
//
//  Created by Mikhail Maslo on 07.10.23.
//

import MacroToolkit

struct DecodableBuilder: CodeBuildable {
    struct BuildingData {
        struct Item {
            let identifier: String
            let function: String
        }

        let accessModifier: AccessModifier?
        let strategy: CodableStrategy
        let items: [Item]
        var isStrict = false
        var isValidated = false
        var defaultKey: DefaultKeyPlan?
    }

    private let buildingData: BuildingData

    init(buildingData: BuildingData) {
        self.buildingData = buildingData
    }

    func build() -> String {
        DeclarationBuilder(accessModifier: buildingData.accessModifier, signature: "init(from decoder: Decoder) throws") {
            if let defaultKey = buildingData.defaultKey, buildingData.strategy == .codingKeys {
                "if let container = try? decoder.container(keyedBy: CodingKeys.self) {"
                if buildingData.isStrict {
                    "try StrictDecoding.rejectUnknownKeys(in: decoder, allowed: CodingKeys.allCases)"
                }
                buildingData.items.map { item in "self.\(item.identifier) = \(item.function.build())" }
                "} else {"
                "let container = try decoder.singleValueContainer()"
                "self.\(defaultKey.identifier) = try container.decode(\(defaultKey.typeName))"
                defaultKey.fallbacks.map { "self.\($0.identifier) = \($0.value)" }
                "}"
            } else if buildingData.items.isEmpty {
                ""
            } else {
                switch buildingData.strategy {
                case .singleValue:
                    "let container = try decoder.singleValueContainer()"
                case .codingKeys:
                    "let container = try decoder.container(keyedBy: CodingKeys.self)"
                }

                if buildingData.isStrict {
                    "try StrictDecoding.rejectUnknownKeys(in: decoder, allowed: CodingKeys.allCases)"
                }

                buildingData.items
                    .map { item in
                        "self.\(item.identifier) = \(item.function.build())"
                    }
            }

            if buildingData.isValidated {
                "try validate()"
            }
        }.build()
    }
}
