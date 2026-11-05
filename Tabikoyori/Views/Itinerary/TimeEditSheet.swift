import SwiftUI
import UIKit

// MARK: - 予定の時間を変えるシート

/// 予定の開始・終了時刻を変えるシート
struct TimeEditSheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID
    let item: ItineraryItem

    @State private var start = Date()
    /// 終了の日(何日目か)と時刻(時刻だけを使う)
    @State private var endDay = 0
    @State private var endTime = Date()
    /// 終了時刻を自分で変えたかどうか(変えていなければ、開始の1時間後にそろえる)
    @State private var isEndTimeEdited = false
    /// 0: 開始 / 1: 終了
    @State private var editing = 0

    private var trip: Trip? { store.trip(tripID) }

    private var timeConverter: ItineraryTimeConverter? {
        trip.map { ItineraryTimeConverter(trip: $0, day: item.day) }
    }

    /// 終了時刻の決まり(上限・範囲に収める・日付と時刻の分け方)。計算は ItineraryTime.swift にまとめている
    private var rules: ItineraryTimeRules {
        ItineraryTimeRules(dayCount: trip?.dayCount ?? 1, itemDay: item.day)
    }

    private func minutesOfDay(_ date: Date) -> Int {
        ItineraryTimeConverter.minuteOfDay(date)
    }

    private var startMinutes: Int { minutesOfDay(start) }

    /// 終了(開始日の0時からの分)。開始より前や、旅行の最終日より後にならないようにする
    private var endTotal: Int {
        rules.clampedEnd(rules.endTotal(day: endDay, minuteOfDay: minutesOfDay(endTime)), start: startMinutes)
    }

    private func setEnd(total: Int) {
        guard let timeConverter else { return }
        let parts = rules.endParts(total)
        endDay = parts.day
        endTime = timeConverter.date(parts.minuteOfDay)
    }

    /// 選んでいる時刻で、時間が重なるほかの予定
    private var overlaps: [String] {
        trip?.overlappingItems(day: item.day, start: startMinutes, end: endTotal, excluding: item.id)
            .map { $0.spot.name } ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text(item.spot.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 16)
                if let timeConverter, let trip {
                    Picker("", selection: $editing) {
                        Text("開始 \(DisplayFormat.clockTime(startMinutes))").tag(0)
                        Text("終了 \(DisplayFormat.endClockTime(endTotal))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    if editing == 0 {
                        // 開始は、その日のうちの時刻
                        DatePicker("開始", selection: Binding(
                            get: { start },
                            set: { newValue in
                                start = newValue
                                if !isEndTimeEdited {
                                    setEnd(total: minutesOfDay(newValue) + 60)
                                }
                            }
                        ), in: timeConverter.dayStart...timeConverter.dayLastMoment, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    } else {
                        // 終了は、日付と時刻を分けて選ぶ(旅行の最終日まで、日付をまたいでよい)。
                        // 日付と時刻のあいだに余白をとるため、別々のホイールにしている
                        HStack(spacing: 24) {
                            Picker("日付", selection: Binding(
                                get: { endDay },
                                set: { endDay = $0; isEndTimeEdited = true }
                            )) {
                                ForEach(item.day..<max(trip.dayCount, item.day + 1), id: \.self) { d in
                                    Text(DisplayFormat.shortMonthDayWeekday.string(from: trip.date(forDay: d))).tag(d)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 140, height: 216)
                            .clipped()
                            // 時と分のホイール(選択中の帯の両端が角丸になるよう、幅に合わせて作っている)
                            HourMinuteWheel(minutes: Binding(
                                get: { minutesOfDay(endTime) },
                                set: { endTime = timeConverter.date($0); isEndTimeEdited = true }
                            ))
                            .frame(width: 150, height: 216)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if !overlaps.isEmpty {
                        // ほかの予定と時間が重なるときの注意(保存はできる)
                        HStack(alignment: .top, spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("予定が重なっています（\(overlaps.joined(separator: "、"))）")
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: 0xB84A3A))
                        .padding(.horizontal, 20)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("時間を変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.setTimes(start: startMinutes, end: endTotal, itemID: item.id, in: tripID)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            guard let timeConverter else { return }
            start = timeConverter.date(item.minutes)
            isEndTimeEdited = item.endMinutes != nil
            setEnd(total: item.end)
        }
    }
}

// MARK: - 時と分のホイール

/// 時(0〜23)と分(0〜59)を選ぶホイール。
/// iOS の時刻ピッカーは幅を狭くできず、選択中の帯の端が切れてしまうので、自分で作っている
struct HourMinuteWheel: UIViewRepresentable {
    /// 0時からの分(0〜1439)
    @Binding var minutes: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.setContentHuggingPriority(.defaultLow, for: .horizontal)
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        context.coordinator.parent = self
        let hour = min(max(minutes / 60, 0), 23)
        let minute = min(max(minutes % 60, 0), 59)
        if picker.selectedRow(inComponent: 0) != hour {
            picker.selectRow(hour, inComponent: 0, animated: false)
        }
        if picker.selectedRow(inComponent: 1) != minute {
            picker.selectRow(minute, inComponent: 1, animated: false)
        }
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: HourMinuteWheel

        init(_ parent: HourMinuteWheel) { self.parent = parent }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            component == 0 ? 24 : 60
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat { 60 }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { 34 }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            label.font = .systemFont(ofSize: 23)
            label.textColor = .label
            label.textAlignment = .center
            // 時は「9」、分は「06」のように表示する(iOS の時刻ピッカーと同じ)
            label.text = component == 0 ? "\(row)" : String(format: "%02d", row)
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let hour = pickerView.selectedRow(inComponent: 0)
            let minute = pickerView.selectedRow(inComponent: 1)
            parent.minutes = hour * 60 + minute
        }
    }
}
