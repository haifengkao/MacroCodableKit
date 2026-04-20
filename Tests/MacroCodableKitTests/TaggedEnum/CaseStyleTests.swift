import MacroCodableKit
import XCTest

final class CaseStyleTests: XCTestCase {
    func test_tokenize() {
        XCTAssertEqual(CaseConverter.tokenize("sampleEntry"), ["sample", "entry"])
        XCTAssertEqual(CaseConverter.tokenize("SampleEntry"), ["sample", "entry"])
        XCTAssertEqual(CaseConverter.tokenize("sample_entry"), ["sample", "entry"])
        XCTAssertEqual(CaseConverter.tokenize("sample-entry"), ["sample", "entry"])
        XCTAssertEqual(CaseConverter.tokenize("apple123Basket"), ["apple123", "basket"])
    }

    func test_format() {
        XCTAssertEqual(CaseConverter.format("sample_entry", to: .verbatim), "sample_entry")
        XCTAssertEqual(CaseConverter.format("sample_entry", to: .camelCase), "sampleEntry")
        XCTAssertEqual(CaseConverter.format("sample_entry", to: .pascalCase), "SampleEntry")
        XCTAssertEqual(CaseConverter.format("sampleEntry", to: .snakeCase), "sample_entry")
        XCTAssertEqual(CaseConverter.format("sampleEntry", to: .screamingSnakeCase), "SAMPLE_ENTRY")
        XCTAssertEqual(CaseConverter.format("sampleEntry", to: .kebabCase), "sample-entry")
        XCTAssertEqual(CaseConverter.format("apple123Basket", to: .snakeCase), "apple123_basket")
    }
}
