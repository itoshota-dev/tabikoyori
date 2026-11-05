import Foundation
import Testing
@testable import Tabikoyori

/// 呼ばれた回数を数える、テスト用のレートの係(通信しない)
private final class CountingRateService: ExchangeRateProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var callCount: Int { lock.withLock { count } }

    func rate(for currency: String, on date: Date) async throws -> ExchangeRate {
        lock.withLock { count += 1 }
        return ExchangeRate(rate: Decimal(string: "162.45")!, date: "2026-11-04")
    }
}

@Suite("為替レートの取得(Frankfurter)")
struct FrankfurterRateServiceTests {

    @Test("返事から、レートと日付を読み取る")
    func decodesRate() throws {
        let json = #"{"date":"2026-11-04","base":"EUR","quote":"JPY","rate":162.45}"#
        let result = try FrankfurterRateService.decode(Data(json.utf8), statusCode: 200)
        #expect(result.rate == Decimal(string: "162.45"))
        #expect(result.date == "2026-11-04")
    }

    @Test("サーバーのエラーを、わかりやすいエラーに変える")
    func mapsErrors() {
        let empty = Data()
        #expect(throws: ExchangeRateError.notFound) { try FrankfurterRateService.decode(empty, statusCode: 404) }
        #expect(throws: ExchangeRateError.rateLimited) { try FrankfurterRateService.decode(empty, statusCode: 429) }
        #expect(throws: ExchangeRateError.server(500)) { try FrankfurterRateService.decode(empty, statusCode: 500) }
        #expect(throws: ExchangeRateError.invalidResponse) { try FrankfurterRateService.decode(Data("oops".utf8), statusCode: 200) }
    }

    @Test("過去の日付は日付つき、未来の日付は日付なし(最新)で問い合わせる")
    func buildsRequest() throws {
        let service = FrankfurterRateService()
        let past = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        let future = Date().addingTimeInterval(30 * 24 * 60 * 60)

        let pastURL = try #require(service.makeRequest(currency: "EUR", date: past).url?.absoluteString)
        #expect(pastURL.contains("/v2/rate/eur/jpy"))
        #expect(pastURL.contains("date=\(RateDay.string(for: past))"))

        let futureURL = try #require(service.makeRequest(currency: "EUR", date: future).url?.absoluteString)
        #expect(!futureURL.contains("date="))
    }
}

@Suite("為替レートの保存(CachedExchangeRateService)")
struct CachedExchangeRateServiceTests {

    @Test("一度取った日付のレートは、もう問い合わせない")
    func usesCache() async throws {
        let base = CountingRateService()
        let cache = CachedExchangeRateService(wrapping: base, fileURL: nil)
        let past = Date().addingTimeInterval(-3 * 24 * 60 * 60)

        _ = try await cache.rate(for: "EUR", on: past)
        _ = try await cache.rate(for: "EUR", on: past)
        #expect(base.callCount == 1)

        // 通貨が違えば、別に問い合わせる
        _ = try await cache.rate(for: "USD", on: past)
        #expect(base.callCount == 2)
    }
}
