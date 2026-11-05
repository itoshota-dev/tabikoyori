import SwiftUI

// MARK: - 下から引き出すカード

/// カードの高さの段階(小さく収納 / 中くらい / ほぼ全面)
enum SheetDetent {
    case small, medium, large

    func height(available: CGFloat) -> CGFloat {
        // 画面より大きくならないように、すべて表示領域の高さで抑える
        let large = max(120, available - 12)
        switch self {
        case .small: return min(112, large)
        case .medium: return min(330, max(120, available - 140))
        case .large: return large
        }
    }
}

/// 下から引き出すカード。
/// - ドラッグ中はカードが指にぴったりついてくる。離すと、指の勢いも使ってばねのように次の高さへ動く
/// - ドラッグ中の再描画はこのカードの中だけで済ませる(地図を巻き込まないので、カクつかない)
/// - 中身の切り替え(一覧 ↔「移動手段を選ぶ」ボタン)は、表示を作り直さず透明度だけで切り替える(動きがちらつかない)
struct DraggableSheet<Header: View, Content: View, Accessory: View>: View {
    @Binding var detent: SheetDetent
    let availableHeight: CGFloat
    /// 小さく収納しているときに出すボタンの文字(タップすると中くらいに開く)
    let collapsedTitle: String
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content
    /// カードの右上の外側に乗せて、カードと一緒に動かすもの(現在地ボタンなど)
    @ViewBuilder var accessory: () -> Accessory

    /// 指で動かしている量(下向きがプラス)
    @State private var dragOffset: CGFloat = 0

    private func height(_ d: SheetDetent) -> CGFloat {
        d.height(available: availableHeight)
    }

    /// 指を離したあと、次の高さへ動くばね
    private func settle(to next: SheetDetent, from current: CGFloat, velocity: CGFloat) {
        let distance = height(next) - current
        let relative = abs(distance) > 1 ? max(-25, min(25, velocity / distance)) : 0
        withAnimation(.interpolatingSpring(mass: 1, stiffness: 300, damping: 33, initialVelocity: relative)) {
            detent = next
            dragOffset = 0
        }
    }

    private var dragGesture: some Gesture {
        // 画面全体の座標で測る(カードが動いても、指の動きがぶれないようにする)
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { dragOffset = value.translation.height }
            }
            .onEnded { value in
                let order: [SheetDetent] = [.small, .medium, .large]
                let current = min(max(height(detent) - value.translation.height, height(.small)), height(.large))
                // 上向きがプラスの速さ(ポイント/秒)
                let velocity = -value.velocity.height
                var next = order.min { abs(height($0) - current) < abs(height($1) - current) } ?? detent
                if velocity > 350 {
                    // 上へはじいたら、今より1段高いところへ
                    next = order.first { height($0) > current + 1 } ?? .large
                } else if velocity < -350 {
                    // 下へはじいたら、今より1段低いところへ
                    next = order.last { height($0) < current - 1 } ?? .small
                }
                settle(to: next, from: current, velocity: velocity)
            }
    }

    var body: some View {
        let small = height(.small)
        let large = height(.large)
        let raw = height(detent) - dragOffset
        // 小さいより下へ引いたときは、少しだけ抵抗をつけて動かす(大きいより上へは動かさない)
        let live = raw < small ? small - min((small - raw) * 0.25, 24) : min(raw, large)
        // 1 のとき「移動手段を選ぶ」ボタン、0 のとき一覧を表示する
        let collapse = min(max((small + 50 - live) / 50, 0), 1)
        // ほぼ全面に近づいたら、カードの上のボタンを消す
        let accessoryOpacity = min(max((large - 60 - live) / 80, 0), 1)

        VStack(spacing: 0) {
            // 上の部分(つまみと合計)を上下にドラッグして、カードの高さを変える
            VStack(spacing: 10) {
                Capsule()
                    .fill(Theme.sand.opacity(0.8))
                    .frame(width: 38, height: 5)
                header()
            }
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onTapGesture {
                // つまみをタップすると、小さい → 中くらい → 大きい の順に切り替わる
                let next: SheetDetent
                switch detent {
                case .small: next = .medium
                case .medium: next = .large
                case .large: next = .small
                }
                settle(to: next, from: live, velocity: 0)
            }

            ZStack(alignment: .top) {
                ScrollView {
                    content()
                }
                .opacity(1 - collapse)
                .allowsHitTesting(collapse < 0.5)

                Button {
                    settle(to: .medium, from: live, velocity: 0)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                        Text(collapsedTitle)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(dragGesture)
                .opacity(collapse)
                .allowsHitTesting(collapse > 0.5)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(height: live, alignment: .top)
        .background {
            // 影は背景だけにつける(中の文字やボタンに影が出ないようにする)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 4)
        }
        .overlay(alignment: .topTrailing) {
            // カードのすぐ上に乗せる(カードの大きさには影響しない)
            accessory()
                .alignmentGuide(.top) { d in d.height + 10 }
                .opacity(accessoryOpacity)
                .allowsHitTesting(accessoryOpacity > 0.5)
        }
        .padding(.horizontal, 16)
    }
}
