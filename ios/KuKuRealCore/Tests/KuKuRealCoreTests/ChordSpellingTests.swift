import XCTest
@testable import KuKuRealCore

final class ChordSpellingTests: XCTestCase {

    // MARK: - Root / accidental / bass parsing

    func testPlainRoot() {
        let s = ChordSpellingParser.parse("C")!
        XCTAssertEqual(s.root, NoteName(letter: .c))
        XCTAssertNil(s.bass)
    }

    func testFlatRoot() {
        let s = ChordSpellingParser.parse("Bb-7")!
        XCTAssertEqual(s.root, NoteName(letter: .b, accidental: .flat))
        XCTAssertEqual(s.quality.family, .minor)
        XCTAssertTrue(s.quality.seventh)
    }

    func testSharpRoot() {
        let s = ChordSpellingParser.parse("F#-7")!
        XCTAssertEqual(s.root, NoteName(letter: .f, accidental: .sharp))
    }

    func testBassNote() {
        let s = ChordSpellingParser.parse("C-7/G")!
        XCTAssertEqual(s.root, NoteName(letter: .c))
        XCTAssertEqual(s.bass, NoteName(letter: .g))
    }

    func testFlatBassNote() {
        let s = ChordSpellingParser.parse("Ab^7/Cb")!
        XCTAssertEqual(s.bass, NoteName(letter: .c, accidental: .flat))
    }

    func testInvisibleRootKeepsBassOnly() {
        let s = ChordSpellingParser.parse("W/G")!
        XCTAssertNil(s.root)
        XCTAssertEqual(s.bass, NoteName(letter: .g))
    }

    func testRejectsGarbageInput() {
        XCTAssertNil(ChordSpellingParser.parse("!!!"))
        XCTAssertNil(ChordSpellingParser.parse(""))
    }

    // MARK: - Quality parsing: the documented table (ireal-format.md §4.3)

    func testMinor7() { XCTAssertQuality("-7", family: .minor, seventh: true) }
    func testMinorTriad() { XCTAssertQuality("-", family: .minor, seventh: false) }
    func testMajor7Caret7() { XCTAssertQuality("^7", family: .major, seventh: true) }
    func testMajor7CaretAlone() { XCTAssertQuality("^", family: .major, seventh: true) }
    func testDominant7() { XCTAssertQuality("7", family: .dominant, seventh: true) }
    func testHalfDim7() { XCTAssertQuality("h7", family: .halfDiminished, seventh: true) }
    func testHalfDimAlone() { XCTAssertQuality("h", family: .halfDiminished, seventh: true) }
    func testDiminished7() { XCTAssertQuality("o7", family: .diminished, seventh: true) }
    func testDiminishedAlone() { XCTAssertQuality("o", family: .diminished, seventh: true) }
    func testSus() { XCTAssertQuality("sus", family: .major, seventh: false, suspended: true) }
    func testSus4() { XCTAssertQuality("sus4", family: .major, seventh: false, suspended: true) }
    func testMajor6() { XCTAssertQuality("6", family: .major, seventh: false, sixth: true) }
    func testMinor6() { XCTAssertQuality("-6", family: .minor, seventh: false, sixth: true) }
    func testSixNine() { XCTAssertQuality("69", family: .major, seventh: false, sixth: true, naturalExtensions: [9]) }
    func testAdd9() { XCTAssertQuality("add9", family: .major, seventh: false, addedTones: [9]) }
    func testAugmented() { XCTAssertQuality("+", family: .augmented, seventh: false) }

    // MARK: - Real-world jazz extensions seen in the fixture songs

    func testDominant7SharpNine() { XCTAssertQuality("7#9", family: .dominant, seventh: true, alterations: ["#9"]) }
    func testDominant7FlatNine() { XCTAssertQuality("7b9", family: .dominant, seventh: true, alterations: ["b9"]) }
    func testMinor9() { XCTAssertQuality("-9", family: .minor, seventh: true, naturalExtensions: [9]) }
    func testMajor9() { XCTAssertQuality("^9", family: .major, seventh: true, naturalExtensions: [9]) }
    func testDominant9Bare() { XCTAssertQuality("9", family: .dominant, seventh: true, naturalExtensions: [9]) }
    func testDominant7Sus() { XCTAssertQuality("7sus", family: .dominant, seventh: true, suspended: true) }
    func testDominant9Sus() { XCTAssertQuality("9sus", family: .dominant, seventh: true, naturalExtensions: [9], suspended: true) }

    func testUnrecognizedSuffixFallsBackGracefullyWithoutCrashing() {
        let q = ChordQualityParser.parse("2")
        XCTAssertFalse(q.recognized)
        XCTAssertEqual(q.raw, "2")
        XCTAssertEqual(q.family, .major) // safe fallback
    }

    // MARK: - Interval computation

    func testMajorTriadIntervals() {
        XCTAssertEqual(ChordQualityParser.parse("").intervals, [0, 4, 7])
    }

