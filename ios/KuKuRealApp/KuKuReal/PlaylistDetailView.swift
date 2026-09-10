import SwiftUI
import KuKuRealCore

/// One playlist's songs, in order — reorder via the Edit button's drag
/// handles, swipe to remove from the playlist (this never deletes the song
/// itself, only its membership in this list).
struct PlaylistDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let songRepository: SongRepository
    let playlistRepository: PlaylistRepository
    let allSongs: [SongRecord]

    @State private var playlist: Playlist
    @State private var openedRecord: SongRecord?

    init(playlist: Playlist, songRepository: SongRepository, playlistRepository: PlaylistRepository, allSongs: [SongRecord]) {
        _playlist = State(initialValue: playlist)
        self.songRepository = songRepository
        self.playlistRepository = playlistRepository
        self.allSongs = allSongs
    }

    private var songsInOrder: [SongRecord] {
        playlist.songIDs.compactMap { id in allSongs.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            List {
                if songsInOrder.isEmpty {
                    Text("这个歌单还没有曲子").foregroundColor(Theme.label)
                }
                ForEach(songsInOrder) { record in
                    Button {
                        openedRecord = record
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.song.title).foregroundColor(Theme.text)
                            if !record.song.composer.isEmpty {
                                Text(record.song.composer).font(.system(size: 12)).foregroundColor(Theme.label)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("移出歌单", role: .destructive) { remove(record) }
                    }
                }
                .onMove(perform: move)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bgPage.ignoresSafeArea())
            .navigationTitle(playlist.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $openedRecord) { record in
            ViewerView(record: record, repository: songRepository)
        }
    }

    private func remove(_ record: SongRecord) {
        playlist.songIDs.removeAll { $0 == record.id }
        playlistRepository.save(playlist)
    }

    private func move(from: IndexSet, to: Int) {
        var ids = playlist.songIDs
        ids.move(fromOffsets: from, toOffset: to)
        playlist.songIDs = ids
        playlistRepository.save(playlist)
    }
}
