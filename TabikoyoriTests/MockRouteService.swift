import Foundation
@testable import Tabikoyori

/// テスト用の経路検索。MapKit や通信を使わず、決めた結果やエラーを返す。
/// - delay を決めると、その時間だけ待ってから返す(検索の途中で取り消したり、移動手段を変えたりする場面を作るため)
final class MockRouteService: RouteSearching, @unchecked Sendable {
    /// 移動手段ごとの答え(決めていない手段は「経路なし」)
    let responses: [TravelMode: Result<RouteResult, RouteError>]
    /// 移動手段ごとの待ち時間(決めていない手段は待たない)
    let delays: [TravelMode: Duration]

    private let lock = NSLock()
    private var recorded: [TravelMode] = []

    init(responses: [TravelMode: Result<RouteResult, RouteError>], delays: [TravelMode: Duration] = [:]) {
        self.responses = responses
        self.delays = delays
    }

    /// 呼ばれた順の移動手段
    var calls: [TravelMode] {
        lock.withLock { recorded }
    }

    func route(from: Spot, to: Spot, mode: TravelMode) async throws -> RouteResult {
        // async の関数の中では lock()/unlock() を直接使えないので、範囲を区切った withLock を使う
        lock.withLock { recorded.append(mode) }

        if let delay = delays[mode] {
            try await Task.sleep(for: delay)
        }
        try Task.checkCancellation()
        guard let response = responses[mode] else { throw RouteError.notFound }
        return try response.get()
    }
}

extension RouteResult {
    /// テスト用の、所要時間と距離だけの結果
    static func sample(minutes: Double, meters: Double = 1000) -> RouteResult {
        RouteResult(coords: nil, time: minutes * 60, distance: meters)
    }
}
