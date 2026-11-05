import SwiftUI

// MARK: - 旅程タブ

/// 旅程タブ。選んでいる旅行の旅程を表示する(右上の飛行機アイコンで旅行を切り替えられる)
struct ItineraryTab: View {
    @Environment(TripStore.self) private var store

    var body: some View {
        if let id = store.activeTripID {
            NavigationStack {
                TripDetailView(tripID: id, showsSwitcher: true)
                    .navigationDestination(for: TripScreen.self) { $0.destination }
            }
            .id(id)
        } else {
            ContentUnavailableView(
                "旅行がありません",
                systemImage: "airplane",
                description: Text("ホームから新しい旅を作成してください。")
            )
        }
    }
}

// MARK: - 経路タブ

/// 下のメニューの「経路」。旅程の右上の地図アイコンから開く画面と同じで、
/// 左上の飛行機アイコンから旅行を切り替えられる
struct RouteTab: View {
    @Environment(TripStore.self) private var store

    var body: some View {
        NavigationStack {
            if let id = store.activeTripID {
                TripMapView(tripID: id, switcher: true)
                    .id(id)
            } else {
                ContentUnavailableView(
                    "旅行がありません",
                    systemImage: "airplane",
                    description: Text("ホームから新しい旅を作成してください。")
                )
            }
        }
    }
}
