import Foundation

// MARK: - 為替レート

/// 外貨1単位が何円か。date はレートの日付(土日・祝日は、前の営業日になることがある)
struct ExchangeRate: Codable, Hashable, Sendable {
    let rate: Decimal
    let date: String?
}

/// レートを取るときのエラー。画面に出す文言も持つ
enum ExchangeRateError: Error, Equatable {
    case network
    case notFound
    case rateLimited
    case server(Int)
    case invalidResponse

    var message: String {
        switch self {
        case .network: return "通信できませんでした"
        case .notFound: return "この通貨のレートが見つかりませんでした"
        case .rateLimited: return "混み合っています。しばらくしてからお試しください"
        case .server, .invalidResponse: return "レートを取得できませんでした"
        }
    }
}

/// レートを取る係の約束。本番は Frankfurter、テストでは偽物に差し替える
protocol ExchangeRateProviding: Sendable {
    /// 支出日のレート(外貨1単位が何円か)を返す
    func rate(for currency: String, on date: Date) async throws -> ExchangeRate
}

/// アプリ全体で使う、レートを取る係(保存つきの Frankfurter)
enum ExchangeRates {
    static let shared: any ExchangeRateProviding = CachedExchangeRateService(wrapping: FrankfurterRateService())
}

// MARK: - 日付

/// レートの日付の扱い
enum RateDay {
    /// 例:"2026-11-05"
    static func string(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// 今日より後の日付か(まだレートがないので、最新のレートを使う)
    static func isFuture(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }

    /// 今日より前の日付か(レートはもう変わらない)
    static func isPast(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Frankfurter

/// 本番用。Frankfurter(https://frankfurter.dev)からレートを取る。API キーは不要。
/// 外に送る情報は、通貨のコードと日付だけ(金額や旅行の内容は送らない)
struct FrankfurterRateService: ExchangeRateProviding {
    var session: URLSession = .shared
    var baseURL = URL(string: "https://api.frankfurter.dev/v2")!

    func rate(for currency: String, on date: Date) async throws -> ExchangeRate {
        let request = makeRequest(currency: currency, date: date)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            // 通貨や日付を変えて、問い合わせを取り消した
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ExchangeRateError.network
        }
        guard let http = response as? HTTPURLResponse else { throw ExchangeRateError.invalidResponse }
        return try Self.decode(data, statusCode: http.statusCode)
    }

    /// 例:https://api.frankfurter.dev/v2/rate/eur/jpy?date=2026-11-05
    /// 今日より後の日付は、まだレートがないので、日付を付けずに最新のレートを取る
    func makeRequest(currency: String, date: Date) -> URLRequest {
        var components = URLComponents(
            url: baseURL.appending(path: "rate/\(currency.lowercased())/jpy"),
            resolvingAgainstBaseURL: false
        )!
        if !RateDay.isFuture(date) {
            components.queryItems = [URLQueryItem(name: "date", value: RateDay.string(for: date))]
        }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// サーバーの返事を、レートかエラーに変える(通信しないでテストできるように、分けておく)
    static func decode(_ data: Data, statusCode: Int) throws -> ExchangeRate {
        switch statusCode {
        case 200: break
        case 404, 422: throw ExchangeRateError.notFound
        case 429: throw ExchangeRateError.rateLimited
        default: throw ExchangeRateError.server(statusCode)
        }
        struct Body: Decodable {
            let rate: Decimal
            let date: String?
        }
        guard let body = try? JSONDecoder().decode(Body.self, from: data), body.rate > 0 else {
            throw ExchangeRateError.invalidResponse
        }
        return ExchangeRate(rate: body.rate, date: body.date)
    }
}

// MARK: - 保存して使い回す

/// 取ったレートを端末に保存して使い回す係。ほかの係(本番は Frankfurter)を包んで使う。
/// 過去の日付のレートは変わらないので、ずっと使い回す。今日と未来の日付は、6時間たったら取り直す
actor CachedExchangeRateService: ExchangeRateProviding {
    struct Entry: Codable, Sendable {
        let rate: ExchangeRate
        let fetchedAt: Date
    }

    private let base: any ExchangeRateProviding
    private let fileURL: URL?
    private var entries: [String: Entry]
    private let refreshInterval: TimeInterval = 6 * 60 * 60

    /// fileURL が nil のときは、ファイルに保存せずメモリの中だけで使う(テスト用)
    init(wrapping base: any ExchangeRateProviding, fileURL: URL? = CachedExchangeRateService.defaultFileURL) {
        self.base = base
        self.fileURL = fileURL
        if let fileURL,
           let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = saved
        } else {
            entries = [:]
        }
    }

    /// アプリの Application Support フォルダの exchange-rates.json
    static var defaultFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("exchange-rates.json")
    }

    func rate(for currency: String, on date: Date) async throws -> ExchangeRate {
        let key = Self.key(currency: currency, date: date)
        if let entry = entries[key], isFresh(entry, for: date) {
            return entry.rate
        }
        let fresh = try await base.rate(for: currency, on: date)
        entries[key] = Entry(rate: fresh, fetchedAt: Date())
        save()
        return fresh
    }

    /// 例:"EUR-2026-11-05"。未来の日付は最新のレートを使うので "EUR-latest"
    static func key(currency: String, date: Date) -> String {
        "\(currency.uppercased())-\(RateDay.isFuture(date) ? "latest" : RateDay.string(for: date))"
    }

    private func isFresh(_ entry: Entry, for date: Date) -> Bool {
        RateDay.isPast(date) || Date().timeIntervalSince(entry.fetchedAt) < refreshInterval
    }

    private func save() {
        guard let fileURL, let data = try? JSONEncoder().encode(entries) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
