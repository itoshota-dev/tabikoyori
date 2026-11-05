import Foundation
import Testing
@testable import Tabikoyori

// MARK: - テスト用の道具

/// タイムゾーンを決めたカレンダー(端末の設定に左右されないようにする)
private func calendar(_ identifier: String) -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: identifier)!
    return cal
}

private let tokyo = calendar("Asia/Tokyo")
/// 夏時間がある地域(アメリカ東部)
private let newYork = calendar("America/New_York")

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, in cal: Calendar) -> Date {
    cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private func spot(_ name: String) -> Spot {
    Spot(
        id: name, name: name, category: .cafe, area: "", address: "",
        region: .kyoto, coordinate: Coordinate(35.0, 135.7), art: .cafe
    )
}

/// 端末のカレンダーで日付を作った旅行(Trip の日数の計算は端末のカレンダーを使うため)
private func trip(days: Int, items: [ItineraryItem] = []) -> Trip {
    let cal = Calendar.current
    let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9))!
    let end = cal.date(byAdding: .day, value: days - 1, to: start)!
    var t = Trip(title: "テスト", region: .kyoto, startDate: start, endDate: end)
    t.items = items
    return t
}

// MARK: - 終了時刻の決まり

@Suite("終了時刻の決まり(ItineraryTimeRules)")
struct ItineraryTimeRulesTests {

    @Test("選べる終了時刻の上限は、旅行の最終日の 23:59")
    func latestEnd() {
        // 3日間の旅行の1日目の予定: 3日目の 23:59 = 2日分 + 1439分
        #expect(ItineraryTimeRules(dayCount: 3, itemDay: 0).latestEnd == 2 * 1440 + 1439)
        // 最終日の予定: その日の 23:59
        #expect(ItineraryTimeRules(dayCount: 3, itemDay: 2).latestEnd == 1439)
    }

    @Test("23:00開始・翌02:00終了は、開始日の0時から1560分")
    func endAcrossMidnight() {
        let rules = ItineraryTimeRules(dayCount: 3, itemDay: 0)
        #expect(rules.endTotal(day: 1, minuteOfDay: 2 * 60) == 1560)
    }

    @Test("2日目に始まる予定でも、開始日を基準に数える")
    func endTotalFromLaterDay() {
        let rules = ItineraryTimeRules(dayCount: 3, itemDay: 1)
        // 2日目開始・3日目の 01:00 終了 → 1440 + 60
        #expect(rules.endTotal(day: 2, minuteOfDay: 60) == 1500)
    }

    @Test("終了時刻は、開始時刻より前にならない")
    func endNotBeforeStart() {
        let rules = ItineraryTimeRules(dayCount: 3, itemDay: 0)
        #expect(rules.clampedEnd(500, start: 600) == 600)
        #expect(rules.clampedEnd(700, start: 600) == 700)
    }

    @Test("終了時刻は、旅行の最終日の 23:59 より後にならない")
    func endNotAfterTrip() {
        let rules = ItineraryTimeRules(dayCount: 3, itemDay: 0)
        #expect(rules.clampedEnd(5000, start: 600) == rules.latestEnd)
    }

    @Test("開始日の0時からの分を、日付と時刻に分ける", arguments: [
        (600, 0, 600),        // 当日の 10:00
        (1560, 1, 120),       // 翌日の 02:00
        (1440, 1, 0),         // ちょうど翌日の 0:00
        (5000, 2, 1439)       // 最終日を超える → 最終日の 23:59
    ])
    func endParts(total: Int, day: Int, minuteOfDay: Int) {
        let parts = ItineraryTimeRules(dayCount: 3, itemDay: 0).endParts(total)
        #expect(parts.day == day)
        #expect(parts.minuteOfDay == minuteOfDay)
    }

    @Test("分けた日付と時刻を戻すと、元の分になる")
    func roundTrip() {
        let rules = ItineraryTimeRules(dayCount: 4, itemDay: 1)
        for total in stride(from: 0, through: rules.latestEnd, by: 15) {
            let parts = rules.endParts(total)
            #expect(rules.endTotal(day: parts.day, minuteOfDay: parts.minuteOfDay) == total)
        }
    }
}

// MARK: - 予定(日付をまたぐ予定)

@Suite("予定と、日付をまたぐ予定(ItineraryItem)")
struct ItineraryItemTests {

    @Test("終了時刻を決めていないときは、開始の1時間後")
    func defaultEnd() {
        #expect(ItineraryItem(spot: spot("A"), day: 0, minutes: 600).end == 660)
    }

