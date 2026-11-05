import Foundation
import MapKit
import Testing
@testable import Tabikoyori

private func makeSpot(_ name: String, _ lat: Double, _ lon: Double) -> Spot {
    Spot(
        id: name, name: name, category: .cafe, area: "", address: "",
        region: .kyoto, coordinate: Coordinate(lat, lon), art: .cafe
    )
}

private let kiyomizu = makeSpot("清水寺", 34.9949, 135.7850)
private let yasaka = makeSpot("八坂神社", 35.0037, 135.7788)

// MARK: - MapKit のエラーの分け方

@Suite("経路検索のエラーの分け方(MapKitRouteService)")
struct RouteErrorMappingTests {

    @Test("経路が見つからないエラーは notFound")
    func directionsNotFound() {
        #expect(MapKitRouteService.routeError(for: MKError(.directionsNotFound)) as? RouteError == .notFound)
        #expect(MapKitRouteService.routeError(for: MKError(.placemarkNotFound)) as? RouteError == .notFound)
    }

    @Test("サーバーや通信のエラーは network(やり直せる)")
    func networkErrors() {
        #expect(MapKitRouteService.routeError(for: MKError(.serverFailure)) as? RouteError == .network)
        #expect(MapKitRouteService.routeError(for: MKError(.loadingThrottled)) as? RouteError == .network)
        #expect(MapKitRouteService.routeError(for: URLError(.notConnectedToInternet)) as? RouteError == .network)
    }

    @Test("取り消しは、失敗ではなく取り消しのまま返す")
    func cancellation() {
        #expect(MapKitRouteService.routeError(for: CancellationError()) is CancellationError)
        #expect(MapKitRouteService.routeError(for: URLError(.cancelled)) is CancellationError)
    }

    @Test("すでに分けたエラーは、そのまま返す")
    func alreadyRouteError() {
        #expect(MapKitRouteService.routeError(for: RouteError.notFound) as? RouteError == .notFound)
    }

    @Test("経路の線から、すべての座標を順番どおりに取り出す")
    func polylineCoordinates() {
        let points = [
            CLLocationCoordinate2D(latitude: 34.99, longitude: 135.78),
            CLLocationCoordinate2D(latitude: 35.00, longitude: 135.77),
            CLLocationCoordinate2D(latitude: 35.01, longitude: 135.76)
        ]
        let polyline = MKPolyline(coordinates: points, count: points.count)
        let coords = MapKitRouteService.coordinates(of: polyline)
        // MKPolyline は内部で座標を地図上の点に変換して持つので、取り出すとごくわずかな誤差が出る。
        // そのため「完全に同じ」ではなく「誤差が十分小さい」ことを確かめる
        #expect(coords.count == points.count)
        for (c, p) in zip(coords, points) {
            #expect(abs(c.latitude - p.latitude) < 1e-9)
            #expect(abs(c.longitude - p.longitude) < 1e-9)
        }
    }
}

// MARK: - 経路検索の決まり(テスト用の偽物で確かめる)

@Suite("経路検索の決まり(RouteSearching)")
struct RouteSearchingContractTests {

    @Test("成功すると、所要時間と距離が返る")
    func success() async throws {
        let service = MockRouteService(responses: [.walk: .success(.sample(minutes: 12, meters: 900))])
        let result = try await service.route(from: kiyomizu, to: yasaka, mode: .walk)
        // 型をはっきりさせる(「12 * 60」のままだと、比べる相手の型が意図どおりに決まらない)
        let expectedTime: TimeInterval = 12 * 60
        let expectedDistance: CLLocationDistance = 900
        #expect(result.time == expectedTime)
        #expect(result.distance == expectedDistance)
    }

    @Test("経路が見つからないときは notFound を投げる")
    func notFound() async {
        let service = MockRouteService(responses: [.car: .failure(.notFound)])
        await #expect(throws: RouteError.notFound) {
            try await service.route(from: kiyomizu, to: yasaka, mode: .car)
        }
    }

    @Test("通信エラーのときは network を投げる")
    func network() async {
        let service = MockRouteService(responses: [.car: .failure(.network)])
        await #expect(throws: RouteError.network) {
            try await service.route(from: kiyomizu, to: yasaka, mode: .car)
        }
    }

    @Test("検索を取り消すと、結果を返さず CancellationError になる")
    func cancel() async {
        let service = MockRouteService(
            responses: [.walk: .success(.sample(minutes: 12))],
            delays: [.walk: .seconds(5)]
        )
        let task = Task { try await service.route(from: kiyomizu, to: yasaka, mode: .walk) }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
