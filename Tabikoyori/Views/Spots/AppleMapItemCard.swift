import SwiftUI
import MapKit

/// Apple マップの「詳細カード」(営業時間・電話番号・ウェブサイト・住所など、Apple がアプリ向けに公開している場所情報)をそのまま表示する。
/// カードの中身(下の「経路を検索」「"マップ"で開く」ボタンを含む)は Apple が作るので、アプリ側では変えない。
/// Maps アプリにある写真・口コミ・評価は、アプリ向けには公開されていないため、このカードには含まれない場合がある。
struct AppleMapItemCard: UIViewControllerRepresentable {
    let mapItem: MKMapItem
    var displaysMap: Bool = false
    /// カードの閉じるボタン(×)を押したときの処理
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> MKMapItemDetailViewController {
        let controller = MKMapItemDetailViewController(mapItem: mapItem, displaysMap: displaysMap)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MKMapItemDetailViewController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    /// カードの閉じるボタン(×)が押されたことを受け取る
    @MainActor
    final class Coordinator: NSObject, MKMapItemDetailViewControllerDelegate {
        var onFinish: () -> Void

        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func mapItemDetailViewControllerDidFinish(_ detailViewController: MKMapItemDetailViewController) {
            onFinish()
        }
    }
}
