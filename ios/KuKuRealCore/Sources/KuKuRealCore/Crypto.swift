import Foundation

/// iReal Pro's `music` field obfuscation. The operation is a self-inverse
/// (symmetric) block permutation, so the same function encodes and decodes.
public enum IrealCrypto {
    public static let musicPrefix = "1r34LbKcu7"

    /// Swaps positions 0-4 with 49-45 and 10-23 with 39-26 within a 50-char block.
    static func obfusc50(_ chars: [Character]) -> [Character] {
        var a = chars
        for i in 0..<5 { a.swapAt(i, 49 - i) }
        for i in 10..<24 { a.swapAt(i, 49 - i) }
        return a
    }

    /// Applies `obfusc50` to every full 50-char block, leaving the trailing
    /// remainder untouched (blocks with fewer than 2 chars left over are
    /// also left unpermuted, matching the reference implementation).
    public static func unscramble(_ s: String) -> String {
        var result = ""
        var rest = Array(s)
        while rest.count > 50 {
            let chunk = Array(rest[0..<50])
            rest.removeFirst(50)
            result += rest.count < 2 ? String(chunk) : String(obfusc50(chunk))
        }
        result += String(rest)
        return result
    }

    /// Strips the `1r34LbKcu7` prefix from a music field and unscrambles the rest.
    /// Returns the field unchanged if the prefix isn't found.
    public static func decodeMusic(_ field: String) -> String {
        guard let range = field.range(of: musicPrefix) else { return field }
        return unscramble(String(field[range.upperBound...]))
    }
}
