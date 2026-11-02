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
    }

    private let buildingData: BuildingData

    init(buildingData: BuildingData) {
        self.buildingData = buildingData
    }

    func build() -> String {
        DeclarationBuilder(accessModifier: buildingData.accessModifier, signature: "init(from decoder: Decoder) throws") {
            if buildingData.items.isEmpty {
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
