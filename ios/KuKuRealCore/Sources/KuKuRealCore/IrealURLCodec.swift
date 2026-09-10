import Foundation

public enum IrealURLError: Error, Equatable {
    case invalidPrefix
    case musicFieldNotFound
}

/// Reads and writes the `irealb://` URL format. Multi-song playlists
/// (`===`-separated) are not handled — the whole body is parsed as one song.
/// (A `===` split was tried, but it's ambiguous: a single song with an empty
/// composer already serializes as `title==...`, and prepending the standard
/// `==` before style adds up to a spurious `===` that isn't a real playlist
/// boundary — same ambiguity the original iReal Pro-format tooling has.)
///
/// Splits on runs of `=` *before* percent-decoding each field individually
/// (rather than decoding the whole body up front). That order matters: a
/// literal `=` inside a title/lyric is percent-encoded as `%3D` by the
/// encoder, and decoding the whole body first would turn it back into `=`
/// before the split runs, corrupting the field boundaries.
public enum IrealURLCodec {
    private static let scheme = "irealb://"

    public static func parse(_ rawUrl: String) throws -> Song {
        guard rawUrl.hasPrefix(scheme) else { throw IrealURLError.invalidPrefix }
        let body = String(rawUrl.dropFirst(scheme.count))
        let parts = splitOnEqualsRuns(body).map(URLCoding.decodeURIComponent)

        guard let mIdx = parts.firstIndex(where: { $0.contains(IrealCrypto.musicPrefix) }) else {
            throw IrealURLError.musicFieldNotFound
        }

        let title = parts.indices.contains(0) && !parts[0].isEmpty ? parts[0] : "Untitled"
        let composer = parts.indices.contains(1) ? parts[1] : ""
        let style = mIdx >= 3 ? parts[mIdx - 2] : ""
        let key = mIdx >= 2 && !parts[mIdx - 1].isEmpty ? parts[mIdx - 1] : "C"
        let dsl = IrealCrypto.decodeMusic(parts[mIdx])

        return Song(title: title, composer: composer, style: style, key: key, tokens: Tokenizer.tokenize(dsl))
    }

    /// Builds a single-song `irealb://` URL with trailing `bpm=0`, `repeats=0`
    /// fields (transpose/playback settings the app doesn't manage yet).
    public static func build(_ song: Song) -> String {
        let dsl = song.tokens.map(\.raw).joined()
        let musicField = IrealCrypto.musicPrefix + IrealCrypto.unscramble(dsl)

        let t = URLCoding.encodeURIComponent(song.title.isEmpty ? "Untitled" : song.title)
        let c = URLCoding.encodeURIComponent(song.composer)
        let st = URLCoding.encodeURIComponent(song.style)
        let k = URLCoding.encodeURIComponent(song.key.isEmpty ? "C" : song.key)
        let m = URLCoding.encodeURIComponent(musicField)

        return "\(scheme)\(t)=\(c)==\(st)=\(k)==\(m)==0=0"
    }

    /// Splits on one-or-more consecutive `=`, dropping empty segments —
    /// equivalent to JS's `s.split(/=+/).filter(x => x !== '')`.
    private static func splitOnEqualsRuns(_ s: String) -> [String] {
        var result: [String] = []
        var current = ""
        for ch in s {
            if ch == "=" {
                if !current.isEmpty { result.append(current); current = "" }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
