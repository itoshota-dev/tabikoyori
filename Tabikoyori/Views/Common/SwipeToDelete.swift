import SwiftUI
import UIKit

// MARK: - 左へスワイプして削除

/// いまスワイプで開いている行(同時に開くのは1つだけにする)
@MainActor
@Observable
final class SwipeRowCenter {
    static let shared = SwipeRowCenter()
    var openID: AnyHashable?
}

/// カードや行を左へスワイプすると、右側に赤い削除ボタンが出てくる。
/// iOS 標準の一覧のスワイプと違い、行の背景や形は変わらない(行がそのまま横へずれるだけ)。
/// - 少しスワイプして離すと、削除ボタンが出たまま止まる。ボタンを押すと削除
/// - 右へのスワイプでは動かない(開いているときだけ、右へスワイプして閉じられる)
/// - 開いているときに行をタップするか、ほかの行をスワイプすると閉じる
/// - 上下のスワイプ・フリックは、すぐに画面のスクロールにまかせる(引っかからないように UIKit で判定)
struct SwipeToDeleteModifier: ViewModifier {
    let id: AnyHashable
    var enabled: Bool = true
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0

    private let actionWidth: CGFloat = 68
    private var center: SwipeRowCenter { SwipeRowCenter.shared }
    private var isOpen: Bool { offset < -1 }

    func body(content: Content) -> some View {
        content
            // 開いているあいだは、行のタップで閉じる(行の中のボタンは押さない)
            .overlay {
                if isOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { close() }
                }
            }
            .offset(x: offset)
            // 削除ボタンは、ずらす前の行の右端に置く(行がずれると見えてくる)
            .background(alignment: .trailing) {
                if isOpen {
                    deleteButton
                        .frame(width: actionWidth)
                        .opacity(min(1, Double(-offset / (actionWidth * 0.6))))
                        .scaleEffect(min(1, max(0.6, -offset / actionWidth)))
                }
            }
            .gesture(
                HorizontalSwipeGesture(
                    enabled: enabled,
                    allowsRight: isOpen,
                    onBegan: {
                        startOffset = offset
                        center.openID = id
                    },
                    onChanged: { dx in
                        var x = startOffset + dx
                        // 右へは動かさない。削除ボタンより先へは重く動く
                        x = min(x, 0)
                        if x < -actionWidth { x = -actionWidth + (x + actionWidth) / 3 }
                        offset = x
                    },
                    onEnded: { dx, velocity in
                        let predicted = startOffset + dx + velocity * 0.15
                        if predicted < -actionWidth / 2 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { offset = -actionWidth }
                        } else {
                            close()
                        }
                    }
                )
            )
            .onChange(of: center.openID) { _, newValue in
                if newValue != id, offset != 0 { close(updateCenter: false) }
            }
            .onChange(of: enabled) { _, newValue in
                if !newValue { close() }
            }
            .accessibilityAction(named: "削除") { delete() }
    }

    private var deleteButton: some View {
        Button(action: delete) {
            VStack(spacing: 3) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color(hex: 0xE5534B), in: Circle())
                Text("削除")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.subText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func close(updateCenter: Bool = true) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { offset = 0 }
        if updateCenter, center.openID == id { center.openID = nil }
    }

    private func delete() {
        if center.openID == id { center.openID = nil }
        offset = 0
        withAnimation(.easeInOut(duration: 0.25)) { onDelete() }
    }
}

/// 横向きのスワイプだけを受け取るジェスチャー。
/// 動き始めの向きが縦なら、すぐにあきらめて画面のスクロールにまかせる
private struct HorizontalSwipeGesture: UIGestureRecognizerRepresentable {
    var enabled: Bool
    /// 右向きのスワイプも受け取るか(開いているときに閉じるため)
    var allowsRight: Bool
    var onBegan: () -> Void
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.enabled = enabled
        context.coordinator.allowsRight = allowsRight
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let dx = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began:
            onBegan()
            onChanged(dx)
        case .changed:
            onChanged(dx)
        case .ended, .cancelled, .failed:
            onEnded(dx, recognizer.velocity(in: recognizer.view).x)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var enabled = true
        var allowsRight = false

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard enabled, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: pan.view)
            // はっきり横向きのときだけ。縦向きなら始めない(スクロールにまかせる)
            guard abs(v.x) > abs(v.y) * 1.2 else { return false }
            return v.x < 0 || allowsRight
        }
    }
}

extension View {
    /// 左へスワイプすると削除ボタンが出るようにする
    func swipeToDelete(id: some Hashable, enabled: Bool = true, onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDeleteModifier(id: AnyHashable(id), enabled: enabled, onDelete: onDelete))
    }
}
