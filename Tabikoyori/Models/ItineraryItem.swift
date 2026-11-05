import Foundation

/// 旅程の1つの予定(どのスポットに、何日目の何時から何時まで)
struct ItineraryItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var spot: Spot
    var day: Int
    var minutes: Int
    var visited: Bool = false
    /// 滞在の終了時刻(0時からの分)。nil のときは開始の1時間後
    var endMinutes: Int? = nil

    /// 日付をまたぐ予定を、次の日以降の旅程にも出すための「複製」のときだけ使う(保存はしない)
    /// - continuationOf: 元の予定の ID
    /// - continuationOffset: 元の予定の開始日から何日後の複製か(1 = 翌日)
    var continuationOf: UUID? = nil
    var continuationOffset: Int? = nil

    /// 終了時刻(開始日の0時からの分)。24時間(1440分)を超えると、翌日以降に終わる予定。
    /// 自分で決めていないときは開始の1時間後(ただし、自動で日付はまたがない)
    var end: Int { endMinutes ?? min(minutes + 60, minutesPerDay) }

    /// 元の予定の ID(複製なら元の予定、そうでなければ自分)。編集・削除などはこの ID で行う
    var sourceID: UUID { continuationOf ?? id }
    /// 前の日から続いている複製か
    var isContinuation: Bool { continuationOf != nil }
    /// この日の0時からの開始時刻(複製はその日の 0:00 から)
    var startOnDay: Int { isContinuation ? 0 : minutes }
    /// この日の0時からの終了時刻(24時間を超えると、さらに次の日以降に終わる)
    var endOnDay: Int { end - (continuationOffset ?? 0) * minutesPerDay }

    /// 開始日から数えて、day 日目にもかかっているか(日付をまたぐ予定の続きの日か)
    func continues(into day: Int) -> Bool {
        day > self.day && end > (day - self.day) * minutesPerDay
    }

    /// day 日目に出す複製(ID は元の予定と日付から決まるので、何度作っても同じ ID になる)
    func occurrence(onDay day: Int) -> ItineraryItem {
        var copy = self
        copy.id = Self.derivedID(id, offset: day - self.day)
        copy.continuationOf = id
        copy.continuationOffset = day - self.day
        return copy
    }

    /// 元の予定の ID と「何日後か」から、複製の ID を決める
    static func derivedID(_ id: UUID, offset: Int) -> UUID {
        var u = id.uuid
        u.14 = u.14 ^ 0xA5
        u.15 = u.15 &+ UInt8(truncatingIfNeeded: offset)
        return UUID(uuid: u)
    }
}

/// 旅程の隣り合う2つの予定の間の移動(移動手段と、検索で分かった所要時間・距離)
struct TravelLeg: Codable, Hashable {
    var fromItem: UUID
    var toItem: UUID
    var mode: String
    var seconds: Double?
    var meters: Double?

    var travelMode: TravelMode? { TravelMode(rawValue: mode) }
}
