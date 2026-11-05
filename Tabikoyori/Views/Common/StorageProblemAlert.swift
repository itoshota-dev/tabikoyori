import SwiftUI

/// 保存・読み込みに失敗したときのお知らせ。
/// アプリのいちばん下の画面と、入力用のシート(保存に失敗しても閉じないもの)に付ける
struct StorageProblemAlert: ViewModifier {
    @Environment(TripStore.self) private var store

    func body(content: Content) -> some View {
        content.alert(
            store.storageProblem?.title ?? "",
            isPresented: Binding(
                get: { store.storageProblem != nil },
                set: { if !$0 { store.storageProblem = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.storageProblem?.message ?? "")
        }
    }
}

extension View {
    /// 保存・読み込みに失敗したときのお知らせを出せるようにする
    func storageProblemAlert() -> some View {
        modifier(StorageProblemAlert())
    }
}
