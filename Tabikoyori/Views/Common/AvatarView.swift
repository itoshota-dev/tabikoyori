import SwiftUI

/// 名前の頭文字を丸の中に表示するアイコン
struct AvatarView: View {
    let name: String
    var size: CGFloat = 34

    var body: some View {
        Text(String(name.prefix(1)))
            .font(.serif(size * 0.45, bold: true))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [Theme.sand, Theme.accent], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle()
            )
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
    }
}
