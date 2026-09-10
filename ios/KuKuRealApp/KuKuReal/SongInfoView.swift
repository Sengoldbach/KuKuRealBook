import SwiftUI
import KuKuRealCore

/// The editable title/composer/key/style fields, shown from the toolbar's
/// info button as a compact popover instead of a persistent bar — frees up
/// the vertical space that used to sit above the chart.
struct SongInfoView: View {
    @Binding var song: Song

    private static let keys = [
        "C", "Db", "D", "Eb", "E", "F", "F#", "Gb", "G", "Ab", "A", "Bb", "B",
        "A-", "Bb-", "B-", "C-", "C#-", "D-", "Eb-", "E-", "F-", "F#-", "G-", "G#-",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("曲目信息")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.label)

            field("曲名", text: $song.title)
            field("作曲", text: $song.composer)
            field("风格", text: $song.style)

            VStack(alignment: .leading, spacing: 4) {
                Text("调性").font(.system(size: 10)).foregroundColor(Theme.label)
                Picker("", selection: $song.key) {
                    ForEach(Self.keys, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Theme.text)
            }
        }
        .padding(16)
        .frame(width: 260)
        .background(Theme.bgBar)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundColor(Theme.label)
            TextField("", text: text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Theme.inputBg)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.border, lineWidth: 1))
        }
    }
}
