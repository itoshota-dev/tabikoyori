import MapKit

// MARK: - Apple マップアプリで開く

/// スポットを Apple マップの場所に変換したり、Apple マップアプリで経路を開いたりする
enum AppleMapsLauncher {
    /// 「Apple マップで開く」ボタンのマーク(SF Symbols の名前)
    static let symbolName = "arrow.up.forward.app"

    /// スポットを、Apple マップで使える場所(MKMapItem)に変換する
    static func mapItem(for spot: Spot) -> MKMapItem {
        let item = MKMapItem(
            location: CLLocation(latitude: spot.coordinate.latitude, longitude: spot.coordinate.longitude),
            address: nil
        )
        item.name = spot.name
        return item
    }

    /// Apple マップアプリで、2つのスポットの間の経路を開く
    @MainActor
    static func openDirections(from: Spot, to: Spot, mode: TravelMode) {
        MKMapItem.openMaps(
            with: [mapItem(for: from), mapItem(for: to)],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: mode.launchMode]
        )
    }
}
