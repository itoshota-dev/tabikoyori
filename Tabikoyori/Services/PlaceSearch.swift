import Foundation
// MapKit の MKMapItem は、まだ並行処理の安全性(Sendable)の印が付いていない。
// 検索結果はメインスレッドで使うだけなので、MapKit 由来の警告は表示しない
@preconcurrency import MapKit
import CoreLocation
import Observation

// MARK: - Apple マップのフリーワード検索

/// スポット検索の画面の状態(検索中か、検索結果、エラー)
@MainActor
@Observable
final class PlaceSearchViewModel {
    var results: [Spot] = []
    var isSearching = false
    var errorMessage: String?
    var searchedQuery: String?
    @ObservationIgnored private var generation = 0

    var hasSearched: Bool { searchedQuery != nil }

    func clear() {
        generation += 1
        results = []
        searchedQuery = nil
        errorMessage = nil
        isSearching = false
    }

    func search(_ query: String, hint: MKCoordinateRegion? = nil, restrictToHint: Bool = false) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            clear()
            return
        }
        generation += 1
        let mine = generation
        isSearching = true
        errorMessage = nil

        do {
            let items = try await PlaceSearchService.search(query: q, region: hint)
            guard mine == generation else { return }

            var spots: [Spot] = []
            var seen = Set<String>()
            for item in items {
                let spot = PlaceSearchService.spot(from: item)
                if seen.insert(spot.id).inserted {
                    // 検索結果の MKMapItem をそのまま詳細カードに使えるよう覚えておく
                    MapItemResolver.shared.register(item, for: spot)
                    spots.append(spot)
                }
            }
            if restrictToHint, let hint {
                let inside = spots.filter { PlaceSearchService.inside($0.coordinate, region: hint) }
                if !inside.isEmpty { spots = inside }
            } else {
                spots = PlaceSearchService.dropOutliers(spots)
            }
            results = spots
            searchedQuery = q
            errorMessage = spots.isEmpty ? "「\(q)」に一致する場所が見つかりませんでした。" : nil
            isSearching = false
        } catch {
            guard mine == generation else { return }
            if let mkError = error as? MKError, mkError.code == .placemarkNotFound {
                results = []
                searchedQuery = q
                errorMessage = "「\(q)」に一致する場所が見つかりませんでした。"
            } else {
                errorMessage = "検索できませんでした。通信状況を確認してもう一度お試しください。"
            }
            isSearching = false
        }
    }
}

/// Apple マップのスポット検索(MKLocalSearch)を呼び、結果を並べ替える
enum PlaceSearchService {
    // MARK: 検索(表示している範囲を優先)

    /// 「観光」「名所」など、場所の種類を指定しない検索か
    static func isGenericTourism(_ query: String) -> Bool {
        let tourismWords = ["観光", "名所", "見どころ", "見所", "定番", "ランドマーク", "名勝", "有名", "スポット"]
        let otherIntent = ["カフェ", "喫茶", "ランチ", "ディナー", "ラーメン", "寿司", "居酒屋", "レストラン", "食", "ホテル", "宿", "温泉",
                           "バー", "パン", "スイーツ", "ショップ", "買い物", "駅", "空港", "コンビニ", "トイレ"]
        guard tourismWords.contains(where: { query.contains($0) }) else { return false }
        return !otherIntent.contains(where: { query.contains($0) })
    }

    /// 検索語から「観光」などの語を除いた、地名の部分
    private static func areaText(of query: String) -> String {
        var t = query
        for w in ["観光スポット", "観光地", "観光名所", "観光", "名所", "見どころ", "見所", "定番", "ランドマーク", "名勝", "有名", "おすすめ", "人気", "スポット"] {
            t = t.replacingOccurrences(of: w, with: " ")
        }
        return t.split(whereSeparator: { $0 == " " || $0 == "　" }).joined(separator: " ")
    }

