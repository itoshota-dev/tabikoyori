import SwiftUI

// MARK: - 旅のお金(予算・支出)

extension ExpenseCategory {
    /// グラフの色(落ち着いたベージュ〜ブラウン系)
    var color: Color {
        switch self {
        case .food: return Color(hex: 0xC28E86)
        case .transport: return Color(hex: 0x8C6B5C)
        case .lodging: return Color(hex: 0xCFA77F)
        case .sightseeing: return Color(hex: 0xB5AB95)
        case .shopping: return Color(hex: 0xB0806A)
        case .other: return Color(hex: 0xDCCABD)
        }
    }
}
