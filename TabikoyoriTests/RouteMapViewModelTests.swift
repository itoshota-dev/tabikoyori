import Foundation
import Testing
@testable import Tabikoyori

// MARK: - テスト用の道具

private func makeSpot(_ name: String, _ lat: Double, _ lon: Double) -> Spot {
    Spot(
        id: name, name: name, category: .cafe, area: "", address: "",
        region: .kyoto, coordinate: Coordinate(lat, lon), art: .cafe
    )
}

/// 1回目は通信エラー、2回目からは成功する経路検索(再試行を確かめるため)
private final class FlakyRouteService: RouteSearching, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    let result: RouteResult

    init(result: RouteResult) { self.result = result }

    var callCount: Int { lock.withLock { count } }

    func route(from: Spot, to: Spot, mode: TravelMode) async throws -> RouteResult {
        let n = lock.withLock { () -> Int in
            count += 1
            return count
        }
        if n == 1 { throw RouteError.network }
        return result
    }
}

/// 2つの予定(清水寺 → 八坂神社)がある1日の旅行と、その ViewModel
@MainActor
private struct Fixture {
    let store: TripStore
    let viewModel: RouteMapViewModel
    let tripID: UUID
    let legs: [RouteLeg]

    init(mode: TravelMode?, service: any RouteSearching) {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9))!
        var trip = Trip(title: "京都の旅", region: .kyoto, startDate: start, endDate: start)
        let a = ItineraryItem(spot: makeSpot("清水寺", 34.9949, 135.7850), day: 0, minutes: 600)
        let b = ItineraryItem(spot: makeSpot("八坂神社", 35.0037, 135.7788), day: 0, minutes: 720)
        trip.items = [a, b]
        if let mode {
            trip.travel = [TravelLeg(fromItem: a.id, toItem: b.id, mode: mode.rawValue)]
        }
        let snapshot = TripSnapshot(trips: [trip], bookmarks: [], userName: "旅人", savedSpots: nil, customTemplates: [], bookmarkDates: nil)
        store = TripStore(repository: InMemoryTripRepository(stored: snapshot), deletePhotos: { _ in })
        tripID = trip.id
        viewModel = RouteMapViewModel(tripID: trip.id, service: service)
        legs = RouteLeg.legs(in: store.trip(trip.id)!, dayFilter: 0)
    }

    var leg: RouteLeg { legs[0] }

    /// 旅程に保存されている、この区間の移動
    var storedTravel: TravelLeg? {
        store.trip(tripID)?.travelLeg(from: leg.from.id, to: leg.to.id)
    }
}

/// 経路検索が呼ばれるまで待つ(別の処理を走らせたまま、途中の状態を作るため)。
/// テストと同じメインスレッドで動かすので、条件のクロージャを別のスレッドへ渡さずに済む
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<1000 where !condition() {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(1))
    }
}

// MARK: - 区間の作り方

@Suite("経路マップの区間(RouteLeg)")
struct RouteLegTests {

    @Test("同じスポットが続くところは、区間にしない")
    func skipsSameSpot() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9))!
        var trip = Trip(title: "t", region: .kyoto, startDate: start, endDate: start)
        let cafe = makeSpot("カフェ", 35.0, 135.7)
        trip.items = [
            ItineraryItem(spot: cafe, day: 0, minutes: 600),
            ItineraryItem(spot: cafe, day: 0, minutes: 700),
            ItineraryItem(spot: makeSpot("寺", 35.1, 135.8), day: 0, minutes: 800)
        ]
        #expect(RouteLeg.legs(in: trip, dayFilter: 0).count == 1)
    }

    @Test("出発・到着の場所が変わると、キャッシュのキーも変わる")
    func cacheKeyIncludesCoordinates() {
        let a = ItineraryItem(spot: makeSpot("A", 35.0, 135.7), day: 0, minutes: 600)
        var b = ItineraryItem(spot: makeSpot("B", 35.1, 135.8), day: 0, minutes: 700)
        let before = RouteLeg(from: a, to: b, day: 0).cacheKey(.walk)
        b.spot.coordinate = Coordinate(35.2, 135.9)
        let after = RouteLeg(from: a, to: b, day: 0).cacheKey(.walk)
        #expect(before != after)
    }
}

// MARK: - 経路マップの ViewModel

@MainActor
@Suite("経路マップの ViewModel(RouteMapViewModel)")
struct RouteMapViewModelTests {

    @Test("結果が届くと、旅程に所要時間と距離が保存される")
    func savesResultToTrip() async {
        let service = MockRouteService(responses: [.walk: .success(.sample(minutes: 12, meters: 900))])
        let f = Fixture(mode: .walk, service: service)

        await f.viewModel.load(f.legs, store: f.store)

        let expectedTime: TimeInterval = 12 * 60
        let expectedDistance: Double = 900
        #expect(f.viewModel.state(for: f.leg, mode: .walk)?.result?.time == expectedTime)
        #expect(f.storedTravel?.seconds == expectedTime)
        #expect(f.storedTravel?.meters == expectedDistance)
        #expect(!f.viewModel.isLoading(f.legs, store: f.store))
    }

