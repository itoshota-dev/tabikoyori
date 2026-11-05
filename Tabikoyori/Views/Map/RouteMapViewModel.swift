import Foundation
import Observation

// MARK: - 経路マップの区間と、経路検索の状態

/// 隣り合う2つの予定の間(1区間)
struct RouteLeg: Identifiable {
    let from: ItineraryItem
    let to: ItineraryItem
    let day: Int

    var id: String { from.id.uuidString + ">" + to.id.uuidString }

    /// 検索結果を覚えておくときのキー。
    /// 区間と移動手段だけでなく、出発・到着の場所(座標)も含めるので、場所が変わったら調べ直す
    func cacheKey(_ mode: TravelMode) -> RouteCacheKey {
        RouteCacheKey(legID: id, from: from.spot.coordinate, to: to.spot.coordinate, mode: mode)
    }

    /// 旅程から、表示する日ごとの区間を作る(同じスポットが続くところは区間にしない)
    /// - dayFilter: nil のときは全日程
    static func legs(in trip: Trip, dayFilter: Int?) -> [RouteLeg] {
        let days = dayFilter.map { [$0] } ?? Array(0..<trip.dayCount)
        var result: [RouteLeg] = []
        for d in days {
            let items = trip.items(forDay: d)
            for (a, b) in zip(items, items.dropFirst()) where a.spot.id != b.spot.id {
                result.append(RouteLeg(from: a, to: b, day: d))
            }
        }
        return result
    }
}

/// 経路の検索結果を覚えておくときのキー(区間・出発と到着の座標・移動手段)
struct RouteCacheKey: Hashable {
    let legID: String
    let from: Coordinate
    let to: Coordinate
    let mode: TravelMode
}

/// 1つの区間の経路検索の状態
enum RouteState {
    case loading
    case loaded(RouteResult)
    case failed(RouteError)

    var result: RouteResult? {
        if case .loaded(let r) = self { return r }
        return nil
    }

    var error: RouteError? {
        if case .failed(let e) = self { return e }
        return nil
    }
}

// MARK: - 経路マップの ViewModel

/// 経路マップの「経路を調べて覚えておく」役。
///
/// 役割の分け方:
/// - 地図・ピン・シート・カメラ位置などの表示 → TripMapView(画面)
/// - 経路の検索結果・キャッシュ・読み込み状態・古い結果を捨てる → このクラス
/// - 実際の経路検索 → RouteSearching(本番は MapKit)
/// - 選んだ移動手段や所要時間の保存 → TripStore
@MainActor
@Observable
final class RouteMapViewModel {
    let tripID: UUID
    /// 区間ごとの検索の状態(キャッシュ)
    private(set) var states: [RouteCacheKey: RouteState] = [:]

    private let service: any RouteSearching
    /// 区間ごとに、いちばん新しい検索の番号。これと違う番号の結果は、古い検索の結果として捨てる
    @ObservationIgnored private var latestRequest: [RouteCacheKey: UUID] = [:]

    init(tripID: UUID, service: any RouteSearching = MapKitRouteService()) {
        self.tripID = tripID
        self.service = service
    }

    // MARK: 状態を読む

    /// その区間で選ばれている移動手段(未選択は nil)
    func chosenMode(_ leg: RouteLeg, store: TripStore) -> TravelMode? {
        store.trip(tripID)?.travelLeg(from: leg.from.id, to: leg.to.id)?.travelMode
    }

    /// その区間の、いま選ばれている移動手段での検索の状態
    func state(for leg: RouteLeg, mode: TravelMode?) -> RouteState? {
        guard let mode else { return nil }
        return states[leg.cacheKey(mode)]
    }

    /// 移動手段を選んだのに、まだ結果が届いていない区間がある
    func isLoading(_ legs: [RouteLeg], store: TripStore) -> Bool {
        legs.contains { leg in
            guard let mode = chosenMode(leg, store: store) else { return false }
            switch states[leg.cacheKey(mode)] {
            case nil, .loading?: return true
            default: return false
            }
        }
    }

    /// 結果が届いている区間の結果
    func loadedResults(_ legs: [RouteLeg], store: TripStore) -> [RouteResult] {
        legs.compactMap { leg in
            state(for: leg, mode: chosenMode(leg, store: store))?.result
        }
    }

    // MARK: 検索する

