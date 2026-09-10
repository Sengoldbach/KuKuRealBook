import Foundation

/// Where saved charts live. `LocalSongRepository` is the only implementation
/// for now; a future `RemoteSongRepository` backed by the forum's REST API
/// (see `public/js/api.js`) can conform to the same protocol without any
/// UI code changing.
public protocol SongRepository {
    func list() -> [SongRecord]
    func save(_ record: SongRecord)
    func delete(id: UUID)
}

/// Stores each chart as one `{id}.json` file in a directory (defaults to
/// `Application Support/Songs` on-device). One file per song keeps saves
/// cheap (only the changed file is rewritten) and makes a single corrupt
/// file harmless to the rest of the library.
public final class LocalSongRepository: SongRepository {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// The on-device default: `Application Support/Songs`, created on first use.
    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Songs", isDirectory: true)
    }

    public func list() -> [SongRecord] {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SongRecord? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(SongRecord.self, from: data)
            }
        return records.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func save(_ record: SongRecord) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(record) else { return }
        try? data.write(to: fileURL(for: record.id), options: .atomic)
    }

    public func delete(id: UUID) {
        try? fileManager.removeItem(at: fileURL(for: id))
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }
}
