import Foundation
import MapKit

// MARK: - 旅

/// 旅行の状態(計画中・旅行中・完了)
enum TripStatus: String, Codable, CaseIterable, Identifiable {
    case planning, ongoing, done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .planning: return "計画中"
        case .ongoing: return "旅行中"
        case .done: return "完了"
        }
    }
}

/// 1つの旅行。旅程・思い出・お金・持ち物をまとめて持つ
struct Trip: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    /// 地図の初期位置や表紙の絵柄に使う地域(行き先の文字から自動で決まる)
    var region: Region
    /// 行き先(自由入力)。空のときは region の名前を使う
    var destination: String = ""
    /// 行き先の地図上の中心と広さ(自由入力の行き先を検索して保存する)
    var destCenter: Coordinate? = nil
    var destSpan: Double? = nil
    var startDate: Date
    var endDate: Date
    var coverPhoto: String? = nil
    var items: [ItineraryItem] = []
    var memories: [Memory] = []
    /// 旅行の予算(円)。0 は未設定
    var budget: Int = 0
    /// カテゴリーごとの予算(キーは ExpenseCategory の rawValue。未設定のカテゴリーは入れない)
    var categoryBudgets: [String: Int] = [:]
    var expenses: [Expense] = []
    var packing: [PackingItem] = []
    var bags: [PackingBag] = []
    /// 旅行を作成した日時(並び替えに使う)
    var createdAt: Date = Date()
    /// 予定の間の移動手段と所要時間
    var travel: [TravelLeg] = []

    enum CodingKeys: String, CodingKey {
        case id, title, region, destination, destCenter, destSpan, startDate, endDate, coverPhoto, items, memories, budget, categoryBudgets, expenses, packing, bags, createdAt, travel
    }

    /// 旅行期間と今日の日付から自動で決まる(手動では変更できない)
    var status: TripStatus {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let firstDay = calendar.startOfDay(for: startDate)
        let lastDay = calendar.startOfDay(for: endDate)
        if today < firstDay { return .planning }
        if today > lastDay { return .done }
        return .ongoing
    }

    var destinationName: String {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? region.name : trimmed
    }

    /// 地図の初期表示範囲
    var mapRegion: MKCoordinateRegion {
        if let center = destCenter {
            let span = destSpan ?? 0.3
            return MKCoordinateRegion(
                center: center.cl,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        }
        return region.mapRegion
    }

    /// 検索のヒントに使う、やや広めの範囲
    var searchRegion: MKCoordinateRegion {
        if let center = destCenter {
            let span = (destSpan ?? 0.3) * 2
            return MKCoordinateRegion(
                center: center.cl,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        }
        return region.searchRegion
    }

    var totalSpent: Int { expenses.reduce(0) { $0 + $1.amount } }

    /// そのカテゴリーの予算(0 は未設定)
    func categoryBudget(_ category: ExpenseCategory) -> Int {
        categoryBudgets[category.rawValue] ?? 0
    }

    func spent(in category: ExpenseCategory) -> Int {
        expenses.filter { $0.category == category }.reduce(0) { $0 + $1.amount }
    }
    var remainingBudget: Int { budget - totalSpent }
    var packedCount: Int { packing.filter { $0.checked }.count }

    var dayCount: Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: startDate), to: cal.startOfDay(for: endDate)).day ?? 0
        return max(1, days + 1)
    }

    func date(forDay day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day, to: startDate) ?? startDate
    }

    func travelLeg(from: UUID, to: UUID) -> TravelLeg? {
        travel.first { $0.fromItem == from && $0.toItem == to }
    }

    /// その日の予定。日付をまたぐ予定は、始まった日だけでなく、続いている日(終わる日まで)にも複製して入れる。
    /// 複製はその日の 0:00 から始まる扱いで、いちばん上に並ぶ(経路でも、その日の出発点になる)
    func items(forDay day: Int) -> [ItineraryItem] {
        let own = items.filter { $0.day == day }
        let carried = day < dayCount
            ? items.filter { $0.continues(into: day) }.map { $0.occurrence(onDay: day) }
            : []
        return (carried + own).sorted { lhs, rhs in
            if lhs.startOnDay != rhs.startOnDay { return lhs.startOnDay < rhs.startOnDay }
            if lhs.isContinuation != rhs.isContinuation { return lhs.isContinuation }
            return lhs.day < rhs.day
        }
    }

    /// 時間が重なっている、ほかの予定(日付をまたぐ予定も含めて、旅行の始まりからの通しの時刻で比べる)
    func overlappingItems(day: Int, start: Int, end: Int, excluding id: UUID) -> [ItineraryItem] {
        let rangeStart = day * minutesPerDay + start
        let rangeEnd = day * minutesPerDay + max(end, start)
        return sortedItems.filter { other in
            guard other.id != id else { return false }
            let otherStart = other.day * minutesPerDay + other.minutes
            let otherEnd = other.day * minutesPerDay + other.end
            return otherStart < rangeEnd && rangeStart < otherEnd
        }
    }

    /// この予定(複製なら元の予定)と時間が重なっている、ほかの予定
    func overlappingItems(with item: ItineraryItem) -> [ItineraryItem] {
        let source = items.first { $0.id == item.sourceID } ?? item
        return overlappingItems(day: source.day, start: source.minutes, end: source.end, excluding: source.id)
    }

    var sortedItems: [ItineraryItem] {
        items.sorted { lhs, rhs in
            if lhs.day != rhs.day { return lhs.day < rhs.day }
            return lhs.minutes < rhs.minutes
        }
    }

    /// 旅行期間の表示。例: 「2026.10.28 - 10.31」(年をまたぐときは終わりの年も出す)
    var dateRangeText: String {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.year, .month, .day], from: startDate)
        let end = calendar.dateComponents([.year, .month, .day], from: endDate)
        let startText = "\(start.year ?? 0).\(start.month ?? 0).\(start.day ?? 0)"
        if start.year == end.year {
            return "\(startText) - \(end.month ?? 0).\(end.day ?? 0)"
        } else {
            return "\(startText) - \(end.year ?? 0).\(end.month ?? 0).\(end.day ?? 0)"
        }
    }
}

/// 以前に保存した旅行データ(予算・持ち物のない形式)も読み込めるようにする
extension Trip {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        region = try container.decodeIfPresent(Region.self, forKey: .region) ?? .kyoto
        destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? ""
        destCenter = try container.decodeIfPresent(Coordinate.self, forKey: .destCenter)
        destSpan = try container.decodeIfPresent(Double.self, forKey: .destSpan)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        coverPhoto = try container.decodeIfPresent(String.self, forKey: .coverPhoto)
        items = try container.decodeIfPresent([ItineraryItem].self, forKey: .items) ?? []
        memories = try container.decodeIfPresent([Memory].self, forKey: .memories) ?? []
        budget = try container.decodeIfPresent(Int.self, forKey: .budget) ?? 0
        categoryBudgets = try container.decodeIfPresent([String: Int].self, forKey: .categoryBudgets) ?? [:]
        expenses = try container.decodeIfPresent([Expense].self, forKey: .expenses) ?? []
        packing = try container.decodeIfPresent([PackingItem].self, forKey: .packing) ?? []
        bags = try container.decodeIfPresent([PackingBag].self, forKey: .bags) ?? []
        // 古いデータには作成日時がないので、読み込み時に並び順から補う
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date.distantPast
        travel = try container.decodeIfPresent([TravelLeg].self, forKey: .travel) ?? []
    }
}
