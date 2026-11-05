import SwiftUI

// MARK: - 日付ごとのタイムライン

/// 同じ日の思い出のまとまり
struct MemoryDayGroup: Identifiable {
    let day: Date
    let entries: [MemoryEntry]
    var id: Date { day }
}

/// 思い出を日付ごとに並べた一覧
struct MemoryTimeline: View {
    let entries: [MemoryEntry]
    var showsTripTitle: Bool = false

    private var groups: [MemoryDayGroup] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: entries) { cal.startOfDay(for: $0.memory.date) }
        return dict.keys.sorted(by: >).map { day in
            let items = (dict[day] ?? []).sorted { $0.memory.date < $1.memory.date }
            return MemoryDayGroup(day: day, entries: items)
        }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(groups) { group in
                Text(DisplayFormat.monthDayWeekday.string(from: group.day))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 4)
                ForEach(group.entries) { entry in
                    MemoryCard(entry: entry, showsTripTitle: showsTripTitle)
                }
            }
        }
    }
}

/// 思い出の一覧の1枚のカード(写真・スポット・メモの冒頭)
struct MemoryCard: View {
    @Environment(TripStore.self) private var store

    let entry: MemoryEntry
    var showsTripTitle: Bool = false

    private var memory: Memory { entry.memory }
    private var media: [MemoryMedia] { memory.media }

    @State private var viewer: PhotoViewerTarget?
    @State private var editing = false
    /// メモの、3行で表示している高さと、全部を表示したときの高さ(省略されているかを見分ける)
    @State private var shownNoteHeight: CGFloat = 0
    @State private var fullNoteHeight: CGFloat = 0

    private var noteTruncated: Bool { fullNoteHeight > shownNoteHeight + 1 }

    private var spot: Spot? {
        guard let id = memory.spotID else { return nil }
        return store.spot(id: id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail
                    .frame(width: 66, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture {
                        if !media.isEmpty { viewer = PhotoViewerTarget(media: media, index: 0) }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text(memory.spotName ?? "メモ")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Spacer(minLength: 0)
                        Menu {
                            Button("編集", systemImage: "pencil") {
                                editing = true
                            }
                            Button("削除", systemImage: "trash", role: .destructive) {
                                store.deleteMemory(memory.id, from: entry.tripID)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(Theme.subText)
                                .frame(width: 28, height: 22)
                                .contentShape(Rectangle())
                                .accessibilityLabel("思い出のメニュー") 
                        }
                    }
                    if let spot {
                        AreaLabel(text: spot.area)
                    } else if showsTripTitle {
                        AreaLabel(text: entry.tripTitle)
                    }
                    if !memory.note.isEmpty {
                        // メモは3行まで。タップすると、全部を読めるページへ進む
                        NavigationLink(value: TripScreen.memory(entry.tripID, memory.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(memory.note)
                                    .font(.system(size: 12.5))
                                    .lineSpacing(4)
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shownNoteHeight = $0 }
                                    .background(alignment: .topLeading) {
                                        // 全部を表示したときの高さを測るための、見えない文字
                                        Text(memory.note)
                                            .font(.system(size: 12.5))
                                            .lineSpacing(4)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .hidden()
                                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullNoteHeight = $0 }
                                    }
                                if noteTruncated {
                                    HStack(spacing: 2) {
                                        Text("続きを読む")
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
            }

            if media.count > 1 {
                photoGrid
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 20)
        .fullScreenCover(item: $viewer) { target in
            PhotoViewer(target: target)
        }
        .sheet(isPresented: $editing) {
            AddMemorySheet(tripID: entry.tripID, editing: memory)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let first = media.first {
            MediaTile(media: first)
        } else if let spot {
            SpotArt(style: spot.art)
        } else {
            ZStack {
                Theme.sandLight
                Image(systemName: "note.text")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private var photoGrid: some View {
        let shown = Array(media.prefix(4))
        let extra = media.count - 4
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                MediaTile(media: item)
                    .frame(height: 96)
                    .overlay {
                        if index == 3 && extra > 0 {
                            ZStack {
                                Color.black.opacity(0.4)
                                Text("+\(extra + 1)")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onTapGesture {
                        viewer = PhotoViewerTarget(media: media, index: index)
                    }
            }
        }
    }
}
