import Foundation
import Observation

/// アプリのデータ(旅行・お気に入り・テンプレートなど)を持ち、変更と保存を担当する。
/// 画面はここからデータを読み、変更もここのメソッドを通して行う。
///
/// データを変えるメソッドは、どれも同じ決まりで動く(`commit` を参照):
/// - 保存に成功したら true を返す
/// - 保存に失敗したら、変更前の状態に戻して false を返す(画面には「保存できませんでした」のお知らせが出る)
/// - 写真ファイルは、保存に成功してから消す
@Observable
final class TripStore {
    var trips: [Trip] = []
    var bookmarks: Set<String> = []
    /// お気に入りに入れた日時(新しいものを上に並べるため)
    var bookmarkDates: [String: Date] = [:]
    /// お気に入りに入れたスポットの実体(地図検索で見つけた場所も保存するため)
    var savedSpots: [String: Spot] = [:]
    var userName: String = "旅人"
    /// 自分で作った持ち物テンプレート(旅行をまたいで使える)
    var customTemplates: [CustomTemplate] = []
    var selectedTripID: UUID?

    /// 保存や読み込みで起きた問題(画面にお知らせを出す)
    var storageProblem: StorageProblem?
    /// 保存を止めているか(保存データが読めず、元のデータを守る必要があるとき)
    private(set) var savingBlocked = false

    /// 保存データの読み書きをする係(本番は JSON ファイル、テストはメモリ上)
    private let repository: TripRepository
    /// 写真ファイルを消す処理(テストでは、消されたかを記録する処理に差し替える)
    private let deletePhotos: ([String]) -> Void

    init(
        repository: TripRepository = JSONFileRepository.standard,
        deletePhotos: @escaping ([String]) -> Void = PhotoStorage.delete
    ) {
        self.repository = repository
        self.deletePhotos = deletePhotos
        loadFromRepository()
        // 旅程・経路タブで選んでいた旅行を読み込む
        if let text = UserDefaults.standard.string(forKey: Self.selectedTripKey) {
            selectedTripID = UUID(uuidString: text)
        }
    }

    // MARK: 取得

    func trip(_ id: UUID) -> Trip? {
        trips.first { $0.id == id }
    }

    private func index(of id: UUID) -> Int? {
        trips.firstIndex { $0.id == id }
    }

    /// 開始日が早い順に並べた旅行(選択メニューなどで使う)
    var tripsByStart: [Trip] {
        trips.sorted { a, b in
            a.startDate != b.startDate ? a.startDate < b.startDate : a.createdAt < b.createdAt
        }
    }

    private static let selectedTripKey = "selectedTripID"

    /// 旅程・経路タブの飛行機アイコンで旅行を選んだときに呼ぶ。選んだ旅行は、アプリを閉じても覚えておく
    func selectTrip(_ id: UUID) {
        selectedTripID = id
        UserDefaults.standard.set(id.uuidString, forKey: Self.selectedTripKey)
    }

    /// 旅程・経路タブで表示する旅行。
    /// 飛行機アイコンで選んだ旅行があれば、ずっとそれを使う(ホーム画面で別の旅行を開いても変えない)。
    /// まだ選んでいないとき(または選んだ旅行を消したとき)は、次の順で決める:
    /// 1. 旅行中の旅行のうち、開始日がいちばん早いもの
    /// 2. 旅行中がなければ、計画中の旅行のうち、開始日がいちばん早いもの
    /// 3. それもなければ、完了した旅行のうち、開始日がいちばん遅いもの
    var activeTripID: UUID? {
        if let id = selectedTripID, trips.contains(where: { $0.id == id }) {
            return id
        }
        let sorted = tripsByStart
        if let trip = sorted.first(where: { $0.status == .ongoing }) { return trip.id }
        if let trip = sorted.first(where: { $0.status == .planning }) { return trip.id }
        if let trip = sorted.last(where: { $0.status == .done }) { return trip.id }
        return sorted.first?.id
    }

    func entries(forFilter filter: MemoryFilter) -> [MemoryEntry] {
        var result: [MemoryEntry] = []
        for trip in trips {
            for memory in trip.memories where filter.matches(memory) {
                result.append(MemoryEntry(tripID: trip.id, tripTitle: trip.title, memory: memory))
            }
        }
        return result
    }

    /// IDからスポットを引く(お気に入り → 旅程の順)
    func spot(id: String) -> Spot? {
        if let s = savedSpots[id] { return s }
        for trip in trips {
            if let item = trip.items.first(where: { $0.spot.id == id }) {
                return item.spot
            }
        }
        return nil
    }

