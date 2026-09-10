import Foundation

/// The token-building rules behind a chord-entry UI (the web editor's
/// "symbol bar": tap root/quality/extension buttons to build up a chord,
/// with the grid cell updating live after every tap). Kept in Core so the
/// grammar — same special symbols, same validation — has one implementation
/// shared by every chord-entry surface, not just the first one.
public enum ChordEntry {
    private static let specials: [String: (raw: String, extra: String)] = [
        "%": ("x", "%"),
        "//": ("r", "//"),
        "/": ("p", "/"),
        "N.C.": ("n", "N.C."),
        "n.c.": ("n", "N.C."),
        "nc": ("n", "N.C."),
    ]

    /// Builds the token a chord-entry UI should write into `song.tokens[idx]`
    /// for the given free-text input.
    /// - Empty text clears the cell to a blank space.
    /// - Recognized special symbols (`%`, `//`, `/`, `N.C.`) become their
    ///   dedicated pseudo-chord tokens.
    /// - Anything else must fully match the chord grammar, or this returns
    ///   `nil` (caller should reject the edit / keep waiting for more input —
    ///   e.g. a trailing bare `/` before a bass letter is picked).
    public static func makeToken(from text: String) -> Token? {
        if text.isEmpty {
            return Token(raw: " ", type: .space, cells: 1, barline: false)
        }
        if let sp = specials[text] ?? specials[text.lowercased()] {
            return Token(raw: sp.raw, type: .chord, cells: 1, barline: false, extra: sp.extra)
        }
        guard Tokenizer.isCompleteChordText(text) else { return nil }
        return Token(raw: text, type: .chord, cells: 1, barline: false)
    }

    /// The text a chord-entry UI should show for an existing token — mirrors
    /// the web editor's `t.extra || t.raw`.
    public static func displayText(for token: Token) -> String {
        token.extra ?? token.raw
    }
}
