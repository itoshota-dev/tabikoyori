import Foundation

// MARK: - 通貨

/// 支出に使う通貨。ISO 4217 の3文字のコード(JPY・USD・EUR など)で表す
struct Currency: Hashable, Identifiable, Sendable {
    let code: String
    var id: String { code }

    static let yenCode = "JPY"
    var isYen: Bool { code == Self.yenCode }

    /// 通貨を選ぶ一覧に並べる、旅行でよく使う通貨
    static let common: [Currency] = [
        "JPY", "USD", "EUR", "KRW", "TWD", "CNY", "HKD", "THB", "SGD",
        "VND", "PHP", "IDR", "MYR", "GBP", "AUD", "NZD", "CAD", "CHF"
    ].map { Currency(code: $0) }

    /// 日本語の名前(例:ユーロ)。端末が知らない通貨はコードのまま
    var name: String {
        Locale(identifier: "ja_JP").localizedString(forCurrencyCode: code) ?? code
    }

    /// 金額を、その通貨の書き方で表す(例:€12.50、$3.00、₩5,000)
    func format(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.currencyCode = code
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount) \(code)"
    }
}

// MARK: - 円への換算

/// 外貨から円への換算。お金の計算は、誤差の出ない Decimal で行う
/// (Double だと 12.50 × 162.45 のような計算で、わずかな誤差が出ることがある)
enum CurrencyConversion {
    /// 外貨の金額 × レート を、四捨五入して円の整数にする
    static func yen(from amount: Decimal, rate: Decimal) -> Int {
        var product = amount * rate
        var rounded = Decimal()
        NSDecimalRound(&rounded, &product, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// 入力された文字を Decimal に変える。「1,234.5」のカンマは無視する。
    /// 数字と小数点(1つまで)以外が入っているときは nil
    static func parse(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty,
              cleaned.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
              cleaned.filter({ $0 == "." }).count <= 1
        else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }
}
