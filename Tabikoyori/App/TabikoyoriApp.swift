import SwiftUI

/// アプリの入り口。データと画面の状態を用意して、すべての画面に渡す
@main
struct TabikoyoriApp: App {
    @State private var store = TabikoyoriApp.makeStore()
    @State private var homeNavigation = HomeNavigation()

    /// ふだんは端末のファイルに保存する。
    /// UI テストのとき(起動時に -ui-testing が渡されたとき)は、端末のデータに触れないよう、空のメモリの保存先で始める
    private static func makeStore() -> TripStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            return TripStore(repository: InMemoryTripRepository(), deletePhotos: { _ in })
        }
        #endif
        
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-sample-data") {
            let store = TripStore()
            SampleData.importIfNeeded(into: store)
            return store
        }
        #endif
        
        return TripStore()
    }

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