    var bookmarkedSpots: [Spot] {
        // お気に入りに入れた日時が新しいものを上に(日時が分からない古いものは、名前順で下に)
        bookmarks.compactMap { spot(id: $0) }.sorted { a, b in
            let da = bookmarkDates[a.id] ?? .distantPast
            let db = bookmarkDates[b.id] ?? .distantPast
            return da != db ? da > db : a.name < b.name
        }
    }

    // MARK: 旅行

    @discardableResult
    func addTrip(_ trip: Trip) -> Bool {
        commit { trips.insert(trip, at: 0) }
    }

    /// 旅行の名前・行き先・日程・表紙を変える(表紙を変えたときは、保存できてから前の表紙の写真を消す)
    @discardableResult
    func updateInfo(_ updated: Trip) -> Bool {
        guard let i = index(of: updated.id) else { return false }
        var oldCover: [String] = []
        if trips[i].coverPhoto != updated.coverPhoto, let old = trips[i].coverPhoto {
            oldCover = [old]
        }
        return commit(deletingPhotos: oldCover) {
            let destinationChanged = trips[i].destination != updated.destination
            trips[i].title = updated.title
            trips[i].region = updated.region
            trips[i].destination = updated.destination
            if destinationChanged {
                trips[i].destCenter = updated.destCenter
                trips[i].destSpan = updated.destSpan
            }
            trips[i].startDate = updated.startDate
            trips[i].endDate = updated.endDate
            trips[i].coverPhoto = updated.coverPhoto
            // 日程が短くなったときは、はみ出した予定を最終日に寄せる
            let lastDay = trips[i].dayCount - 1
            for j in trips[i].items.indices {
                trips[i].items[j].day = min(trips[i].items[j].day, lastDay)
            }
        }
    }

    /// 自由入力の行き先を地図で検索して見つかった、中心と広さを保存する。
    /// 検索している間に行き先が変わっていたら(古い検索の結果なので)保存しない
    @discardableResult
    func setDestinationGeo(center: Coordinate, span: Double, forDestination destination: String, of id: UUID) -> Bool {
        guard let i = index(of: id), trips[i].destination == destination else { return false }
        return commit {
            trips[i].destCenter = center
            trips[i].destSpan = span
        }
    }

    /// 旅行を削除する(保存できてから、思い出と表紙の写真を消す)
    @discardableResult
    func deleteTrip(_ id: UUID) -> Bool {
        guard let i = index(of: id) else { return false }
        var files = trips[i].memories.flatMap { $0.photos }
        if let cover = trips[i].coverPhoto {
            files.append(cover)
        }
        return commit(deletingPhotos: files) { _ = trips.remove(at: i) }
    }

    // MARK: 旅程

    /// その日に予定を追加するときの、おすすめの開始時刻(最後の予定の2時間後。最初の予定は 9:00)
    func nextMinutes(in trip: Trip, day: Int) -> Int {
        let times = trip.items.filter { $0.day == day }.map { $0.minutes }
        guard let last = times.max() else { return 9 * 60 }
        return min(last + 120, 22 * 60)
    }

    /// 旅程にスポットを追加する(同じ日に同じスポットがあるときは追加しない)
    @discardableResult
    func addSpot(_ spot: Spot, to tripID: UUID, day: Int, minutes: Int? = nil) -> Bool {
        guard let i = index(of: tripID) else { return false }
        let exists = trips[i].items.contains { $0.day == day && $0.spot.id == spot.id }
        if exists { return false }
        let start = minutes ?? nextMinutes(in: trips[i], day: day)
        return commit { trips[i].items.append(ItineraryItem(spot: spot, day: day, minutes: start)) }
    }

    @discardableResult
    func removeItem(_ itemID: UUID, from tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        // 日付をまたぐ予定の複製(翌日以降)の移動情報も消す
        let related = Set([itemID] + (1...60).map { ItineraryItem.derivedID(itemID, offset: $0) })
        return commit {
            trips[i].items.removeAll { $0.id == itemID }
            trips[i].travel.removeAll { related.contains($0.fromItem) || related.contains($0.toItem) }
        }
    }

    /// 2つの予定の間の移動手段を選ぶ(nil で解除)
    @discardableResult
    func setTravelMode(_ mode: TravelMode?, from: UUID, to: UUID, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        return commit {
            trips[i].travel.removeAll { $0.fromItem == from }
            if let mode {
                trips[i].travel.append(TravelLeg(fromItem: from, toItem: to, mode: mode.rawValue, seconds: nil, meters: nil))
            }
        }
    }

