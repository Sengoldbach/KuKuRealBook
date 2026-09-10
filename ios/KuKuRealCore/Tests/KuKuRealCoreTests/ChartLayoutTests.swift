import XCTest
@testable import KuKuRealCore

final class ChartLayoutTests: XCTestCase {

    func testWrapsAtSixteenColumns() {
        // 20 single-space tokens -> row of 16, then row of 4.
        let tokens = Tokenizer.tokenize(String(repeating: " ", count: 20))
        let rows = ChartLayout.rows(for: tokens)
        XCTAssertEqual(rows.count, 2)
        guard case .cells(let first) = rows[0], case .cells(let second) = rows[1] else {
            return XCTFail("expected two cell rows")
        }
        XCTAssertEqual(first.count, 16)
        XCTAssertEqual(second.count, 4)
    }

    func testChordCellCarriesDisplayText() {
        let tokens = Tokenizer.tokenize("C-7")
        let rows = ChartLayout.rows(for: tokens)
        guard case .cells(let cells) = rows[0] else { return XCTFail() }
        XCTAssertEqual(cells, [ChartCell(content: .chord("C-7"), tokenIndex: 0)])
    }

    func testInvisibleRootKeepsRawTextForRendererToTypeset() {
        // The 'W' marker is preserved raw — hiding the root letter is now a
        // rendering concern (ChordSpellingParser + the chart view), not layout's.
        let tokens = Tokenizer.tokenize("W/G")
        let rows = ChartLayout.rows(for: tokens)
        guard case .cells(let cells) = rows[0] else { return XCTFail() }
        XCTAssertEqual(cells, [ChartCell(content: .chord("W/G"), tokenIndex: 0)])
    }

    func testTokenIndexPointsBackToOriginatingToken() {
        // "|C D" tokenizes to [barline, chord C, space, chord D] at indices 0..3.
        // Cells only exist for the chord/space tokens (indices 1-3); the
        // cell for 'C' must point at token 1, not the barline at 0.
        let tokens = Tokenizer.tokenize("|C D")
        let rows = ChartLayout.rows(for: tokens)
        guard case .cells(let cells) = rows[0] else { return XCTFail() }
        XCTAssertEqual(cells.map(\.tokenIndex), [1, 2, 3])
    }

    func testBarlineAttachesToFollowingCellOnly() {
        let tokens = Tokenizer.tokenize("|C D")
        let rows = ChartLayout.rows(for: tokens)
        guard case .cells(let cells) = rows[0] else { return XCTFail() }
        XCTAssertEqual(cells.count, 3) // C, space, D
        XCTAssertEqual(cells[0].leftBarline, .single)
        XCTAssertEqual(cells[0].content, .chord("C"))
        XCTAssertNil(cells[1].leftBarline)
        XCTAssertNil(cells[2].leftBarline)
    }

    func testRepeatPauseNoChordDisplayKinds() {
        let tokens = Tokenizer.tokenize("rxpn")
        let rows = ChartLayout.rows(for: tokens)
        guard case .cells(let cells) = rows[0] else { return XCTFail() }
        XCTAssertEqual(cells.map(\.content), [.repeatTwoBars, .repeatOneBar, .pause, .noChord])
    }

    func testSectionMarkAndVoltaAttachToNextCellOnly() {
        let tokens = Tokenizer.tokenize("*AN1C D")
        let rows = ChartLayout.rows(for: tokens)
        guard case .cells(let cells) = rows[0] else { return XCTFail() }
        XCTAssertEqual(cells[0].sectionMark, "A")
        XCTAssertEqual(cells[0].volta, "1")
        XCTAssertNil(cells[1].sectionMark)
        XCTAssertNil(cells[1].volta)
    }

    func testTimeSigReadsIndividualDigitsNotConcatenatedString() {
        // Regression per ireal-format.md §4.5: T44 must read as top='4' bottom='4',
        // not as the two-char string "44" from a naive \d+ match.
        let tokens = Tokenizer.tokenize("T44C")
        let rows = ChartLayout.rows(for: tokens)
        guard case .cells(let cells) = rows[0] else { return XCTFail() }
        XCTAssertEqual(cells[0].timeSigTop, "4")
        XCTAssertEqual(cells[0].timeSigBottom, "4")
    }

    func testUnevenTimeSigDigits() {
        let tokens = Tokenizer.tokenize("T68C")
        let rows = ChartLayout.rows(for: tokens)
        guard case .cells(let cells) = rows[0] else { return XCTFail() }
        XCTAssertEqual(cells[0].timeSigTop, "6")
        XCTAssertEqual(cells[0].timeSigBottom, "8")
    }

    func testLayoutTokenForcesRowBreakAndEmitsSpacer() {
        // 5 spaces, then Y (spacer of 1 unit), then 3 more spaces:
        // the partial 5-cell row must flush immediately (not wait for 16),
        // the spacer is its own row, and the next cells start a fresh row.
        let tokens = Tokenizer.tokenize("     Y   ")
        let rows = ChartLayout.rows(for: tokens)
        XCTAssertEqual(rows.count, 3)
        guard case .cells(let first) = rows[0] else { return XCTFail() }
        XCTAssertEqual(first.count, 5)
        guard case .spacer(let units) = rows[1] else { return XCTFail() }
        XCTAssertEqual(units, 1)
        guard case .cells(let third) = rows[2] else { return XCTFail() }
        XCTAssertEqual(third.count, 3)
    }

    func testTripleYSpacerUnitsMatchRunLength() {
        let tokens = Tokenizer.tokenize("YYY")
        let rows = ChartLayout.rows(for: tokens)
        guard case .spacer(let units) = rows[0] else { return XCTFail() }
        XCTAssertEqual(units, 3)
    }

    func testAnnotationAndSizeTokensProduceNoCells() {
        let tokens = Tokenizer.tokenize("l<lyric>sC")
        let rows = ChartLayout.rows(for: tokens)
        guard case .cells(let cells) = rows[0] else { return XCTFail() }
        XCTAssertEqual(cells, [ChartCell(content: .chord("C"), tokenIndex: 3)])
    }

    // MARK: - Real-song sanity checks

    func testRealSongCellCountMatchesTokenCellSum() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample_dsl.txt", withExtension: nil, subdirectory: "Fixtures"))
        let dsl = try String(contentsOf: url, encoding: .utf8)
        let tokens = Tokenizer.tokenize(dsl)
        let expectedCells = tokens.reduce(0) { $0 + $1.cells }

        let rows = ChartLayout.rows(for: tokens)
        let actualCells = rows.reduce(0) { sum, row -> Int in
            if case .cells(let cells) = row { return sum + cells.count }
            return sum
        }
        XCTAssertEqual(actualCells, expectedCells)
    }

    func testVisualEffectsSongLayoutDoesNotCrashAndAccountsForAllCells() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "visual_dsl.txt", withExtension: nil, subdirectory: "Fixtures"))
        let dsl = try String(contentsOf: url, encoding: .utf8)
        let tokens = Tokenizer.tokenize(dsl)
        let expectedCells = tokens.reduce(0) { $0 + $1.cells }

        let rows = ChartLayout.rows(for: tokens)
        let actualCells = rows.reduce(0) { sum, row -> Int in
            if case .cells(let cells) = row { return sum + cells.count }
            return sum
        }
        XCTAssertEqual(actualCells, expectedCells)
        XCTAssertTrue(rows.contains { if case .spacer = $0 { return true }; return false })
    }
}
