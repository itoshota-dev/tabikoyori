import MapKit

// MARK: - 経路の移動手段

/// 予定と予定の間の移動手段
enum TravelMode: String, CaseIterable, Identifiable, Codable {
    case car, walk, bike, transit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .car: return "車"
        case .walk: return "徒歩"
        case .bike: return "自転車"
        case .transit: return "電車・バス"
        }
    }

    var symbol: String {
        switch self {
        case .car: return "car.fill"
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        case .transit: return "tram.fill"
        }
    }

    var transportType: MKDirectionsTransportType {
        switch self {
        case .car: return .automobile
        case .walk: return .walking
        case .bike: return .cycling
        case .transit: return .transit
        }
    }

    /// Apple マップを開くときの移動手段
    var launchMode: String {
        switch self {
        case .car: return MKLaunchOptionsDirectionsModeDriving
        case .walk: return MKLaunchOptionsDirectionsModeWalking
        case .bike: return MKLaunchOptionsDirectionsModeDefault
        case .transit: return MKLaunchOptionsDirectionsModeTransit
        }
    }
}