    @Test("一度調べた区間はキャッシュを使い、もう一度検索しない")
    func usesCache() async {
        let service = MockRouteService(responses: [.walk: .success(.sample(minutes: 12))])
        let f = Fixture(mode: .walk, service: service)

        await f.viewModel.load(f.legs, store: f.store)
        await f.viewModel.load(f.legs, store: f.store)

        #expect(service.calls == [.walk])
    }

    @Test("移動手段を変えると、新しい手段で検索して保存する")
    func changingModeSearchesAgain() async {
        let service = MockRouteService(responses: [
            .walk: .success(.sample(minutes: 30)),
            .car: .success(.sample(minutes: 8))
        ])
        let f = Fixture(mode: .walk, service: service)

        await f.viewModel.load(f.legs, store: f.store)
        f.viewModel.choose(.car, for: f.leg, store: f.store)
        await f.viewModel.load(f.legs, store: f.store)

        let carTime: TimeInterval = 8 * 60
        #expect(service.calls == [.walk, .car])
        #expect(f.storedTravel?.mode == TravelMode.car.rawValue)
        #expect(f.storedTravel?.seconds == carTime)
    }

    @Test("同じ移動手段をもう一度選ぶと、選択を解除する")
    func chooseSameModeClears() {
        let service = MockRouteService(responses: [:])
        let f = Fixture(mode: .walk, service: service)
        f.viewModel.choose(.walk, for: f.leg, store: f.store)
        #expect(f.storedTravel == nil)
    }

    @Test("検索の途中で移動手段を変えたら、古い手段の結果は旅程に保存しない")
    func ignoresStaleResult() async {
        let service = MockRouteService(
            responses: [
                .walk: .success(.sample(minutes: 30)),
                .car: .success(.sample(minutes: 8))
            ],
            delays: [.walk: .milliseconds(300)]
        )
        let f = Fixture(mode: .walk, service: service)

        // 徒歩の検索を始める(取り消さずに、そのまま結果が届くようにする)
        let walkLoad = Task { await f.viewModel.load(f.legs, store: f.store) }
        await waitUntil { service.calls.contains(.walk) }

        // 徒歩の結果が届く前に、車に変えて検索する
        f.viewModel.choose(.car, for: f.leg, store: f.store)
        await f.viewModel.load(f.legs, store: f.store)
        // あとから徒歩の結果が届く
        await walkLoad.value

        let carTime: TimeInterval = 8 * 60
        #expect(f.storedTravel?.mode == TravelMode.car.rawValue)
        #expect(f.storedTravel?.seconds == carTime)
    }

    @Test("取り消した検索の結果は保存せず、失敗としても記録しない")
    func cancelledSearchIsNotRecorded() async {
        let service = MockRouteService(
            responses: [.walk: .success(.sample(minutes: 30))],
            delays: [.walk: .seconds(5)]
        )
        let f = Fixture(mode: .walk, service: service)

        let task = Task { await f.viewModel.load(f.legs, store: f.store) }
        await waitUntil { service.calls.contains(.walk) }
        task.cancel()
        await task.value

        #expect(f.viewModel.state(for: f.leg, mode: .walk) == nil)
        #expect(f.storedTravel?.seconds == nil)
    }

    @Test("経路が見つからなかった区間は、調べ直さない")
    func notFoundIsNotRetried() async {
        let service = MockRouteService(responses: [.car: .failure(.notFound)])
        let f = Fixture(mode: .car, service: service)

        await f.viewModel.load(f.legs, store: f.store)
        await f.viewModel.load(f.legs, store: f.store)

        #expect(service.calls == [.car])
        #expect(f.viewModel.state(for: f.leg, mode: .car)?.error == .notFound)
    }

    @Test("通信エラーの後、もう一度試すと成功する")
    func retryAfterNetworkError() async {
        let service = FlakyRouteService(result: .sample(minutes: 15))
        let f = Fixture(mode: .bike, service: service)

        await f.viewModel.load(f.legs, store: f.store)
        #expect(f.viewModel.state(for: f.leg, mode: .bike)?.error == .network)

        await f.viewModel.retry(f.leg, store: f.store)

        let expectedTime: TimeInterval = 15 * 60
        #expect(service.callCount == 2)
        #expect(f.viewModel.state(for: f.leg, mode: .bike)?.result?.time == expectedTime)
        #expect(f.storedTravel?.seconds == expectedTime)
    }

    @Test("場所が変わった区間は、調べ直す")
    func movedSpotSearchesAgain() async {
        let service = MockRouteService(responses: [.walk: .success(.sample(minutes: 12))])
        let f = Fixture(mode: .walk, service: service)

        await f.viewModel.load(f.legs, store: f.store)
        var moved = f.leg.to
        moved.spot.coordinate = Coordinate(35.02, 135.77)
        await f.viewModel.load([RouteLeg(from: f.leg.from, to: moved, day: 0)], store: f.store)

        #expect(service.calls == [.walk, .walk])
    }

    @Test("まとめて設定すると、すべての区間の移動手段が変わる")
    func setAllChangesEveryLeg() {
        let service = MockRouteService(responses: [:])
        let f = Fixture(mode: .walk, service: service)
        f.viewModel.setAll(.transit, legs: f.legs, store: f.store)
        #expect(f.storedTravel?.mode == TravelMode.transit.rawValue)
        f.viewModel.setAll(nil, legs: f.legs, store: f.store)
        #expect(f.storedTravel == nil)
    }
}
