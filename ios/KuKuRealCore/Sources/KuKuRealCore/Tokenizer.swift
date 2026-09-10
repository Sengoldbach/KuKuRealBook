import Foundation

/// Ported from the editor's `tokenize()` (ireal_editor.html). Scans the
/// decrypted DSL string left-to-right, matching tokens by priority. `XyQ`
/// and `LZ` are expanded into their constituent space/barline tokens so
/// every token in the output is independently editable and re-serializable.
public enum Tokenizer {
    private static let rootChars: Set<Character> = ["A", "B", "C", "D", "E", "F", "G", "W"]
    private static let bassRootChars: Set<Character> = ["A", "B", "C", "D", "E", "F", "G"]
    private static let qualityChars: Set<Character> = ["+", "-", "^", "h", "o", "b", "#", "s", "u", "a", "d", "t"]

    public static func tokenize(_ s: String) -> [Token] {
        let chars = Array(s)
        let n = chars.count
        var tokens: [Token] = []
        var i = 0

        func slice(_ from: Int, _ to: Int) -> String {
            String(chars[from..<min(to, n)])
        }

        while i < n {
            let c = chars[i]

            if slice(i, i + 3) == "XyQ" {
                tokens.append(Token(raw: " ", type: .space, cells: 1, barline: false))
                tokens.append(Token(raw: " ", type: .space, cells: 1, barline: false))
                tokens.append(Token(raw: " ", type: .space, cells: 1, barline: false))
                i += 3; continue
            }
            if slice(i, i + 2) == "LZ" {
                tokens.append(Token(raw: " ", type: .space, cells: 1, barline: false))
                tokens.append(Token(raw: "|", type: .barline, cells: 0, barline: true, barlineType: .single))
                i += 2; continue
            }
            if c == "|" { tokens.append(Token(raw: "|", type: .barline, cells: 0, barline: true, barlineType: .single)); i += 1; continue }
            if c == "[" { tokens.append(Token(raw: "[", type: .barline, cells: 0, barline: true, barlineType: .double)); i += 1; continue }
            if c == "]" { tokens.append(Token(raw: "]", type: .barline, cells: 0, barline: true, barlineType: .rdouble)); i += 1; continue }
            if c == "{" { tokens.append(Token(raw: "{", type: .barline, cells: 0, barline: true, barlineType: .repOpen)); i += 1; continue }
            if c == "}" { tokens.append(Token(raw: "}", type: .barline, cells: 0, barline: true, barlineType: .repClose)); i += 1; continue }
            if c == "Z" { tokens.append(Token(raw: "Z", type: .barline, cells: 0, barline: true, barlineType: .final)); i += 1; continue }
            if c == " " { tokens.append(Token(raw: " ", type: .space, cells: 1, barline: false)); i += 1; continue }

            if c == "T", i + 1 < n, chars[i + 1].isASCIIDigit {
                var j = i + 1
                while j < n, chars[j].isASCIIDigit { j += 1 }
                tokens.append(Token(raw: slice(i, j), type: .timesig, cells: 0, barline: false))
                i = j; continue
            }
            if c == "*", i + 1 < n {
                tokens.append(Token(raw: "*" + String(chars[i + 1]), type: .mark, cells: 0, barline: false))
                i += 2; continue
            }
            if c == "<" {
                if let closeIdx = findChar(">", in: chars, from: i, n: n), closeIdx > i {
                    tokens.append(Token(raw: slice(i, closeIdx + 1), type: .annotation, cells: 0, barline: false))
                    i = closeIdx + 1; continue
                }
            }
            if slice(i, i + 3) == "Kcl" {
                tokens.append(Token(raw: "|", type: .barline, cells: 0, barline: true, barlineType: .single))
                tokens.append(Token(raw: " ", type: .space, cells: 1, barline: false))
                tokens.append(Token(raw: "p", type: .chord, cells: 1, barline: false, extra: "/"))
                i += 3; continue
            }
            if c == "r" { tokens.append(Token(raw: "r", type: .chord, cells: 1, barline: false, extra: "//")); i += 1; continue }
            if c == "x" { tokens.append(Token(raw: "x", type: .chord, cells: 1, barline: false, extra: "%")); i += 1; continue }
            if c == "Y" {
                var j = i
                while j < n, chars[j] == "Y" { j += 1 }
                tokens.append(Token(raw: slice(i, j), type: .layout, cells: 0, barline: false))
                i = j; continue
            }
            if c == "p" { tokens.append(Token(raw: "p", type: .chord, cells: 1, barline: false, extra: "/")); i += 1; continue }
            if c == "n" { tokens.append(Token(raw: "n", type: .chord, cells: 1, barline: false, extra: "N.C.")); i += 1; continue }
            if c == "N", i + 1 < n, chars[i + 1].isASCIIDigit {
                tokens.append(Token(raw: "N" + String(chars[i + 1]), type: .mark, cells: 0, barline: false))
                i += 2; continue
            }
            if c == "Q" { tokens.append(Token(raw: "Q", type: .mark, cells: 0, barline: false, extra: "Coda")); i += 1; continue }
            if c == "S" { tokens.append(Token(raw: "S", type: .mark, cells: 0, barline: false, extra: "Segno")); i += 1; continue }
            if c == "U" { tokens.append(Token(raw: "U", type: .mark, cells: 0, barline: false, extra: "End")); i += 1; continue }
            if c == "f" { tokens.append(Token(raw: "f", type: .mark, cells: 0, barline: false, extra: "\u{1D110}")); i += 1; continue }
            if c == "," { tokens.append(Token(raw: ",", type: .sep, cells: 0, barline: false)); i += 1; continue }
            if c == "l" { tokens.append(Token(raw: "l", type: .size, cells: 0, barline: false, extra: "normal")); i += 1; continue }
            if c == "s", !(i + 1 < n && chars[i + 1] == "u") {
                tokens.append(Token(raw: "s", type: .size, cells: 0, barline: false, extra: "small")); i += 1; continue
            }

            if let matchLen = matchChord(chars, at: i, n: n) {
                tokens.append(Token(raw: slice(i, i + matchLen), type: .chord, cells: 1, barline: false))
                i += matchLen; continue
            }

            tokens.append(Token(raw: String(c), type: .unknown, cells: 0, barline: false))
            i += 1
        }

        var merged: [Token] = []
        for tok in tokens {
            if tok.type == .unknown, !merged.isEmpty, merged[merged.count - 1].type == .unknown {
                merged[merged.count - 1].raw += tok.raw
            } else {
                merged.append(tok)
            }
        }
        return merged
    }

    /// Whether `s` is, in its entirety, one valid chord token — the anchored
    /// form of the chord grammar (`^...$`, not just a prefix match). Used by
    /// chord-entry UI to validate free text before committing it to a token.
    public static func isCompleteChordText(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        let chars = Array(s)
        guard let length = matchChord(chars, at: 0, n: chars.count) else { return false }
        return length == chars.count
    }

    /// `/^[A-GW][+\-^\dhob#suadt]*(\/[A-G][#b]?)?/` reimplemented as a manual scan.
    private static func matchChord(_ chars: [Character], at start: Int, n: Int) -> Int? {
        guard start < n, rootChars.contains(chars[start]) else { return nil }
        var j = start + 1
        while j < n, chars[j].isASCIIDigit || qualityChars.contains(chars[j]) { j += 1 }
        if j + 1 < n, chars[j] == "/", bassRootChars.contains(chars[j + 1]) {
            var k = j + 2
            if k < n, chars[k] == "#" || chars[k] == "b" { k += 1 }
            j = k
        }
        return j - start
    }

    private static func findChar(_ target: Character, in chars: [Character], from: Int, n: Int) -> Int? {
        var j = from
        while j < n {
            if chars[j] == target { return j }
            j += 1
        }
        return nil
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
