import Foundation

// MARK: - 予定の時刻の計算(画面に依存しない)
//
// 予定の時刻は「予定の開始日の0時からの分」で表す。
// 1440分(24時間)を超えると、翌日以降に終わる予定になる(例: 1560分 = 翌日の 02:00)。

/// 1日の分数
let minutesPerDay = 24 * 60

/// 予定の時刻と日付の変換(開始日の0時からの分 ⇔ 日付つきの時刻)。
///
/// 「0時から何分たったか」ではなく、**時計に表示される時・分**で計算する。
/// 夏時間がある地域では、切り替わる日の1日が23時間や25時間になる。
/// 経過した分で計算すると、その日の時刻が1時間ずれてしまうため。
struct ItineraryTimeConverter {
    /// 計算に使うカレンダー(テストでは、タイムゾーンを決めたものを渡す)
    let calendar: Calendar
    /// 予定の開始日の0時
    let dayStart: Date
    /// 旅行の最終日の 23:59(終了時刻はここまで)
    let lastMoment: Date

    init(trip: Trip, day: Int, calendar: Calendar = .current) {
        self.calendar = calendar
        let tripStart = calendar.startOfDay(for: trip.startDate)
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: day, to: tripStart) ?? tripStart)
        dayStart = start
        let lastDay = calendar.startOfDay(for: trip.endDate)
        let last = Self.moment(minutesPerDay - 1, from: lastDay, calendar: calendar)
        lastMoment = max(last, Self.moment(minutesPerDay - 1, from: start, calendar: calendar))
    }

    /// 開始日の0時からの分 → 日付つきの時刻
    func date(_ minutes: Int) -> Date {
        Self.moment(minutes, from: dayStart, calendar: calendar)
    }

    /// 日付つきの時刻 → 開始日の0時からの分
    func minutes(_ date: Date) -> Int {
        let days = calendar.dateComponents([.day], from: dayStart, to: calendar.startOfDay(for: date)).day ?? 0
        return days * minutesPerDay + Self.minuteOfDay(date, calendar: calendar)
    }

    /// 開始日の 23:59(開始時刻はその日のうち)
    var dayLastMoment: Date { date(minutesPerDay - 1) }

    /// その日の0時からの分(時計の時・分から求める)
    static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// ある日の0時から minutes 分の時刻。何日後かを決めてから、その日の時・分を指定して作る
    private static func moment(_ minutes: Int, from dayStart: Date, calendar: Calendar) -> Date {
        // マイナスのときも正しく「何日前か」になるよう、切り捨ての割り算にする
        let days = Int((Double(minutes) / Double(minutesPerDay)).rounded(.down))
        let rest = minutes - days * minutesPerDay
        let day = calendar.date(byAdding: .day, value: days, to: dayStart) ?? dayStart
        return calendar.date(bySettingHour: rest / 60, minute: rest % 60, second: 0, of: day) ?? day
    }
}

/// 予定の終了時刻の決まり(時刻を変える画面などで使う)
struct ItineraryTimeRules {
    /// 旅行の日数
    let dayCount: Int
    /// 予定の開始日(0 = 1日目)
    let itemDay: Int

    init(dayCount: Int, itemDay: Int) {
        self.dayCount = max(1, dayCount)
        self.itemDay = itemDay
    }

    init(trip: Trip, itemDay: Int) {
        self.init(dayCount: trip.dayCount, itemDay: itemDay)
    }

    /// 選べる終了時刻のいちばん遅い時刻(旅行の最終日の 23:59。開始日の0時からの分)
    var latestEnd: Int {
        (dayCount - 1 - itemDay) * minutesPerDay + minutesPerDay - 1
    }

    /// 終了時刻を、選べる範囲(開始時刻〜旅行の最終日の 23:59)に収める
    func clampedEnd(_ end: Int, start: Int) -> Int {
        min(max(end, start), max(latestEnd, start))
    }

    /// 終了の「何日目」と「その日の0時からの分」→ 開始日の0時からの分
    func endTotal(day: Int, minuteOfDay: Int) -> Int {
        (day - itemDay) * minutesPerDay + minuteOfDay
    }

    /// 開始日の0時からの分 → 終了の「何日目」と「その日の0時からの分」(旅行の最終日を超えないようにする)
    func endParts(_ total: Int) -> (day: Int, minuteOfDay: Int) {
        let t = min(max(total, 0), latestEnd)
        return (itemDay + t / minutesPerDay, t % minutesPerDay)
    }
}
