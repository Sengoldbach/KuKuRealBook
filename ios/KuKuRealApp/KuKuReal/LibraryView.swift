import SwiftUI
import KuKuRealCore
import UniformTypeIdentifiers

/// The app's home screen. Mirrors iReal Pro's own library: playlists +
/// a searchable/sortable "all songs" list, multi-select for bulk delete /
/// add-to-playlist, swipe-to-duplicate. Existing charts open in `ViewerView`
/// (read-only) first — editing is a deliberate extra step from there.
struct LibraryView: View {
    private let songRepository: SongRepository = LocalSongRepository(directory: LocalSongRepository.defaultDirectory())
    private let playlistRepository: PlaylistRepository = LocalPlaylistRepository(directory: LocalPlaylistRepository.defaultDirectory())

    private enum Destination: Identifiable {
        case view(SongRecord)
        case edit(SongRecord)

        var id: UUID {
            switch self {
            case .view(let record): return record.id
            case .edit(let record): return record.id
            }
        }
    }

    @State private var records: [SongRecord] = []
    @State private var playlists: [Playlist] = []
    @State private var searchText = ""
    @State private var sortOrder: SongSortOrder = .recentlyUpdated
    @State private var destination: Destination?
    @State private var openedPlaylist: Playlist?
    @State private var isImporting = false
    @State private var importErrorMessage: String?
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""

    private var displayedRecords: [SongRecord] {
        SongLibraryQuery.sort(SongLibraryQuery.filter(records, searchText: searchText), by: sortOrder)
    }

    var body: some View {
        NavigationStack {
            List {
                if !isSelecting {
                    Section("示例曲目") {
                        Button("孤独患者") { openSample(SampleData.lonelyPatient) }
                        Button("视觉效果测试") { openSample(SampleData.visualEffectsTest) }
                    }
                    .foregroundColor(Theme.btnText)

                    Section("歌单") {
                        ForEach(playlists) { playlist in
                            Button {
                                openedPlaylist = playlist
                            } label: {
                                HStack {
                                    Text(playlist.name).foregroundColor(Theme.text)
                                    Spacer()
                                    Text("\(playlist.songIDs.count)").foregroundColor(Theme.label)
                                }
                            }
                        }
                        Button("+ 新建歌单") { isCreatingPlaylist = true }
                            .foregroundColor(Theme.btnText)
                    }
                }

                Section(isSelecting ? "选择曲谱" : "所有曲谱") {
                    if displayedRecords.isEmpty {
                        Text(searchText.isEmpty ? "还没有保存的曲谱" : "没有匹配的曲谱").foregroundColor(Theme.label)
                    }
                    ForEach(displayedRecords) { record in
                        songRow(record)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bgPage.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "搜索曲名或作曲")
            .navigationTitle("KuKuReal")
            .toolbar { toolbarContent }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: reload)
        .fullScreenCover(item: $destination, onDismiss: reload) { destination in
            switch destination {
            case .view(let record):
                ViewerView(record: record, repository: songRepository)
            case .edit(let record):
                EditorView(record: record, repository: songRepository) { _ in }
            }
        }
        .fullScreenCover(item: $openedPlaylist, onDismiss: reload) { playlist in
            PlaylistDetailView(
                playlist: playlist,
                songRepository: songRepository,
                playlistRepository: playlistRepository,
                allSongs: records
            )
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.html, .plainText, .data]) { result in
            handleImport(result)
        }
        .alert(
            "导入失败",
            isPresented: Binding(get: { importErrorMessage != nil }, set: { if !$0 { importErrorMessage = nil } })
        ) {
            Button("好") { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
        .alert("新建歌单", isPresented: $isCreatingPlaylist) {
            TextField("歌单名", text: $newPlaylistName)
            Button("创建") { createPlaylist() }
            Button("取消", role: .cancel) { newPlaylistName = "" }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") { isSelecting = false; selectedIDs = [] }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Menu {
                    if playlists.isEmpty {
                        Text("还没有歌单")
                    }
                    ForEach(playlists) { playlist in
                        Button(playlist.name) { addSelected(to: playlist) }
                    }
                } label: {
                    Label("加入歌单", systemImage: "text.badge.plus")
                }
                .disabled(selectedIDs.isEmpty)

                Spacer()

                Button(role: .destructive) { bulkDelete() } label: {
                    Label("删除", systemImage: "trash")
                }
                .disabled(selectedIDs.isEmpty)
            }
        } else {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Picker("排序", selection: $sortOrder) {
                        Text("最近修改").tag(SongSortOrder.recentlyUpdated)
                        Text("曲名").tag(SongSortOrder.title)
                        Text("作曲").tag(SongSortOrder.composer)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("选择") { isSelecting = true }
                Menu {
                    Button("新建空白曲谱", systemImage: "doc.badge.plus") {
                        destination = .edit(SongRecord(song: .blank()))
                    }
                    Button("导入 .ireal 文件", systemImage: "square.and.arrow.down") {
                        isImporting = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func songRow(_ record: SongRecord) -> some View {
        Button {
            if isSelecting {
                if selectedIDs.contains(record.id) { selectedIDs.remove(record.id) } else { selectedIDs.insert(record.id) }
            } else {
                destination = .view(record)
            }
        } label: {
            HStack(spacing: 10) {
                if isSelecting {
                    Image(systemName: selectedIDs.contains(record.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedIDs.contains(record.id) ? Theme.btnText : Theme.label)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.song.title).foregroundColor(Theme.text)
                    if !record.song.composer.isEmpty {
                        Text(record.song.composer).font(.system(size: 12)).foregroundColor(Theme.label)
                    }
                }
                Spacer()
            }
        }
        .swipeActions(edge: .trailing) {
            if !isSelecting {
                Button("删除", role: .destructive) { delete(record) }
            }
        }
        .swipeActions(edge: .leading) {
            if !isSelecting {
                Button("复制") { duplicate(record) }.tint(.blue)
            }
        }
    }

    // MARK: - Actions

    private func reload() {
        records = songRepository.list()
        playlists = playlistRepository.list()
    }

    private func openSample(_ url: String) {
        guard let song = try? IrealURLCodec.parse(url) else { return }
        destination = .view(SongRecord(song: song))
    }

    private func delete(_ record: SongRecord) {
        songRepository.delete(id: record.id)
        reload()
    }

    private func duplicate(_ record: SongRecord) {
        var copy = record.song
        copy.title = record.song.title + " 副本"
        songRepository.save(SongRecord(song: copy))
        reload()
    }

    private func bulkDelete() {
        for id in selectedIDs { songRepository.delete(id: id) }
        selectedIDs = []
        isSelecting = false
        reload()
    }

    private func addSelected(to playlist: Playlist) {
        var updated = playlist
        for id in selectedIDs where !updated.songIDs.contains(id) {
            updated.songIDs.append(id)
        }
        updated.updatedAt = Date()
        playlistRepository.save(updated)
        selectedIDs = []
        isSelecting = false
        reload()
    }

    private func createPlaylist() {
        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        playlistRepository.save(Playlist(name: name))
        newPlaylistName = ""
        reload()
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure:
            importErrorMessage = "无法读取这个文件"
        case .success(let url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
                importErrorMessage = "无法读取这个文件"
                return
            }
            do {
                let song = try IrealFileFormat.parse(text)
                destination = .view(SongRecord(song: song))
            } catch {
                importErrorMessage = "这个文件里没找到有效的 iReal 谱面链接"
            }
        }
    }
}

#Preview {
    LibraryView()
}
