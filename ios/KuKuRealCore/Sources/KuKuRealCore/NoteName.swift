import Foundation

public enum Letter: String, Equatable, CaseIterable {
    case c = "C", d = "D", e = "E", f = "F", g = "G", a = "A", b = "B"

    var naturalPitchClass: Int {
        switch self {
        case .c: return 0
        case .d: return 2
        case .e: return 4
        case .f: return 5
        case .g: return 7
        case .a: return 9
        case .b: return 11
        }
    }
}

public enum Accidental: Equatable {
    case flat, natural, sharp

    var semitoneOffset: Int {
        switch self {
        case .flat: return -1
        case .natural: return 0
        case .sharp: return 1
        }
    }

    var symbol: String {
        switch self {
        case .flat: return "b"
        case .natural: return ""
        case .sharp: return "#"
        }
    }
}

/// A spelled note (letter + accidental), not just a pitch class — "Ab" and
/// "G#" are the same pitch but different `NoteName`s, which matters once
/// staff notation needs to know which line/space to draw on.
public struct NoteName: Equatable {
    public var letter: Letter
    public var accidental: Accidental

    public init(letter: Letter, accidental: Accidental = .natural) {
        self.letter = letter
        self.accidental = accidental
    }

    /// 0-11, C = 0.
    public var pitchClass: Int {
        ((letter.naturalPitchClass + accidental.semitoneOffset) % 12 + 12) % 12
    }

    public var display: String { letter.rawValue + accidental.symbol }
}
