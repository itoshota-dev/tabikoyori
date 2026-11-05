import SwiftUI
import MapKit

// MARK: - 地図で見る(旅程のスポット)

/// 旅行の地図(スポットの表示と、経路の表示)
struct TripMapView: View {
    @Environment(TripStore.self) private var store

    let tripID: UUID
    /// true のとき(下のメニューの「経路」)は、戻るボタンの代わりに旅行を切り替える飛行機アイコンを出し、経路の表示で始める
    var switcher = false
    init(tripID: UUID, switcher: Bool = false, routeService: any RouteSearching = MapKitRouteService()) {
        self.tripID = tripID
        self.switcher = switcher
        // 経路の検索結果の管理は ViewModel に任せる(経路を調べる係は、テストやプレビューでは差し替えられる)
        _routes = State(initialValue: RouteMapViewModel(tripID: tripID, service: routeService))
        _layer = State(initialValue: switcher ? .route : .spots)
        _dayFilter = State(initialValue: switcher ? 0 : nil)
    }

    enum Layer: String, CaseIterable, Identifiable {
        case spots = "スポット"
        case route = "経路"

        var id: String { rawValue }
    }

    @State private var layer: Layer = .spots
    @State private var selected: Spot?
    @State private var position: MapCameraPosition = .automatic
    /// nil のときは全日程、数字のときはその日(0 が1日目)だけを表示する
    @State private var dayFilter: Int?
    /// 経路の検索結果・キャッシュ・読み込み状態(RouteMapViewModel.swift)
    @State private var routes: RouteMapViewModel
    @State private var sheetDetent: SheetDetent = .small
    /// 地図の表示領域の高さ(カードをほぼ全面に広げるときの高さに使う)
    @State private var mapAreaHeight: CGFloat = 700

    /// 表示中の日ごとに、順番に並んだ予定の間の区間
    private var legs: [RouteLeg] {
        guard layer == .route, let trip else { return [] }
        return RouteLeg.legs(in: trip, dayFilter: dayFilter)
    }

    /// その区間で選ばれている移動手段(未選択は nil)
    private func chosenMode(_ leg: RouteLeg) -> TravelMode? {
        routes.chosenMode(leg, store: store)
    }

    private var routeLines: [RouteLine] {
        legs.enumerated().map { index, leg in
            let color = RouteColors.color(at: index)
            let mode = chosenMode(leg)
            var label: String?
            let state = routes.state(for: leg, mode: mode)
            if mode != nil {
                let stored = trip?.travelLeg(from: leg.from.id, to: leg.to.id)?.seconds
                if state?.error == nil, let seconds = state?.result?.time ?? stored {
                    label = DisplayFormat.duration(seconds)
                }
            }
            // 札をタップして選んだ移動手段を、その区間に設定する
            let onChoose: (TravelMode) -> Void = { choose($0, for: leg) }
            if let mode, let coords = state?.result?.coords {
                return RouteLine(
                    id: mode.rawValue + "|" + leg.id, coords: coords, isDirectLine: false,
                    label: label, sublabel: mode.label, color: color,
                    mode: mode, onChoose: onChoose
                )
            }
            return RouteLine(
                id: leg.id + "|line|" + (mode?.rawValue ?? "none"),
                // 2つの目的地を結ぶ線(いまは直線。RouteDrawing.swift の RouteCurve.bulge を 0 より大きくするとカーブになる)
                coords: RouteCurve.arc(from: leg.from.spot.coordinate.cl, to: leg.to.spot.coordinate.cl),
                isDirectLine: true,
                // 移動手段をまだ選んでいない区間は「未選択」の札を出す(タップして選べる)
                label: mode == nil ? "未選択" : label,
                sublabel: mode?.label,
                color: color,
                mode: mode,
                onChoose: onChoose
            )
        }
    }

