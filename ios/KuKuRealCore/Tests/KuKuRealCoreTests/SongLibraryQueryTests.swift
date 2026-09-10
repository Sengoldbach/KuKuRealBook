import XCTest
@testable import KuKuRealCore

final class SongLibraryQueryTests: XCTestCase {
    private let autumn = SongRecord(song: Song(title: "Autumn Leaves", composer: "Johnny Mercer"), updatedAt: Date(timeIntervalSince1970: 1000))
    private let lonely = SongRecord(song: Song(title: "孤独患者", composer: "陈奕迅"), updatedAt: Date(timeIntervalSince1970: 3000))
    private let blue = SongRecord(song: Song(title: "Blue Bossa", composer: "Kenny Dorham"), updatedAt: Date(timeIntervalSince1970: 2000))

    private var all: [SongRecord] { [autumn, lonely, blue] }

    // MARK: - filter

    func testEmptySearchReturnsEverythingUnfiltered() {
        XCTAssertEqual(SongLibraryQuery.filter(all, searchText: ""), all)
    }

    func testFiltersByTitleCaseInsensitive() {
        let result = SongLibraryQuery.filter(all, searchText: "autumn")
        XCTAssertEqual(result.map(\.song.title), ["Autumn Leaves"])
    }

    func testFiltersByComposer() {
        let result = SongLibraryQuery.filter(all, searchText: "Dorham")
        XCTAssertEqual(result.map(\.song.title), ["Blue Bossa"])
    }

    func testFiltersByChineseTitle() {
        let result = SongLibraryQuery.filter(all, searchText: "孤独")
        XCTAssertEqual(result.map(\.song.title), ["孤独患者"])
    }

    func testWhitespaceOnlySearchIsTreatedAsEmpty() {
        XCTAssertEqual(SongLibraryQuery.filter(all, searchText: "   "), all)
    }

    func testNoMatchesReturnsEmpty() {
        XCTAssertEqual(SongLibraryQuery.filter(all, searchText: "zzz-no-match"), [])
    }

    // MARK: - sort

    func testSortByTitleAlphabetical() {
        let result = SongLibraryQuery.sort(all, by: .title)
        XCTAssertEqual(result.map(\.song.title), ["Autumn Leaves", "Blue Bossa", "孤独患者"])
    }

    func testSortByComposer() {
        // Alphabetical: Johnny (J) before Kenny (K).
        let result = SongLibraryQuery.sort(all, by: .composer)
        XCTAssertEqual(result.map(\.song.composer), ["Johnny Mercer", "Kenny Dorham", "陈奕迅"])
    }

    func testSortByRecentlyUpdatedNewestFirst() {
        let result = SongLibraryQuery.sort(all, by: .recentlyUpdated)
        XCTAssertEqual(result.map(\.song.title), ["孤独患者", "Blue Bossa", "Autumn Leaves"])
    }
}
