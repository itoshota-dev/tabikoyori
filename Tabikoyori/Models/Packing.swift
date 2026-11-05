import Foundation

// MARK: - 旅の持ち物

/// 持ち物の種類(衣類・電子機器など)
enum PackingCategory: String, Codable, CaseIterable, Identifiable {
    case clothing, electronics, toiletries, documents, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clothing: return "衣類"
        case .electronics: return "電子機器"
        case .toiletries: return "洗面用品"
        case .documents: return "書類"
        case .other: return "その他"
        }
    }

    var symbol: String {
        switch self {
        case .clothing: return "tshirt.fill"
        case .electronics: return "iphone"
        case .toiletries: return "drop.fill"
        case .documents: return "doc.text.fill"
        case .other: return "bag.fill"
        }
    }
}

/// 持ち物リストの1項目
struct PackingItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var quantity: Int = 1
    var category: PackingCategory
    var checked: Bool = false
    var note: String = ""
    /// 入れるカバン(未設定なら nil)
    var bagID: UUID? = nil
}

/// カバンの種類(スーツケース・リュックなど)
enum BagKind: String, Codable, CaseIterable, Identifiable {
    case suitcase, boston, backpack, handbag, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .suitcase: return "スーツケース"
        case .boston: return "ボストンバッグ"
        case .backpack: return "バックパック"
        case .handbag: return "ハンドバッグ"
        case .other: return "その他のカバン"
        }
    }

    var symbol: String {
        switch self {
        case .suitcase: return "suitcase.rolling"
        case .boston: return "duffle.bag.fill"
        case .backpack: return "backpack.fill"
        case .handbag: return "handbag.fill"
        case .other: return "bag.fill"
        }
    }
}

/// 旅行に持っていくカバン
struct PackingBag: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: BagKind
}

/// 自分で作って保存できる持ち物テンプレート
struct TemplateEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var category: PackingCategory
    var quantity: Int = 1
}

/// 自分で作った持ち物テンプレート(マイテンプレート)
struct CustomTemplate: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var entries: [TemplateEntry] = []

    var summary: String { entries.map { $0.name }.joined(separator: "・") }
}

/// アプリに用意している持ち物テンプレート
enum PackingTemplate: String, CaseIterable, Identifiable {
    case domestic, overseas, outdoor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .domestic: return "国内旅行の基本セット"
        case .overseas: return "海外旅行セット"
        case .outdoor: return "アウトドアセット"
        }
    }

    var subtitle: String {
        switch self {
        case .domestic: return "週末旅行や観光におすすめ"
        case .overseas: return "海外旅行の準備に"
        case .outdoor: return "自然を楽しむ旅行に"
        }
    }

    var symbol: String {
        switch self {
        case .domestic: return "tram.fill"
        case .overseas: return "airplane"
        case .outdoor: return "mountain.2.fill"
        }
    }

    var entries: [(name: String, category: PackingCategory, quantity: Int)] {
        switch self {
        case .domestic:
            return [("着替え", .clothing, 3), ("下着", .clothing, 3), ("充電器", .electronics, 1),
                    ("モバイルバッテリー", .electronics, 1), ("歯ブラシ", .toiletries, 1),
                    ("タオル", .toiletries, 1), ("財布", .other, 1)]
        case .overseas:
            return [("パスポート", .documents, 1), ("航空券・予約情報", .documents, 1), ("着替え", .clothing, 3),
                    ("充電器", .electronics, 1), ("変換プラグ", .electronics, 1), ("歯ブラシ", .toiletries, 1),
                    ("常備薬", .other, 1), ("財布", .other, 1)]
        case .outdoor:
            return [("帽子", .clothing, 1), ("動きやすい服", .clothing, 1), ("タオル", .toiletries, 1),
                    ("雨具", .other, 1), ("水筒", .other, 1), ("モバイルバッテリー", .electronics, 1),
                    ("日焼け止め", .toiletries, 1)]
        }
    }

    var summary: String { entries.map { $0.name }.joined(separator: "・") }
}
