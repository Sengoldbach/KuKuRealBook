import XCTest
@testable import KuKuRealCore

final class CryptoTests: XCTestCase {
    func testUnscrambleIsSelfInverse() {
        let samples = [
            String(repeating: "a", count: 50),
            String(repeating: "ab", count: 30),
            "short",
            String(repeating: "x", count: 51),
            String(repeating: "y", count: 100),
            String(repeating: "z", count: 123),
        ]
        for s in samples {
            let scrambled = IrealCrypto.unscramble(s)
            XCTAssertEqual(IrealCrypto.unscramble(scrambled), s, "round trip failed for length \(s.count)")
        }
    }

    func testDecodeMusicStripsPrefix() {
        let field = IrealCrypto.musicPrefix + IrealCrypto.unscramble("|C^ |G-7|")
        XCTAssertEqual(IrealCrypto.decodeMusic(field), "|C^ |G-7|")
    }

    func testDecodeMusicWithoutPrefixReturnsInputUnchanged() {
        XCTAssertEqual(IrealCrypto.decodeMusic("no-prefix-here"), "no-prefix-here")
    }
}
