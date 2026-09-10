import SwiftUI
import KuKuRealCore

/// Renders a laid-out chart as a fixed 16-column grid, matching the visual
/// language of `ireal_editor.html` (`.gcell`, `.chord`, `.mark`, `.ts`, ...):
/// dark cells, green bold chords, colored barlines, red section-mark badges,
/// yellow time signatures, and a selected-cell outline for editing.
///
/// `cellWidth` is supplied by the caller (screen width / 16) so all 16
/// columns always fit on one page — no horizontal scrolling. Long chord
/// names shrink to fit via `minimumScaleFactor` rather than truncating or
/// overflowing into neighboring cells.
struct ChartView: View {
    let rows: [ChartRow]
    let cellWidth: CGFloat
    var selectedTokenIndex: Int?
    var onSelect: (ChartCell) -> Void = { _ in }

    private let cellHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                switch row {
                case .cells(let cells):
                    HStack(spacing: 0) {
                        ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                            ChartCellView(cell: cell, isSelected: cell.tokenIndex == selectedTokenIndex)
                                .frame(width: cellWidth, height: cellHeight)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(cell) }
                        }
                    }
                case .spacer(let units):
                    Color.clear.frame(height: CGFloat(units) * 14)
                }
            }
        }
        .padding(.top, 14)
    }
}

private struct ChartCellView: View {
    let cell: ChartCell
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? Theme.selBg : Color.clear)
                .overlay(Rectangle().stroke(Theme.cellBorder, lineWidth: 0.5))
                .overlay(isSelected ? Rectangle().stroke(Theme.selOutline, lineWidth: 2) : nil)

            barlineOverlay

            cellText
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.leading, 3)
                .padding(.trailing, 1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let mark = cell.sectionMark {
                badge(mark, background: Theme.markBg, textColor: Theme.markText)
                    .offset(x: 1, y: -10)
            } else if let volta = cell.volta {
                badge(volta + ".", background: .clear, textColor: Theme.barlineRepeat)
                    .offset(x: 4, y: -10)
            }

            if let top = cell.timeSigTop, let bottom = cell.timeSigBottom {
                VStack(spacing: 0) {
                    Text(top)
                    Text(bottom)
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.timeSig)
                .offset(x: -10)
            }
        }
        .clipped()
    }

    @ViewBuilder
    private var barlineOverlay: some View {
        if let bl = cell.leftBarline {
            switch bl {
            case .single:
                Rectangle().fill(Theme.barlineSingle).frame(width: 1.5)
            case .double, .rdouble:
                HStack(spacing: 1.5) {
                    Rectangle().fill(Theme.barlineDouble).frame(width: 1)
                    Rectangle().fill(Theme.barlineDouble).frame(width: 1)
                }
            case .repOpen:
                HStack(spacing: 1.5) {
                    Rectangle().fill(Theme.repeatColor).frame(width: 2)
                    Rectangle().fill(Theme.repeatColor).frame(width: 1)
                }
            case .repClose:
                HStack(spacing: 1.5) {
                    Rectangle().fill(Theme.repeatColor).frame(width: 1)
                    Rectangle().fill(Theme.repeatColor).frame(width: 2)
                }
            case .final:
                HStack(spacing: 1.5) {
                    Rectangle().fill(Theme.barlineDouble).frame(width: 1)
                    Rectangle().fill(Theme.barlineDouble).frame(width: 2)
                }
            }
        }
    }

    private func badge(_ text: String, background: Color, textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 7, weight: .bold))
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .background(background)
            .foregroundColor(textColor)
            .cornerRadius(2)
    }

    /// The cell's text, typeset per-content-type. Chords go through
    /// `ChordSymbolText.render` (shared with the chord-entry preview badge)
    /// — everything else is a plain single-style `Text`, matching
    /// `ireal_editor.html`'s `.rc-*` / `.gcell.*` classes.
    private var cellText: Text {
        switch cell.content {
        case .chord(let raw):
            return ChordSymbolText.render(raw)
        case .space:
            return Text("")
        case .repeatOneBar:
            return Text("%").font(.system(size: 14, design: .monospaced)).foregroundColor(Theme.repeatColor)
        case .repeatTwoBars:
            return Text("//").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(Theme.repeatColor)
        case .pause:
            return Text("/").font(.system(size: 11, design: .monospaced)).foregroundColor(Theme.pause)
        case .noChord:
            return Text("N.C.").italic().font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(Theme.noChord)
        }
    }

}

#Preview("孤独患者") {
    GeometryReader { geo in
        ScrollView(.vertical) {
            let song = try! IrealURLCodec.parse(SampleData.lonelyPatient)
            ChartView(rows: ChartLayout.rows(for: song.tokens), cellWidth: geo.size.width / 16)
        }
    }
    .background(Theme.bgPage)
}

#Preview("视觉效果测试") {
    GeometryReader { geo in
        ScrollView(.vertical) {
            let song = try! IrealURLCodec.parse(SampleData.visualEffectsTest)
            ChartView(rows: ChartLayout.rows(for: song.tokens), cellWidth: geo.size.width / 16)
        }
    }
    .background(Theme.bgPage)
}
