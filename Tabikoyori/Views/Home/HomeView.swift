import SwiftUI

/// 旅行一覧の絞り込み
enum HomeFilter: String, CaseIterable, Identifiable {
    case all, planning, ongoing, done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "すべて"
        case .planning: return "計画中"
        case .ongoing: return "旅行中"
        case .done: return "完了"
        }
    }

    func matches(_ status: TripStatus) -> Bool {
        switch self {
        case .all: return true
        case .planning: return status == .planning
        case .ongoing: return status == .ongoing
        case .done: return status == .done
        }
    }
}

/// 旅行一覧の並び順
enum HomeSort: String, CaseIterable, Identifiable {
    case startAsc, startDesc, createdAsc, createdDesc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startAsc: return "開始日が早い順"
        case .startDesc: return "開始日が遅い順"
        case .createdAsc: return "作成日が古い順"
        case .createdDesc: return "作成日が新しい順"
        }
    }

    func areInOrder(_ a: Trip, _ b: Trip) -> Bool {
        switch self {
        case .startAsc:
            return a.startDate != b.startDate ? a.startDate < b.startDate : a.createdAt < b.createdAt
        case .startDesc:
            return a.startDate != b.startDate ? a.startDate > b.startDate : a.createdAt > b.createdAt
        case .createdAsc:
            return a.createdAt < b.createdAt
        case .createdDesc:
            return a.createdAt > b.createdAt
        }
    }
}

/// ホームタブ。旅行の一覧と、開いた旅行の旅程を表示する
struct HomeView: View {
    @Environment(TripStore.self) private var store
    @Environment(HomeNavigation.self) private var homeNavigation
    @State private var query = ""
    @State private var filter: HomeFilter = .all
    @State private var showingNew = false
    @State private var showingNotice = false
    @State private var tripToDelete: Trip?
    @State private var editingTrip: Trip?
    /// ホームの画面の移動の記録(ホームボタンでどこまで戻るかを決めるため)
    @State private var path: [TripScreen] = []
    /// 並び順(初期は開始日が早い順。選んだ順は覚えておく)
    @AppStorage("homeSort") private var sortRaw = HomeSort.startAsc.rawValue

    private var sort: HomeSort { HomeSort(rawValue: sortRaw) ?? .startAsc }

    private var filtered: [Trip] {
        store.trips.sorted(by: sort.areInOrder).filter { trip in
            let statusOK = filter.matches(trip.status)
            let queryOK = query.isEmpty
                || trip.title.localizedCaseInsensitiveContains(query)
                || trip.destinationName.localizedCaseInsensitiveContains(query)
            return statusOK && queryOK
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            // 旅行を開いたときは、旅程の画面をこのページの一番下(元の画面)に置く。
            // ホームボタンをもう一度押すと iOS がこの元の画面まで戻すので、
            // 地図・持ち物・お金の画面からは旅程の画面に戻る
            Group {
                if let id = homeNavigation.openTripID, store.trip(id) != nil {
                    TripDetailView(tripID: id, onClose: {
                        withAnimation(.easeInOut(duration: 0.28)) { homeNavigation.openTripID = nil }
                    })
                    .id(id)
                    .transition(.move(edge: .trailing))
                } else {
                    tripList
                        .transition(.move(edge: .leading))
                }
            }
            .navigationDestination(for: TripScreen.self) { $0.destination }
            .onChange(of: path.count) { _, count in
                homeNavigation.pathDepth = count
            }
            .sheet(isPresented: $showingNew) {
                TripEditSheet()
            }
            .sheet(item: $editingTrip) { trip in
                TripEditSheet(editing: store.trip(trip.id))
            }
            .alert("お知らせ", isPresented: $showingNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("新しいお知らせはありません。")
            }
            .confirmationDialog(
                "この旅行を削除しますか？",
                isPresented: Binding(
                    get: { tripToDelete != nil },
                    set: { if !$0 { tripToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    if let trip = tripToDelete {
                        store.deleteTrip(trip.id)
                    }
                    tripToDelete = nil
                }
                Button("キャンセル", role: .cancel) { tripToDelete = nil }
            } message: {
                Text("旅程と思い出も一緒に削除されます。")
            }
        }
    }

    /// 旅行の一覧(ホームの最初の画面)
    private var tripList: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                searchField
                chips
                cards
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) { addButton }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("旅こより")
                .font(.serif(30))
                .foregroundStyle(Theme.accentDark)
            Spacer()
            Button {
                showingNotice = true
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 19))
                    .foregroundStyle(Theme.accentDark)
                    .frame(width: 36, height: 36)
                    .accessibilityLabel("お知らせ")
            }
            AvatarView(name: store.userName, size: 34)
            // 設定(下のメニューから移動)
            NavigationLink(value: TripScreen.settings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 19))
                    .foregroundStyle(Theme.accentDark)
                    .frame(width: 36, height: 36)
                    .accessibilityLabel("設定")
            }
        }
    }

    private var searchField: some View {
        MapSearchBar(text: $query, prompt: "旅行を検索")
    }

    private var chips: some View {
        ChipRow {
            ForEach(HomeFilter.allCases) { f in
                Chip(title: f.title, selected: filter == f) { filter = f }
            }
        } trailing: {
            Menu {
                Picker("並び替え", selection: $sortRaw) {
                    ForEach(HomeSort.allCases) { s in
                        Text(s.title).tag(s.rawValue)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accentDark)
                    .frame(width: ChipMetrics.height, height: ChipMetrics.height)
                    .background(Theme.sandLight, in: Circle())
                    .accessibilityLabel("並び替え")
            }
        }
    }

    @ViewBuilder
    private var cards: some View {
        if filtered.isEmpty {
            if store.trips.isEmpty {
                EmptyStateView(
                    systemImage: "airplane.departure",
                    title: "旅行はまだありません",
                    message: "右下の＋から、最初の旅行を計画しましょう。"
                )
            } else {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "該当する旅行がありません",
                    message: "検索する言葉や絞り込みを変えてみてください。"
                )
            }
        } else {
            LazyVStack(spacing: 16) {
                ForEach(filtered) { trip in
                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) { homeNavigation.openTripID = trip.id }
                    } label: {
                        TripCard(trip: trip)
                    }
                    .buttonStyle(.plain)
                    // カード右上のボタンからも、編集・削除ができる
                    .overlay(alignment: .topTrailing) {
                        Menu {
                            tripMenuItems(trip)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.black.opacity(0.28), in: Circle())
                                .contentShape(Circle())
                                .accessibilityLabel("\(trip.title)のメニュー")
                        }
                        .menuOrder(.fixed)
                        .padding(12)
                    }
                    // 長押しのメニュー
                    .contextMenu {
                        tripMenuItems(trip)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tripMenuItems(_ trip: Trip) -> some View {
        Button("旅行を編集", systemImage: "pencil") { editingTrip = trip }
        Button("旅行を削除", systemImage: "trash", role: .destructive) { tripToDelete = trip }
    }

    private var addButton: some View {
        Button {
            showingNew = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Theme.accent, in: Circle())
                .shadow(color: Theme.accent.opacity(0.4), radius: 10, x: 0, y: 5)
                .accessibilityLabel("新しい旅行を作成")
        }
        .padding(.trailing, 22)
        .padding(.bottom, 16)
    }
}
