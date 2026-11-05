import Foundation
import Testing
@testable import Tabikoyori

// MARK: - お金の計算

@Suite("旅行のお金の計算(Trip)")
struct TripMoneyCalculationTests {

    /// 予算 10,000円(食費は 5,000円)で、食費 3,000円・2,500円、交通費 6,000円を使った旅行
    private func tripWithExpenses() -> Trip {
        var trip = Fixtures.trip()
        trip.budget = 10_000
        trip.categoryBudgets = [ExpenseCategory.food.rawValue: 5_000]
        trip.expenses = [
            Fixtures.expense(3_000, .food),
            Fixtures.expense(2_500, .food),
            Fixtures.expense(6_000, .transport)
        ]
        return trip
    }

    @Test("支出の合計")
    func totalSpent() {
        #expect(tripWithExpenses().totalSpent == 11_500)
    }

    @Test("カテゴリーごとの支出。使っていないカテゴリーは 0")
    func spentByCategory() {
        let trip = tripWithExpenses()
        #expect(trip.spent(in: .food) == 5_500)
        #expect(trip.spent(in: .transport) == 6_000)
        #expect(trip.spent(in: .lodging) == 0)
    }

    @Test("予算を超えると、残りの予算はマイナスになる")
    func remainingBudget() {
        #expect(tripWithExpenses().remainingBudget == -1_500)
    }

    @Test("予算を決めていないカテゴリーは 0")
    func categoryBudget() {
        let trip = tripWithExpenses()
        #expect(trip.categoryBudget(.food) == 5_000)
        #expect(trip.categoryBudget(.shopping) == 0)
    }
}

// MARK: - 日数と状態

@Suite("旅行の日数と状態(Trip)")
struct TripDayCountAndStatusTests {

    @Test("日数は、出発日と帰着日の両方を数える")
    func dayCount() {
        let threeDays = Fixtures.trip(start: Fixtures.date(2026, 11, 5), end: Fixtures.date(2026, 11, 7))
        let dayTrip = Fixtures.trip(start: Fixtures.date(2026, 11, 5), end: Fixtures.date(2026, 11, 5))
        #expect(threeDays.dayCount == 3)
        #expect(dayTrip.dayCount == 1)
    }

    @Test("今日の日付から、計画中・旅行中・完了が決まる", arguments: [
        (3, 5, TripStatus.planning),    // これから行く
        (-1, 1, TripStatus.ongoing),    // 旅行中
        (0, 0, TripStatus.ongoing),     // 今日だけの日帰り
        (-5, -3, TripStatus.done)       // もう終わった
    ])
    func status(startOffset: Int, endOffset: Int, expected: TripStatus) {
        let trip = Fixtures.trip(
            start: Fixtures.daysFromToday(startOffset),
            end: Fixtures.daysFromToday(endOffset)
        )
        #expect(trip.status == expected)
    }
}

// MARK: - 行き先から地域を見つける

@Suite("行き先から地域を見つける(Region)")
struct RegionMatchTests {

    @Test("行き先の文字に地域名が入っていれば、その地域になる", arguments: [
        ("京都", Region.kyoto),
        ("京都・奈良", Region.kyoto),
        ("沖縄本島", Region.okinawa),
        ("パリ", Region.paris)
    ])
    func matches(text: String, expected: Region) {
        #expect(Region.match(text) == expected)
    }

    @Test("組み込みの地域がない行き先は nil")
    func noMatch() {
        #expect(Region.match("モンゴル") == nil)
        #expect(Region.match("") == nil)
    }
}

// MARK: - 表示の書式

@Suite("表示の書式(DisplayFormat)")
struct DisplayFormatTests {

    @Test("金額", arguments: [
        (0, "¥0"),
        (43_000, "¥43,000"),
        (-1_200, "-¥1,200")
    ])
    func yen(value: Int, expected: String) {
        #expect(DisplayFormat.yen(value) == expected)
    }

    @Test("所要時間。1分未満は「1分」", arguments: [
        (30.0, "1分"),
        (720.0, "12分"),
        (3_600.0, "1時間"),
        (3_900.0, "1時間5分")
    ])
    func duration(seconds: Double, expected: String) {
        #expect(DisplayFormat.duration(seconds) == expected)
    }

    @Test("距離。1km 未満はメートル", arguments: [
        (850.0, "850m"),
        (3_240.0, "3.2km")
    ])
    func distance(meters: Double, expected: String) {
        #expect(DisplayFormat.distance(meters) == expected)
    }
}
