import Foundation

/// スポットの種類(寺・神社・カフェなど)
enum SpotCategory: String, Codable {
    case temple, shrine, nature, cafe, gourmet, landmark, sea, museum

    var label: String {
        switch self {
        case .temple: return "寺院"
        case .shrine: return "神社"
        case .nature: return "自然"
        case .cafe: return "カフェ"
        case .gourmet: return "グルメ"
        case .landmark: return "名所"
        case .sea: return "海・島"
        case .museum: return "美術館"
        }
    }
}

/// 写真の代わりに表示するイラストの絵柄
enum ArtStyle: String, Codable, CaseIterable {
    case temple, torii, bamboo, golden, street, cafe, castle, market
    case sea, cliff, tower, museum, cathedral, ruins, fountain, canal
}

// MARK: - スポット

/// 旅程やお気に入りに入れる場所
struct Spot: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var category: SpotCategory
    var rating: Double = 0
    var reviewCount: Int = 0
    var area: String
    var address: String
    var summary: String = ""
    var region: Region
    var coordinate: Coordinate
    var art: ArtStyle
    var isCustom: Bool = false
    var phone: String? = nil
    var website: String? = nil
    /// Apple マップの場所ID(MKMapItem.Identifier の文字列)。詳細カードの表示に使う
    var appleID: String? = nil
}
