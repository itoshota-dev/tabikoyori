import Foundation
import Testing
@testable import Tabikoyori

// MARK: - テスト用の道具

/// テストごとに空の一時フォルダを作る(本物の保存データには触れない)
private func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("TabikoyoriTests-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeSpot(_ name: String) -> Spot {
    Spot(
        id: name, name: name, category: .cafe, area: "", address: "",
        region: .kyoto, coordinate: Coordinate(35.0, 135.7), art: .cafe
    )
}

/// 比べやすいよう、日時は秒の端数のない値にした旅行
private func makeTrip(_ title: String, photos: [String] = [], cover: String? = nil) -> Trip {
    let start = Date(timeIntervalSince1970: 1_790_000_000)
    var trip = Trip(title: title, region: .kyoto, startDate: start, endDate: start.addingTimeInterval(2 * 86_400))
    trip.createdAt = start
    trip.coverPhoto = cover
    trip.items = [ItineraryItem(spot: makeSpot("清水寺"), day: 0, minutes: 600)]
    if !photos.isEmpty {
        trip.memories = [Memory(date: start, note: "楽しかった", photos: photos)]
    }
    return trip
}

private func makeSnapshot(_ trips: [Trip]) -> TripSnapshot {
    TripSnapshot(trips: trips, bookmarks: ["kiyomizu"], userName: "旅人", savedSpots: nil, customTemplates: [], bookmarkDates: nil)
}

private struct SaveFailure: Error {}

/// 消された写真を記録する(本物の写真ファイルには触れない)
private final class PhotoDeletionLog {
    var deleted: [String] = []
}

// MARK: - JSON ファイルへの保存

@Suite("JSON ファイルへの保存(JSONFileRepository)")
struct JSONFileRepositoryTests {

    @Test("保存して読み込むと、同じデータに戻る")
    func saveAndLoad() throws {
        let dir = try makeTempDirectory()
        let repo = JSONFileRepository(fileURL: dir.appendingPathComponent("tabikoyori.json"))
        let snapshot = makeSnapshot([makeTrip("京都の旅")])

        try repo.save(snapshot)
        #expect(try repo.load() == snapshot)
    }

    @Test("ファイルがないとき(初めての起動)は nil で、エラーにならない")
    func missingFile() throws {
        let dir = try makeTempDirectory()
        let repo = JSONFileRepository(fileURL: dir.appendingPathComponent("tabikoyori.json"))
        #expect(try repo.load() == nil)
    }

    @Test("壊れた JSON は、エラーになり、元のファイルを別名で残し、元のファイルも変えない")
    func corruptedFile() throws {
        let dir = try makeTempDirectory()
        let file = dir.appendingPathComponent("tabikoyori.json")
        let broken = Data("{ これは壊れたデータ".utf8)
        try broken.write(to: file)
        let repo = JSONFileRepository(fileURL: file)

        var backup: URL?
        do {
            _ = try repo.load()
            Issue.record("壊れたデータなのにエラーになりませんでした")
        } catch TripRepositoryError.corrupted(let url) {
            backup = url
        }

        // 別名で残したファイルの中身は、元のデータと同じ
        let backupURL = try #require(backup)
        #expect(try Data(contentsOf: backupURL) == broken)
        #expect(backupURL.lastPathComponent.hasPrefix("tabikoyori-broken-"))
        // 元のファイルは書き換えていない
        #expect(try Data(contentsOf: file) == broken)
    }

    @Test("保存に失敗したときは、エラーが呼び出し元に伝わる")
    func saveFailure() throws {
        let dir = try makeTempDirectory()
        // 存在しないフォルダの中には書けない
        let repo = JSONFileRepository(fileURL: dir.appendingPathComponent("no-such-folder/tabikoyori.json"))
        #expect(throws: (any Error).self) {
            try repo.save(makeSnapshot([]))
        }
    }
}

// MARK: - TripStore の読み込みと保存

@Suite("TripStore の読み込みと保存")
struct TripStoreStorageTests {

    @Test("起動時に、保存データを読み込む")
    func loadsOnInit() {
        let repo = InMemoryTripRepository(stored: makeSnapshot([makeTrip("京都の旅")]))
        let store = TripStore(repository: repo, deletePhotos: { _ in })
        #expect(store.trips.map(\.title) == ["京都の旅"])
        #expect(store.userName == "旅人")
        #expect(store.storageProblem == nil)
    }

