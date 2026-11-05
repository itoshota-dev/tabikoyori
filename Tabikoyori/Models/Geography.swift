import Foundation
import CoreLocation
import MapKit

// MARK: - 位置

/// 緯度・経度(保存できる形)
struct Coordinate: Codable, Hashable {
    var latitude: Double
    var longitude: Double

    init(_ latitude: Double, _ longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ c: CLLocationCoordinate2D) {
        self.latitude = c.latitude
        self.longitude = c.longitude
    }

    var cl: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// 旅行先の地域。地図の初期位置や表紙の絵柄に使う
enum Region: String, Codable, CaseIterable, Identifiable {
    case kyoto, okinawa, paris, italy

    var id: String { rawValue }

    var name: String {
        switch self {
        case .kyoto: return "京都"
        case .okinawa: return "沖縄"
        case .paris: return "パリ"
        case .italy: return "イタリア"
        }
    }

    var center: Coordinate {
        switch self {
        case .kyoto: return Coordinate(35.0116, 135.7681)
        case .okinawa: return Coordinate(26.45, 127.85)
        case .paris: return Coordinate(48.86, 2.30)
        case .italy: return Coordinate(43.0, 12.4)
        }
    }

    var spanDegrees: Double {
        switch self {
        case .kyoto: return 0.14
        case .okinawa: return 0.9
        case .paris: return 0.25
        case .italy: return 6.0
        }
    }

    var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center.cl,
            span: MKCoordinateSpan(latitudeDelta: spanDegrees, longitudeDelta: spanDegrees)
        )
    }

    /// 検索のヒントに使う、やや広めの範囲
    var searchRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center.cl,
            span: MKCoordinateSpan(latitudeDelta: spanDegrees * 2, longitudeDelta: spanDegrees * 2)
        )
    }

    /// 自由入力の行き先から、近い組み込み地域を探す(なければ nil)
    static func match(_ text: String) -> Region? {
        allCases.first { text.contains($0.name) }
    }

    /// 検索ワードに地域名(京都など)が含まれていれば、その地域の範囲を返す
    static func hint(for query: String) -> MKCoordinateRegion? {
        allCases.first { query.contains($0.name) }?.searchRegion
    }

    var coverStyle: ArtStyle {
        switch self {
        case .kyoto: return .street
        case .okinawa: return .sea
        case .paris: return .cathedral
        case .italy: return .ruins
        }
    }
}
