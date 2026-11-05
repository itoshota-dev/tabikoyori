import SwiftUI

// MARK: - 地図の読み込み待ち

/// 地図を最初に作るときは、数秒かかって画面が固まることがある。
/// 先に「読み込み中」を表示してから地図を作るので、固まったように見えず、何を待っているのか分かる。
/// 2回目以降(同じ起動中)は、すぐに地図を出す。
enum MapWarmup {
    nonisolated(unsafe) static var done = false
}

/// 地図の準備ができるまで「読み込み中」を表示し、できたら中身を出す
struct MapLoadingGate<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var ready = MapWarmup.done

    var body: some View {
        Group {
            if ready {
                content()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Theme.sandLight, Theme.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("マップを読み込んでいます…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Text("最初の1回は、少し時間がかかります")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subText)
                    }
                }
            }
        }
        .task {
            guard !ready else { return }
            // 画面が切り替わるアニメーションが終わって、「読み込み中」がきちんと表示されてから地図を作る
            // (アニメーションの途中で固まらないように、少し長めに待つ)
            try? await Task.sleep(for: .milliseconds(800))
            MapWarmup.done = true
            ready = true
        }
    }
}