    @Test("変更すると保存される")
    func savesChanges() {
        let repo = InMemoryTripRepository()
        let store = TripStore(repository: repo, deletePhotos: { _ in })
        store.addTrip(makeTrip("沖縄の旅"))
        #expect(repo.stored?.trips.map(\.title) == ["沖縄の旅"])
    }

    @Test("壊れたデータを別名で残せたときは、空で始めてお知らせを出し、保存は続けられる")
    func corruptedWithBackup() {
        let repo = InMemoryTripRepository()
        repo.loadError = TripRepositoryError.corrupted(backupURL: URL(fileURLWithPath: "/tmp/tabikoyori-broken.json"))
        let store = TripStore(repository: repo, deletePhotos: { _ in })

        #expect(store.trips.isEmpty)
        #expect(store.storageProblem != nil)
        #expect(!store.savingBlocked)

        store.addTrip(makeTrip("新しい旅行"))
        #expect(repo.saveCount == 1)
    }

    @Test("壊れたデータを残せなかったときは、上書きしないよう保存を止める")
    func corruptedWithoutBackup() {
        let original = makeSnapshot([makeTrip("大事な旅")])
        let repo = InMemoryTripRepository(stored: original)
        repo.loadError = TripRepositoryError.corrupted(backupURL: nil)
        let store = TripStore(repository: repo, deletePhotos: { _ in })

        #expect(store.savingBlocked)
        #expect(store.storageProblem != nil)

        store.addTrip(makeTrip("新しい旅行"))
        // 保存していない = 元のデータが空のデータで上書きされていない
        #expect(repo.saveCount == 0)
        #expect(repo.stored == original)
    }

    @Test("読み出せなかったときも、保存を止める")
    func unreadable() {
        let repo = InMemoryTripRepository()
        repo.loadError = TripRepositoryError.unreadable
        let store = TripStore(repository: repo, deletePhotos: { _ in })
        #expect(store.savingBlocked)
    }

    @Test("保存に失敗すると、お知らせを出す")
    func saveFailureShowsProblem() {
        let repo = InMemoryTripRepository()
        let store = TripStore(repository: repo, deletePhotos: { _ in })
        repo.saveError = SaveFailure()

        store.addTrip(makeTrip("沖縄の旅"))
        #expect(store.storageProblem?.title == "保存できませんでした")
    }
}

// MARK: - 削除と写真ファイル

@Suite("削除するときの写真ファイルの扱い")
struct TripStorePhotoTests {

    @Test("旅行を削除すると、保存できてから、思い出と表紙の写真を消す")
    func deleteTripDeletesPhotos() throws {
        let trip = makeTrip("京都の旅", photos: ["p1.jpg", "p2.jpg"], cover: "cover.jpg")
        let repo = InMemoryTripRepository(stored: makeSnapshot([trip]))
        let log = PhotoDeletionLog()
        let store = TripStore(repository: repo, deletePhotos: { log.deleted += $0 })

        store.deleteTrip(trip.id)

        #expect(store.trips.isEmpty)
        #expect(try #require(repo.stored).trips.isEmpty)
        #expect(Set(log.deleted) == ["p1.jpg", "p2.jpg", "cover.jpg"])
    }

    @Test("旅行の削除で保存に失敗したら、旅行を元に戻し、写真も消さない")
    func deleteTripKeepsPhotosWhenSaveFails() {
        let trip = makeTrip("京都の旅", photos: ["p1.jpg"], cover: "cover.jpg")
        let repo = InMemoryTripRepository(stored: makeSnapshot([trip]))
        let log = PhotoDeletionLog()
        let store = TripStore(repository: repo, deletePhotos: { log.deleted += $0 })
        repo.saveError = SaveFailure()

        store.deleteTrip(trip.id)

        #expect(store.trips.map(\.id) == [trip.id])
        #expect(log.deleted.isEmpty)
    }

    @Test("思い出の削除で保存に失敗したら、思い出を元に戻し、写真も消さない")
    func deleteMemoryKeepsPhotosWhenSaveFails() throws {
        let trip = makeTrip("京都の旅", photos: ["p1.jpg"])
        let memory = try #require(trip.memories.first)
        let repo = InMemoryTripRepository(stored: makeSnapshot([trip]))
        let log = PhotoDeletionLog()
        let store = TripStore(repository: repo, deletePhotos: { log.deleted += $0 })
        repo.saveError = SaveFailure()

        store.deleteMemory(memory.id, from: trip.id)

        #expect(store.trip(trip.id)?.memories.map(\.id) == [memory.id])
        #expect(log.deleted.isEmpty)
    }

