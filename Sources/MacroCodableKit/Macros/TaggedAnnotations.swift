/// The strategy used to transform enum case names into the serialized tag value.
public enum TaggedCodableCaseStyle {
    case verbatim
    case camelCase
    case snakeCase
    case screamingSnakeCase
}

/// Generates `Decodable` and `Encodable` conformances for an enum using an
/// adjacently tagged format: one key for the discriminator tag, another for
/// the associated-value parameters.
///
/// Use together with ``CodedAt(_:caseStyle:)`` and ``ContentAt(_:)``:
/// ```swift
/// @TaggedCodable
/// @CodedAt("intent", caseStyle: .screamingSnakeCase)
/// @ContentAt("intent_params")
/// enum Command {
///     case scroll
///     case search(query: String)
///     case paginate(direction: String, scope: String, target: Int?)
/// }
/// ```
/// Encodes `Command.search(query: "hi")` as:
/// ```json
/// {"intent": "SEARCH", "intent_params": {"query": "hi"}}
/// ```
/// Encodes `Command.scroll` as:
/// ```json
/// {"intent": "SCROLL"}
/// ```
@attached(extension, conformances: Decodable, Encodable, names: arbitrary)
public macro TaggedCodable() = #externalMacro(module: "Macro", type: "TaggedCodableMacro")

/// Specifies the discriminator key name and case-name transformation style
/// for ``TaggedCodable()``.
///
/// - Parameters:
///   - key: The JSON key used as the discriminator (e.g. `"intent"`).
///   - caseStyle: How enum case names map to tag values. Defaults to `.screamingSnakeCase`.
@attached(peer)
public macro CodedAt(_ key: String, caseStyle: TaggedCodableCaseStyle = .screamingSnakeCase) = #externalMacro(module: "Macro", type: "CodedAtMacro")

/// Specifies the JSON key under which associated values are nested for
/// ``TaggedCodable()``.
///
/// - Parameter key: The JSON key for the params object (e.g. `"intent_params"`).
@attached(peer)
public macro ContentAt(_ key: String) = #externalMacro(module: "Macro", type: "ContentAtMacro")
