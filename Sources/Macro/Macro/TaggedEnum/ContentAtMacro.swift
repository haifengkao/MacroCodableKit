import SwiftSyntax
import SwiftSyntaxMacros

/// Peer macro — serves only as an annotation read by `TaggedCodableMacro`.
public struct ContentAtMacro: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf _: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
