import XCTest
@testable import KuKuRealCore

final class TokenizerTests: XCTestCase {

    // MARK: - Golden fixture (extracted from the real editor.html tokenizer
    // running against 孤独患者's actual .ireal data)

    func testMatchesReferenceImplementationOnRealSong() throws {
        let dsl = try loadFixtureString("sample_dsl.txt")
        let expected = try loadFixtureTokens("sample_tokens.json")

        let actual = Tokenizer.tokenize(dsl)

        XCTAssertEqual(actual.count, expected.count)
        XCTAssertEqual(actual, expected)
    }

    func testNoUnknownTokensOnRealSong() throws {
        let dsl = try loadFixtureString("sample_dsl.txt")
        let tokens = Tokenizer.tokenize(dsl)
        XCTAssertTrue(tokens.filter { $0.type == .unknown }.isEmpty)
    }

    // MARK: - Individual token rules

    func testBarlines() {
        let tokens = Tokenizer.tokenize("|[]{}Z")
        XCTAssertEqual(tokens.map(\.barlineType), [.single, .double, .rdouble, .repOpen, .repClose, .final])
    }

    func testXyQExpandsToThreeSpaces() {
        let tokens = Tokenizer.tokenize("XyQ")
        XCTAssertEqual(tokens, [
            Token(raw: " ", type: .space, cells: 1, barline: false),
            Token(raw: " ", type: .space, cells: 1, barline: false),
            Token(raw: " ", type: .space, cells: 1, barline: false),
        ])
    }

    func testLZExpandsToSpaceThenSingleBarline() {
        let tokens = Tokenizer.tokenize("LZ")
        XCTAssertEqual(tokens, [
            Token(raw: " ", type: .space, cells: 1, barline: false),
            Token(raw: "|", type: .barline, cells: 0, barline: true, barlineType: .single),
        ])
    }

    func testKclExpandsToBarlineSpacePauseChord() {
        let tokens = Tokenizer.tokenize("Kcl")
        XCTAssertEqual(tokens, [
            Token(raw: "|", type: .barline, cells: 0, barline: true, barlineType: .single),
            Token(raw: " ", type: .space, cells: 1, barline: false),
            Token(raw: "p", type: .chord, cells: 1, barline: false, extra: "/"),
        ])
    }

    func testTimesig() {
        let tokens = Tokenizer.tokenize("T44")
        XCTAssertEqual(tokens, [Token(raw: "T44", type: .timesig, cells: 0, barline: false)])
    }

    func testSectionMarkAndVolta() {
        let tokens = Tokenizer.tokenize("*AN1")
        XCTAssertEqual(tokens, [
            Token(raw: "*A", type: .mark, cells: 0, barline: false),
            Token(raw: "N1", type: .mark, cells: 0, barline: false),
        ])
    }

    func testAnnotation() {
        let tokens = Tokenizer.tokenize("<hello world>")
        XCTAssertEqual(tokens, [Token(raw: "<hello world>", type: .annotation, cells: 0, barline: false)])
    }

    func testRepeatPauseNoChord() {
        let tokens = Tokenizer.tokenize("rxpn")
        XCTAssertEqual(tokens.map(\.extra), ["//", "%", "/", "N.C."])
    }

    func testSizeToggleLAndS() {
        // "su" must NOT be consumed as the small-size token `s`.
        let tokens = Tokenizer.tokenize("lCsu s")
        XCTAssertEqual(tokens[0], Token(raw: "l", type: .size, cells: 0, barline: false, extra: "normal"))
        XCTAssertEqual(tokens[1].type, .chord)
        XCTAssertEqual(tokens[1].raw, "Csu")
        XCTAssertEqual(tokens[2], Token(raw: " ", type: .space, cells: 1, barline: false))
        XCTAssertEqual(tokens[3], Token(raw: "s", type: .size, cells: 0, barline: false, extra: "small"))
    }

    func testChordWithBassNote() {
        let tokens = Tokenizer.tokenize("C-7/G")
        XCTAssertEqual(tokens, [Token(raw: "C-7/G", type: .chord, cells: 1, barline: false)])
    }

    func testChordWithFlatBassNote() {
        let tokens = Tokenizer.tokenize("Ab^7/Cb")
        XCTAssertEqual(tokens, [Token(raw: "Ab^7/Cb", type: .chord, cells: 1, barline: false)])
    }

    func testInvisibleRootPlaceholder() {
        // 'W' = invisible root, only the slash bass renders.
        let tokens = Tokenizer.tokenize("W/G")
        XCTAssertEqual(tokens, [Token(raw: "W/G", type: .chord, cells: 1, barline: false)])
    }

    func testYRunsMergeIntoOneLayoutToken() {
        let tokens = Tokenizer.tokenize("YYY")
        XCTAssertEqual(tokens, [Token(raw: "YYY", type: .layout, cells: 0, barline: false)])
    }

    func testUnknownCharsMergeConsecutively() {
        // Bare non-ASCII text outside <...> (annotation-overflow fragments
        // at encryption block boundaries) should merge into one token.
        let tokens = Tokenizer.tokenize("好不")
        XCTAssertEqual(tokens, [Token(raw: "好不", type: .unknown, cells: 0, barline: false)])
    }

    // MARK: - Helpers

    private func loadFixtureString(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func loadFixtureTokens(_ name: String) throws -> [Token] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Token].self, from: data)
    }
}
