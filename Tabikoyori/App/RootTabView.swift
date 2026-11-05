import SwiftUI

/// 下のタブ
enum AppTab: Hashable {
    case home, search, plan, route, memories
}

/// アプリの一番外側の画面(下のタブと、各タブの画面)
struct RootTabView: View {
    @Environment(TripStore.self) private var store
    @Environment(HomeNavigation.self) private var homeNavigation
    @State private var selection: AppTab = .home

    /// カレンダーの週の始まり(設定で選ぶ。false: 日曜日 / true: 月曜日)
    @AppStorage("weekStartsMonday") private var weekStartsMonday = false

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = weekStartsMonday ? 2 : 1
        return cal
    }

    var body: some View {
        TabView(selection: Binding(
            get: { selection },
            set: { newValue in
                // いま開いているホームをもう一度押したとき:
                // - 旅程の上に地図・持ち物・お金などを開いているときは、iOS が旅程の画面まで戻す(ここでは何もしない)
                // - 旅程の画面にいるときは、旅行の一覧へ戻る
                if newValue == selection && newValue == .home, homeNavigation.shouldReturnToTripList {
                    withAnimation(.easeInOut(duration: 0.28)) { homeNavigation.openTripID = nil }
                }
                selection = newValue
            }
        )) {
            Tab("ホーム", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("見つける", systemImage: "magnifyingglass", value: AppTab.search) {
                SpotSearchView()
            }
            Tab("旅程", systemImage: "calendar", value: AppTab.plan) {
                ItineraryTab()
            }
            Tab("経路", systemImage: "map", value: AppTab.route) {
                RouteTab()
            }
            Tab("コレクション", systemImage: "photo.on.rectangle.angled", value: AppTab.memories) {
                MemoriesView()
            }
        }
        .tint(Theme.accent)
        // アプリ内のカレンダー(日付の選択)の週の始まりを、設定に合わせる
        .environment(\.calendar, calendar)
        // 画面の下の方から開くメニューでも、上から書いた順(1日目が先頭など)に並べる
        .menuOrder(.fixed)
    }
}
