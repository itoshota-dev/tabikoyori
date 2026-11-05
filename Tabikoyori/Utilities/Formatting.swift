import Foundation
import CoreLocation

// MARK: - フォーマット

extension String {
    /// Googleマップの検索語に向けて、住所から郵便番号・国名・カンマを取り除く
    var cleanedForMapSearch: String {
        var text = self
        for pattern in ["〒\\s*\\d{3}-?\\d{4}", "\\b\\d{3}-\\d{4}\\b"] {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        for word in ["日本、", "日本,", "日本 ", "Japan"] {
            text = text.replacingOccurrences(of: word, with: " ")
        }
        text = text.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "、", with: " ")
        return text.split(whereSeparator: { $0 == " " || $0 == "　" }).joined(separator: " ")
    }

    /// URLのクエリ部分に安全に入れられる形にする
    var urlEncoded: String {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?#"))
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

/// 画面に表示する日付・時刻・金額・所要時間・距離の書式
enum DisplayFormat {

    // MARK: 日付

    /// 例: 10/28（水）
    static let shortMonthDayWeekday = formatter("M/d（E）")
    /// 例: 10月28日（水）
    static let monthDayWeekday = formatter("M月d日（E）")
    /// 例: 2026年10月28日
    static let yearMonthDay = formatter("yyyy年M月d日")
    /// 例: 2026年 10月28日(見出し用。年と月の間を少しあける)
    static let yearMonthDaySpaced = formatter("yyyy年 M月d日")

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = format
        return formatter
    }

    // MARK: 時刻(0時からの分)

    /// 例: 600 → 「10:00」
    static func clockTime(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// 旅程に出す開始時刻(前の日から続く予定の複製は「前日から」)
    static func startClockTime(_ item: ItineraryItem) -> String {
        item.isContinuation ? "前日から" : clockTime(item.minutes)
    }

    /// 終了時刻(開始日の0時からの分)。日付をまたぐときは「翌 01:00」「2日後 09:00」
    static func endClockTime(_ minutes: Int) -> String {
        let time = clockTime(minutes % minutesPerDay)
        if let prefix = dayOffsetPrefix(minutes) { return prefix + " " + time }
        return time
    }

    /// 日付をまたぐときに、時刻の前につける言葉(当日なら nil)。例: 「翌」「2日後」
    static func dayOffsetPrefix(_ minutes: Int) -> String? {
        let days = minutes / minutesPerDay
        switch days {
        case ..<1: return nil
        case 1: return "翌"
        default: return "\(days)日後"
        }
    }

    // MARK: 金額

    /// 例: ¥43,000 / -¥1,200
    static func yen(_ value: Int) -> String {
        (value < 0 ? "-¥" : "¥") + abs(value).formatted()
    }

    // MARK: 移動

    /// 所要時間。例: 「12分」「1時間」「1時間5分」(1分未満は「1分」)
    static func duration(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(1, Int((seconds / 60).rounded()))
        if totalMinutes < 60 { return "\(totalMinutes)分" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours)時間" : "\(hours)時間\(minutes)分"
    }

    /// 距離。例: 「850m」「3.2km」
    static func distance(_ meters: CLLocationDistance) -> String {
        meters < 1000 ? "\(Int(meters.rounded()))m" : String(format: "%.1fkm", meters / 1000)
    }
}
