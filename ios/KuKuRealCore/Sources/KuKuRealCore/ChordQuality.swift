import Foundation

/// A chord's harmonic content, independent of its root — parsed from the
/// suffix portion of a raw chord token (everything after the root letter
/// and its accidental, before an optional `/bass`).
///
/// iReal's suffix syntax is a small flexible grammar rather than a fixed
/// vocabulary (`7b9`, `9sus`, `7#9`, `add9`, ... can all combine), so this
/// is a real left-to-right scanner, not a lookup table. Unrecognized
/// fragments never fail the parse — they just leave `recognized == false`
/// and fall back to a plain major triad, so a weird/typo'd chord in a real
/// chart degrades gracefully instead of crashing the renderer.
public struct ChordQuality: Equatable {
    public enum Family: Equatable {
        case major, minor, dominant, halfDiminished, diminished, augmented
    }

    public var family: Family
    public var seventh: Bool
    public var sixth: Bool
    public var naturalExtensions: Set<Int>   // 9, 11, 13 — unaltered
    public var alterations: Set<String>      // "b5", "#5", "b9", "#9", "#11", "b13", ...
    public var addedTones: Set<Int>          // from "addN" — no implied 7th
    public var suspended: Bool               // sus4 replacing the 3rd
    public var raw: String
    public var recognized: Bool

    public init(
        family: Family,
        seventh: Bool = false,
        sixth: Bool = false,
        naturalExtensions: Set<Int> = [],
        alterations: Set<String> = [],
        addedTones: Set<Int> = [],
        suspended: Bool = false,
        raw: String,
        recognized: Bool = true
    ) {
        self.family = family
        self.seventh = seventh
        self.sixth = sixth
        self.naturalExtensions = naturalExtensions
        self.alterations = alterations
        self.addedTones = addedTones
        self.suspended = suspended
        self.raw = raw
        self.recognized = recognized
    }

    /// Semitones from the root, deduplicated and sorted (e.g. major triad → [0, 4, 7]).
    /// Alterations override whatever natural degree they share a scale step with,
    /// so "b5" replaces the perfect 5th rather than sounding alongside it.
    public var intervals: [Int] {
        var result: Set<Int> = [0]

        if suspended {
            result.insert(5) // 4th replaces the 3rd
        } else {
            switch family {
            case .major, .dominant, .augmented: result.insert(4)
            case .minor, .halfDiminished, .diminished: result.insert(3)
            }
        }

        switch family {
        case .halfDiminished, .diminished: result.insert(6)
        case .augmented: result.insert(8)
        case .major, .dominant, .minor: result.insert(7)
        }

        if sixth { result.insert(9) }

        if seventh {
            switch family {
            case .major: result.insert(11)
            case .diminished: result.insert(9) // fully-diminished 7th (bb7)
            case .minor, .dominant, .halfDiminished, .augmented: result.insert(10)
            }
        }

        for ext in naturalExtensions {
            if let semitone = Self.naturalDegreeSemitone(ext) { result.insert(semitone) }
        }
        for add in addedTones {
            if let semitone = Self.naturalDegreeSemitone(add) { result.insert(semitone) }
        }

        for alt in alterations {
            guard let (degree, semitone) = Self.parseAlteration(alt) else { continue }
            if let natural = Self.naturalDegreeSemitone(degree) { result.remove(natural) }
            if degree == 5 { result.remove(7); result.remove(6); result.remove(8) }
            result.insert(semitone)
        }

        return result.sorted()
    }

    private static func naturalDegreeSemitone(_ degree: Int) -> Int? {
        switch degree {
        case 5: return 7
        case 9: return 2
        case 11: return 5
        case 13: return 9
        default: return nil
        }
    }

    /// "b9" → (9, 1), "#11" → (11, 6), etc.
    private static func parseAlteration(_ token: String) -> (degree: Int, semitone: Int)? {
        guard let signChar = token.first else { return nil }
        let sign: Int
        switch signChar {
        case "b": sign = -1
        case "#": sign = 1
        default: return nil
        }
        guard let degree = Int(token.dropFirst()), let base = naturalDegreeSemitone(degree) else { return nil }
        return (degree, ((base + sign) % 12 + 12) % 12)
    }
}

public enum ChordQualityParser {
    /// Parses the suffix substring of a chord token (i.e. everything after
    /// the root+accidental and before an optional `/bass`).
    public static func parse(_ suffix: String) -> ChordQuality {
        let chars = Array(suffix)
        let n = chars.count
        var i = 0

        var family: Family = .major
        var explicitFamily = false
        var seventh = false
        var sixth = false
        var naturalExtensions: Set<Int> = []
        var alterations: Set<String> = []
        var addedTones: Set<Int> = []
        var suspended = false
        var recognized = true

        func matches(_ s: String) -> Bool {
            let sc = Array(s)
            guard i + sc.count <= n else { return false }
            return Array(chars[i..<i + sc.count]) == sc
        }

        func readDigits() -> Int? {
            var j = i
            while j < n, chars[j].isASCII, chars[j].isNumber { j += 1 }
            guard j > i, let value = Int(String(chars[i..<j])) else { return nil }
            i = j
            return value
        }

        while i < n {
            if matches("add") {
                i += 3
                if let n2 = readDigits() { addedTones.insert(n2) } else { recognized = false }
                continue
            }
            if matches("sus4") { suspended = true; i += 4; continue }
            if matches("sus") { suspended = true; i += 3; continue }
            if matches("^") { family = .major; explicitFamily = true; seventh = true; i += 1; continue }
            if matches("h") { family = .halfDiminished; explicitFamily = true; seventh = true; i += 1; continue }
            if matches("o") { family = .diminished; explicitFamily = true; seventh = true; i += 1; continue }
            if matches("-") { family = .minor; explicitFamily = true; i += 1; continue }
            if matches("+") { family = .augmented; explicitFamily = true; i += 1; continue }
            if matches("69") { sixth = true; naturalExtensions.insert(9); i += 2; continue }
            if chars[i] == "b" || chars[i] == "#" {
                let sign = String(chars[i]); i += 1
                if let degree = readDigits() {
                    alterations.insert(sign + String(degree))
                } else {
                    recognized = false
                }
                continue
            }
            if chars[i].isASCII, chars[i].isNumber {
                let start = i
                guard let value = readDigits() else { i = start + 1; recognized = false; continue }
                switch value {
                case 6:
                    sixth = true
                case 7, 9, 11, 13:
                    if !explicitFamily { family = .dominant }
                    seventh = true
                    if value > 7 { naturalExtensions.insert(value) }
                default:
                    recognized = false
                }
                continue
            }
            // Unrecognized character — skip it but keep parsing the rest.
            recognized = false
            i += 1
        }

        return ChordQuality(
            family: family,
            seventh: seventh,
            sixth: sixth,
            naturalExtensions: naturalExtensions,
            alterations: alterations,
            addedTones: addedTones,
            suspended: suspended,
            raw: suffix,
            recognized: recognized
        )
    }

    public typealias Family = ChordQuality.Family
}
