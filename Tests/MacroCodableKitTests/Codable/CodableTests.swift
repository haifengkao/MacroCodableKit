//
//  CodableTests.swift
//
//
//  Created by Mikhail Maslo on 24.09.23.
//

import MacroCodableKit
import XCTest

final class CodableTests: XCTestCase {
    @Codable
    struct NestedCodable: Equatable {
        @Codable
        struct B: Equatable {
            let int: Int
            let boolean: Bool

            @CodingKey("string_string")
            let stringString: String
        }

        @Codable
        struct C: Equatable {
            let anotherInt: Int
        }

        let b: B
        let c: C
    }

    @Codable(caseStyle: .snakeCase)
    struct SnakeCaseCodable: Equatable {
        let primaryValue: String
        let secondaryLabel: String?
        let apple123Basket: String

        @CodingKey("ManualName")
        let customField: String?
    }

    func test_ValidNestedCodable() throws {
        let testCases: [(String, NestedCodable)] = [
            (
                #"{"b":{"int":1,"boolean":true,"string_string":"string string"},"c":{"anotherInt":1}}"#,
                NestedCodable(b: NestedCodable.B(int: 1, boolean: true, stringString: "string string"), c: NestedCodable.C(anotherInt: 1))
            ),
        ]
        for testCase in testCases {
            guard let data = testCase.0.data(using: .utf8) else {
                XCTFail("Couldn't get data from \(testCase.0)")
                continue
            }

            XCTAssertEqual(try JSONDecoder().decode(NestedCodable.self, from: data), testCase.1)
            XCTAssertEqual(try JSONDecoder().decode(NestedCodable.self, from: try JSONEncoder().encode(testCase.1)), testCase.1)
        }
    }

    func test_InvalidNestedCodable() {
        let json = "{\"int\": 1, \"boolean\": true, \"string\": \"some string\"}"
        do {
            _ = try json.data(using: .utf8).flatMap { try JSONDecoder().decode(NestedCodable.self, from: $0) }
            XCTFail("Shouldn't decode invalid \(json)")
        } catch {}
    }

    func test_SnakeCaseStyleAppliesToGeneratedCodingKeys() throws {
        let json = #"{"primary_value":"alpha","secondary_label":"beta","apple123_basket":"fruit","ManualName":"gamma"}"#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(SnakeCaseCodable.self, from: data)

        XCTAssertEqual(
            decoded,
            SnakeCaseCodable(
                primaryValue: "alpha",
                secondaryLabel: "beta",
                apple123Basket: "fruit",
                customField: "gamma"
            )
        )

        let encoded = try JSONEncoder().encode(decoded)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: String])

        XCTAssertEqual(object["primary_value"], "alpha")
        XCTAssertEqual(object["secondary_label"], "beta")
        XCTAssertEqual(object["apple123_basket"], "fruit")
        XCTAssertEqual(object["ManualName"], "gamma")
        XCTAssertNil(object["primaryValue"])
        XCTAssertNil(object["secondaryLabel"])
        XCTAssertNil(object["apple123Basket"])
        XCTAssertNil(object["customField"])
    }
}
