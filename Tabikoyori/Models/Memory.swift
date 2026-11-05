import Foundation

/// 旅の思い出(写真とメモ)
struct Memory: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var spotID: String?
    var spotName: String?
    var note: String
    var photos: [String] = []
    /// サンプル表示用のイラスト写真
    var artworks: [ArtStyle] = []
}

/// 思い出に付いた写真(またはサンプルのイラスト)
enum MemoryMedia: Hashable, Identifiable {
    case photo(String)
    case art(ArtStyle, Int)

    var id: String {
        switch self {
        case .photo(let name): return "p-" + name
        case .art(let style, let index): return "a-\(style.rawValue)-\(index)"
        }
    }
}

extension Memory {
    var media: [MemoryMedia] {
        var result: [MemoryMedia] = photos.map { MemoryMedia.photo($0) }
        for (index, style) in artworks.enumerated() {
            result.append(.art(style, index))
        }
        return result
    }
}

/// 一覧に出す思い出と、それがどの旅行のものか
struct MemoryEntry: Identifiable {
    let tripID: UUID
    let tripTitle: String
    let memory: Memory
    var id: UUID { memory.id }
}

/// 思い出の一覧の絞り込み
enum MemoryFilter: String, CaseIterable, Identifiable {
    case all, photo, memo, spot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "すべて"
        case .photo: return "写真"
        case .memo: return "メモ"
        case .spot: return "スポット"
        }
    }

    func matches(_ memory: Memory) -> Bool {
        switch self {
        case .all: return true
        case .photo: return !memory.media.isEmpty
        case .memo: return !memory.note.isEmpty
        case .spot: return memory.spotID != nil
        }
    }
}
