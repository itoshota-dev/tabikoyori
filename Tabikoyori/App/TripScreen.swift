import SwiftUI

// MARK: - 画面の行き先(ホーム・旅程タブの画面の移動に使う)

/// 旅行の画面から移動する先。値で移動するので、ホームボタンを押したときに、どこまで戻るかを決められる
enum TripScreen: Hashable {
    case trip(UUID)
    case map(UUID)
    case money(UUID)
    case packing(UUID)
    case settings
    /// 思い出の詳細(旅行の id, 思い出の id)
    case memory(UUID, UUID)

    /// 移動先の画面。画面はメインスレッドで作るので MainActor にする
    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .trip(let id): TripDetailView(tripID: id)
        case .map(let id): TripMapView(tripID: id)
        case .money(let id): TripMoneyView(tripID: id)
        case .packing(let id): TripPackingView(tripID: id)
        case .settings: SettingsView()
        case .memory(let tripID, let memoryID): MemoryDetailView(tripID: tripID, memoryID: memoryID)
        }
    }
}
