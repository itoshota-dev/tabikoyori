import SwiftUI

/// アプリの入り口。データと画面の状態を用意して、すべての画面に渡す
@main
struct TabikoyoriApp: App {
    @State private var store = TripStore()
    @State private var homeNavigation = HomeNavigation()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                // 保存・読み込みに失敗したときのお知らせ(store を受け取れるよう、environment より前に付ける)
                .storageProblemAlert()
                .environment(store)
                .environment(homeNavigation)
                .tint(Theme.accent)
                .preferredColorScheme(.light)
                // 入力欄以外をタップしたら、キーボードを閉じる(アプリ内のすべての入力欄に効く)
                .onAppear { KeyboardDismisser.shared.install() }
                // スクロールしてもキーボードは閉じない(閉じるのは、入力欄以外をタップしたときだけ)
                .scrollDismissesKeyboard(.never)
        }
    }
}
