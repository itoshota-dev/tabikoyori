import SwiftUI

/// 経路モードの目的地につける表示(通し番号と、開始・終了時刻)
struct RouteStopInfo {
    var number: Int
    var times: [String]
    /// 時刻をその場で編集するための値(onSave が nil のときは編集できない)
    var startMinutes: Int = 0
    var endMinutes: Int = 0
    var isEndTimeSet: Bool = false
    /// 予定の開始日と旅行の最終日(日付をまたぐ時刻の計算に使う)
    var timeConverter: ItineraryTimeConverter? = nil
    var onSave: ((Int, Int) -> Void)? = nil
}

/// 通し番号(①②③… のような丸い番号)
struct NumberBadge: View {
    let number: Int
    var size: CGFloat = 20

    var body: some View {
        Text("\(number)")
            .font(.system(size: size * 0.55, weight: .bold).monospacedDigit())
            .foregroundStyle(.white)
            .minimumScaleFactor(0.6)
            .frame(width: size, height: size)
            .background(Theme.accent, in: Circle())
    }
}

/// 経路モードで、丸いピンの代わりに出す表示(番号・開始時刻・終了時刻・スポット名)
struct RouteStopPin: View {
    let spot: Spot
    let info: RouteStopInfo
    var selected: Bool = false
    /// スポット名をタップしたときの処理(詳細を開く)
    var onSelect: () -> Void = {}

    /// 時刻の札をタップしたときに出す、時刻を変える吹き出し
    @State private var editingTime = false

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                NumberBadge(number: info.number)
                VStack(spacing: 1) {
                    ForEach(Array(info.times.enumerated()), id: \.offset) { index, text in
                        Text(text)
                            .font(.system(size: 10, weight: index == 0 ? .bold : .medium).monospacedDigit())
                            .foregroundStyle(index == 0 ? Theme.text : Theme.subText)
                    }
                }
            }
            .padding(.leading, 7)
            .padding(.trailing, 9)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Theme.accent : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if info.onSave != nil && info.timeConverter != nil { editingTime = true } else { onSelect() }
            }
            .popover(isPresented: $editingTime) {
                if let onSave = info.onSave, let timeConverter = info.timeConverter {
                    StopTimePopover(
                        name: spot.name,
                        startMinutes: info.startMinutes,
                        endMinutes: info.endMinutes,
                        isEndTimeSet: info.isEndTimeSet,
                        timeConverter: timeConverter,
                        onSave: onSave
                    )
                    .presentationCompactAdaptation(.popover)
                }
            }
            Text(spot.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.92), in: Capsule())
                .onTapGesture { onSelect() }
        }
        .scaleEffect(selected ? 1.08 : 1)
        .animation(.spring(duration: 0.25), value: selected)
    }
}
