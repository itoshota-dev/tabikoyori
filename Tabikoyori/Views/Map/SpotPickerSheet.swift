import SwiftUI
import MapKit

// MARK: - スポット追加シート(地図 / お気に入り)

/// 旅程にスポットを追加するシート(地図から探す / お気に入りから選ぶ)
struct SpotPickerSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case map = "地図"
        case saved = "お気に入り"

        var id: String { rawValue }
    }

    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID
    let day: Int
    @State private var mode: Mode

    @State private var query = ""
    @State private var selected: Spot?
    @State private var position: MapCameraPosition = .automatic
    @State private var customPin: Coordinate?
    @State private var customName = ""
    @State private var search = PlaceSearchViewModel()
    @State private var mapQuery = ""

    init(tripID: UUID, day: Int, mode: Mode) {
        self.tripID = tripID
        self.day = day
        _mode = State(initialValue: mode)
    }

    private var trip: Trip? { store.trip(tripID) }

    private var mapSpots: [Spot] {
        search.hasSearched ? search.results : []
    }

    private var listSpots: [Spot] {
        var base = store.bookmarkedSpots
        if !query.isEmpty {
            base = base.filter {
                $0.name.localizedCaseInsensitiveContains(query) || $0.area.localizedCaseInsensitiveContains(query)
            }
        }
        return base
    }

    private func isAdded(_ spot: Spot) -> Bool {
        guard let trip else { return false }
        return trip.items.contains { $0.day == day && $0.spot.id == spot.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    if let trip {
                        Text("\(day + 1)日目(\(DisplayFormat.shortMonthDayWeekday.string(from: trip.date(forDay: day))))に追加")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subText)
                    }
                    Picker("追加方法", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if mode == .map {
                    mapContent
                } else {
                    listContent
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("スポットを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .spotDetailSheet($selected, tripID: tripID, day: day)
        .onAppear {
            if let trip {
                position = .region(trip.mapRegion)
            }
        }
        .onChange(of: mapSpots.map { $0.id }) { _, _ in
            if mode == .map { fitMap() }
        }
        .onChange(of: mode) { _, newValue in
            if newValue == .map { fitMap() }
        }
    }

    private func fitMap() {
        guard let trip else { return }
        position = .region(MapFit.region(for: mapSpots.map { $0.coordinate }, fallback: trip.mapRegion))
    }

    // MARK: リスト

    @ViewBuilder
    private var listContent: some View {
        VStack(spacing: 0) {
            MapSearchBar(text: $query, prompt: "お気に入りから検索")
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            if listSpots.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "heart")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.sand)
                    Text(store.bookmarks.isEmpty ? "お気に入りはまだありません" : "見つかりませんでした")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.subText)
                    if store.bookmarks.isEmpty {
                        Text("「地図」タブで探した場所を、お気に入りに追加できます。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(listSpots) { spot in
                            pickerRow(spot)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func pickerRow(_ spot: Spot) -> some View {
        HStack(spacing: 12) {
            SpotArt(style: spot.art)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                RatingLabel(spot: spot)
                HStack(spacing: 6) {
                    CategoryTag(text: spot.category.label)
                    AreaLabel(text: spot.area)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selected = spot }
            Spacer(minLength: 0)
            addButton(for: spot)
        }
        .padding(10)
        .cardStyle(radius: 18)
    }

    @ViewBuilder
    private func addButton(for spot: Spot) -> some View {
        if isAdded(spot) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Theme.accent)
        } else {
            Button {
                store.addSpot(spot, to: tripID, day: day)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 地図(フリーワード検索)

    private var mapContent: some View {
        VStack(spacing: 8) {
            MapSearchBar(
                text: $mapQuery,
                prompt: "\(trip?.destinationName ?? "京都") カフェ",
                isSearching: search.isSearching,
                onSearch: runMapSearch,
                onClear: {
                    search.clear()
                    selected = nil
                },
                trailing: { EmptyView() }
            )
            .padding(.horizontal, 16)

            if let message = search.errorMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.subText)
                    .padding(.horizontal, 16)
            }

            ZStack(alignment: .bottom) {
                MapLoadingGate {
                    SpotMapCanvas(
                        spots: mapSpots,
                        customPin: customPin,
                        selected: $selected,
                        position: $position,
                        onTapMap: { coordinate in
                            selected = nil
                            customPin = Coordinate(coordinate)
                            customName = ""
                        }
                    )
                    .onChange(of: selected) { _, newValue in
                        if newValue != nil { customPin = nil }
                    }
                }

                mapCard
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .onChange(of: mapQuery) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                search.clear()
            }
        }
    }

    private func runMapSearch() {
        let q = mapQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            search.clear()
            return
        }
        let hint = Region.hint(for: q) ?? trip?.searchRegion
        Task {
            await search.search(q, hint: hint)
            selected = nil
            customPin = nil
        }
    }

    @ViewBuilder
    private var mapCard: some View {
        if selected == nil, let pin = customPin, let trip {
            VStack(spacing: 10) {
                AppTextField(prompt: "場所の名前(例：お気に入りの食堂)", text: $customName)
                Button {
                    let name = customName.trimmingCharacters(in: .whitespaces)
                    let spot = Spot(
                        id: "custom-" + UUID().uuidString,
                        name: name.isEmpty ? "選んだ場所" : name,
                        category: .landmark,
                        area: "地図で選択",
                        address: String(format: "%.4f, %.4f", pin.latitude, pin.longitude),
                        summary: "地図から追加した場所です。",
                        region: trip.region,
                        coordinate: pin,
                        art: trip.region.coverStyle,
                        isCustom: true
                    )
                    store.addSpot(spot, to: tripID, day: day)
                    customPin = nil
                    customName = ""
                } label: {
                    PrimaryCapsuleLabel(title: "この場所を旅程に追加", systemImage: "mappin.and.ellipse")
                }
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 4)
        } else if !search.hasSearched {
            Text("上の検索欄に「\(trip?.destinationName ?? "京都") カフェ」のように入力できます")
                .font(.system(size: 12))
                .foregroundStyle(Theme.subText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.surface.opacity(0.95), in: Capsule())
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
        }
    }
}
