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
/// @CodedAt("kind", caseStyle: .screamingSnakeCase)
/// @ContentAt("details")
/// enum Command {
///     case ping
///     case message(text: String)
///     case move(axis: String, unit: String, amount: Int?)
/// }
/// ```
/// Encodes `Command.message(text: "hi")` as:
/// ```json
/// {"kind": "MESSAGE", "details": {"text": "hi"}}
/// ```
/// Encodes `Command.ping` as:
/// ```json
/// {"kind": "PING"}
/// ```
@attached(extension, conformances: Decodable, Encodable, names: named(CodingKeys), named(init(from:)), named(encode(to:)))
public macro TaggedCodable() = #externalMacro(module: "Macro", type: "TaggedCodableMacro")

/// Specifies the discriminator key name and case-name transformation style
/// for ``TaggedCodable()``.
///
/// - Parameters:
///   - key: The JSON key used as the discriminator (e.g. `"kind"`).
///   - caseStyle: How enum case names map to tag values. Defaults to `.screamingSnakeCase`.
@attached(peer)
public macro CodedAt(_ key: String, caseStyle: TaggedCodableCaseStyle = .screamingSnakeCase) = #externalMacro(module: "Macro", type: "CodedAtMacro")

/// Specifies the JSON key under which associated values are nested for
/// ``TaggedCodable()``.
///
/// - Parameter key: The JSON key for the params object (e.g. `"details"`).
@attached(peer)
public macro ContentAt(_ key: String) = #externalMacro(module: "Macro", type: "ContentAtMacro")
