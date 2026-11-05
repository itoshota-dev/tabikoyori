import Observation
import Foundation

/// ホームタブの画面の状態(どの旅行を開いているか、どこまで画面を重ねているか)。
/// 保存するデータではなく画面の状態なので、TripStore とは分けて持つ
@MainActor
@Observable
final class HomeNavigation {
    /// 開いている旅行(nil のときは旅行の一覧)
    var openTripID: UUID?
    /// 旅程の上に重ねて開いている画面の数(地図・持ち物・お金・設定など)
    var pathDepth = 0
    /// 旅程からスポットの詳細を開いているか
    var isSpotDetailOpen = false

    /// ホームボタンをもう一度押したときに、旅行の一覧へ戻るか。
    /// 旅程の画面にいるときだけ戻る(上に重ねた画面があるときは、iOS が旅程まで戻すのにまかせる)
    var shouldReturnToTripList: Bool {
        pathDepth == 0 && !isSpotDetailOpen && openTripID != nil
    }
}
