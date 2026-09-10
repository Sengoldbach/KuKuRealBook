import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Ports the `:root` dark palette from `ireal_editor.html`'s CSS variables
/// 1:1 (names kept close to the `--c-*` originals) so the native app and the
/// web editor read as the same product.
enum Theme {
    static let bgPage = Color(hex: 0x1b2730)
    static let bgBar = Color(hex: 0x0d1a22)
    static let bgToolbar = Color(hex: 0x13222c)

    static let text = Color(hex: 0xe6e3da)
    static let label = Color(hex: 0x555566)
    static let border = Color(hex: 0x333344)

    static let inputBg = Color(hex: 0x1b2730)
    static let btnBg = Color(hex: 0x1e3a4a)
    static let btnBorder = Color(hex: 0x444455)
    static let btnText = Color(hex: 0x94d5ff)

    static let cellBorder = Color(hex: 0x1e3040)
    static let selBg = Color(hex: 0x0e2a38)
    static let selOutline = Color(hex: 0x44aaff)

    static let chord = Color(hex: 0x7fffb2)
    static let space = Color(hex: 0x1e3040)
    static let noChord = Color(hex: 0xffd700)
    static let pause = Color(hex: 0x888888)
    static let repeatColor = Color(hex: 0x94d5ff)

    static let barlineSingle = Color(hex: 0x666688)
    static let barlineDouble = Color(hex: 0xbbbbbb)
    static let barlineRepeat = Color(hex: 0xee5533)

    static let markBg = Color(hex: 0xc0392b)
    static let markText = Color.white

    static let timeSig = Color(hex: 0xffd700)
    static let annotation = Color(hex: 0x87ceeb)

    static let inputBorder = Color(hex: 0x44aaff)
}
