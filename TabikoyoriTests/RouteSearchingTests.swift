import Foundation
import MapKit
import Testing
@testable import Tabikoyori


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

