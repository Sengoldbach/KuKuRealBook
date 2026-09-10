import XCTest
@testable import KuKuRealCore

final class IrealURLCodecTests: XCTestCase {

    func testParsesRealSongMetadata() throws {
        let rawUrl = try loadFixtureString("sample_raw_url.txt")
        let song = try IrealURLCodec.parse(rawUrl)

        XCTAssertEqual(song.title, "？01-孤独患者")
        XCTAssertEqual(song.composer, "陈奕迅（方大同）")
        XCTAssertEqual(song.style, "Kukumber制谱")
        XCTAssertEqual(song.key, "Ab")
        XCTAssertEqual(song.tokens.count, 300)
    }

    func testParseRejectsWrongScheme() {
        XCTAssertThrowsError(try IrealURLCodec.parse("https://example.com")) { error in
            XCTAssertEqual(error as? IrealURLError, .invalidPrefix)
        }
    }

    func testParseRejectsMissingMusicField() {
        XCTAssertThrowsError(try IrealURLCodec.parse("irealb://Title=Composer==Style=C==NoMusicHere==0=0")) { error in
            XCTAssertEqual(error as? IrealURLError, .musicFieldNotFound)
        }
    }

    func testBuildThenParseRoundTripsMetadataAndTokens() throws {
        let original = Song(
            title: "Autumn Leaves",
            composer: "Johnny Mercer",
            style: "Medium Swing",
            key: "Cm",
            tokens: Tokenizer.tokenize("[*AT44Cm7 |F7 |BbMaj7 |EbMaj7|Ah7 |D7b9 |Gm6 Z")
        )

        let url = IrealURLCodec.build(original)
        let reparsed = try IrealURLCodec.parse(url)

        XCTAssertEqual(reparsed.title, original.title)
        XCTAssertEqual(reparsed.composer, original.composer)
        XCTAssertEqual(reparsed.style, original.style)
        XCTAssertEqual(reparsed.key, original.key)
        XCTAssertEqual(reparsed.tokens, original.tokens)
    }

    func testBuildEscapesFieldSeparatorInsideTitle() throws {
        // A literal '=' in a title must not be mistaken for a field
        // separator after the URL is decoded again.
        let original = Song(title: "A=B", composer: "C", style: "S", key: "C", tokens: Tokenizer.tokenize("|C |"))
        let url = IrealURLCodec.build(original)
        let reparsed = try IrealURLCodec.parse(url)
        XCTAssertEqual(reparsed.title, "A=B")
    }

    func testRoundTripThroughSerializeAndReTokenizeIsIdempotent() {
        // XyQ/LZ/Kcl are expanded on first tokenize, so re-serializing won't
        // byte-match the *original* DSL — but tokenizing the serialized
        // output must reproduce the same token stream (fixed point).
        let dsl = "|*iT44Abadd9XyQ|Ab+LZDb^,Kcl{Eb7susZ"
        let firstPass = Tokenizer.tokenize(dsl)
        let serialized = firstPass.map(\.raw).joined()
        let secondPass = Tokenizer.tokenize(serialized)
        XCTAssertEqual(firstPass, secondPass)
    }

    func testBlankSongParsesBackCleanly() throws {
        let blank = Song.blank()
        let url = IrealURLCodec.build(blank)
        let reparsed = try IrealURLCodec.parse(url)
        XCTAssertEqual(reparsed.tokens, blank.tokens)
    }

    private func loadFixtureString(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }
}
