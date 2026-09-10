import XCTest
@testable import KuKuRealCore

final class PlaylistRepositoryTests: XCTestCase {
    private var tempDir: URL!
    private var repo: LocalPlaylistRepository!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        repo = LocalPlaylistRepository(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testEmptyRepositoryListsNothing() {
        XCTAssertEqual(repo.list(), [])
    }

    func testSaveThenListRoundTrips() {
        let songID = UUID()
        let playlist = Playlist(name: "Gig 1", songIDs: [songID])
        repo.save(playlist)

        let listed = repo.list()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.name, "Gig 1")
        XCTAssertEqual(listed.first?.songIDs, [songID])
    }

    func testSavingSameIdOverwrites() {
        var playlist = Playlist(name: "V1")
        repo.save(playlist)
        playlist.name = "V2"
        repo.save(playlist)

        let listed = repo.list()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.name, "V2")
    }

    func testDeleteRemovesPlaylist() {
        let playlist = Playlist(name: "Temp")
        repo.save(playlist)
        repo.delete(id: playlist.id)
        XCTAssertEqual(repo.list(), [])
    }

    func testOrderedSongIDsArePreserved() {
        let ids = [UUID(), UUID(), UUID()]
        let playlist = Playlist(name: "Set", songIDs: ids)
        repo.save(playlist)
        XCTAssertEqual(repo.list().first?.songIDs, ids)
    }
}
