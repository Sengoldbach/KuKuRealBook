import Foundation

public struct Song: Equatable, Codable {
    public var title: String
    public var composer: String
    public var style: String
    public var key: String
    public var tokens: [Token]

    public init(
        title: String = "Untitled",
        composer: String = "",
        style: String = "Medium Swing",
        key: String = "C",
        tokens: [Token] = []
    ) {
        self.title = title
        self.composer = composer
        self.style = style
        self.key = key
        self.tokens = tokens
    }

    /// A fresh 16-bar chart bounded by a double barline and a final barline,
    /// matching the editor's `blankTokens()`.
    public static func blank() -> Song {
        var toks: [Token] = []
        toks.append(Token(raw: "[", type: .barline, cells: 0, barline: true, barlineType: .double))
        for measure in 0..<16 {
            for _ in 0..<4 {
                toks.append(Token(raw: " ", type: .space, cells: 1, barline: false))
            }
            if measure < 15 {
                toks.append(Token(raw: "|", type: .barline, cells: 0, barline: true, barlineType: .single))
            }
        }
        // .rdouble (not .double) to match what Tokenizer itself assigns to ']',
        // so a freshly-built blank chart round-trips identically through parse().
        toks.append(Token(raw: "]", type: .barline, cells: 0, barline: true, barlineType: .rdouble))
        toks.append(Token(raw: "Z", type: .barline, cells: 0, barline: true, barlineType: .final))
        return Song(tokens: toks)
    }
}