    /// 移動手段が選ばれている区間の経路を調べる。
    /// - 結果が届いている区間は、キャッシュを使う(もう一度検索しない)
    /// - 通信エラーだった区間は、もう一度調べる。経路が見つからなかった区間は調べ直さない
    /// - 検索を取り消したときや、途中で移動手段が変わったときの結果は、旅程に保存しない
    func load(_ legs: [RouteLeg], store: TripStore) async {
        var pending: [(leg: RouteLeg, mode: TravelMode, key: RouteCacheKey, request: UUID)] = []
        for leg in legs {
            guard let mode = chosenMode(leg, store: store) else { continue }
            let key = leg.cacheKey(mode)
            switch states[key] {
            case .loaded(let result)?:
                syncStored(leg, mode, result, store: store)
            case .failed(.notFound)?:
                continue
            case nil, .loading?, .failed(.network)?:
                let request = UUID()
                latestRequest[key] = request
                states[key] = .loading
                pending.append((leg, mode, key, request))
            }
        }
        guard !pending.isEmpty else { return }

        let service = self.service
        await withTaskGroup(of: (Int, Outcome).self) { group in
            for (index, item) in pending.enumerated() {
                let from = item.leg.from.spot
                let to = item.leg.to.spot
                let mode = item.mode
                group.addTask {
                    do {
                        return (index, .success(try await service.route(from: from, to: to, mode: mode)))
                    } catch is CancellationError {
                        return (index, .cancelled)
                    } catch let error as RouteError {
                        return (index, .failure(error))
                    } catch {
                        return (index, .failure(.network))
                    }
                }
            }
            for await (index, outcome) in group {
                let item = pending[index]
                // 同じ区間で新しい検索が始まっていたら、この結果は古いので捨てる
                guard latestRequest[item.key] == item.request else { continue }
                switch outcome {
                case .cancelled:
                    // 取り消した検索は、失敗として記録しない(次に表示したときに、もう一度調べる)
                    states[item.key] = nil
                    latestRequest[item.key] = nil
                case .failure(let error):
                    states[item.key] = .failed(error)
                case .success(let result):
                    states[item.key] = .loaded(result)
                    // 途中で移動手段が変わっていたら、旅程には保存しない(結果はキャッシュに残す)
                    if chosenMode(item.leg, store: store) == item.mode {
                        syncStored(item.leg, item.mode, result, store: store)
                    }
                }
            }
        }
    }

    /// 通信エラーだった区間を、もう一度調べる
    func retry(_ leg: RouteLeg, store: TripStore) async {
        guard let mode = chosenMode(leg, store: store),
              states[leg.cacheKey(mode)]?.error == .network else { return }
        await load([leg], store: store)
    }

    // MARK: 移動手段を変える

    /// 区間の移動手段を選ぶ(同じものをもう一度選ぶと解除)
    func choose(_ mode: TravelMode, for leg: RouteLeg, store: TripStore) {
        let next = chosenMode(leg, store: store) == mode ? nil : mode
        if let next { clearFailure(leg.cacheKey(next)) }
        store.setTravelMode(next, from: leg.from.id, to: leg.to.id, in: tripID)
    }

    /// 表示中のすべての区間を、同じ移動手段にする(nil で解除)
    func setAll(_ mode: TravelMode?, legs: [RouteLeg], store: TripStore) {
        for leg in legs {
            if let mode, chosenMode(leg, store: store) == mode { continue }
            if let mode { clearFailure(leg.cacheKey(mode)) }
            store.setTravelMode(mode, from: leg.from.id, to: leg.to.id, in: tripID)
        }
    }

    // MARK: 内部の処理

    private enum Outcome: Sendable {
        case success(RouteResult)
        case failure(RouteError)
        case cancelled
    }

    /// 選び直したときは、前の失敗を忘れて調べ直す
    private func clearFailure(_ key: RouteCacheKey) {
        if states[key]?.error != nil { states[key] = nil }
    }

    /// 検索で分かった所要時間と距離を、旅程に保存する(旅程の予定の間に表示される)
    private func syncStored(_ leg: RouteLeg, _ mode: TravelMode, _ result: RouteResult, store: TripStore) {
        guard let stored = store.trip(tripID)?.travelLeg(from: leg.from.id, to: leg.to.id),
              stored.mode == mode.rawValue,
              stored.seconds != result.time || stored.meters != result.distance else { return }
        store.setTravelResult(seconds: result.time, meters: result.distance, from: leg.from.id, to: leg.to.id, in: tripID)
    }
}
