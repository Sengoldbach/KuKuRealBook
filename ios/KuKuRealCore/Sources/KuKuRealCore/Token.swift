import Foundation

public enum TokenType: String, Codable, Equatable {
    case space, barline, timesig, mark, annotation, chord, layout, sep, size, unknown
}

public enum BarlineType: String, Codable, Equatable {
    case single
    case double
    case rdouble
    case repOpen = "rep-open"
    case repClose = "rep-close"
    case final
}

/// One unit in the flat iReal token stream. `raw` is the exact DSL substring
/// this token was parsed from (or, for expanded tokens like `XyQ`/`LZ`, the
/// substring that re-serializes to an equivalent DSL fragment).
public struct Token: Codable, Equatable {
    public var raw: String
    public var type: TokenType
    public var cells: Int
    public var barline: Bool
    public var barlineType: BarlineType?
    public var extra: String?

    public init(
        raw: String,
        type: TokenType,
        cells: Int,
        barline: Bool,
        barlineType: BarlineType? = nil,
        extra: String? = nil
    ) {
        self.raw = raw
        self.type = type
        self.cells = cells
        self.barline = barline
        self.barlineType = barlineType
        self.extra = extra
    }
}
