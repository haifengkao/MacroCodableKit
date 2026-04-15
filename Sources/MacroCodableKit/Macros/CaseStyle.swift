import Foundation

public enum CaseStyle {
    case verbatim
    case camelCase
    case pascalCase
    case snakeCase
    case screamingSnakeCase
    case kebabCase
}

public struct CaseConverter {
    public static func tokenize(_ input: String) -> [String] {
        let splitCamel = input.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )

        let separators = CharacterSet.alphanumerics.inverted
        let components = splitCamel.components(separatedBy: separators)

        return components
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
    }

    public static func format(_ string: String, to style: CaseStyle) -> String {
        let tokens = tokenize(string)
        guard !tokens.isEmpty else { return string }

        switch style {
        case .verbatim:
            return string
        case .camelCase:
            let first = tokens[0]
            let rest = tokens.dropFirst().map(\.capitalized)
            return first + rest.joined()
        case .pascalCase:
            return tokens.map(\.capitalized).joined()
        case .snakeCase:
            return tokens.joined(separator: "_")
        case .screamingSnakeCase:
            return tokens.joined(separator: "_").uppercased()
        case .kebabCase:
            return tokens.joined(separator: "-")
        }
    }
}

@available(*, deprecated, renamed: "CaseStyle")
public typealias TaggedCodableCaseStyle = CaseStyle
