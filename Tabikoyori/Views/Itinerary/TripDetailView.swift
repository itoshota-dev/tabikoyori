import SwiftUI

/// 1つの旅行の画面(旅程と思い出)
struct TripDetailView: View {
    @Environment(TripStore.self) private var store
    @Environment(HomeNavigation.self) private var homeNavigation
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID
    var showsSwitcher: Bool = false
    /// ホーム画面で開いたときの「戻る」(旅行の一覧へ戻る)
    var onClose: (() -> Void)? = nil

    enum DetailTab: String, CaseIterable {
        case plan = "旅程"
        case memories = "思い出"
    }

    @State private var tab: DetailTab = .plan
    @State private var day = 0
    /// 日を切り替えるとき、次の日へ進むか(画面の動く向きに使う)
    @State private var dayForward = true
    /// 画面の幅(左右の端からのスワイプを見分けるため)
    @State private var screenWidth: CGFloat = 0
    @State private var pickerMode: SpotPickerSheet.Mode?
    @State private var showingAddMemory = false
    @State private var editingItem: ItineraryItem?
    @State private var detailSpot: Spot?
    @State private var showingEdit = false
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let trip = store.trip(tripID) {
                VStack(spacing: 0) {
                    header(trip)
                    ScrollView {
                        Group {
                            switch tab {
                            case .plan:
                                planContent(trip)
                                    .id(day)
                                    .transition(.push(from: dayForward ? .trailing : .leading))
                            case .memories:
                                memoriesContent(trip)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
                // 画面の左右の端からスワイプすると、前の日・次の日の旅程に切り替える
                .simultaneousGesture(daySwipe(trip))
                .sensoryFeedback(.selection, trigger: day)
                .safeAreaInset(edge: .bottom) { bottomBar(trip) }
            } else {
                ContentUnavailableView("旅行が見つかりません", systemImage: "airplane")
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        // ホームから開いた旅程では、スポットの詳細を開いているかをホームに伝える(ホームボタンで戻る先を決めるため)
        .onChange(of: detailSpot) { _, newValue in
            if onClose != nil { homeNavigation.isSpotDetailOpen = newValue != nil }
        }

        .navigationDestination(item: $detailSpot) { spot in
            SpotDetailView(spot: spot)
        }
        .sheet(item: $pickerMode) { mode in
            SpotPickerSheet(tripID: tripID, day: day, mode: mode)
        }
        .sheet(isPresented: $showingAddMemory) {
            AddMemorySheet(tripID: tripID)
        }
        .sheet(item: $editingItem) { item in
            TimeEditSheet(tripID: tripID, item: item)
        }
        .sheet(isPresented: $showingEdit) {
            TripEditSheet(editing: store.trip(tripID))
        }
        .confirmationDialog("この旅行を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                store.deleteTrip(tripID)
                if let onClose { onClose() } else if !showsSwitcher { dismiss() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("旅程と思い出も一緒に削除されます。")
        }
        .onChange(of: store.trip(tripID)?.dayCount ?? 1) { _, count in
            if day >= count { day = max(0, count - 1) }
        }
    }

    // MARK: ツールバー

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if let trip = store.trip(tripID) {
                VStack(spacing: 1) {
                    Text(trip.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text(trip.dateRangeText)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.subText)
                }
            }
        }
        if let onClose {
            // ホーム画面で開いた旅程の「戻る」(旅行の一覧へ)
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
            }
        }
        if showsSwitcher {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(store.tripsByStart) { t in
                        Button {
                            store.selectTrip(t.id)
                        } label: {
                            if t.id == tripID {
                                Label(t.title, systemImage: "checkmark")
                            } else {
                                Text(t.title)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "airplane")
                }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            NavigationLink(value: TripScreen.map(tripID)) {
                Image(systemName: "map")
            }
            Menu {
                Button("旅行を編集", systemImage: "pencil") { showingEdit = true }
                Button("旅行を削除", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: ヘッダー

    private func header(_ trip: Trip) -> some View {
        VStack(spacing: 12) {
            ChipRow {
                ForEach(DetailTab.allCases, id: \.self) { t in
                    Chip(title: t.rawValue, selected: tab == t) { tab = t }
                }
            } trailing: {
                Text(trip.status.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accentDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.sandLight, in: Capsule())
            }
            if tab == .plan {
                shortcuts(trip)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<trip.dayCount, id: \.self) { d in
                                dayTab(trip, d)
                                    .id(d)
                            }
                        }
                    }
                    // スワイプで日が変わったら、選んでいる日のボタンが見えるようにずらす
                    .onChange(of: day) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.28)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    /// 日を切り替える(画面の動く向きもあわせて決める)
    private func goToDay(_ d: Int, in trip: Trip) {
        guard d != day, d >= 0, d < trip.dayCount else { return }
        dayForward = d > day
        withAnimation(.easeInOut(duration: 0.28)) { day = d }
    }

    /// 左右の端からのスワイプ。
    /// 左端 → 右へスワイプで前の日、右端 → 左へスワイプで次の日。
    /// (ほかの画面から重ねて開いたときは、左端は iOS の「戻る」に使うので前の日へは切り替えない)
    private func daySwipe(_ trip: Trip) -> some Gesture {
        let edge: CGFloat = 36
        let leftEdgeEnabled = onClose != nil || showsSwitcher
        return DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard tab == .plan, screenWidth > 0 else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                // 横向きにはっきり動かしたときだけ
                guard abs(dx) > 50, abs(dx) > abs(dy) * 1.5 else { return }
                let startX = value.startLocation.x
                if dx > 0, leftEdgeEnabled, startX <= edge {
                    goToDay(day - 1, in: trip)
                } else if dx < 0, startX >= screenWidth - edge {
                    goToDay(day + 1, in: trip)
                }
            }
    }

    private func dayTab(_ trip: Trip, _ d: Int) -> some View {
        let selected = d == day
        return Button {
            goToDay(d, in: trip)
        } label: {
            VStack(spacing: 2) {
                Text("\(d + 1)日目")
                    .font(.system(size: 13, weight: .semibold))
                Text(DisplayFormat.shortMonthDayWeekday.string(from: trip.date(forDay: d)))
                    .font(.system(size: 10))
            }
            .foregroundStyle(selected ? Color.white : Theme.subText)
            .frame(width: 76)
            .padding(.vertical, 8)
            .background(selected ? Theme.accent : Theme.sandLight.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: 旅のお金・持ち物への入口

    private func shortcuts(_ trip: Trip) -> some View {
        HStack(spacing: 12) {
            NavigationLink(value: TripScreen.money(tripID)) {
                shortcutCard(
                    symbol: "wallet.bifold.fill",
                    title: "旅のお金",
                    detail: trip.budget > 0 ? "残り \(DisplayFormat.yen(trip.remainingBudget))" : (trip.expenses.isEmpty ? "予算・支出" : "支出 \(DisplayFormat.yen(trip.totalSpent))")
                )
            }
            NavigationLink(value: TripScreen.packing(tripID)) {
                shortcutCard(
                    symbol: "suitcase.fill",
                    title: "旅の持ち物",
                    detail: trip.packing.isEmpty ? "準備リスト" : "\(trip.packedCount) / \(trip.packing.count) 準備済み"
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func shortcutCard(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.sandLight.opacity(0.8), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.subText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .cardStyle(radius: 18)
    }

    // MARK: 旅程

    @ViewBuilder
    private func planContent(_ trip: Trip) -> some View {
        let d = min(day, trip.dayCount - 1)
        // 日付をまたぐ予定は、続いている日にも複製されて入っている(いちばん上)
        let items = trip.items(forDay: d)
        if items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 38))
                    .foregroundStyle(Theme.sand)
                Text("この日の予定はまだありません")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text("下のボタンから、おすすめや地図で\n行きたい場所を追加しましょう。")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.subText)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 70)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    TimelineRow(
                        trip: trip,
                        item: item,
                        isFirst: index == 0,
                        isLast: index == items.count - 1,
                        travel: index < items.count - 1
                            ? trip.travelLeg(from: item.id, to: items[index + 1].id)
                            : nil,
                        overlaps: trip.overlappingItems(with: item).map { $0.spot.name },
                        onOpen: { detailSpot = item.spot },
                        // 複製の時間を変えるときは、元の予定を編集する
                        onEditTime: { editingItem = trip.items.first { $0.id == item.sourceID } ?? item }
                    )
                }
            }
        }
    }

    private func memoriesContent(_ trip: Trip) -> some View {
        Group {
            if trip.memories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "camera")
                        .font(.system(size: 38))
                        .foregroundStyle(Theme.sand)
                    Text("まだ思い出がありません")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text("写真やメモを追加して、旅の記録を残しましょう。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.subText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 70)
            } else {
                MemoryTimeline(
                    entries: trip.memories.map { MemoryEntry(tripID: trip.id, tripTitle: trip.title, memory: $0) }
                )
            }
        }
    }

    // MARK: 下部バー

    @ViewBuilder
    private func bottomBar(_ trip: Trip) -> some View {
        HStack(spacing: 12) {
            if tab == .plan {
                Button {
                    pickerMode = .saved
                } label: {
                    Image(systemName: "heart")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accentDark)
                        .frame(width: 50, height: 50)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
                }
                Button {
                    pickerMode = .map
                } label: {
                    PrimaryCapsuleLabel(title: "スポットを追加", systemImage: "plus")
                }
            } else {
                Button {
                    showingAddMemory = true
                } label: {
                    PrimaryCapsuleLabel(title: "思い出を追加", systemImage: "camera.fill")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            LinearGradient(colors: [Theme.background.opacity(0), Theme.background], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }
}
