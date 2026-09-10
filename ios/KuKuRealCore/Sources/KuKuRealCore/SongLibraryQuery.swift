import Foundation

public enum SongSortOrder: CaseIterable {
    case title, composer, recentlyUpdated
}

/// Pure filter/sort helpers over a song list — kept framework-agnostic and
/// testable so the library screen's search box and sort menu are just thin
/// wiring, not logic.
public enum SongLibraryQuery {
    public static func filter(_ records: [SongRecord], searchText: String) -> [SongRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return records }
        return records.filter {
            $0.song.title.localizedCaseInsensitiveContains(query)
                || $0.song.composer.localizedCaseInsensitiveContains(query)
        }
    }

    public static func sort(_ records: [SongRecord], by order: SongSortOrder) -> [SongRecord] {
        switch order {
        case .title:
            return records.sorted { $0.song.title.localizedStandardCompare($1.song.title) == .orderedAscending }
        case .composer:
            return records.sorted { $0.song.composer.localizedStandardCompare($1.song.composer) == .orderedAscending }
        case .recentlyUpdated:
            return records.sorted { $0.updatedAt > $1.updatedAt }
        }
    }
}