    /// 表示範囲を 2×2 に分けて、それぞれの範囲を優先して検索する(結果が中央に偏らないように)
    private static func tiles(_ region: MKCoordinateRegion?) -> [MKCoordinateRegion?] {
        guard let r = region, r.span.latitudeDelta <= 3 else { return [region] }
        var result: [MKCoordinateRegion?] = []
        for i in 0..<2 {
            for j in 0..<2 {
                let center = CLLocationCoordinate2D(
                    latitude: r.center.latitude + (Double(i) - 0.5) * r.span.latitudeDelta / 2,
                    longitude: r.center.longitude + (Double(j) - 0.5) * r.span.longitudeDelta / 2
                )
                let span = MKCoordinateSpan(
                    latitudeDelta: r.span.latitudeDelta / 2 * 1.3,
                    longitudeDelta: r.span.longitudeDelta / 2 * 1.3
                )
                result.append(MKCoordinateRegion(center: center, span: span))
            }
        }
        return result
    }

    private static func fetch(_ query: String, region: MKCoordinateRegion?, types: MKLocalSearch.ResultType) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = types
        if let region {
            request.region = region
        }
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems
    }

    static func search(query: String, region: MKCoordinateRegion?) async throws -> [MKMapItem] {
        let generic = isGenericTourism(query)
        var queries = [query]
        if generic {
            let area = areaText(of: query)
            queries.append(area.isEmpty ? "観光名所" : area + " 観光名所")
        }
        let regions = tiles(region)

        // 範囲×検索語の組み合わせを並行して検索する
        var merged: [MKMapItem] = []
        var firstError: Error?
        await withTaskGroup(of: Result<[MKMapItem], Error>.self) { group in
            for q in queries {
                for r in regions {
                    group.addTask {
                        do {
                            return .success(try await fetch(q, region: r, types: .pointOfInterest))
                        } catch {
                            return .failure(error)
                        }
                    }
                }
            }
            for await result in group {
                switch result {
                case .success(let items):
                    merged.append(contentsOf: items)
                case .failure(let error):
                    if let mk = error as? MKError, mk.code == .placemarkNotFound { continue }
                    if firstError == nil { firstError = error }
                }
            }
        }

        if merged.isEmpty {
            if let firstError { throw firstError }
            // 施設で見つからない場合は住所も含めて再検索する
            return try await fetch(query, region: region, types: [.pointOfInterest, .address])
        }

        var seen = Set<String>()
        var items: [MKMapItem] = []
        for item in merged {
            let c = item.location.coordinate
            let key = item.identifier?.rawValue
                ?? "\(item.name ?? "")@" + String(format: "%.4f,%.4f", c.latitude, c.longitude)
            if seen.insert(key).inserted { items.append(item) }
        }

        // 表示している範囲の中の結果を優先する(範囲内に1件もなければそのまま)
        if let region, region.span.latitudeDelta <= 3 {
            let within = items.filter { PlaceSearchService.inside(Coordinate($0.location.coordinate), region: region, scale: 1.0) }
            if !within.isEmpty { items = within }
        }

        if generic { items = rankedByProminence(items) }
        return items
    }

    // MARK: 定番スポットを優先

    private static let majorKeywords = ["寺", "神社", "大社", "神宮", "宮", "城", "庭園", "公園", "美術館", "博物館", "水族館", "動物園",
                                         "タワー", "塔", "御所", "離宮", "大仏", "天守", "展望", "テーマパーク", "遊園地", "ビーチ", "岬", "滝", "湖", "山"]
    private static let minorKeywords = ["跡", "之地", "の地", "碑", "遺跡", "旧", "生誕", "発祥", "記念", "像", "邸", "屋敷", "史跡", "石", "門"]

    /// 公式サイトの有無・施設の種類・名前から「有名そうか」を点数にして、上位だけ残す
    /// (Apple のマップ情報には人気や口コミの数が含まれないための目安です)
    static func prominenceScore(_ item: MKMapItem) -> Int {
        var score = 0
        let name = item.name ?? ""
        if item.url != nil { score += 3 }
        if item.phoneNumber != nil { score += 1 }
        if let raw = item.pointOfInterestCategory?.rawValue.lowercased() {
            let strong = ["museum", "nationalpark", "park", "zoo", "aquarium", "amusementpark", "beach", "castle", "fortress", "nationalmonument"]
            if strong.contains(where: { raw.contains($0) }) { score += 2 }
            else if raw.contains("landmark") { score += 1 }
        }
        if majorKeywords.contains(where: { name.contains($0) }) { score += 2 }
        if minorKeywords.contains(where: { name.contains($0) }) { score -= 3 }
        return score
    }

    static func rankedByProminence(_ items: [MKMapItem], limit: Int = 20) -> [MKMapItem] {
        let scored = items.enumerated().map { (index: $0.offset, item: $0.element, score: prominenceScore($0.element)) }
        let sorted = scored.sorted { l, r in
            l.score != r.score ? l.score > r.score : l.index < r.index
        }
        let strong = sorted.filter { $0.score >= 3 }
        let picked = strong.count >= 5 ? strong : Array(sorted.prefix(10))
        return picked.prefix(limit).map { $0.item }
    }

    static func spot(from item: MKMapItem) -> Spot {
        let coordinate = item.location.coordinate
        let name = item.name ?? "名称未設定の場所"
        let (category, art) = classify(name: name, poi: item.pointOfInterestCategory)
        let (full, area) = address(from: item)
        let appleID = item.identifier?.rawValue
        let id: String
        if let appleID {
            id = "apple:" + appleID
        } else {
            id = "mk:" + String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude) + ":" + name
        }
        return Spot(
            id: id,
            name: name,
            category: category,
            area: area,
            address: full,
            region: nearestRegion(to: coordinate),
            coordinate: Coordinate(coordinate),
            art: art,
            phone: item.phoneNumber,
            website: item.url?.absoluteString,
            appleID: appleID
        )
    }

    static func classify(name: String, poi: MKPointOfInterestCategory?) -> (SpotCategory, ArtStyle) {
        let raw = (poi?.rawValue ?? "").lowercased()
        if raw.contains("cafe") { return (.cafe, .cafe) }
        let foodWords = ["restaurant", "bakery", "foodmarket", "brewery", "winery", "distillery", "nightlife"]
        if foodWords.contains(where: { raw.contains($0) }) { return (.gourmet, .market) }
        if name.contains("神社") || name.contains("大社") || name.hasSuffix("宮") { return (.shrine, .torii) }
        if name.contains("寺") || name.hasSuffix("院") { return (.temple, .temple) }
        if raw.contains("museum") || raw.contains("theater") { return (.museum, .museum) }
        if raw.contains("beach") || raw.contains("marina") || raw.contains("aquarium") || raw.contains("surf") { return (.sea, .sea) }
        if raw.contains("park") || raw.contains("hiking") || raw.contains("campground") { return (.nature, .bamboo) }
        if raw.contains("castle") || raw.contains("fortress") { return (.landmark, .castle) }
        return (.landmark, .street)
    }

    /// 住所(全体)と、一覧に出す短い地名(市区町村など)
    private static func address(from item: MKMapItem) -> (full: String, area: String) {
        let reps = item.addressRepresentations
        let full = reps?.fullAddress(includingRegion: false, singleLine: true)
            ?? item.address?.fullAddress
            ?? ""
        let area = reps?.cityWithContext ?? reps?.cityName ?? ""
        return (full, area)
    }

    static func nearestRegion(to c: CLLocationCoordinate2D) -> Region {
        let here = CLLocation(latitude: c.latitude, longitude: c.longitude)
        var best = Region.kyoto
        var bestDistance = Double.greatestFiniteMagnitude
        for region in Region.allCases {
            let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            let d = here.distance(from: center)
            if d < bestDistance {
                bestDistance = d
                best = region
            }
        }
        return best
    }

    /// 検索結果の中心から大きく離れた店を除いて、表示範囲を絞る
    static func dropOutliers(_ spots: [Spot]) -> [Spot] {
        guard spots.count > 2 else { return spots }
        let lats = spots.map { $0.coordinate.latitude }.sorted()
        let lons = spots.map { $0.coordinate.longitude }.sorted()
        let median = CLLocation(latitude: lats[lats.count / 2], longitude: lons[lons.count / 2])
        let kept = spots.filter {
            CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude).distance(from: median) < 150_000
        }
        return kept.isEmpty ? spots : kept
    }

    static func inside(_ c: Coordinate, region: MKCoordinateRegion, scale: Double = 1.15) -> Bool {
        let latOK = abs(c.latitude - region.center.latitude) <= region.span.latitudeDelta * scale / 2
        let lonOK = abs(c.longitude - region.center.longitude) <= region.span.longitudeDelta * scale / 2
        return latOK && lonOK
    }
}

