import XCTest
@testable import KuKuRealCore

final class SongRepositoryTests: XCTestCase {
    private var tempDir: URL!
    private var repo: LocalSongRepository!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        repo = LocalSongRepository(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testEmptyRepositoryListsNothing() {
        XCTAssertEqual(repo.list(), [])
    }

    func testSaveThenListRoundTrips() {
        let record = SongRecord(song: Song(title: "Autumn Leaves", tokens: Tokenizer.tokenize("|C-7 |F7 |")))
        repo.save(record)

        let listed = repo.list()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.id, record.id)
        XCTAssertEqual(listed.first?.song, record.song)
    }

    func testSavingSameIdOverwritesRatherThanDuplicating() {
        var record = SongRecord(song: Song(title: "V1"))
        repo.save(record)
        record.song.title = "V2"
        repo.save(record)

        let listed = repo.list()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.song.title, "V2")
    }

    func testDeleteRemovesRecord() {
        let record = SongRecord(song: Song(title: "Temp"))
        repo.save(record)
        XCTAssertEqual(repo.list().count, 1)

        repo.delete(id: record.id)
        XCTAssertEqual(repo.list(), [])
    }

    func testListSortsNewestFirst() {
        let older = SongRecord(song: Song(title: "Older"), updatedAt: Date(timeIntervalSince1970: 1000))
        let newer = SongRecord(song: Song(title: "Newer"), updatedAt: Date(timeIntervalSince1970: 2000))
        repo.save(older)
        repo.save(newer)

        XCTAssertEqual(repo.list().map(\.song.title), ["Newer", "Older"])
    }

    func testCreatesDirectoryIfMissing() {
        let freshDir = tempDir.appendingPathComponent("nested/does/not/exist")
        let freshRepo = LocalSongRepository(directory: freshDir)
        XCTAssertEqual(freshRepo.list(), [])
        freshRepo.save(SongRecord(song: Song(title: "X")))
        XCTAssertEqual(freshRepo.list().count, 1)
    }
}
