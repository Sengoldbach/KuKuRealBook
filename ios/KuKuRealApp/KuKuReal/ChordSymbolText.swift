import SwiftUI
import KuKuRealCore

/// Composes a raw chord token into a properly typeset chord symbol — big
/// root letter, superscript accidental, Δ/ø/° quality glyphs, smaller
/// trailing bass — mirroring `renderChordSVG()` in `ireal_editor.html`.
/// Shared by the chart grid cells and the chord-entry preview badge so both
/// show the exact same rendering.
enum ChordSymbolText {
    static func render(
        _ raw: String,
        rootSize: CGFloat = 13,
        accSize: CGFloat = 9,
        qualitySize: CGFloat = 10,
        bassSize: CGFloat = 9,
        color: Color = Theme.chord
    ) -> Text {
        // Root stays bold monospaced — it's the anchor glyph. Everything
        // else (accidental, quality, bass) is medium-weight default-design:
        // lighter so it reads as an annotation on the root rather than
        // competing with it, and Δ/ø/° render as cleaner shapes outside the
        // monospaced face. Bass is dimmed slightly to separate it visually
        // from the quality glyphs it's now sitting flush against.
        let rootFont = Font.system(size: rootSize, weight: .bold, design: .monospaced)
        let accFont = Font.system(size: accSize, weight: .medium, design: .default)
        let qualityFont = Font.system(size: qualitySize, weight: .medium, design: .default)
        let bassFont = Font.system(size: bassSize, weight: .medium, design: .monospaced)
        let bassColor = color.opacity(0.8)

        guard !raw.isEmpty, let spelling = ChordSpellingParser.parse(raw) else {
            return Text(raw).font(rootFont).foregroundColor(color)
        }

        guard let root = spelling.root else {
            // Invisible root: only the bass note is meant to be shown.
            let bassText = spelling.bass.map { "/" + $0.display } ?? raw
            return Text(bassText).font(.system(size: rootSize - 2, weight: .semibold, design: .monospaced)).foregroundColor(color)
        }

        var text = Text(root.letter.rawValue).font(rootFont).foregroundColor(color)
        if root.accidental != .natural {
            text = text + Text(root.accidental == .flat ? "♭" : "♯").font(accFont).foregroundColor(color).baselineOffset(4)
        }
        let qualityDisplay = spelling.quality.raw
            .replacingOccurrences(of: "^", with: "Δ")
            .replacingOccurrences(of: "h", with: "ø")
            .replacingOccurrences(of: "o", with: "°")
        if !qualityDisplay.isEmpty {
            text = text + Text(qualityDisplay).font(qualityFont).foregroundColor(color)
        }
        if let bass = spelling.bass {
            text = text + Text("/" + bass.display).font(bassFont).foregroundColor(bassColor)
        }
        return text
    }
}
