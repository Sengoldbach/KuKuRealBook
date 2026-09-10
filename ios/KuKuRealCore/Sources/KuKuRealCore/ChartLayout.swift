import Foundation

/// A single grid cell in a rendered chart: one beat/space slot, with
/// whatever decorations (barline, section mark, volta bracket, time
/// signature) were pending on the token stream when it was emitted.
public struct ChartCell: Equatable {
    public enum Content: Equatable {
        /// Raw chord text, unmodified (e.g. `"Ab^7/C"`, or `"W/G"` for an
        /// invisible root) — pass it to `ChordSpellingParser` to typeset it.
        case chord(String)
        case space
        case repeatOneBar    // 'x' → displays '%'
        case repeatTwoBars   // 'r' → displays '//'
        case pause           // 'p' / expanded 'Kcl' → displays '/'
        case noChord         // 'n' → displays 'N.C.'
    }

    public var content: Content
    public var leftBarline: BarlineType?
    public var sectionMark: String?
    public var volta: String?
    public var timeSigTop: String?
    public var timeSigBottom: String?
    /// Index into the `[Token]` array this cell was produced from — lets an
    /// editor find-and-replace the exact token behind a tapped cell.
    public var tokenIndex: Int

    public init(
        content: Content,
        leftBarline: BarlineType? = nil,
        sectionMark: String? = nil,
        volta: String? = nil,
        timeSigTop: String? = nil,
        timeSigBottom: String? = nil,
        tokenIndex: Int
    ) {
        self.content = content
        self.leftBarline = leftBarline
        self.sectionMark = sectionMark
        self.volta = volta
        self.timeSigTop = timeSigTop
        self.timeSigBottom = timeSigBottom
        self.tokenIndex = tokenIndex
    }
}

public enum ChartRow: Equatable {
    case cells([ChartCell])
    /// A full-width vertical gap (iReal's `Y`/`YY`/`YYY` layout token).
    /// `units` is the run length (1 for `Y`, 3 for `YYY`); rendering scales
    /// it to pixels.
    case spacer(units: Int)
}

/// Arranges a flat token stream into fixed-width rows, mirroring the
/// CSS-grid renderer in `renderer.js` (`repeat(16, 1fr)`, auto-wrapping,
/// full-span spacer rows for `Y` tokens). Framework-agnostic — no SwiftUI
/// dependency — so it's unit-testable on its own.
public enum ChartLayout {
    public static let columnsPerRow = 16

    public static func rows(for tokens: [Token]) -> [ChartRow] {
        var rows: [ChartRow] = []
        var currentRow: [ChartCell] = []

        var pendingBarlineLeft: BarlineType?
        var pendingMark: String?
        var pendingVolta: String?
        var pendingTimeSig: (top: String, bottom: String)?

        func appendCell(_ content: ChartCell.Content, tokenIndex: Int) {
            var cell = ChartCell(content: content, tokenIndex: tokenIndex)
            if let bl = pendingBarlineLeft { cell.leftBarline = bl; pendingBarlineLeft = nil }
            if let mark = pendingMark { cell.sectionMark = mark; pendingMark = nil }
            if let volta = pendingVolta { cell.volta = volta; pendingVolta = nil }
            if let ts = pendingTimeSig { cell.timeSigTop = ts.top; cell.timeSigBottom = ts.bottom; pendingTimeSig = nil }
            currentRow.append(cell)
            if currentRow.count == columnsPerRow {
                rows.append(.cells(currentRow))
                currentRow = []
            }
        }

        for (tokenIndex, t) in tokens.enumerated() {
            switch t.type {
            case .size, .sep, .unknown, .annotation:
                continue

            case .layout:
                if !currentRow.isEmpty { rows.append(.cells(currentRow)); currentRow = [] }
                rows.append(.spacer(units: t.raw.count))

            case .timesig:
                // raw = "T44" / "T68" / etc. Index into the digits directly
                // (raw[1], raw[2]) rather than regex-matching all digits, so
                // "T44" reads as top='4' bottom='4' and not the string "44".
                let digits = Array(t.raw.dropFirst())
                let top = digits.indices.contains(0) ? String(digits[0]) : "?"
                let bottom = digits.indices.contains(1) ? String(digits[1]) : "?"
                pendingTimeSig = (top, bottom)

            case .mark:
                if t.raw.hasPrefix("*") {
                    pendingMark = String(t.raw.dropFirst())
                } else if t.raw.hasPrefix("N") {
                    pendingVolta = String(t.raw.dropFirst())
                }
                // Coda/Segno/End/Fermata (Q/S/U/f) aren't rendered yet —
                // matches the reference renderer, which silently drops them too.

            case .barline:
                pendingBarlineLeft = t.barlineType

            case .chord:
                let content: ChartCell.Content
                switch t.extra {
                case "%": content = .repeatOneBar
                case "//": content = .repeatTwoBars
                case "/": content = .pause
                case "N.C.": content = .noChord
                default:
                    // Keep the raw text as-is (including a leading 'W' for
                    // invisible-root chords) — typesetting a chord symbol
                    // (splitting root/quality/bass, hiding an invisible root)
                    // is a presentation concern for the renderer, not layout.
                    content = .chord(t.raw)
                }
                for _ in 0..<t.cells { appendCell(content, tokenIndex: tokenIndex) }

            case .space:
                for _ in 0..<t.cells { appendCell(.space, tokenIndex: tokenIndex) }
            }
        }

        if !currentRow.isEmpty { rows.append(.cells(currentRow)) }
        return rows
    }
}