    func testMinor7Intervals() {
        XCTAssertEqual(ChordQualityParser.parse("-7").intervals, [0, 3, 7, 10])
    }

    func testMajor7Intervals() {
        XCTAssertEqual(ChordQualityParser.parse("^7").intervals, [0, 4, 7, 11])
    }

    func testDominant7Intervals() {
        XCTAssertEqual(ChordQualityParser.parse("7").intervals, [0, 4, 7, 10])
    }

    func testHalfDiminishedIntervals() {
        XCTAssertEqual(ChordQualityParser.parse("h7").intervals, [0, 3, 6, 10])
    }

    func testDiminished7Intervals() {
        // Fully-diminished 7th: bb7 (9 semitones) — enharmonic to a major 6th.
        XCTAssertEqual(ChordQualityParser.parse("o7").intervals, [0, 3, 6, 9])
    }

    func testDominant7Flat9Intervals() {
        XCTAssertEqual(ChordQualityParser.parse("7b9").intervals, [0, 1, 4, 7, 10])
    }

    func testDominant7Sharp9Intervals() {
        XCTAssertEqual(ChordQualityParser.parse("7#9").intervals, [0, 3, 4, 7, 10])
    }

    func testMinor6Intervals() {
        // No 7th at all in a m6 chord.
        XCTAssertEqual(ChordQualityParser.parse("-6").intervals, [0, 3, 7, 9])
    }

    func testSixNineIntervals() {
        XCTAssertEqual(ChordQualityParser.parse("69").intervals, [0, 2, 4, 7, 9])
    }

    func testAdd9Intervals() {
        // Added 9th, no 7th.
        XCTAssertEqual(ChordQualityParser.parse("add9").intervals, [0, 2, 4, 7])
    }

    func testSusIntervals() {
        XCTAssertEqual(ChordQualityParser.parse("sus").intervals, [0, 5, 7])
    }

    func testAugmentedIntervals() {
        XCTAssertEqual(ChordQualityParser.parse("+").intervals, [0, 4, 8])
    }

    /// The alteration must *replace* the natural degree, not sound alongside it —
    /// "-7b5" is {root, b3, b5, b7}, not {root, b3, b5, 5, b7}.
    func testFlatFiveAlterationReplacesNaturalFifth() {
        let intervals = ChordQualityParser.parse("-7b5").intervals
        XCTAssertEqual(intervals, [0, 3, 6, 10])
        XCTAssertFalse(intervals.contains(7))
    }

    func testSharpElevenReplacesNaturalEleven() {
        let intervals = ChordQualityParser.parse("^7#11").intervals
        XCTAssertEqual(intervals, [0, 4, 6, 7, 11])
    }

    // MARK: - Golden fixtures: every real chord from both sample songs must parse without crashing

    func testAllChordsInRealSongsParseSuccessfully() throws {
        for fixture in ["sample_tokens.json", "visual_tokens.json"] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: fixture, withExtension: nil, subdirectory: "Fixtures"))
            let data = try Data(contentsOf: url)
            let tokens = try JSONDecoder().decode([Token].self, from: data)
            for token in tokens where token.type == .chord && token.extra == nil {
                let spelling = ChordSpellingParser.parse(token.raw)
                XCTAssertNotNil(spelling, "failed to parse chord raw text: \(token.raw)")
                // Every interval set must at least contain the root and be well-formed.
                if let spelling {
                    XCTAssertTrue(spelling.quality.intervals.contains(0), "\(token.raw) missing root interval")
                    XCTAssertTrue(spelling.quality.intervals.allSatisfy { (0...11).contains($0) }, "\(token.raw) produced out-of-range interval")
                }
            }
        }
    }

    // MARK: - Helpers

    private func XCTAssertQuality(
        _ suffix: String,
        family: ChordQuality.Family,
        seventh: Bool,
        sixth: Bool = false,
        naturalExtensions: Set<Int> = [],
        alterations: Set<String> = [],
        addedTones: Set<Int> = [],
        suspended: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let q = ChordQualityParser.parse(suffix)
        XCTAssertTrue(q.recognized, "expected '\(suffix)' to be recognized", file: file, line: line)
        XCTAssertEqual(q.family, family, "family mismatch for '\(suffix)'", file: file, line: line)
        XCTAssertEqual(q.seventh, seventh, "seventh mismatch for '\(suffix)'", file: file, line: line)
        XCTAssertEqual(q.sixth, sixth, "sixth mismatch for '\(suffix)'", file: file, line: line)
        XCTAssertEqual(q.naturalExtensions, naturalExtensions, "naturalExtensions mismatch for '\(suffix)'", file: file, line: line)
        XCTAssertEqual(q.alterations, alterations, "alterations mismatch for '\(suffix)'", file: file, line: line)
        XCTAssertEqual(q.addedTones, addedTones, "addedTones mismatch for '\(suffix)'", file: file, line: line)
        XCTAssertEqual(q.suspended, suspended, "suspended mismatch for '\(suffix)'", file: file, line: line)
    }
}
