import SwiftUI

/// 保存済み写真を、親のサイズいっぱいに表示する
struct StoredPhoto: View {
    let name: String

    var body: some View {
        GeometryReader { geo in
            if let image = PhotoStorage.image(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                Theme.sandLight
            }
        }
    }
}

/// 思い出の写真(またはサンプルのイラスト)を1枚表示する
struct MediaTile: View {
    let media: MemoryMedia

    var body: some View {
        switch media {
        case .photo(let name):
            StoredPhoto(name: name)
        case .art(let style, let index):
            SpotArt(style: style, variant: index)
        }
    }
}
