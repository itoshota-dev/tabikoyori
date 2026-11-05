import SwiftUI
import MapKit

/// スポットを表示する共通の地図
struct SpotMapCanvas: View {
    var spots: [Spot]
    var route: [Coordinate] = []
    /// 道に沿った経路など、地図に描く線
    var routeLines: [RouteLine] = []
    /// 経路モードで、目的地に出す番号と開始・終了時刻(スポットID → 表示)
    var stopInfos: [String: RouteStopInfo] = [:]
    var customPin: Coordinate? = nil
    @Binding var selected: Spot?
    @Binding var position: MapCameraPosition
    var onTapMap: ((CLLocationCoordinate2D) -> Void)? = nil
    var onCameraChange: ((MKCoordinateRegion) -> Void)? = nil
    /// true のとき、Apple マップ標準のスポット表示を出し、タップで詳細を開けるようにする
    var nativePOI = false
    /// false のとき、近いピンをまとめず、すべて個別のピンで表示する
    var clustering = true
    /// false のとき、地図の地名や施設名(「金閣寺」など)をタップしても何も起こらない
    var featureSelectable = true

    @State private var featureSelection: MapSelection<MKMapItem>?
    /// いま見えている地図の範囲(近いピンをまとめる計算に使う)
    @State private var currentRegion: MKCoordinateRegion?
    /// まとめ方の基準にしている地図の広さ。拡大・縮小で大きく変わったときだけ更新する
    /// (地図を動かしただけでは、まとめ方が変わらないようにする)
    @State private var clusterSpan: MKCoordinateSpan?
    @State private var zoomTask: Task<Void, Never>?

    /// 近くにあるピンをまとめた1つの表示単位
    private struct PinCluster: Identifiable {
        let id: String
        let spots: [Spot]