// MARK: - スポット → Apple の MKMapItem(詳細カード用)

/// 保存済みのスポット(旅程・お気に入り・おすすめ一覧)を、電話・サイトの取得や Apple マップで開くための MKMapItem に変換する。
/// ① 検索で得た MKMapItem  ② 場所ID  ③ 名前+座標での再検索  の順に試す。
@MainActor
final class MapItemResolver {
    static let shared = MapItemResolver()

    struct Resolved {
        let item: MKMapItem
        /// Apple マップ上の実在の場所と結びついたか(false なら座標と名前だけの簡易アイテム)
        let matched: Bool
    }

    private var cache: [String: MKMapItem] = [:]

    func register(_ item: MKMapItem, for spot: Spot) {
        cache[spot.id] = item
    }

    func resolve(_ spot: Spot) async -> Resolved {
        if let cached = cache[spot.id] { return Resolved(item: cached, matched: true) }

        if let raw = spot.appleID, let identifier = MKMapItem.Identifier(rawValue: raw) {
            let request = MKMapItemRequest(mapItemIdentifier: identifier)
            if let item = try? await request.mapItem {
                cache[spot.id] = item
                return Resolved(item: item, matched: true)
            }
        }

        if !spot.isCustom, let item = await searchNearby(spot) {
            cache[spot.id] = item
            return Resolved(item: item, matched: true)
        }

        // どれも見つからなければ、名前と座標だけの簡易な地図アイテム
        let item = MKMapItem(location: CLLocation(latitude: spot.coordinate.latitude, longitude: spot.coordinate.longitude), address: nil)
        item.name = spot.name
        return Resolved(item: item, matched: false)
    }

    private func normalized(_ s: String) -> String {
        String(String.UnicodeScalarView(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }

    /// 名前と座標から、Apple マップ上の同じ場所を探す。
    /// 名前が一致する場所を優先し、一致がなければ、ごく近い場所だけを採用する。
    private func searchNearby(_ spot: Spot) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = spot.name
        request.region = MKCoordinateRegion(
            center: spot.coordinate.cl,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        request.resultTypes = .pointOfInterest
        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }

        let here = CLLocation(latitude: spot.coordinate.latitude, longitude: spot.coordinate.longitude)
        func distance(_ item: MKMapItem) -> Double {
            return item.location.distance(from: here)
        }

        let target = normalized(spot.name)
        func nameMatches(_ item: MKMapItem) -> Bool {
            let n = normalized(item.name ?? "")
            guard n.count >= 2, target.count >= 2 else { return false }
            return n.contains(target) || target.contains(n)
        }

        let items = response.mapItems
        if let byName = items.filter({ nameMatches($0) && distance($0) < 1000 }).min(by: { distance($0) < distance($1) }) {
            return byName
        }
        if let near = items.min(by: { distance($0) < distance($1) }), distance(near) < 120 {
            return near
        }
        return nil
    }
}
