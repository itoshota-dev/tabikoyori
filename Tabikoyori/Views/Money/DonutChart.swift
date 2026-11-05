import SwiftUI

// MARK: - ドーナツグラフ(Swift Charts を使わず、軽い自前描画)

/// ドーナツグラフの1つの項目
struct DonutSlice: Identifiable {
    let id: String
    let color: Color
    let value: Double
}

/// 輪の一部(扇形)。真上から時計回りに、start〜end(0〜1)の範囲を描く
private struct RingSectorShape: Shape {
    let start: Double
    let end: Double
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let a0 = Angle.radians(2 * .pi * start - .pi / 2)
        let a1 = Angle.radians(2 * .pi * end - .pi / 2)
        var p = Path()
        p.addArc(center: center, radius: outer, startAngle: a0, endAngle: a1, clockwise: false)
        p.addArc(center: center, radius: inner, startAngle: a1, endAngle: a0, clockwise: true)
        p.closeSubpath()
        return p
    }
}

/// 切れ目のない、ふつうのドーナツ型の円グラフ。
/// 輪の太さはどこも同じなので、各項目の面積は割合(角度)にそのまま比例する
struct DonutChart: View {
    let slices: [DonutSlice]

    private let innerRatio: CGFloat = 0.6

    var body: some View {
        let shown = slices.filter { $0.value > 0 }
        let total = shown.reduce(0) { $0 + $1.value }
        let ranges = fractions(shown, total: total)

        return ZStack {
            if total > 0 {
                ForEach(Array(shown.enumerated()), id: \.offset) { index, slice in
                    let range = ranges[index]
                    // 隣との境目に細いすき間が見えないよう、次の項目の下へほんの少しだけ伸ばして描く
                    let overlap = index == shown.count - 1 ? 0 : 0.002
                    RingSectorShape(start: range.0, end: min(range.1 + overlap, 1), innerRatio: innerRatio)
                        .fill(slice.color)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fractions(_ slices: [DonutSlice], total: Double) -> [(Double, Double)] {
        guard total > 0 else { return [] }
        var cursor = 0.0
        return slices.enumerated().map { index, slice in
            let start = cursor
            cursor += slice.value / total
            // 最後の項目は、計算の誤差があってもぴったり一周で閉じる
            return (start, index == slices.count - 1 ? 1 : cursor)
        }
    }
}