        var coordinate: CLLocationCoordinate2D {
            let lat = spots.map { $0.coordinate.latitude }.reduce(0, +) / Double(spots.count)
            let lon = spots.map { $0.coordinate.longitude }.reduce(0, +) / Double(spots.count)
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// 地図の範囲を格子に区切り、同じ格子に入るピンを1つにまとめる。
    /// 選択中のピンと、十分に拡大した状態では、まとめない。
    private var clusters: [PinCluster] {
        let single = { (spot: Spot) in PinCluster(id: spot.id, spots: [spot]) }
        guard clustering, spots.count > 1,
              let span = clusterSpan ?? (currentRegion ?? position.region)?.span,
              span.latitudeDelta > 0.004 else {
            return spots.map(single)
        }
        let latCell = span.latitudeDelta / 7
        let lonCell = span.longitudeDelta / 5
        var order: [String] = []
        var buckets: [String: [Spot]] = [:]
        var result: [PinCluster] = []
        for spot in spots {
            if spot.id == selected?.id {
                result.append(single(spot))
                continue
            }
            let row = Int((spot.coordinate.latitude / latCell).rounded(.down))
            let col = Int((spot.coordinate.longitude / lonCell).rounded(.down))
            let key = "\(row),\(col)"
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(spot)
        }
        for key in order {
            guard let group = buckets[key] else { continue }
            if group.count == 1 {
                result.append(single(group[0]))
            } else {
                result.append(PinCluster(id: "cluster:" + group.map { $0.id }.sorted().joined(separator: "|"), spots: group))
            }
        }
        return result
    }

    /// まとめたピンをタップしたとき、その中のピンが見える範囲まで拡大する
    private func zoom(to cluster: PinCluster) {
        let lats = cluster.spots.map { $0.coordinate.latitude }
        let lons = cluster.spots.map { $0.coordinate.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let current = currentRegion ?? position.region
        var latDelta = max((maxLat - minLat) * 1.8, 0.002)
        var lonDelta = max((maxLon - minLon) * 1.8, 0.002)
        // 少なくとも今より拡大する
        if let current {
            latDelta = min(latDelta, current.span.latitudeDelta * 0.6)
            lonDelta = min(lonDelta, current.span.longitudeDelta * 0.6)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        animateCamera(to: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        ))
    }

    /// 拡大の速さを、今の縮尺や移動距離に関係なく一定にするため、自分で途中経過を計算して動かす。
    /// 広さは対数で補間し(体感の速さが一定になる)、中心は目的の場所が画面上で動かないように補間する。
    private func animateCamera(to target: MKCoordinateRegion, duration: Double = 0.4) {
        zoomTask?.cancel()
        guard let start = currentRegion ?? position.region else {
            position = .region(target)
            return
        }
        zoomTask = Task { @MainActor in
            let steps = 24
            let frame = UInt64(duration / Double(steps) * 1_000_000_000)
            let s0 = start.span.latitudeDelta
            let s1 = target.span.latitudeDelta
            for i in 1...steps {
                if Task.isCancelled { return }
                let t = Double(i) / Double(steps)
                let eased = t * t * (3 - 2 * t)
                func logLerp(_ a: Double, _ b: Double) -> Double {
                    exp(log(a) + (log(b) - log(a)) * eased)
                }
                let latSpan = logLerp(s0, s1)
                let lonSpan = logLerp(start.span.longitudeDelta, target.span.longitudeDelta)
                // 広さの変化に応じた割合で中心を動かす(広さが同じなら、時間の割合で動かす)
                let f = abs(s0 - s1) > 1e-9 ? (s0 - latSpan) / (s0 - s1) : eased
                let center = CLLocationCoordinate2D(
                    latitude: start.center.latitude + (target.center.latitude - start.center.latitude) * f,
                    longitude: start.center.longitude + (target.center.longitude - start.center.longitude) * f
                )
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    position = .region(MKCoordinateRegion(
                        center: center,
                        span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
                    ))
                }
                try? await Task.sleep(nanoseconds: frame)
            }
        }
    }

    /// 日常的な施設(コンビニ・駐車場など)は出さず、観光に関わるスポットを表示する
    private static let hiddenCategories: [MKPointOfInterestCategory] = [
        .restaurant, .cafe, .bakery, .store, .atm, .bank, .gasStation, .parking, .evCharger,
        .pharmacy, .laundry, .postOffice, .carRental, .restroom, .fitnessCenter, .hospital,
        .police, .fireStation, .school
    ]

    private var style: MapStyle {
        if nativePOI {
            return .standard(elevation: .flat, pointsOfInterest: .excluding(Self.hiddenCategories))
        }
        return .standard(elevation: .flat, pointsOfInterest: .excludingAll)
    }

    private func open(_ item: MKMapItem) {
        let spot = PlaceSearchService.spot(from: item)
        MapItemResolver.shared.register(item, for: spot)
        selected = spot
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $position, selection: $featureSelection) {
                UserAnnotation()

                if route.count > 1 {
                    MapPolyline(coordinates: route.map { $0.cl })
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [7, 6]))
                }

