import SwiftUI

/// 画面の下に出す、大きな丸いボタンの見た目
struct PrimaryCapsuleLabel: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Theme.accent, in: Capsule())
        .shadow(color: Theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

/// スポットの評価(地図から追加した場所は「地図から追加」)
struct RatingLabel: View {
    let spot: Spot

    var body: some View {
        if spot.rating > 0 {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.star)
                Text(String(format: "%.1f", spot.rating))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                if spot.reviewCount > 0 {
                    Text("(\(spot.reviewCount.formatted()))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subText)
                }
            }
        } else if spot.isCustom {
            Text("地図から追加")
                .font(.system(size: 12))
                .foregroundStyle(Theme.subText)
        }
    }
}

/// スポットの種類を表す小さな札
struct CategoryTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.accentDark)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Theme.sandLight, in: Capsule())
    }
}

/// ピンのマークと地名(住所の一部)
struct AreaLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
        }
        .foregroundStyle(Theme.subText)
        .lineLimit(1)
    }
}

/// お気に入りに入れる・外すハートのボタン
struct BookmarkButton: View {
    @Environment(TripStore.self) private var store
    let spot: Spot

    var body: some View {
        let saved = store.bookmarks.contains(spot.id)
        Button {
            store.toggleBookmark(spot)
        } label: {
            Image(systemName: saved ? "heart.fill" : "heart")
                .font(.system(size: 16))
                .foregroundStyle(saved ? Theme.accent : Theme.subText)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 画面の上に出すタイトル
struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.text)
    }
}
