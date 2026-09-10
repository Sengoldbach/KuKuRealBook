import SwiftUI

/// A fixed-grid chord keyboard, like iReal Pro's own custom keyboard: rows
/// of equal-width keys you tap to build a chord, with a live typeset
/// preview above — not a labeled/grouped button panel.
///
/// Row 1: roots + accidentals   C D E F G A B ♭ ♯ −
/// Row 2: extensions + quality  1 2 3 4 5 6 7 9 ° ø Δ
/// Row 3: sus/add/aug/bass/⌫    sus add + / ⌫ ✕
/// Row 4: special symbols       % // N.C.  ·  完成
struct ChordInputBar: View {
    @Binding var text: String
    var onRoot: (String) -> Void
    var onAppend: (String) -> Void
    var onReplace: (String) -> Void
    var onBackspace: () -> Void
    var onClear: () -> Void
    var onDone: () -> Void

    private let roots = ["C", "D", "E", "F", "G", "A", "B"]
    private let extensions = ["1", "2", "3", "4", "5", "6", "7", "9"]

    var body: some View {
        VStack(spacing: 8) {
            preview

            keyRow {
                ForEach(roots, id: \.self) { letter in key(letter) { onRoot(letter) } }
                key("♭") { onAppend("b") }
                key("♯") { onAppend("#") }
                key("−") { onAppend("-") }
            }
            keyRow {
                ForEach(extensions, id: \.self) { ext in key(ext) { onAppend(ext) } }
                key("°") { onAppend("o") }
                key("ø") { onAppend("h") }
                key("Δ") { onAppend("^") }
            }
            keyRow {
                key("sus") { onAppend("sus") }
                key("add") { onAppend("add") }
                key("+") { onAppend("+") }
                key("/") { onAppend("/") }
                key("⌫", action: onBackspace)
                key("✕", action: onClear)
            }
            keyRow {
                key("%") { onReplace("%") }
                key("//") { onReplace("//") }
                key("N.C.") { onReplace("N.C.") }
                Spacer(minLength: 4)
                Button(action: onDone) {
                    Text("完成")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.chord)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Theme.btnBg)
                        .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Theme.bgToolbar)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 0.5), alignment: .top)
    }

    private var preview: some View {
        HStack(spacing: 10) {
            ChordSymbolText.render(text, rootSize: 18, accSize: 11, qualitySize: 12, bassSize: 11)
                .frame(minWidth: 40, minHeight: 26, alignment: .leading)

            Text(text.isEmpty ? "—" : text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.label)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.inputBg)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.inputBorder, lineWidth: 1))
    }

    private func keyRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 5) { content() }
    }

    private func key(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.btnText)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Theme.btnBg)
                .cornerRadius(6)
        }
    }
}
