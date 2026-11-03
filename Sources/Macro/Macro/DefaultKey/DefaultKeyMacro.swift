import SwiftSyntax
import SwiftSyntaxMacros

/// Peer macro — serves only as an annotation read by `CodableMacro`.
public struct DefaultKeyMacro: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf _: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