    @Test("思い出の書き換えで保存に失敗したら、元に戻して false を返す")
    func updateMemoryRollsBack() throws {
        let trip = makeTrip("京都の旅", photos: ["p1.jpg"])
        var memory = try #require(trip.memories.first)
        let repo = InMemoryTripRepository(stored: makeSnapshot([trip]))
        let store = TripStore(repository: repo, deletePhotos: { _ in })
        repo.saveError = SaveFailure()

        memory.note = "書き換えたメモ"
        #expect(store.updateMemory(memory, in: trip.id) == false)
        #expect(store.trip(trip.id)?.memories.first?.note == "楽しかった")
    }
}

// MARK: - 保存に失敗したときの決まり

@Suite("保存に失敗したら、変更を元に戻す(TripStore)")
struct TripStoreRollbackTests {

    @Test("旅行の追加で保存に失敗したら、追加を取り消して false を返す")
    func addTripRollsBack() {
        let repo = InMemoryTripRepository()
        let store = TripStore(repository: repo, deletePhotos: { _ in })
        repo.saveError = SaveFailure()

        #expect(store.addTrip(makeTrip("沖縄の旅")) == false)
        #expect(store.trips.isEmpty)
    }

    @Test("思い出の追加で保存に失敗したら、追加を取り消して false を返す")
    func addMemoryRollsBack() {
        let trip = makeTrip("京都の旅")
        let repo = InMemoryTripRepository(stored: makeSnapshot([trip]))
        let store = TripStore(repository: repo, deletePhotos: { _ in })
        repo.saveError = SaveFailure()

        let memory = Memory(date: trip.startDate, note: "新しい思い出")
        #expect(store.addMemory(memory, to: trip.id) == false)
        #expect(store.trip(trip.id)?.memories.isEmpty == true)
    }

    @Test("表紙を変えて保存に失敗したら、元の表紙に戻し、前の表紙の写真も消さない")
    func updateCoverRollsBack() {
        let trip = makeTrip("京都の旅", cover: "old.jpg")
        let repo = InMemoryTripRepository(stored: makeSnapshot([trip]))
        let log = PhotoDeletionLog()
        let store = TripStore(repository: repo, deletePhotos: { log.deleted += $0 })
        repo.saveError = SaveFailure()

        var updated = trip
        updated.coverPhoto = "new.jpg"
        #expect(store.updateInfo(updated) == false)
        #expect(store.trip(trip.id)?.coverPhoto == "old.jpg")
        #expect(log.deleted.isEmpty)
    }

    @Test("表紙を変えて保存できたら、前の表紙の写真を消す")
    func updateCoverDeletesOldPhoto() {
        let trip = makeTrip("京都の旅", cover: "old.jpg")
        let repo = InMemoryTripRepository(stored: makeSnapshot([trip]))
        let log = PhotoDeletionLog()
        let store = TripStore(repository: repo, deletePhotos: { log.deleted += $0 })

        var updated = trip
        updated.coverPhoto = "new.jpg"
        #expect(store.updateInfo(updated))
        #expect(log.deleted == ["old.jpg"])
    }

    @Test("行き先の検索結果は、いまの行き先と同じときだけ保存する")
    func destinationGeoChecksCurrentDestination() {
        var trip = makeTrip("旅")
        trip.destination = "大阪"
        let repo = InMemoryTripRepository(stored: makeSnapshot([trip]))
        let store = TripStore(repository: repo, deletePhotos: { _ in })

        // 「京都」で検索していた古い結果は保存しない
        #expect(store.setDestinationGeo(center: Coordinate(35.0, 135.7), span: 0.3, forDestination: "京都", of: trip.id) == false)
        #expect(store.trip(trip.id)?.destCenter == nil)

        // いまの行き先「大阪」の結果は保存する
        #expect(store.setDestinationGeo(center: Coordinate(34.7, 135.5), span: 0.3, forDestination: "大阪", of: trip.id))
        #expect(store.trip(trip.id)?.destCenter == Coordinate(34.7, 135.5))
    }
}
