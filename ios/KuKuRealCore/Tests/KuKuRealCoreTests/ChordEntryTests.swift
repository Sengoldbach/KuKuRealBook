import XCTest
@testable import KuKuRealCore

final class ChordEntryTests: XCTestCase {

    // MARK: - isCompleteChordText

    func testCompleteChordTexts() {
        for text in ["C", "C-7", "Ab^7/C", "W/G", "F#-7", "Bb-", "C69"] {
            XCTAssertTrue(Tokenizer.isCompleteChordText(text), "'\(text)' should be complete")
        }
    }

    func testIncompleteChordTextsWhileMidEntry() {
        // A trailing bare '/' (bass slash tapped, root letter not yet picked)
        // must NOT validate — this is what keeps live-preview from clobbering
        // the cell with garbage while the user is still building the chord.
        for text in ["C/", "", "Ab/", "!!!", "123"] {
            XCTAssertFalse(Tokenizer.isCompleteChordText(text), "'\(text)' should be incomplete")
        }
    }

    // MARK: - ChordEntry.makeToken

    func testEmptyTextClearsToSpace() {
        let tok = ChordEntry.makeToken(from: "")
        XCTAssertEqual(tok, Token(raw: " ", type: .space, cells: 1, barline: false))
    }

    func testPlainChordText() {
        let tok = ChordEntry.makeToken(from: "C-7")
        XCTAssertEqual(tok, Token(raw: "C-7", type: .chord, cells: 1, barline: false))
    }

    func testSpecialSymbols() {
        XCTAssertEqual(ChordEntry.makeToken(from: "%"), Token(raw: "x", type: .chord, cells: 1, barline: false, extra: "%"))
        XCTAssertEqual(ChordEntry.makeToken(from: "//"), Token(raw: "r", type: .chord, cells: 1, barline: false, extra: "//"))
        XCTAssertEqual(ChordEntry.makeToken(from: "/"), Token(raw: "p", type: .chord, cells: 1, barline: false, extra: "/"))
        XCTAssertEqual(ChordEntry.makeToken(from: "N.C."), Token(raw: "n", type: .chord, cells: 1, barline: false, extra: "N.C."))
    }

    func testSpecialSymbolsCaseInsensitiveLowercaseVariants() {
        XCTAssertEqual(ChordEntry.makeToken(from: "nc"), Token(raw: "n", type: .chord, cells: 1, barline: false, extra: "N.C."))
        XCTAssertEqual(ChordEntry.makeToken(from: "n.c."), Token(raw: "n", type: .chord, cells: 1, barline: false, extra: "N.C."))
    }

    func testInvalidTextReturnsNilRatherThanCorruptingTheCell() {
        XCTAssertNil(ChordEntry.makeToken(from: "C/"))
        XCTAssertNil(ChordEntry.makeToken(from: "!!!"))
    }

    func testDisplayTextPrefersExtraOverRaw() {
        let repeatToken = Token(raw: "r", type: .chord, cells: 1, barline: false, extra: "//")
        XCTAssertEqual(ChordEntry.displayText(for: repeatToken), "//")

        let chordToken = Token(raw: "C-7", type: .chord, cells: 1, barline: false)
        XCTAssertEqual(ChordEntry.displayText(for: chordToken), "C-7")
    }

    /// Simulates the button-tap sequence the symbol bar drives: root → accidental
    /// → quality → extension → bass, checking each intermediate step the way
    /// live-preview does (only committed when `makeToken` succeeds).
    func testSimulatedButtonBuildSequence() {
        var text = ""
        func tapRoot(_ letter: String) { text = text.hasSuffix("/") ? text + letter : letter }
        func tapAppend(_ chars: String) { text += chars }

        tapRoot("A")
        XCTAssertEqual(ChordEntry.makeToken(from: text)?.raw, "A")

        tapAppend("b") // accidental
        XCTAssertEqual(ChordEntry.makeToken(from: text)?.raw, "Ab")

        tapAppend("^") // major7 quality
        XCTAssertEqual(ChordEntry.makeToken(from: text)?.raw, "Ab^")

        tapAppend("7") // extension
        XCTAssertEqual(ChordEntry.makeToken(from: text)?.raw, "Ab^7")

        tapAppend("/") // bass slash — incomplete until a root follows
        XCTAssertNil(ChordEntry.makeToken(from: text))

        tapRoot("C") // ends with '/', so this appends rather than replacing
        XCTAssertEqual(text, "Ab^7/C")
        XCTAssertEqual(ChordEntry.makeToken(from: text)?.raw, "Ab^7/C")
    }
}
