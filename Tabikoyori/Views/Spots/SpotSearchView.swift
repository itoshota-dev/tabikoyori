import SwiftUI
import MapKit

/// 見つけるタブの切り替え(検索 / お気に入り)
enum SpotTab: String, CaseIterable, Identifiable {
    case search = "検索"
    case favorites = "お気に入り"

    var id: String { rawValue }
}

/// 見つけるタブ。スポットを検索したり、お気に入りを見たりする
struct SpotSearchView: View {
    @Environment(TripStore.self) private var store

    enum Mode { case list, map }

    @State private var query = ""
    @State private var tab: SpotTab = .search
    @State private var mode: Mode = .map
    @State private var selected: Spot?
    @State private var position: MapCameraPosition = .region(Self.wideRegion)
    @State private var search = PlaceSearchViewModel()
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var lastFit: MKCoordinateRegion?
    @State private var showRedo = false
    /// 地図の生成は重いので、検索を始めるなど必要になるまで作らない
    @State private var mapReady = false
    @State private var mapLoading = false

    /// 最初に開く地図は、細かい道路や地形の少ない日本全体の範囲にして軽くする
    private static let wideRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.0, longitude: 137.5),
        span: MKCoordinateSpan(latitudeDelta: 14, longitudeDelta: 14)
    )

    /// 地図を作る。重い処理なので、先に「読み込み中」を表示してから始める
    private func ensureMap() {
        guard !mapReady, !mapLoading else { return }
        mapLoading = true
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            mapReady = true
            MapWarmup.done = true
            mapLoading = false
        }
    }

    // MARK: 表示するスポット

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// お気に入り: 入力した言葉とエリアで絞り込む
    private var favoritesFiltered: [Spot] {
        let tokens = trimmedQuery
            .split(whereSeparator: { $0 == " " || $0 == "　" })
            .map { String($0) }
        return store.bookmarkedSpots.filter { spot in
            return tokens.allSatisfy { matches(spot, token: $0) }
        }
    }

    private var displayed: [Spot] {
        tab == .favorites ? favoritesFiltered : search.results
    }

    private var mapSpots: [Spot] { displayed }

    private func matches(_ spot: Spot, token: String) -> Bool {
        spot.name.localizedCaseInsensitiveContains(token)
            || spot.area.localizedCaseInsensitiveContains(token)
            || spot.region.name.contains(token)
            || spot.address.localizedCaseInsensitiveContains(token)
    }

    private var shouldOfferSearch: Bool {
        tab == .search && !trimmedQuery.isEmpty && trimmedQuery != search.searchedQuery
    }

    // MARK: 本体

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MapSearchBar(
                    text: $query,
                    prompt: "京都 カフェ",
                    isSearching: search.isSearching,
                    onSearch: { runSearch() },
                    onClear: {
                        search.clear()
                        selected = nil
                        showRedo = false
                    }
                )
                .padding(.horizontal, 20)

                chips

                if let message = search.errorMessage {
                    notice(message)
                }

                if mode == .list {
                    listContent
                } else {
                    mapContent
                }
            }
            .padding(.top, 4)
            .background(Theme.background.ignoresSafeArea())
            .overlay(alignment: .bottom) { modeSwitch }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { ScreenTitle(text: "観光地を探す") }
            }
            .spotDetailSheet($selected)
            .onChange(of: query) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, search.hasSearched {
                    search.clear()
                    showRedo = false
                }
            }
            .onChange(of: mapSpots.map { $0.id }) { _, _ in
                if mode == .map { fitMap() }
            }
            .onChange(of: mode) { _, newValue in
                if newValue == .map {
                    ensureMap()
                    fitMap()
                }
            }
            .onChange(of: tab) { _, _ in
                selected = nil
                if mode == .map {
                    if tab == .favorites { ensureMap() }
                    fitMap()
                }
            }
        }
    }

    // MARK: 検索

    /// 検索の範囲。いま見えている地図の範囲を最優先にする(visible が true のとき)
    private func defaultHint(for q: String) -> (region: MKCoordinateRegion?, visible: Bool) {
        var visible: MKCoordinateRegion?
        if mode == .map, let v = visibleRegion, v.span.latitudeDelta < 3 { visible = v }
        if let named = Region.hint(for: q) {
            // 見えている範囲が検索語の地域を含んでいれば、見えている範囲を使う
            if let visible, PlaceSearchService.inside(Coordinate(named.center), region: visible, scale: 1.0) {
                return (visible, true)
            }
            return (named, false)
        }
        if let visible { return (visible, true) }
        return (nil, false)
    }

    private func runSearch(hint override: MKCoordinateRegion? = nil, restrict: Bool = false) {
        let q = trimmedQuery
        guard !q.isEmpty else {
            search.clear()
            return
        }
        let chosen = override.map { (region: Optional($0), visible: true) } ?? defaultHint(for: q)
        let hint = chosen.region
        let keepView = chosen.visible
        // 検索の通信を待っている間に、地図の準備も進める
        if mode == .map { ensureMap() }
        Task {
            await search.search(q, hint: hint, restrictToHint: restrict)
            selected = nil
            showRedo = false
            tab = .search
            if mode == .map {
                // 見えている範囲で探したときは、地図を動かさない(範囲外の結果があるときだけ全体を映す)
                if keepView, let view = hint,
                   !mapSpots.isEmpty,
                   mapSpots.allSatisfy({ PlaceSearchService.inside($0.coordinate, region: view, scale: 1.05) }) {
                    lastFit = view
                } else {
                    fitMap()
                }
            }
        }
    }

    private func fitMap() {
        // 表示するスポットがないとき(検索窓を消したときなど)は、今の地図の表示を変えない
        guard !mapSpots.isEmpty else {
            showRedo = false
            return
        }
        let region = MapFit.region(for: mapSpots.map { $0.coordinate }, fallback: Self.wideRegion)
        lastFit = region
        position = .region(region)
        showRedo = false
    }

    private func handleCamera(_ region: MKCoordinateRegion) {
        visibleRegion = region
        guard search.hasSearched, let fit = lastFit else { return }
        let movedLat = abs(region.center.latitude - fit.center.latitude) > region.span.latitudeDelta * 0.2
        let movedLon = abs(region.center.longitude - fit.center.longitude) > region.span.longitudeDelta * 0.2
        showRedo = movedLat || movedLon
    }

    // MARK: パーツ

    private var chips: some View {
        ChipRow {
            ForEach(SpotTab.allCases) { t in
                Chip(title: t.rawValue, selected: tab == t) { tab = t }
            }
        }
        .padding(.horizontal, 20)
    }

    private func notice(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
            Text(text)
                .font(.system(size: 12))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.accentDark)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.sandLight, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var searchPrompt: some View {
        Button {
            runSearch()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "map")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("「\(trimmedQuery)」をマップで検索")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("お店・観光地を Apple マップから探します")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.subText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.subText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(radius: 18)
        }
        .buttonStyle(.plain)
    }

    // MARK: リスト

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: tab == .favorites ? "heart" : "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(Theme.sand)
            if tab == .favorites {
                Text(store.bookmarks.isEmpty ? "お気に入りはまだありません" : "条件に合うお気に入りがありません")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.subText)
                if store.bookmarks.isEmpty {
                    Text("検索した場所の詳細で、ブックマークのボタンから追加できます。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subText)
                }
            } else {
                Text(search.hasSearched ? "検索結果がありません" : "行きたい場所を検索しましょう")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.subText)
                if !search.hasSearched {
                    Text("例:「京都 カフェ」「三十三間堂」")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subText)
                }
            }
        }
        .padding(.top, 50)
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if shouldOfferSearch {
                    searchPrompt
                }
                if tab == .search, search.isSearching, displayed.isEmpty {
                    ProgressView()
                        .padding(.top, 40)
                } else if displayed.isEmpty {
                    emptyState
                }
                ForEach(displayed) { spot in
                    SpotRow(spot: spot)
                        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .onTapGesture { selected = spot }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 90)
        }
    }

    // MARK: 地図

    private var mapContent: some View {
        Group {
            if mapReady {
                SpotMapCanvas(
                    spots: mapSpots,
                    selected: $selected,
                    position: $position,
                    onTapMap: { _ in selected = nil },
                    onCameraChange: { handleCamera($0) },
                    nativePOI: true
                )
            } else {
                mapStartPanel
            }
        }
        .overlay(alignment: .top) {
            if showRedo && search.hasSearched && tab == .search {
                Button {
                    runSearch(hint: visibleRegion, restrict: true)
                } label: {
                    Label("このエリアで再検索", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accentDark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.surface, in: Capsule())
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
                }
                .padding(.top, 10)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            // 件数は、地図の邪魔にならない右上に小さく表示する
            if mapSpots.isEmpty == false {
                Text("\(mapSpots.count)件")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.subText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.surface.opacity(0.9), in: Capsule())
                    .padding(.top, 10)
                    .padding(.trailing, 12)
            }
        }
    }

    /// 地図を作る前の画面。すぐ操作できるようにして、検索してもらう間に地図を準備する
    private var mapStartPanel: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.sandLight, Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 14) {
                if mapLoading || search.isSearching {
                    ProgressView()
                    Text(search.isSearching ? "検索して、地図を準備しています…" : "地図を準備しています…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.subText)
                } else {
                    Image(systemName: "map")
                        .font(.system(size: 38))
                        .foregroundStyle(Theme.sand)
                    Text("行きたい場所を検索しましょう")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text("検索するか、地図上のスポットをタップして詳細を確認できます")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subText)
                    VStack(spacing: 8) {
                        ForEach(["京都 カフェ", "沖縄 ビーチ", "パリ 美術館"], id: \.self) { word in
                            Button {
                                query = word
                                runSearch()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 12))
                                    Text(word)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(Theme.accentDark)
                                .padding(.horizontal, 16)
                                .frame(height: ChipMetrics.height)
                                .background(Theme.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 80)
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 0) {
            modeButton(title: "地図", systemImage: "map", target: .map)
            modeButton(title: "リスト", systemImage: "list.bullet", target: .list)
        }
        .padding(4)
        .background(Theme.surface, in: Capsule())
        .shadow(color: Theme.accentDark.opacity(0.18), radius: 10, x: 0, y: 4)
        .frame(width: 240)
        .padding(.bottom, 12)
    }

    private func modeButton(title: String, systemImage: String, target: Mode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { mode = target }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(mode == target ? Color.white : Theme.subText)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(mode == target ? Theme.accent : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
