import SwiftUI

// MARK: - タイムライン行

/// 旅程のタイムラインの1行(時刻・スポットのカード・次の予定までの移動)
struct TimelineRow: View {
    @Environment(TripStore.self) private var store

    let trip: Trip
    let item: ItineraryItem
    let isFirst: Bool
    let isLast: Bool
    /// この予定から次の予定までの移動(地図の経路で選んだもの)
    var travel: TravelLeg? = nil
    /// 時間が重なっている、ほかの予定の名前
    var overlaps: [String] = []
    var onOpen: () -> Void
    var onEditTime: () -> Void

    private let timeWidth: CGFloat = 46
    private let railWidth: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                // 開始時刻はカードの上、終了時刻はカードの下端にそろえる
                VStack(alignment: .leading, spacing: 0) {
                    // 前の日から続く予定(複製)は「前日から」
                    Text(DisplayFormat.startClockTime(item))
                        .font(.system(size: item.isContinuation ? 11 : 14, weight: .medium))
                        .foregroundStyle(Theme.subText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    // 日付をまたぐときは、時刻の上に「翌」「2日後」を小さく出す
                    VStack(alignment: .leading, spacing: 0) {
                        if let prefix = DisplayFormat.dayOffsetPrefix(item.endOnDay) {
                            Text(prefix)
                                .font(.system(size: 9, weight: .semibold))
                        }
                        Text(DisplayFormat.clockTime(item.endOnDay % minutesPerDay))
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Theme.subText.opacity(0.75))
                    .padding(.bottom, 8)
                }
                .frame(width: timeWidth, alignment: .leading)
                .padding(.top, 4)

                ZStack(alignment: .top) {
                    Color.clear
                    Circle()
                        .fill(item.visited ? Theme.accent : Theme.surface)
                        .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
                        .frame(width: 11, height: 11)
                        // 左の開始時刻の文字の真ん中と高さをそろえる
                        .padding(.top, 7)
                }
                .frame(width: railWidth)

                card
            }
            .fixedSize(horizontal: false, vertical: true)

            if !overlaps.isEmpty {
                // ほかの予定と時間が重なっているときの注意
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text("予定が重なっています（\(overlaps.joined(separator: "、"))）")
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(2)
                }
                .foregroundStyle(Color(hex: 0xB84A3A))
                .padding(.leading, timeWidth + railWidth + 20)
                .padding(.top, 8)
            }

            if let travel, let mode = travel.travelMode {
                travelRow(travel, mode: mode)
                    .padding(.leading, timeWidth + railWidth + 16)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
            }
        }
        .padding(.bottom, 14)
        .background(alignment: .topLeading) {
            if !isLast {
                // 下の端は丸くする
                Capsule()
                    .fill(Theme.accent.opacity(0.45))
                    .frame(width: 2)
                    .padding(.bottom, 3)
                    .padding(.leading, timeWidth + 8 + railWidth / 2 - 1)
                    .padding(.top, 18)
            }
        }
    }

    /// 次の予定までの移動手段・所要時間・距離
    /// 所要時間を先頭に、移動手段・距離を並べる(区切りの「・」や矢印は付けない)
    private func travelRow(_ travel: TravelLeg, mode: TravelMode) -> some View {
        HStack(spacing: 10) {
            if let seconds = travel.seconds {
                Text(DisplayFormat.duration(seconds))
                    .font(.system(size: 12, weight: .medium))
            }
            HStack(spacing: 4) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 11))
                Text(mode.label)
                    .font(.system(size: 12, weight: .medium))
            }
            if let meters = travel.meters {
                Text(DisplayFormat.distance(meters))
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .foregroundStyle(Theme.subText)
        .padding(.leading, 4)
    }

    private var card: some View {
        HStack(alignment: .top, spacing: 12) {
            SpotArt(style: item.spot.art)
                .frame(width: 64, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 4) {
                    Text(item.spot.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    menu
                }
                RatingLabel(spot: item.spot)
                AreaLabel(text: item.spot.area)
                Button {
                    store.toggleVisited(item.sourceID, in: trip.id)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text(item.visited ? "訪問済み" : "これから")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(item.visited ? Color.white : Theme.subText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(item.visited ? Theme.accent : Theme.sandLight.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 18)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: onOpen)
    }

    private var menu: some View {
        Menu {
            Button("詳細を見る", systemImage: "info.circle", action: onOpen)
            Button("時間を変更", systemImage: "clock", action: onEditTime)
            if trip.dayCount > 1 {
                Menu("別の日に移動", systemImage: "arrow.left.arrow.right") {
                    ForEach(0..<trip.dayCount, id: \.self) { d in
                        if d != item.day {
                            Button("\(d + 1)日目 \(DisplayFormat.shortMonthDayWeekday.string(from: trip.date(forDay: d)))") {
                                store.moveItem(item.sourceID, in: trip.id, toDay: d)
                            }
                        }
                    }
                }
            }
            Button("削除", systemImage: "trash", role: .destructive) {
                store.removeItem(item.sourceID, from: trip.id)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14))
                .foregroundStyle(Theme.subText)
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
                .accessibilityLabel("予定のメニュー")
        }
    }
}
