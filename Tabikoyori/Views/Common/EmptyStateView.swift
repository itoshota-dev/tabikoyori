import SwiftUI

/// 表示するものがないときの案内(アイコン・タイトル・説明文)。
/// 旅の思い出・ホーム・旅程・経路で、同じ見た目にそろえるために使う
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String? = nil
    /// 上の余白。上に絞り込みのボタンなどがある画面と、ない画面で変える
    var topPadding: CGFloat = 70

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 38))
                .foregroundStyle(Theme.sand)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.text)
            if let message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.subText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, topPadding)
    }
}

/// 旅行がひとつもないときの、旅程タブ・経路タブの画面
struct NoTripView: View {
    /// 画面の上に表示する名前(「旅程」「経路」)
    let screenTitle: String

    var body: some View {
        ScrollView {
            // 旅の思い出の画面と同じ高さに並ぶように、絞り込みのボタンの分(34 + 14)だけ余白を足す
            EmptyStateView(
                systemImage: "airplane",
                title: "旅行がありません",
                message: "ホームの＋から、新しい旅を作成してください。",
                topPadding: 70 + ChipMetrics.height + 14
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { ScreenTitle(text: screenTitle) }
        }
    }
}
