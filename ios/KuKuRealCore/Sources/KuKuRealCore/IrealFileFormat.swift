import Foundation

/// Reads and writes the `.html`/`.ireal` file wrapper iReal Pro itself
/// exports — an XHTML document with a single `<a href="irealb://...">`
/// link. Matches `exportSong()` in `ireal_editor.html` byte-for-byte in
/// structure, so a chart saved here opens correctly in the real iReal Pro
/// app (and vice versa for import).
public enum IrealFileFormat {
    public enum FileError: Error, Equatable {
        case noLinkFound
    }

    public static func build(_ song: Song) -> String {
        let url = IrealURLCodec.build(song)
        let title = song.title.isEmpty ? "Untitled" : song.title
        return """
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><meta charset="UTF-8"><title>iReal Pro</title></head>
        <body>
        <h3><a href="\(url.replacingOccurrences(of: "\"", with: "&quot;"))">\(escapeHTML(title))</a> - \(escapeHTML(song.composer))</h3>
        <br/>Made with KuKuReal
        </body>
        </html>
        """
    }

    /// Extracts and parses the first `irealb://` link found in file content
    /// (an exported `.html`, or a real iReal Pro `.ireal` export — both are
    /// the same underlying format).
    public static func parse(_ fileContents: String) throws -> Song {
        let pattern = try! NSRegularExpression(pattern: #"href="(irealb://[^"]+)""#)
        let nsString = fileContents as NSString
        guard let match = pattern.firstMatch(in: fileContents, range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges > 1 else {
            throw FileError.noLinkFound
        }
        let url = nsString.substring(with: match.range(at: 1))
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
        return try IrealURLCodec.parse(url)
    }

    /// A filesystem-safe filename (no extension) derived from the title,
    /// mirroring the export button's `title.replace(/[^\w\s-]/g,'').trim()`.
    public static func suggestedFilename(for song: Song) -> String {
        let title = song.title.isEmpty ? "Untitled" : song.title
        let cleaned = title.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" || $0 == "_" }
            .map(Character.init)
        let result = String(cleaned).trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? "Untitled" : result
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
