/// Generates `Decodable` and `Encodable` conformances for an enum using an
/// adjacently tagged format: one key for the discriminator tag, another for
/// the associated-value parameters.
///
/// Use together with ``CodedAt(_:caseStyle:keyStyle:)`` and optionally ``ContentAt(_:)``:
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
@attached(extension, conformances: Decodable, Encodable, names: arbitrary)
public macro TaggedCodable() = #externalMacro(module: "Macro", type: "TaggedCodableMacro")

/// Specifies the discriminator key name and case-name transformation style
/// for ``TaggedCodable()``.
///
/// - Parameters:
///   - key: The JSON key used as the discriminator (e.g. `"kind"`).
///   - caseStyle: How enum case names map to tag values. Defaults to `.verbatim`.
///   - keyStyle: How associated-value labels map to JSON keys. Defaults to `.verbatim`.
///   - strict: Throw when the JSON has a key this case doesn't declare. Defaults to `false`.
///   - validated: Call `try validate()` after decoding. Defaults to `false`.
@attached(peer)
public macro CodedAt(_ key: String, caseStyle: CaseStyle = .verbatim, keyStyle: CaseStyle = .verbatim, strict: Bool = false, validated: Bool = false) = #externalMacro(module: "Macro", type: "CodedAtMacro")

/// Overrides the tag value of one enum case for ``TaggedCodable()``.
///
/// - Parameter tag: The exact JSON tag string for this case.
@attached(peer)
public macro CaseTag(_ tag: String) = #externalMacro(module: "Macro", type: "CaseTagMacro")

/// Specifies the JSON key under which associated values are nested for
/// ``TaggedCodable()``. Leave it out and associated values are siblings of the
/// tag: `{"kind": "MESSAGE", "text": "hi"}`.
///
/// A case with one unlabeled associated value stores that value directly at this key.
///
/// - Parameter key: The JSON key for the params object (e.g. `"details"`).
@attached(peer)
public macro ContentAt(_ key: String) = #externalMacro(module: "Macro", type: "ContentAtMacro")
