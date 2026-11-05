import SwiftUI

/// 経路の線の上に出す札(所要時間と、その下に移動手段)
struct RouteLabelView: View {
    let text: String
    var sub: String? = nil
    let color: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: sub == nil ? 12 : 10, style: .continuous)
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 10, weight: .bold))
            if let sub {
                Text(sub)
                    .font(.system(size: 7, weight: .medium))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(color, in: shape)
        .overlay(shape.stroke(Color.white, lineWidth: 1.5))
    }
}

// MARK: - 地図の上でその場で編集する吹き出し

/// 経路の札(所要時間・移動手段)。タップすると吹き出しで移動手段を選べる
struct RouteLabelButton: View {
    let line: RouteLine
    @State private var choosing = false

    var body: some View {
        RouteLabelView(text: line.label ?? "", sub: line.sublabel, color: line.color)
            .contentShape(Rectangle())
            .onTapGesture {
                if line.onChoose != nil { choosing = true }
            }
            .popover(isPresented: $choosing) {
                TravelModePopover(current: line.mode, color: line.color) { mode in
                    line.onChoose?(mode)
                    choosing = false
                }
                .presentationCompactAdaptation(.popover)
            }
    }
}

/// 移動手段を選ぶ吹き出しの中身
struct TravelModePopover: View {
    let current: TravelMode?
    let color: Color
    var onChoose: (TravelMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("移動手段")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
            HStack(spacing: 6) {
                ForEach(TravelMode.allCases) { mode in
                    Chip(title: mode.label, selected: current == mode, tint: color) {
                        onChoose(mode)
                    }
                }
            }
            if current != nil {
                Text("選んでいる手段をもう一度押すと、解除できます")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.subText)
            }
        }
        .padding(14)
        .fixedSize()
    }
}

/// 目的地の開始・終了時刻を、その場で変える吹き出しの中身
struct StopTimePopover: View {
    @Environment(\.dismiss) private var dismiss

    let name: String
    let startMinutes: Int
    let endMinutes: Int
    /// 終了時刻を一度でも自分で設定しているか
    let isEndTimeSet: Bool
    /// 予定の開始日と、旅行の最終日(日付をまたぐ終了時刻の計算に使う)
    let timeConverter: ItineraryTimeConverter
    var onSave: (Int, Int) -> Void

    @State private var start = Date()
    @State private var end = Date()
    /// 終了時刻を自分で変えたかどうか(変えていなければ、開始の1時間後にそろえる)
    @State private var isEndTimeEdited = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            DatePicker("開始", selection: Binding(
                get: { start },
                set: { newValue in
                    start = newValue
                    if !isEndTimeEdited {
                        end = min(newValue.addingTimeInterval(60 * 60), timeConverter.lastMoment)
                    }
                    if end < start { end = start }
                }
            ), in: timeConverter.dayStart...timeConverter.dayLastMoment, displayedComponents: .hourAndMinute)
            // 終了は日付と時刻で選ぶ(旅行の最終日まで、日付をまたいでよい)
            DatePicker("終了", selection: Binding(
                get: { end },
                set: { newValue in
                    end = newValue
                    isEndTimeEdited = true
                }
            ), in: start...max(start, timeConverter.lastMoment), displayedComponents: [.date, .hourAndMinute])
            .environment(\.locale, Locale(identifier: "ja_JP"))
            HStack {
                Button("キャンセル") { dismiss() }
                    .foregroundStyle(Theme.subText)
                Spacer()
                Button("保存") {
                    onSave(timeConverter.minutes(start), timeConverter.minutes(end))
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundStyle(Theme.accentDark)
            }
            .padding(.top, 2)
        }
        .font(.system(size: 14))
        .foregroundStyle(Theme.text)
        .padding(14)
        .frame(width: 300)
        .onAppear {
            start = timeConverter.date(startMinutes)
            end = min(timeConverter.date(endMinutes), timeConverter.lastMoment)
            isEndTimeEdited = isEndTimeSet
        }
    }
}
