import Foundation

/// A named, ordered collection of songs — a song can belong to any number
/// of playlists (membership is just "this song's id appears in the list"),
/// matching iReal Pro's own playlist model.
public struct Playlist: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var songIDs: [UUID]
    public var updatedAt: Date

    public init(id: UUID = UUID(), name: String, songIDs: [UUID] = [], updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.songIDs = songIDs
        self.updatedAt = updatedAt
    }
}

public protocol PlaylistRepository {
    func list() -> [Playlist]
    func save(_ playlist: Playlist)
    func delete(id: UUID)
}

/// Same one-file-per-record storage pattern as `LocalSongRepository`, kept
/// as a separate small type (playlists and songs have very different
/// lifecycles — deleting a song shouldn't require rewriting every playlist
/// file, so callers just leave dangling ids and filter them at read time).
public final class LocalPlaylistRepository: PlaylistRepository {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Playlists", isDirectory: true)
    }

    public func list() -> [Playlist] {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let playlists = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Playlist? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Playlist.self, from: data)
            }
        return playlists.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func save(_ playlist: Playlist) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(playlist) else { return }
        try? data.write(to: fileURL(for: playlist.id), options: .atomic)
    }

    public func delete(id: UUID) {
        try? fileManager.removeItem(at: fileURL(for: id))
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }
}