                // 道に沿った経路(太さ6)
                ForEach(routeLines.filter { !$0.isDirectLine }) { line in
                    MapPolyline(coordinates: line.coords)
                        .stroke(line.color, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }

                // 電車・バスや、移動手段を選んでいない区間は「中が白い直線」で描く(外側5・中3.5。色は両側に細く残る)。
                // 直線かカーブかは RouteDrawing.swift の RouteCurve.bulge で決めている
                // 道に沿った経路(中まで塗った線)と見分けがつき、実際にその道を通るようには見えない。
                // 実線を2本重ねるだけなので、地図に張り付き、ズームしてもぼやけない
                ForEach(routeLines.filter { $0.isDirectLine }) { line in
                    MapPolyline(coordinates: line.coords)
                        .stroke(line.color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    MapPolyline(coordinates: line.coords)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                }

                // 経路の上の所要時間(タップすると、吹き出しで移動手段を選べる)
                ForEach(routeLines) { line in
                    if let label = line.label, let mid = line.midpoint {
                        Annotation("", coordinate: mid, anchor: .center) {
                            // タップすると、吹き出しで移動手段を選べる
                            RouteLabelButton(line: line)
                                .opacity(label.isEmpty ? 0 : 1)
                        }
                    }
                }

                ForEach(clusters) { cluster in
                    if cluster.spots.count == 1, let spot = cluster.spots.first {
                        if let stopInfo = stopInfos[spot.id] {
                            // 経路モードでは、丸いピンの代わりに開始・終了時刻を出す
                            Annotation("", coordinate: spot.coordinate.cl, anchor: .center) {
                                RouteStopPin(
                                    spot: spot,
                                    info: stopInfo,
                                    selected: selected?.id == spot.id,
                                    onSelect: { selected = spot }
                                )
                            }
                        } else {
                            Annotation("", coordinate: spot.coordinate.cl, anchor: .bottom) {
                                SpotPin(spot: spot, selected: selected?.id == spot.id)
                                    .onTapGesture { selected = spot }
                            }
                        }
                    } else {
                        Annotation("", coordinate: cluster.coordinate, anchor: .center) {
                            ClusterPin(count: cluster.spots.count)
                                .onTapGesture { zoom(to: cluster) }
                        }
                    }
                }

                // 地図の標準スポットなど、ピンのない場所を選んだときも、選んだ場所にピンを立てる
                if let current = selected, !spots.contains(where: { $0.id == current.id }) {
                    Annotation("", coordinate: current.coordinate.cl, anchor: .bottom) {
                        SpotPin(spot: current, selected: true)
                    }
                }

                if let pin = customPin {
                    Annotation("", coordinate: pin.cl, anchor: .bottom) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white, Theme.accent)
                            .shadow(radius: 3)
                    }
                }
            }
            .mapStyle(style)
            .onMapCameraChange(frequency: .onEnd) { context in
                currentRegion = context.region
                let newSpan = context.region.span
                if let base = clusterSpan, base.latitudeDelta > 0 {
                    // 拡大・縮小の倍率が約1.4倍を超えたときだけ、まとめ方を作り直す
                    if abs(log2(newSpan.latitudeDelta / base.latitudeDelta)) > 0.5 {
                        clusterSpan = newSpan
                    }
                } else {
                    clusterSpan = newSpan
                }
                onCameraChange?(context.region)
            }
            .onChange(of: featureSelection) { _, newValue in
                guard let newValue else { return }
                featureSelection = nil
                guard featureSelectable else { return }
                if let item = newValue.value {
                    open(item)
                } else if let feature = newValue.feature {
                    Task {
                        if let item = try? await MKMapItemRequest(feature: feature).mapItem {
                            open(item)
                        }
                    }
                }
            }
            .onTapGesture { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    onTapMap?(coordinate)
                }
            }
        }
    }
}

/// 近くのピンをまとめた丸いバッジ(数字は件数)
struct ClusterPin: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Theme.accent, in: Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
}

/// 地図の上に置く、丸いボタン(現在地・全体表示など)
struct MapRoundButton: View {
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.accentDark)
                .frame(width: 46, height: 46)
                .background(Theme.surface, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        }
    }
}

/// フリーワード検索バー(「京都 カフェ」など)
struct MapSearchBar<Trailing: View>: View {
    @Binding var text: String
    var prompt: String
    var isSearching: Bool
    var onSearch: () -> Void
    var onClear: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    @FocusState private var focused: Bool

    init(
        text: Binding<String>,
        prompt: String,
        isSearching: Bool = false,
        onSearch: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {},
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self._text = text
        self.prompt = prompt
        self.isSearching = isSearching
        self.onSearch = onSearch
        self.onClear = onClear
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.subText)
            TextField(prompt, text: $text)
                .font(.system(size: 14))
                .submitLabel(.search)
                .autocorrectionDisabled()
                .focused($focused)
                .onSubmit {
                    focused = false
                    onSearch()
                }
            if isSearching {
                ProgressView().controlSize(.small)
            } else if !text.isEmpty {
                Button {
                    text = ""
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.sand)
                        .accessibilityLabel("検索の文字を消す")
                }
                .buttonStyle(.plain)
            }
            trailing()
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 46)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// 末尾の部品がない検索窓(アプリ内の検索窓はすべてこの見た目に統一する)
extension MapSearchBar where Trailing == EmptyView {
    init(
        text: Binding<String>,
        prompt: String,
        isSearching: Bool = false,
        onSearch: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {}
    ) {
        self.init(text: text, prompt: prompt, isSearching: isSearching, onSearch: onSearch, onClear: onClear) {
            EmptyView()
        }
    }
}
