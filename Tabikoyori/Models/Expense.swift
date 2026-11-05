import Foundation

// MARK: - 旅のお金

/// 支出の種類(食費・交通費など)
enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food, transport, lodging, sightseeing, shopping, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .food: return "食費"
        case .transport: return "交通費"
        case .lodging: return "宿泊費"
        case .sightseeing: return "観光費"
        case .shopping: return "買い物"
        case .other: return "その他"
        }
    }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "tram.fill"
        case .lodging: return "bed.double.fill"
        case .sightseeing: return "ticket.fill"
        case .shopping: return "bag.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

/// 1件の支出
struct Expense: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    /// 円の金額。外貨で入力したときは、レートで換算した金額。合計・予算・グラフはこれで計算する
    var amount: Int
    var category: ExpenseCategory
    var date: Date
    var note: String = ""
    /// 通貨のコード。円は "JPY"
    var currency: String = Currency.yenCode
    /// 外貨で入力した金額(円のときは nil)
    var originalAmount: Decimal? = nil
    /// 換算に使ったレート。外貨1単位が何円か(円のときは nil)
    var rate: Decimal? = nil

    /// 外貨で入力した支出か
    var isForeign: Bool { currency != Currency.yenCode }
}

extension Expense {
    enum CodingKeys: String, CodingKey {
        case id, title, amount, category, date, note, currency, originalAmount, rate
    }

    /// 保存したデータから読み込む。
    /// 通貨の項目がない古いデータも読めるように、新しい項目は無くてもよいことにする(無ければ円)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Int.self, forKey: .amount)
        category = try container.decode(ExpenseCategory.self, forKey: .category)
        date = try container.decode(Date.self, forKey: .date)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? Currency.yenCode
        originalAmount = try container.decodeIfPresent(Decimal.self, forKey: .originalAmount)
        rate = try container.decodeIfPresent(Decimal.self, forKey: .rate)
    }
}
