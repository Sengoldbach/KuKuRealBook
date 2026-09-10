import XCTest
@testable import KuKuRealCore

/// Golden-fixture test using a real chart exported from iReal Pro that
/// deliberately exercises many token types (time sig changes, all section
/// marks, l/s size toggles, r/x/n/W chords) — provided by the user
/// specifically to stress-test the tokenizer beyond the first sample song.
final class VisualEffectsFixtureTests: XCTestCase {
    func testMatchesReferenceImplementation() throws {
        let dsl = try loadFixtureString("visual_dsl.txt")
        let expected = try loadFixtureTokens("visual_tokens.json")

        let actual = Tokenizer.tokenize(dsl)

        XCTAssertEqual(actual.count, expected.count)
        XCTAssertEqual(actual, expected)
    }

    func testNoUnknownTokens() throws {
        let dsl = try loadFixtureString("visual_dsl.txt")
        let tokens = Tokenizer.tokenize(dsl)
        XCTAssertTrue(tokens.filter { $0.type == .unknown }.isEmpty)
    }

    func testParsesFullUrlMetadata() throws {
        let rawUrl = try loadFixtureString("visual_raw_url.txt")
        let song = try IrealURLCodec.parse(rawUrl)

        XCTAssertEqual(song.title, "视觉效果测试")
        XCTAssertEqual(song.composer, "Kuku")
        XCTAssertEqual(song.style, "Medium Swing")
        XCTAssertEqual(song.key, "C")
        XCTAssertEqual(song.tokens.count, 151)
    }

    func testBuildThenParseRoundTripsTokens() throws {
        let rawUrl = try loadFixtureString("visual_raw_url.txt")
        let original = try IrealURLCodec.parse(rawUrl)
        let rebuilt = try IrealURLCodec.parse(IrealURLCodec.build(original))
        XCTAssertEqual(rebuilt.tokens, original.tokens)
    }

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
