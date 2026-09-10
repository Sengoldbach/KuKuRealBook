import Foundation

/// A chord token's harmonic content: root, quality, and optional bass note.
/// `root` is `nil` for iReal's invisible-root chords (raw text starts with
/// `W`, e.g. `"W/G"` — only the slash bass is meant to be shown/played).
public struct ChordSpelling: Equatable {
    public var root: NoteName?
    public var quality: ChordQuality
    public var bass: NoteName?

    public init(root: NoteName?, quality: ChordQuality, bass: NoteName?) {
        self.root = root
        self.quality = quality
        self.bass = bass
    }
}

public enum ChordSpellingParser {
    /// Parses a chord token's raw text (`Token.raw` for `.chord` tokens with
    /// no `extra` — i.e. not the `r`/`x`/`p`/`n` pseudo-chords). Returns
    /// `nil` only when the text doesn't even start with a valid root letter
    /// or `W`; an unrecognized *quality* suffix still returns a spelling
    /// (with `quality.recognized == false`) rather than failing outright.
    public static func parse(_ raw: String) -> ChordSpelling? {
        let chars = Array(raw)
        guard let first = chars.first else { return nil }

        var root: NoteName?
        var i: Int

        if first == "W" {
            i = 1
        } else if let letter = Letter(rawValue: String(first)) {
            i = 1
            var accidental: Accidental = .natural
            if i < chars.count, chars[i] == "b" { accidental = .flat; i += 1 }
            else if i < chars.count, chars[i] == "#" { accidental = .sharp; i += 1 }
            root = NoteName(letter: letter, accidental: accidental)
        } else {
            return nil
        }

        let rest = String(chars[i...])
        let parts = rest.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let qualitySuffix = String(parts[0])
        let bass = parts.count > 1 ? parseNoteName(String(parts[1])) : nil

        return ChordSpelling(root: root, quality: ChordQualityParser.parse(qualitySuffix), bass: bass)
    }

    private static func parseNoteName(_ s: String) -> NoteName? {
        let chars = Array(s)
        guard let first = chars.first, let letter = Letter(rawValue: String(first)) else { return nil }
        var accidental: Accidental = .natural
        if chars.count > 1, chars[1] == "b" { accidental = .flat }
        else if chars.count > 1, chars[1] == "#" { accidental = .sharp }
        return NoteName(letter: letter, accidental: accidental)
    }
}