    /// 表示中の予定の通し番号(旅程の順に 1, 2, 3 …)
    private var stopNumbers: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: visibleItems.enumerated().map { ($1.id, $0 + 1) })
    }

    /// 経路の表示中は、目的地に旅程の通し番号と開始・終了時刻を出す
    private var stopInfos: [String: RouteStopInfo] {
        guard layer == .route else { return [:] }
        let numbers = stopNumbers
        var result: [String: RouteStopInfo] = [:]
        for item in visibleItems where result[item.spot.id] == nil {
            // 前の日から続く予定(複製)の時間を変えるときは、元の予定を編集する
            let original = trip?.items.first { $0.id == item.sourceID } ?? item
            result[item.spot.id] = RouteStopInfo(
                number: numbers[item.id] ?? 0,
                times: [DisplayFormat.startClockTime(item), DisplayFormat.endClockTime(item.endOnDay)],
                startMinutes: original.minutes,
                endMinutes: original.end,
                isEndTimeSet: original.endMinutes != nil,
                timeConverter: trip.map { ItineraryTimeConverter(trip: $0, day: original.day) },
                onSave: { start, end in
                    store.setTimes(start: start, end: end, itemID: original.id, in: tripID)
                }
            )
        }
        return result
    }

    private var routeTaskKey: String {
        layer.rawValue + "|" + legs.map { $0.id + ":" + (chosenMode($0)?.rawValue ?? "-") }.joined(separator: ",")
    }

    /// 移動手段を選んだのに、まだ結果が届いていない区間がある
    private var loadingRoutes: Bool {
        routes.isLoading(legs, store: store)
    }

    /// 区間の移動手段を選ぶ(同じものをもう一度押すと解除)
    private func choose(_ mode: TravelMode, for leg: RouteLeg) {
        routes.choose(mode, for: leg, store: store)
    }

    /// 表示中のすべての区間を、同じ移動手段にする(nil で解除)
    private func setAll(_ mode: TravelMode?) {
        routes.setAll(mode, legs: legs, store: store)
    }

    private var trip: Trip? { store.trip(tripID) }

    /// 表示する日の予定(日・時間順)
    private var visibleItems: [ItineraryItem] {
        guard let trip else { return [] }
        if let dayFilter { return trip.items(forDay: dayFilter) }
        return trip.sortedItems
    }

    private var tripSpots: [Spot] {
        var seen = Set<String>()
        var result: [Spot] = []
        for item in visibleItems where !seen.contains(item.spot.id) {
            seen.insert(item.spot.id)
            result.append(item.spot)
        }
        return result
    }

    // MARK: 経路カードの引き出し(小さく収納 / 中くらい / ほぼ全面)

    private func detentHeight(_ detent: SheetDetent) -> CGFloat {
        detent.height(available: mapAreaHeight)
    }

    private var showsRoutePanel: Bool {
        layer == .route && !legs.isEmpty
    }

    /// 現在地と、旅程全体を表示するボタン
    private var mapButtons: some View {
        VStack(spacing: 10) {
            MapRoundButton(systemImage: "location.fill") {
                LocationService.shared.requestAuthorization()
                position = .userLocation(fallback: .automatic)
            }
            // 旅程全体が入るように表示する
            MapRoundButton(systemImage: "viewfinder") {
                fitToTrip()
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MapLoadingGate {
                SpotMapCanvas(
                    spots: tripSpots,
                    routeLines: routeLines,
                    stopInfos: stopInfos,
                    selected: $selected,
                    position: $position,
                    onTapMap: { _ in selected = nil },
                    clustering: false,
                    // このページでは新しい場所は探さないので、地図上の地名などをタップしても詳細を出さない
                    featureSelectable: false
                )
            }
            // Apple のロゴと法律情報を、小さく畳んだカードのすぐ上に出す。
            // カードの高さを変えても、地図の余白は変えない(余白を変えると、MapKit が地図を描き直して位置が動くため)。
            // そのため、カードを中・大に広げたときは、ロゴはカードの下に隠れる
            .safeAreaInset(edge: .bottom, spacing: 0) {
                let height: CGFloat = showsRoutePanel ? detentHeight(.small) + 8 : 0
                Color.clear
                    .frame(height: height)
                    // 地図の余白は、アニメーションさせない(動かすと地図が重くなる)
                    .animation(nil, value: height)
            }
            // 地図の表示領域の高さ。下の余白を含めた、地図そのものの大きさで測る
            // (カードの大きさの影響は受けない。余白の内側で測ると、その分「大」が低くなってしまう)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { mapAreaHeight = $0 }

            // 経路のカードを出しているときは、ボタンはカードの上に乗せて、カードと一緒に動かす
            if !showsRoutePanel {
                VStack(spacing: 10) {
                    Spacer()
                    HStack {
                        Spacer()
                        mapButtons
                            .padding(.trailing, 16)
                    }
                    bottomCard
                }
                .padding(.bottom, 8)
            }

            if showsRoutePanel {
                routeCard
                    .padding(.bottom, 8)
            }
        }
        .task(id: routeTaskKey) { await routes.load(legs, store: store) }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .navigationTitle(trip?.title ?? "地図で見る")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if switcher {
                // 旅行を切り替える(旅程タブと同じ)
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
                            .accessibilityLabel("旅行を切り替え")
                    }
                    .menuOrder(.fixed)
                }
            }
            // スポット / 経路の切り替えは、右上にまとめる
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("表示", selection: $layer) {
                        ForEach(Layer.allCases) { l in
                            Text(l.rawValue).tag(l)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(layer.rawValue)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accentDark)
                }
                .menuOrder(.fixed)
            }
        }
        .spotDetailSheet($selected, tripID: tripID)
        .onAppear { fitToTrip() }
        .onChange(of: layer) { _, newValue in
            if newValue == .route {
                if dayFilter == nil { dayFilter = 0 }
                fitToTrip()
            }
        }
        .onChange(of: dayFilter) { _, _ in
            // 日を切り替えても、地図の位置や縮尺は動かさない
            selected = nil
        }
    }

    /// 上部: 日ごとの切り替え(全日程 / 1日目 / 2日目…)と、表示の種類(スポット / 経路)
    private var topBar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 経路は日ごとに見るので、「全日程」は経路のときは出さない
                    if layer != .route {
                        Chip(title: "全日程", selected: dayFilter == nil) { dayFilter = nil }
                    }
                    ForEach(0..<(trip?.dayCount ?? 0), id: \.self) { d in
                        // 何日目かではなく、日付と曜日(例: 10/28（水）)で表示する
                        Chip(
                            title: trip.map { DisplayFormat.shortMonthDayWeekday.string(from: $0.date(forDay: d)) } ?? "\(d + 1)日目",
                            selected: dayFilter == d
                        ) { dayFilter = d }
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollClipDisabled()
        }
        .padding(.vertical, 10)
    }

    private func fitToTrip() {
        guard let trip else { return }
        let coords = tripSpots.map { $0.coordinate }
        position = .region(MapFit.region(for: coords, fallback: trip.mapRegion))
    }

    // MARK: 経路の表示

    /// 経路のカードに並べる行(目的地 → 移動 → 目的地 …)
    private enum RouteRow: Identifiable {
        case day(Int)
        case stop(ItineraryItem, Int)
        case leg(RouteLeg, Int)

        var id: String {
            switch self {
            case .day(let d): return "day\(d)"
            case .stop(let item, let n): return "stop|\(item.id)|\(n)"
            case .leg(let leg, _): return "leg|\(leg.id)"
            }
        }
    }

    private var routeRows: [RouteRow] {
        var rows: [RouteRow] = []
        var lastDay: Int?
        var lastStop: UUID?
        for (index, leg) in legs.enumerated() {
            if leg.day != lastDay {
                if dayFilter == nil { rows.append(.day(leg.day)) }
                lastDay = leg.day
                lastStop = nil
            }
            if lastStop != leg.from.id {
                rows.append(.stop(leg.from, index * 2))
            }
            rows.append(.leg(leg, index))
            rows.append(.stop(leg.to, index * 2 + 1))
            lastStop = leg.to.id
        }
        return rows
    }

    private var routeCard: some View {
        let done = routes.loadedResults(legs, store: store)
        let totalTime = done.compactMap { $0.time }.reduce(0, +)
        let numbers = stopNumbers

        return DraggableSheet(detent: $sheetDetent, availableHeight: mapAreaHeight, collapsedTitle: "移動手段を選ぶ") {
            HStack(spacing: 8) {
                if loadingRoutes {
                    ProgressView().controlSize(.small)
                    Text("経路を検索中…")
                } else if done.isEmpty {
                    Text("区間ごとに移動手段を選んでください")
                } else {
                    Text("移動時間の合計 \(DisplayFormat.duration(totalTime))")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.text)
                }
                Spacer()
                Menu {
                    ForEach(TravelMode.allCases) { m in
                        Button(m.label, systemImage: m.symbol) { setAll(m) }
                    }
                    Divider()
                    Button("すべて解除", systemImage: "xmark.circle", role: .destructive) { setAll(nil) }
                } label: {
                    HStack(spacing: 3) {
                        Text("まとめて設定")
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accentDark)
                }
                .menuOrder(.fixed)
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.subText)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(routeRows) { row in
                    switch row {
                    case .day(let d):
                        Text("\(d + 1)日目")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.subText)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    case .stop(let item, _):
                        stopRow(item, number: numbers[item.id] ?? 0)
                    case .leg(let leg, let index):
                        legRow(leg, color: RouteColors.color(at: index))
                    }
                }
                Text("電車・バスは経路の線を地図に表示できないため、所要時間と距離の目安だけを表示します。乗り換えは、各区間右の \(Image(systemName: AppleMapsLauncher.symbolName)) から Apple マップで確認できます。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.subText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }
        } accessory: {
            mapButtons
        }
    }

    private func stopRow(_ item: ItineraryItem, number: Int) -> some View {
        HStack(spacing: 8) {
            NumberBadge(number: number)
                .frame(width: 22)
            Text(item.spot.name)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Text("\(DisplayFormat.startClockTime(item))–\(DisplayFormat.endClockTime(item.endOnDay))")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Theme.subText)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    /// 2つの目的地の間(↓の色は、地図の線の色と同じ)
    private func legRow(_ leg: RouteLeg, color: Color) -> some View {
        let chosen = chosenMode(leg)
        let state = routes.state(for: leg, mode: chosen)
        let stored = trip?.travelLeg(from: leg.from.id, to: leg.to.id)

        var detail = "移動手段を選ぶと、所要時間を検索します"
        var canRetry = false
        if let chosen {
            switch state {
            case .failed(.notFound)?:
                detail = "経路が見つかりませんでした"
            case .failed(.network)?:
                detail = "通信エラーで検索できませんでした"
                canRetry = true
            default:
                if let seconds = state?.result?.time ?? stored?.seconds {
                    detail = chosen.label + " ・ " + DisplayFormat.duration(seconds)
                    if let meters = state?.result?.distance ?? stored?.meters {
                        detail += " ・ " + DisplayFormat.distance(meters)
                    }
                } else {
                    detail = "検索中…"
                }
            }
        }

        return HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                    .offset(y: -2)
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 6) {
                ChipRow {
                    ForEach(TravelMode.allCases) { m in
                        Chip(title: m.label, selected: chosen == m, tint: color) { choose(m, for: leg) }
                    }
                }
                HStack(spacing: 6) {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.subText)
                    if canRetry {
                        // 通信エラーのときは、その区間だけもう一度調べる
                        Button("再試行") {
                            Task { await routes.retry(leg, store: store) }
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.accentDark)
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 4)
                    Button {
                        AppleMapsLauncher.openDirections(from: leg.from.spot, to: leg.to.spot, mode: chosen ?? .car)
                    } label: {
                        // Apple マップで開く(アプリへ移動するリンクのマーク)
                        Image(systemName: AppleMapsLauncher.symbolName)
                            .font(.system(size: 19))
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel("Apple マップで経路を開く")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var bottomCard: some View {
        if selected == nil, tripSpots.isEmpty {
            Text(dayFilter == nil ? "旅程にスポットを追加すると、ここに表示されます" : "この日の予定はまだありません")
                .font(.system(size: 12))
                .foregroundStyle(Theme.subText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.surface.opacity(0.95), in: Capsule())
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
        }
    }
}
