import XCTest
@testable import KuKuRealCore

final class IrealFileFormatTests: XCTestCase {

    func testBuildThenParseRoundTrips() throws {
        let original = Song(
            title: "Autumn Leaves",
            composer: "Johnny Mercer",
            style: "Medium Swing",
            key: "Cm",
            tokens: Tokenizer.tokenize("[*AT44Cm7 |F7 |BbMaj7 |EbMaj7 Z")
        )
        let html = IrealFileFormat.build(original)
        let parsed = try IrealFileFormat.parse(html)

        XCTAssertEqual(parsed.title, original.title)
        XCTAssertEqual(parsed.composer, original.composer)
        XCTAssertEqual(parsed.style, original.style)
        XCTAssertEqual(parsed.key, original.key)
        XCTAssertEqual(parsed.tokens, original.tokens)
    }

    func testParseRealExportedFixtureFromEditor() throws {
        // Same shape as a real file exported by ireal_editor.html / iReal Pro:
        // an XHTML wrapper around a single <a href="irealb://...">.
        let html = """
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><meta charset="UTF-8"><title>iReal Pro</title></head>
        <body>
        <h3><a href="irealb://Test=Composer==Medium%20Swing=C==1r34LbKcu7C%20%7C==0=0">Test</a> - Composer</h3>
        <br/>Made with iReal Editor
        </body>
        </html>
        """
        let song = try IrealFileFormat.parse(html)
        XCTAssertEqual(song.title, "Test")
        XCTAssertEqual(song.composer, "Composer")
    }

    func testParseThrowsWhenNoLinkPresent() {
        XCTAssertThrowsError(try IrealFileFormat.parse("<html><body>nothing here</body></html>")) { error in
            XCTAssertEqual(error as? IrealFileFormat.FileError, .noLinkFound)
        }
    }

    func testSuggestedFilenameStripsPunctuationButKeepsCJK() {
        XCTAssertEqual(IrealFileFormat.suggestedFilename(for: Song(title: "孤独患者")), "孤独患者")
        XCTAssertEqual(IrealFileFormat.suggestedFilename(for: Song(title: "A/B: Test?")), "AB Test")
        XCTAssertEqual(IrealFileFormat.suggestedFilename(for: Song(title: "")), "Untitled")
    }

    func testBuildEscapesQuotesAndAmpersandsInTitle() throws {
        let song = Song(title: "Rock & Roll \"Anthem\"", tokens: Tokenizer.tokenize("|C |"))
        let html = IrealFileFormat.build(song)
        let parsed = try IrealFileFormat.parse(html)
        XCTAssertEqual(parsed.title, "Rock & Roll \"Anthem\"")
    }
}