    @Test("終了時刻を決めていないときは、自動では日付をまたがない")
    func defaultEndDoesNotCrossMidnight() {
        #expect(ItineraryItem(spot: spot("A"), day: 0, minutes: 23 * 60 + 30).end == 1440)
    }

    @Test("翌朝に終わる予定は、翌日にかかり、翌々日にはかからない")
    func continuesIntoNextDay() {
        // 20:00 開始・翌 08:00 終了
        let hotel = ItineraryItem(spot: spot("ホテル"), day: 0, minutes: 20 * 60, endMinutes: 1440 + 8 * 60)
        #expect(hotel.continues(into: 1))
        #expect(!hotel.continues(into: 2))
    }

    @Test("ちょうど 0:00 に終わる予定は、翌日にはかからない")
    func endsAtMidnight() {
        let item = ItineraryItem(spot: spot("A"), day: 0, minutes: 22 * 60, endMinutes: 1440)
        #expect(!item.continues(into: 1))
    }

    @Test("翌日に出す複製は、0:00 から始まり、元の予定の ID を持つ")
    func occurrence() {
        let hotel = ItineraryItem(spot: spot("ホテル"), day: 0, minutes: 20 * 60, endMinutes: 1440 + 8 * 60)
        let copy = hotel.occurrence(onDay: 1)
        #expect(copy.isContinuation)
        #expect(copy.sourceID == hotel.id)
        #expect(copy.startOnDay == 0)
        #expect(copy.endOnDay == 8 * 60)
        // 何度作っても同じ ID になる(画面の更新で別物扱いにならないように)
        #expect(hotel.occurrence(onDay: 1).id == copy.id)
        #expect(copy.id != hotel.id)
    }
}

// MARK: - 旅程(その日の予定・予定の重なり)

@Suite("旅程の予定と、予定の重なり(Trip)")
struct TripScheduleTests {

    @Test("日付をまたぐ予定は、翌日の旅程のいちばん上にも出る")
    func carriedItemsComeFirst() {
        let hotel = ItineraryItem(spot: spot("ホテル"), day: 0, minutes: 20 * 60, endMinutes: 1440 + 8 * 60)
        let breakfast = ItineraryItem(spot: spot("朝食"), day: 1, minutes: 7 * 60)
        let t = trip(days: 3, items: [hotel, breakfast])

        let day2 = t.items(forDay: 1)
        #expect(day2.map(\.spot.name) == ["ホテル", "朝食"])
        #expect(day2.first?.isContinuation == true)
        // 3日目にはかからない
        #expect(t.items(forDay: 2).isEmpty)
    }

    @Test("時間が重なる予定を見つける")
    func overlapping() {
        let a = ItineraryItem(spot: spot("A"), day: 0, minutes: 600, endMinutes: 720)   // 10:00〜12:00
        let b = ItineraryItem(spot: spot("B"), day: 0, minutes: 700, endMinutes: 800)   // 11:40〜13:20
        let t = trip(days: 2, items: [a, b])
        #expect(t.overlappingItems(with: a).map(\.spot.name) == ["B"])
    }

    @Test("終わりと始まりがぴったり接する予定は、重なりとみなさない")
    func touchingIsNotOverlap() {
        let a = ItineraryItem(spot: spot("A"), day: 0, minutes: 600, endMinutes: 720)   // 10:00〜12:00
        let c = ItineraryItem(spot: spot("C"), day: 0, minutes: 720, endMinutes: 780)   // 12:00〜13:00
        let t = trip(days: 2, items: [a, c])
        #expect(t.overlappingItems(with: a).isEmpty)
    }

    @Test("日付をまたいで重なる予定も見つける")
    func overlapAcrossMidnight() {
        let hotel = ItineraryItem(spot: spot("ホテル"), day: 0, minutes: 20 * 60, endMinutes: 1440 + 8 * 60) // 〜翌 08:00
        let breakfast = ItineraryItem(spot: spot("朝食"), day: 1, minutes: 7 * 60, endMinutes: 8 * 60)        // 翌 07:00〜08:00
        let t = trip(days: 3, items: [hotel, breakfast])
        #expect(t.overlappingItems(with: breakfast).map(\.spot.name) == ["ホテル"])
    }

    @Test("自分自身は重なりに含めない")
    func excludesItself() {
        let a = ItineraryItem(spot: spot("A"), day: 0, minutes: 600, endMinutes: 720)
        let t = trip(days: 1, items: [a])
        #expect(t.overlappingItems(day: 0, start: 600, end: 720, excluding: a.id).isEmpty)
    }
}

// MARK: - 日付と時刻の変換

@Suite("日付と時刻の変換(ItineraryTimeConverter)")
struct ItineraryTimeConverterTests {

