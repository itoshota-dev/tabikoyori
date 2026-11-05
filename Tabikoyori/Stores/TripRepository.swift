import Foundation

// MARK: - 保存データの読み書き
//
// TripStore は、データを「どこに・どう保存するか」を知らない。
// 保存は TripRepository に任せ、本番では JSON ファイル、テストではメモリ上に保存する。

/// 保存するデータ全体
struct TripSnapshot: Codable, Equatable {
    var trips: [Trip]
    var bookmarks: [String]
    var userName: String
    var savedSpots: [String: Spot]?
    var customTemplates: [CustomTemplate]?
    var bookmarkDates: [String: Date]?
}

/// 保存データの読み込みで起きる問題
enum TripRepositoryError: Error, Equatable {
    /// 保存データが壊れていて読めない。元のファイルは backupURL に別名で残した(残せなかったときは nil)
    case corrupted(backupURL: URL?)
    /// ファイルはあるが、読み出せない(権限など)。中身が壊れているかは分からない
    case unreadable
}

/// 保存データの読み書きをする係
protocol TripRepository {
    /// 保存データを読み込む。
    /// - Returns: まだ保存データがない(初めての起動)ときは nil
    /// - Throws: 保存データはあるのに読めないとき(`TripRepositoryError`)
    func load() throws -> TripSnapshot?
    /// 保存する。失敗したらエラーを投げる
    func save(_ snapshot: TripSnapshot) throws
}

// MARK: - 本番用:JSON ファイル

/// 本番用の保存係。端末の書類フォルダの JSON ファイルに保存する
struct JSONFileRepository: TripRepository {
    let fileURL: URL

    /// アプリの書類フォルダの tabikoyori.json
    static var standard: JSONFileRepository {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return JSONFileRepository(fileURL: base.appendingPathComponent("tabikoyori.json"))
    }

    func load() throws -> TripSnapshot? {
        let fm = FileManager.default
        // ファイルがない = 初めての起動。エラーではない
        guard fm.fileExists(atPath: fileURL.path) else { return nil }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw TripRepositoryError.unreadable
        }

        do {
            return try JSONDecoder().decode(TripSnapshot.self, from: data)
        } catch {
            // 壊れていても、あとで調べたり直したりできるように、元のファイルを別名で残す
            throw TripRepositoryError.corrupted(backupURL: makeBackup())
        }
    }

    func save(_ snapshot: TripSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        // .atomic: いったん別のファイルに書いてから置き換えるので、書き込みの途中で失敗しても元のファイルは壊れない
        try data.write(to: fileURL, options: .atomic)
    }

    /// 元のファイルを「tabikoyori-broken-日時.json」として複製する。複製できなかったときは nil
    private func makeBackup() -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = fileURL.deletingPathExtension().lastPathComponent
            + "-broken-" + formatter.string(from: Date()) + ".json"
        let backup = fileURL.deletingLastPathComponent().appendingPathComponent(name)
        do {
            try FileManager.default.copyItem(at: fileURL, to: backup)
            return backup
        } catch {
            return nil
        }
    }
}

// MARK: - テスト・プレビュー用:メモリ上に保存

/// テスト・プレビュー用の保存係。メモリ上だけに保存する
final class InMemoryTripRepository: TripRepository {
    /// 保存されているデータ
    var stored: TripSnapshot?
    /// load() で投げるエラー(読み込みの失敗を試すとき)
    var loadError: Error?
    /// save() で投げるエラー(保存の失敗を試すとき)
    var saveError: Error?
    /// 保存に成功した回数
    private(set) var saveCount = 0

    init(stored: TripSnapshot? = nil) {
        self.stored = stored
    }

    func load() throws -> TripSnapshot? {
        if let loadError { throw loadError }
        return stored
    }

    func save(_ snapshot: TripSnapshot) throws {
        if let saveError { throw saveError }
        stored = snapshot
        saveCount += 1
    }
}