    /// 検索で分かった所要時間と距離を保存する
    @discardableResult
    func setTravelResult(seconds: Double?, meters: Double?, from: UUID, to: UUID, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID),
              let j = trips[i].travel.firstIndex(where: { $0.fromItem == from && $0.toItem == to }) else { return false }
        return commit {
            trips[i].travel[j].seconds = seconds
            trips[i].travel[j].meters = meters
        }
    }

    @discardableResult
    func toggleVisited(_ itemID: UUID, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID),
              let j = trips[i].items.firstIndex(where: { $0.id == itemID }) else { return false }
        return commit { trips[i].items[j].visited.toggle() }
    }

    /// 予定の開始・終了時刻を変える(終了は開始の0時からの分。開始より前にはしない)
    @discardableResult
    func setTimes(start: Int, end: Int, itemID: UUID, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID),
              let j = trips[i].items.firstIndex(where: { $0.id == itemID }) else { return false }
        return commit {
            trips[i].items[j].minutes = start
            trips[i].items[j].endMinutes = max(start, end)
        }
    }

    @discardableResult
    func moveItem(_ itemID: UUID, in tripID: UUID, toDay day: Int) -> Bool {
        guard let i = index(of: tripID),
              let j = trips[i].items.firstIndex(where: { $0.id == itemID }) else { return false }
        return commit { trips[i].items[j].day = day }
    }

    func tripContains(spotID: String, tripID: UUID) -> Bool {
        guard let trip = trip(tripID) else { return false }
        return trip.items.contains { $0.spot.id == spotID }
    }

    // MARK: 思い出

    @discardableResult
    func addMemory(_ memory: Memory, to tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        return commit { trips[i].memories.append(memory) }
    }

    @discardableResult
    func updateMemory(_ memory: Memory, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID),
              let j = trips[i].memories.firstIndex(where: { $0.id == memory.id }) else { return false }
        return commit { trips[i].memories[j] = memory }
    }

    /// 思い出を削除する(保存できてから写真を消す)
    @discardableResult
    func deleteMemory(_ memoryID: UUID, from tripID: UUID) -> Bool {
        guard let i = index(of: tripID),
              let j = trips[i].memories.firstIndex(where: { $0.id == memoryID }) else { return false }
        let files = trips[i].memories[j].photos
        return commit(deletingPhotos: files) { _ = trips[i].memories.remove(at: j) }
    }

    // MARK: 旅のお金

    /// 全体の予算と、カテゴリーごとの予算をまとめて保存する(0 以下のカテゴリーは未設定にする)
    @discardableResult
    func setBudgets(total: Int, categories: [ExpenseCategory: Int], for tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        var budgets: [String: Int] = [:]
        for (category, amount) in categories where amount > 0 {
            budgets[category.rawValue] = amount
        }
        return commit {
            trips[i].budget = max(0, total)
            trips[i].categoryBudgets = budgets
        }
    }

    /// 支出を追加する(同じ ID の支出があれば書き換える)
    @discardableResult
    func saveExpense(_ expense: Expense, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        return commit {
            if let j = trips[i].expenses.firstIndex(where: { $0.id == expense.id }) {
                trips[i].expenses[j] = expense
            } else {
                trips[i].expenses.append(expense)
            }
        }
    }

    @discardableResult
    func deleteExpense(_ expenseID: UUID, from tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        return commit { trips[i].expenses.removeAll { $0.id == expenseID } }
    }

    // MARK: 旅の持ち物

    /// 持ち物を追加する(同じ ID の持ち物があれば書き換える)
    @discardableResult
    func savePacking(_ item: PackingItem, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        return commit {
            if let j = trips[i].packing.firstIndex(where: { $0.id == item.id }) {
                trips[i].packing[j] = item
            } else {
                trips[i].packing.append(item)
            }
        }
    }

    @discardableResult
    func deletePacking(_ itemID: UUID, from tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        return commit { trips[i].packing.removeAll { $0.id == itemID } }
    }

    @discardableResult
    func togglePacking(_ itemID: UUID, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID),
              let j = trips[i].packing.firstIndex(where: { $0.id == itemID }) else { return false }
        return commit { trips[i].packing[j].checked.toggle() }
    }

    // MARK: 持ち物の一括操作

    @discardableResult
    func setPacked(_ checked: Bool, forItems ids: Set<UUID>, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        return commit {
            for j in trips[i].packing.indices where ids.contains(trips[i].packing[j].id) {
                trips[i].packing[j].checked = checked
            }
        }
    }

    @discardableResult
    func setBag(_ bagID: UUID?, forItems ids: Set<UUID>, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        return commit {
            for j in trips[i].packing.indices where ids.contains(trips[i].packing[j].id) {
                trips[i].packing[j].bagID = bagID
            }
        }
    }

    @discardableResult
    func deletePacking(items ids: Set<UUID>, from tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        return commit { trips[i].packing.removeAll { ids.contains($0.id) } }
    }

    /// テンプレートの持ち物を追加する(同じ名前がすでにあれば飛ばす)。追加した数を返す(保存に失敗したら 0)
    @discardableResult
    func addTemplate(_ template: PackingTemplate, to tripID: UUID) -> Int {
        appendPacking(template.entries.map { ($0.name, $0.category, $0.quantity) }, to: tripID)
    }

    @discardableResult
    func addCustomTemplate(_ template: CustomTemplate, to tripID: UUID) -> Int {
        appendPacking(template.entries.map { ($0.name, $0.category, $0.quantity) }, to: tripID)
    }

    /// 持ち物をまとめて追加する(entries は 名前・種類・数量)
    private func appendPacking(_ entries: [(String, PackingCategory, Int)], to tripID: UUID) -> Int {
        guard let i = index(of: tripID) else { return 0 }
        var added = 0
        let saved = commit {
            for (name, category, quantity) in entries where !trips[i].packing.contains(where: { $0.name == name }) {
                trips[i].packing.append(PackingItem(name: name, quantity: quantity, category: category))
                added += 1
            }
        }
        return saved ? added : 0
    }

    /// 別の旅行の持ち物リストを(未チェックの状態で)コピーする。追加した数を返す(保存に失敗したら 0)
    @discardableResult
    func copyPacking(from sourceID: UUID, to tripID: UUID) -> Int {
        guard let i = index(of: tripID), let source = trip(sourceID) else { return 0 }
        var added = 0
        let saved = commit {
            for item in source.packing where !trips[i].packing.contains(where: { $0.name == item.name }) {
                trips[i].packing.append(PackingItem(name: item.name, quantity: item.quantity, category: item.category, note: item.note))
                added += 1
            }
        }
        return saved ? added : 0
    }

    // MARK: マイテンプレート

    @discardableResult
    func saveCustomTemplate(_ template: CustomTemplate) -> Bool {
        commit {
            if let j = customTemplates.firstIndex(where: { $0.id == template.id }) {
                customTemplates[j] = template
            } else {
                customTemplates.append(template)
            }
        }
    }

    @discardableResult
    func deleteCustomTemplate(_ id: UUID) -> Bool {
        commit { customTemplates.removeAll { $0.id == id } }
    }

    /// 今の持ち物(未チェックの状態)をそのままテンプレートにして保存する
    @discardableResult
    func saveTemplate(named name: String, fromTrip tripID: UUID) -> Bool {
        guard let trip = trip(tripID), !trip.packing.isEmpty else { return false }
        let entries = trip.packing.map { TemplateEntry(name: $0.name, category: $0.category, quantity: $0.quantity) }
        return commit { customTemplates.append(CustomTemplate(name: name, entries: entries)) }
    }

    // MARK: カバン

    /// カバンを追加する(同じ ID のカバンがあれば書き換える)
    @discardableResult
    func saveBag(_ bag: PackingBag, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        return commit {
            if let j = trips[i].bags.firstIndex(where: { $0.id == bag.id }) {
                trips[i].bags[j] = bag
            } else {
                trips[i].bags.append(bag)
            }
        }
    }

    /// カバンを削除する(中の持ち物は消さず「カバン未設定」にする)
    @discardableResult
    func deleteBag(_ bagID: UUID, from tripID: UUID) -> Bool {
        guard let i = index(of: tripID) else { return false }
        return commit {
            trips[i].bags.removeAll { $0.id == bagID }
            for j in trips[i].packing.indices where trips[i].packing[j].bagID == bagID {
                trips[i].packing[j].bagID = nil
            }
        }
    }

    @discardableResult
    func setBag(_ bagID: UUID?, forItem itemID: UUID, in tripID: UUID) -> Bool {
        guard let i = index(of: tripID),
              let j = trips[i].packing.firstIndex(where: { $0.id == itemID }) else { return false }
        return commit { trips[i].packing[j].bagID = bagID }
    }

    // MARK: お気に入り

    @discardableResult
    func toggleBookmark(_ spot: Spot) -> Bool {
        commit {
            if bookmarks.contains(spot.id) {
                bookmarks.remove(spot.id)
                bookmarkDates[spot.id] = nil
                savedSpots[spot.id] = nil
            } else {
                bookmarks.insert(spot.id)
                bookmarkDates[spot.id] = Date()
                savedSpots[spot.id] = spot
            }
        }
    }

    // MARK: 設定

    @discardableResult
    func setUserName(_ name: String) -> Bool {
        commit { userName = name }
    }

    /// すべてのデータを消す(保存できてから写真も消す)
    @discardableResult
    func eraseAll() -> Bool {
        let files = trips.flatMap { $0.memories.flatMap { $0.photos } } + trips.compactMap { $0.coverPhoto }
        let erased = commit(deletingPhotos: files) {
            trips = []
            bookmarks = []
            bookmarkDates = [:]
            savedSpots = [:]
            customTemplates = []
        }
        if erased {
            selectedTripID = nil
            UserDefaults.standard.removeObject(forKey: Self.selectedTripKey)
        }
        return erased
    }

    // MARK: 変更と保存

    /// データを変更して保存する。データを変えるメソッドは、すべてこれを通す。
    /// - 保存に失敗したら、変更前の状態に戻して false を返す
    /// - deletingPhotos: 保存に成功したときだけ消す写真ファイル
    ///   (先に消すと、保存に失敗したときに「データは残っているのに写真がない」状態になるため)
    @discardableResult
    private func commit(deletingPhotos files: [String] = [], _ change: () -> Void) -> Bool {
        let before = snapshot
        change()
        guard save() else {
            restore(before)
            return false
        }
        if !files.isEmpty { deletePhotos(files) }
        return true
    }

    /// いまのデータ全体
    private var snapshot: TripSnapshot {
        TripSnapshot(
            trips: trips, bookmarks: Array(bookmarks), userName: userName,
            savedSpots: savedSpots, customTemplates: customTemplates, bookmarkDates: bookmarkDates
        )
    }

    /// 保存する。成功したら true。
    /// 失敗したときは画面にお知らせを出す(すでに出ているときは重ねて出さない)
    private func save() -> Bool {
        guard !savingBlocked else { return false }
        do {
            try repository.save(snapshot)
            return true
        } catch {
            if storageProblem == nil {
                storageProblem = StorageProblem(
                    title: "保存できませんでした",
                    message: "変更を保存できなかったため、元に戻しました。端末の空き容量を確認して、もう一度お試しください。"
                )
            }
            return false
        }
    }

    /// 変更前の状態に戻す(保存に失敗したとき)
    private func restore(_ snapshot: TripSnapshot) {
        trips = snapshot.trips
        bookmarks = Set(snapshot.bookmarks)
        userName = snapshot.userName
        savedSpots = snapshot.savedSpots ?? [:]
        customTemplates = snapshot.customTemplates ?? []
        bookmarkDates = snapshot.bookmarkDates ?? [:]
    }

    // MARK: 読み込み

    /// 起動時に保存データを読み込む。
    /// 読めなかったときに空のデータで上書きしてしまわないよう、「データがない」と「壊れている」を分けて扱う
    private func loadFromRepository() {
        do {
            if let loaded = try repository.load() {
                apply(loaded)
            }
            // nil のときは初めての起動。空のデータで始める
        } catch TripRepositoryError.corrupted(let backupURL?) {
            // 元のファイルは別名で残せたので、新しいデータの保存は続けてよい
            storageProblem = StorageProblem(
                title: "保存データを読み込めませんでした",
                message: "保存データが壊れていたため、空の状態で始めます。元のデータは「\(backupURL.lastPathComponent)」として残してあります。"
            )
        } catch {
            // 元のデータを残せなかった(または読み出せなかった)ので、上書きしないよう保存を止める
            savingBlocked = true
            storageProblem = StorageProblem(
                title: "保存データを読み込めませんでした",
                message: "元のデータを守るため、いまは変更を保存できません(変更しても元に戻ります)。アプリを再起動してもこの表示が出るときは、お問い合わせください。"
            )
        }
    }

    /// 読み込んだ保存データを、いまのデータに反映する
    private func apply(_ snapshot: TripSnapshot) {
        // 作成日時のない古い旅行には、保存されている並び順(新しいものが先頭)から作成日時を補う
        let count = snapshot.trips.count
        trips = snapshot.trips.enumerated().map { index, trip in
            var trip = trip
            if trip.createdAt == Date.distantPast {
                trip.createdAt = Date(timeIntervalSince1970: 1_700_000_000 + Double(count - index))
            }
            return trip
        }
        bookmarks = Set(snapshot.bookmarks)
        userName = snapshot.userName
        savedSpots = snapshot.savedSpots ?? [:]
        customTemplates = snapshot.customTemplates ?? []
        bookmarkDates = snapshot.bookmarkDates ?? [:]
    }
}

/// 保存・読み込みの問題を知らせるお知らせ
struct StorageProblem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
