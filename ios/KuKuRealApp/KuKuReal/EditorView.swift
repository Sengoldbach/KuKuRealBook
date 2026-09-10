import SwiftUI
import KuKuRealCore

/// The chart editor screen: meta bar + grid + chord keyboard, plus the
/// file-operation toolbar (Cancel / Save / Export) the library screen hands
/// off to.
struct EditorView: View {
    @Environment(\.dismiss) private var dismiss

    let repository: SongRepository
    var onSaved: (SongRecord) -> Void

    @State private var record: SongRecord
    @State private var selectedTokenIndex: Int?
    @State private var sbText: String = ""
    @State private var isExporting = false
    @State private var isShowingInfo = false

    init(record: SongRecord, repository: SongRepository, onSaved: @escaping (SongRecord) -> Void) {
        _record = State(initialValue: record)
        self.repository = repository
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(.vertical) {
                    ChartView(
                        rows: ChartLayout.rows(for: record.song.tokens),
                        cellWidth: geo.size.width / 16,
                        selectedTokenIndex: selectedTokenIndex,
                        onSelect: select
                    )
                }
            }
            .background(Theme.bgPage.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text(record.song.title).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        isShowingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .popover(isPresented: $isShowingInfo) {
                        SongInfoView(song: $record.song)
                    }

                    Button {
                        isExporting = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button("保存") { save() }
                }
            }
            .toolbarBackground(Theme.bgBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: IrealDocument(text: IrealFileFormat.build(record.song)),
            contentType: .html,
            defaultFilename: IrealFileFormat.suggestedFilename(for: record.song)
        ) { _ in }
        .preferredColorScheme(.dark)
        .background(
            ChordKeyboardHost(isActive: isEditingBinding) {
                ChordInputBar(
                    text: $sbText,
                    onRoot: tapRoot,
                    onAppend: tapAppend,
                    onReplace: tapReplace,
                    onBackspace: tapBackspace,
                    onClear: tapClear,
                    onDone: { selectedTokenIndex = nil }
                )
            }
            .frame(width: 0, height: 0)
        )
    }

    private func save() {
        record.updatedAt = Date()
        repository.save(record)
        onSaved(record)
        dismiss()
    }

    /// Drives the custom keyboard's first-responder state from cell
    /// selection: selecting a cell shows the keyboard, and dismissing the
    /// keyboard by any means (Done button, swipe-down, tapping another
    /// field) clears the selection.
    private var isEditingBinding: Binding<Bool> {
        Binding(
            get: { selectedTokenIndex != nil },
            set: { active in if !active { selectedTokenIndex = nil } }
        )
    }

    // MARK: - Selection & editing

    private func select(_ cell: ChartCell) {
        selectedTokenIndex = cell.tokenIndex
        sbText = ChordEntry.displayText(for: record.song.tokens[cell.tokenIndex])
    }

    private func liveApply() {
        guard let idx = selectedTokenIndex, record.song.tokens.indices.contains(idx) else { return }
        guard let token = ChordEntry.makeToken(from: sbText) else { return }
        record.song.tokens[idx] = token
    }

    private func tapRoot(_ letter: String) {
        sbText = sbText.hasSuffix("/") ? sbText + letter : letter
        liveApply()
    }

    private func tapAppend(_ chars: String) {
        sbText += chars
        liveApply()
    }

    private func tapReplace(_ symbol: String) {
        guard let idx = selectedTokenIndex, record.song.tokens.indices.contains(idx) else { return }
        guard let token = ChordEntry.makeToken(from: symbol) else { return }
        record.song.tokens[idx] = token
        sbText = symbol
    }

    private func tapBackspace() {
        guard !sbText.isEmpty else { return }
        sbText.removeLast()
        liveApply()
    }

    private func tapClear() {
        sbText = ""
        liveApply()
    }
}
