import Foundation

/// A saved chart: the `Song` data plus library bookkeeping (stable identity
/// so a save overwrites the same entry instead of duplicating it, and a
/// timestamp for sorting/display).
public struct SongRecord: Codable, Identifiable, Equatable {
    public var id: UUID
    public var song: Song
    public var updatedAt: Date

    public init(id: UUID = UUID(), song: Song, updatedAt: Date = Date()) {
        self.id = id
        self.song = song
        self.updatedAt = updatedAt
    }
}
