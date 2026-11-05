import MapKit
import CoreLocation

/// 2つのスポットの間の経路の検索結果
struct RouteResult {
    /// 道に沿った経路の座標(電車・バスのときは nil)
    var coords: [CLLocationCoordinate2D]?
    var time: TimeInterval?
    var distance: CLLocationDistance?
    // 失敗はここでは持たない(経路検索の係がエラーで返し、画面の状態は RouteState で表す)
}

// MARK: - 経路検索の決まり(プロトコル)

/// 経路検索で起きる問題
enum RouteError: Error, Equatable {
    /// 経路が見つからない(海を越えるなど)。同じ条件でやり直しても見つからない
    case notFound
    /// 通信エラーなど。時間をおいてやり直すと成功することがある
    case network
}

/// 2つの場所の間の経路を調べる係。
/// 本番では MapKit(MapKitRouteService)、テストでは決まった答えを返す偽物を使う
protocol RouteSearching: Sendable {
    /// - Throws: `RouteError`。検索を取り消したときは `CancellationError`
    func route(from: Spot, to: Spot, mode: TravelMode) async throws -> RouteResult
}

// MARK: - 本番用:Apple マップの経路検索(MKDirections)

/// 本番用の経路検索。Apple マップ(MKDirections)で調べる
struct MapKitRouteService: RouteSearching {
    func route(from: Spot, to: Spot, mode: TravelMode) async throws -> RouteResult {
        let request = MKDirections.Request()
        request.source = AppleMapsLauncher.mapItem(for: from)
        request.destination = AppleMapsLauncher.mapItem(for: to)
        request.transportType = mode.transportType
        let directions = MKDirections(request: request)
        do {
            if mode == .transit {
                // 電車・バスは、経路の線ではなく所要時間の目安だけが取得できる
                let eta = try await directions.calculateETA()
                return RouteResult(coords: nil, time: eta.expectedTravelTime, distance: eta.distance)
            }
            let response = try await directions.calculate()
            guard let route = response.routes.first else { throw RouteError.notFound }
            return RouteResult(
                coords: Self.coordinates(of: route.polyline),
                time: route.expectedTravelTime,
                distance: route.distance
            )
        } catch {
            throw Self.routeError(for: error)
        }
    }

    /// MapKit などのエラーを、アプリで扱うエラーに分ける(取り消しはそのまま返す)
    static func routeError(for error: Error) -> Error {
        if error is CancellationError || error is RouteError { return error }
        if let mk = error as? MKError {
            switch mk.code {
            case .directionsNotFound, .placemarkNotFound:
                return RouteError.notFound
            default:
                return RouteError.network
            }
        }
        if let url = error as? URLError, url.code == .cancelled {
            return CancellationError()
        }
        return RouteError.network
    }

    /// 経路の線の座標を取り出す
    static func coordinates(of polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        return coords
    }
}