    private func kyotoTrip(in cal: Calendar, start: (Int, Int, Int), end: (Int, Int, Int)) -> Trip {
        Trip(
            title: "テスト", region: .kyoto,
            startDate: date(start.0, start.1, start.2, 9, in: cal),
            endDate: date(end.0, end.1, end.2, 9, in: cal)
        )
    }

    @Test("2日目の予定の基準は、2日目の 0:00")
    func dayStart() {
        let t = kyotoTrip(in: tokyo, start: (2026, 10, 28), end: (2026, 10, 31))
        let timeConverter = ItineraryTimeConverter(trip: t, day: 1, calendar: tokyo)
        #expect(timeConverter.dayStart == date(2026, 10, 29, in: tokyo))
    }

    @Test("分 → 日付つきの時刻")
    func minutesToDate() {
        let t = kyotoTrip(in: tokyo, start: (2026, 10, 28), end: (2026, 10, 31))
        let timeConverter = ItineraryTimeConverter(trip: t, day: 1, calendar: tokyo)
        #expect(timeConverter.date(600) == date(2026, 10, 29, 10, 0, in: tokyo))
        #expect(timeConverter.date(1560) == date(2026, 10, 30, 2, 0, in: tokyo))
    }

    @Test("日付つきの時刻 → 分")
    func dateToMinutes() {
        let t = kyotoTrip(in: tokyo, start: (2026, 10, 28), end: (2026, 10, 31))
        let timeConverter = ItineraryTimeConverter(trip: t, day: 1, calendar: tokyo)
        #expect(timeConverter.minutes(date(2026, 10, 29, 10, 0, in: tokyo)) == 600)
        #expect(timeConverter.minutes(date(2026, 10, 30, 2, 0, in: tokyo)) == 1560)
    }

    @Test("終了時刻の上限は旅行の最終日の 23:59、開始時刻の上限はその日の 23:59")
    func lastMoments() {
        let t = kyotoTrip(in: tokyo, start: (2026, 10, 28), end: (2026, 10, 31))
        let timeConverter = ItineraryTimeConverter(trip: t, day: 1, calendar: tokyo)
        #expect(timeConverter.lastMoment == date(2026, 10, 31, 23, 59, in: tokyo))
        #expect(timeConverter.dayLastMoment == date(2026, 10, 29, 23, 59, in: tokyo))
    }

    @Test("夏時間が終わる日(1日が25時間)でも、時刻がずれない")
    func fallBackDay() {
        // アメリカ東部は 2026年11月1日 2:00 に 1:00 へ戻る
        let t = kyotoTrip(in: newYork, start: (2026, 11, 1), end: (2026, 11, 2))
        let timeConverter = ItineraryTimeConverter(trip: t, day: 0, calendar: newYork)
        #expect(timeConverter.date(600) == date(2026, 11, 1, 10, 0, in: newYork))
        #expect(timeConverter.minutes(date(2026, 11, 1, 10, 0, in: newYork)) == 600)
        #expect(timeConverter.date(1440 + 60) == date(2026, 11, 2, 1, 0, in: newYork))
    }

    @Test("夏時間が始まる日(1日が23時間)でも、時刻がずれない")
    func springForwardDay() {
        // アメリカ東部は 2026年3月8日 2:00 に 3:00 へ進む
        let t = kyotoTrip(in: newYork, start: (2026, 3, 8), end: (2026, 3, 9))
        let timeConverter = ItineraryTimeConverter(trip: t, day: 0, calendar: newYork)
        #expect(timeConverter.date(600) == date(2026, 3, 8, 10, 0, in: newYork))
        #expect(timeConverter.minutes(date(2026, 3, 8, 10, 0, in: newYork)) == 600)
        #expect(timeConverter.date(1440 + 60) == date(2026, 3, 9, 1, 0, in: newYork))
    }

    @Test("夏時間が終わる日も、分 → 時刻 → 分 で元に戻る")
    func fallBackRoundTrip() {
        let t = kyotoTrip(in: newYork, start: (2026, 11, 1), end: (2026, 11, 2))
        let timeConverter = ItineraryTimeConverter(trip: t, day: 0, calendar: newYork)
        for m in stride(from: 0, to: 2 * 1440, by: 15) {
            #expect(timeConverter.minutes(timeConverter.date(m)) == m)
        }
    }

    @Test("その日の0時からの分(時計の時・分から求める)")
    func minuteOfDay() {
        #expect(ItineraryTimeConverter.minuteOfDay(date(2026, 10, 29, 13, 45, in: tokyo), calendar: tokyo) == 13 * 60 + 45)
    }
}
