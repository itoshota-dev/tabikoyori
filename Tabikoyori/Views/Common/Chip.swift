import SwiftUI

// MARK: - 共通パーツ

/// アプリ共通のタブ・絞り込みチップ。高さ・文字・枠線はすべてここで決める
/// (選択中も枠線の太さは同じにして、切り替えても大きさが変わらないようにする)
enum ChipMetrics {
    static let height: CGFloat = 34
    static let fontSize: CGFloat = 13
    static let horizontalPadding: CGFloat = 14
}

/// タブや絞り込みに使う、丸いボタン
struct Chip: View {
    let title: String
    let selected: Bool
    var systemImage: String? = nil
    /// true のとき、選択状態に関係なく淡い塗りのボタンとして表示する(「カバン」など)
    var soft: Bool = false
    /// 選択中の塗りの色(指定がなければ基調色)
    var tint: Color? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: ChipMetrics.fontSize, weight: .medium))
            .padding(.horizontal, ChipMetrics.horizontalPadding)
            .frame(height: ChipMetrics.height)
            .foregroundStyle(selected ? Color.white : Theme.accentDark)
            .background(fill, in: Capsule())
            .overlay(Capsule().strokeBorder(selected || soft ? Color.clear : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var fill: Color {
        if selected { return tint ?? Theme.accent }
        return soft ? Theme.sandLight : Theme.surface
    }
}

/// チップを並べる行。どの画面でも同じ間隔・左端にそろえる
struct ChipRow<Content: View, Trailing: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            content()
            Spacer(minLength: 8)
            trailing()
        }
        .frame(height: ChipMetrics.height)
    }
}

extension ChipRow where Trailing == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.init(content: content, trailing: { EmptyView() })
    }
}
