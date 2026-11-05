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
    var amount: Int
    var category: ExpenseCategory
    var date: Date
    var note: String = ""
}
