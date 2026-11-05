import Foundation
@testable import Tabikoyori

/// テストで使うデータを作る道具。いくつものテストで同じ準備を使い回す
enum Fixtures {
    static let calendar = Calendar.current

    /// 日付を作る(例:date(2026, 11, 5) → 2026年11月5日 9:00)
    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// 今日から days 日後の日付(マイナスなら前の日)
    static func daysFromToday(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: Date())!
    }

    static func trip(
        title: String = "京都の旅行",
        start: Date = date(2026, 11, 5),
        end: Date = date(2026, 11, 7)
    ) -> Trip {
        Trip(title: title, region: .kyoto, startDate: start, endDate: end)
    }

    static func expense(_ amount: Int, _ category: ExpenseCategory = .food) -> Expense {
        Expense(title: "支出", amount: amount, category: category, date: date(2026, 11, 5))
    }

    static func spot(_ name: String = "清水寺") -> Spot {
        Spot(
            id: name, name: name, category: .cafe, area: "", address: "",
            region: .kyoto, coordinate: Coordinate(34.9949, 135.7850), art: .cafe
        )
    }

    /// 旅行を入れた TripStore。保存先はメモリの中なので、端末のデータには触れない
    static func store(with trips: [Trip] = []) -> TripStore {
        let snapshot = TripSnapshot(
            trips: trips, bookmarks: [], userName: "旅人",
            savedSpots: nil, customTemplates: [], bookmarkDates: nil
        )
        return TripStore(repository: InMemoryTripRepository(stored: snapshot), deletePhotos: { _ in })
    }
}
