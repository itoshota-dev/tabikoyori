import SwiftUI

/// 地図上のピン(丸いサムネイル+名前)
struct SpotPin: View {
    let spot: Spot
    var selected: Bool = false

    var body: some View {
        VStack(spacing: 3) {
            SpotArt(style: spot.art)
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                .overlay(Circle().stroke(selected ? Theme.accent : Color.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            Text(spot.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.92), in: Capsule())
        }
        .scaleEffect(selected ? 1.12 : 1)
        .animation(.spring(duration: 0.25), value: selected)
    }
}
