import SwiftUI
import KuKuRealCore

/// Read-only chart display — no cell selection, no chord keyboard. This is
/// where playback (highlighting the current chord, auto-scroll) will live;
/// editing is a deliberate separate step via the "编辑" button, not
/// something this screen does itself.
struct ViewerView: View {
    @Environment(\.dismiss) private var dismiss

    let repository: SongRepository
    @State private var record: SongRecord
    @State private var isEditing = false

    init(record: SongRecord, repository: SongRepository) {
        _record = State(initialValue: record)
        self.repository = repository
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                GeometryReader { geo in
                    ScrollView(.vertical) {
                        ChartView(
                            rows: ChartLayout.rows(for: record.song.tokens),
                            cellWidth: geo.size.width / 16,
                            selectedTokenIndex: nil
                        )
                    }
                }
                .background(Theme.bgPage)
            }
            .background(Theme.bgPage.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("编辑") { isEditing = true }
                }
            }
            .toolbarBackground(Theme.bgBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $isEditing) {
            EditorView(record: record, repository: repository) { updated in
                record = updated
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(record.song.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.text)
            HStack(spacing: 10) {
                if !record.song.composer.isEmpty {
                    Text(record.song.composer)
                }
                Text(record.song.key)
                if !record.song.style.isEmpty {
                    Text(record.song.style)
                }
            }
            .font(.system(size: 12))
            .foregroundColor(Theme.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.bgBar)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 0.5), alignment: .bottom)
    }
}
