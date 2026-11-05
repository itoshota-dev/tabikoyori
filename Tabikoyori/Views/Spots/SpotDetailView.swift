import SwiftUI
import MapKit

/// スポットの詳細。上に操作ボタン(お気に入り・旅程に追加・Google/Appleマップ)、
/// その下に Apple マップの詳細カード(営業時間・電話番号・ウェブサイト・住所)を表示する。
struct SpotDetailContent: View {
    @Environment(TripStore.self) private var store

    let spot: Spot
    /// 旅程に追加する対象の旅行(指定がなければ追加時に選ぶ)
    var tripID: UUID? = nil
    /// 追加する日(指定すると「この日に追加」になる)
    var day: Int? = nil
    /// 詳細カードに地図を含めるか(シート表示のときは含めない)
    var showsMap: Bool = true
    var onClose: () -> Void = {}

    @State private var mapItem: MKMapItem?

    /// 大きいサイズのシートに収まる、詳細カードの高さ(画面の高さ − 上の余白とボタン行)
    private static var fullCardHeight: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let screen = scene?.screen.bounds.height ?? 850
        return max(500, screen - 140)
    }

    private var googleMapsURL: URL? {
        // 郵便番号などを除いた「名前 + 住所」で検索すると、1件に絞れやすい
        let q = "\(spot.name) \(spot.address.cleanedForMapSearch)".urlEncoded
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(q)")
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 8) {
                actionBar
                    .padding(.horizontal, 16)
                    .padding(.top, showsMap ? 12 : 30)

                Group {
                    if let mapItem {
                        AppleMapItemCard(mapItem: mapItem, displaysMap: showsMap, onFinish: onClose)
                            .id(spot.id)
                            // シート表示のときは、カードを全部見せられる高さで先に置いておく。
                            // 半分の状態では下半分がシートの外に隠れ、シートを引き上げると続きが見える
                            .frame(height: showsMap ? nil : Self.fullCardHeight)
                    } else {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Apple マップから読み込み中…")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.subText)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: showsMap ? .infinity : nil)
            }
            // 内容がシートより高くても、上(ボタン行)を基準にそろえる。はみ出した分はシートの外に隠れる
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .clipped()
        .background(Theme.background.ignoresSafeArea())
        .task(id: spot.id) {
            mapItem = nil
            let resolved = await MapItemResolver.shared.resolve(spot)
            mapItem = resolved.item
        }
    }

    // MARK: 操作ボタン

    private var actionBar: some View {
        HStack(spacing: 8) {
            favoriteButton
            addControl
            if let url = googleMapsURL {
                Link(destination: url) {
                    barLabel("Googleマップ", systemImage: nil, style: .outline)
                }
            }
            Button {
                if let mapItem {
                    _ = mapItem.openInMaps(launchOptions: nil)
                }
            } label: {
                barLabel("Appleマップ", systemImage: nil, style: .outline)
            }
            .disabled(mapItem == nil)
        }
    }

    private var favoriteButton: some View {
        let saved = store.bookmarks.contains(spot.id)
        return Button {
            store.toggleBookmark(spot)
        } label: {
            barLabel(nil, systemImage: saved ? "heart.fill" : "heart", style: saved ? .soft : .outline)
                .frame(width: 44)
        }
        .accessibilityLabel(saved ? "お気に入りから外す" : "お気に入りに追加")
    }

    private func isAdded(tripID: UUID, day: Int) -> Bool {
        store.trip(tripID)?.items.contains { $0.day == day && $0.spot.id == spot.id } ?? false
    }

    @ViewBuilder
    private var addControl: some View {
        if let tripID, let day {
            if isAdded(tripID: tripID, day: day) {
                barLabel("追加済み", systemImage: "checkmark", style: .soft)
            } else {
                Button {
                    store.addSpot(spot, to: tripID, day: day)
                } label: {
                    barLabel("この日に追加", systemImage: "plus", style: .filled)
                }
            }
        } else if let tripID {
            if store.tripContains(spotID: spot.id, tripID: tripID) {
                barLabel("追加済み", systemImage: "checkmark", style: .soft)
            } else {
                AddToTripMenu(spot: spot, tripID: tripID) {
                    barLabel("旅程に追加", systemImage: "plus", style: .filled)
                }
            }
        } else {
            AddToTripMenu(spot: spot) {
                barLabel("旅程に追加", systemImage: "plus", style: .filled)
            }
        }
    }

    private enum BarStyle { case filled, outline, soft }

    private func barLabel(_ title: String?, systemImage: String?, style: BarStyle) -> some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
            }
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
            }
        }
        .padding(.horizontal, 6)
        .foregroundStyle(style == .filled ? Color.white : Theme.accentDark)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(
            style == .filled ? Theme.accent : (style == .soft ? Theme.sandLight : Theme.surface),
            in: Capsule()
        )
        .overlay(Capsule().stroke(Theme.line, lineWidth: style == .outline ? 1 : 0))
    }
}

/// 画面を push して開くスポット詳細(旅程のカードなどから)
struct SpotDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let spot: Spot

    var body: some View {
        SpotDetailContent(spot: spot, showsMap: true, onClose: { dismiss() })
            .navigationTitle(spot.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

extension View {
    /// ピンや一覧の行を選んだときに、下から詳細カードのシートを出す。
    /// 中サイズの間は後ろの地図も操作できる(別のピンを選べば内容が切り替わる)。
    func spotDetailSheet(_ selected: Binding<Spot?>, tripID: UUID? = nil, day: Int? = nil) -> some View {
        sheet(item: selected) { spot in
            SpotDetailContent(
                spot: spot,
                tripID: tripID,
                day: day,
                showsMap: false,
                onClose: { selected.wrappedValue = nil }
            )
            .id(spot.id)
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationDragIndicator(.visible)
        }
    }
}
