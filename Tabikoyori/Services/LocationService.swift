import Foundation
import CoreLocation

/// 位置情報の許可を求める係。CLLocationManager はメインスレッドで使うので、MainActor にする
@MainActor
final class LocationService {
    static let shared = LocationService()
    private let manager = CLLocationManager()

    func requestAuthorization() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }
}
