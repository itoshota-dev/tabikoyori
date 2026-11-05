import Foundation
import CoreLocation
import MapKit

// MARK: - 地図ユーティリティ

/// 地図に表示する範囲の計算
enum MapFit {
    static func region(for coords: [Coordinate], fallback: MKCoordinateRegion) -> MKCoordinateRegion {
        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return fallback
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let latDelta = max((maxLat - minLat) * 1.6, 0.02)
        let lonDelta = max((maxLon - minLon) * 1.6, 0.02)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }
}
