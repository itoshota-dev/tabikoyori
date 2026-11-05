import SwiftUI

// MARK: - 旅程に追加するメニュー

/// スポットを旅程に追加するメニュー(どの旅行の何日目に入れるか選ぶ)
struct AddToTripMenu<Label: View>: View {
    @Environment(TripStore.self) private var store

    let spot: Spot
    let tripID: UUID?
    private let label: () -> Label

    init(spot: Spot, tripID: UUID? = nil, @ViewBuilder label: @escaping () -> Label) {
        self.spot = spot
        self.tripID = tripID
        self.label = label
    }

    var body: some View {
        Menu {
            if let tripID {
                dayButtons(for: tripID)
            } else {
                ForEach(store.tripsByStart) { trip in
                    Menu(trip.title) {
                        dayButtons(for: trip.id)
                    }
                }
            }
        } label: {
            label()
        }
        .menuOrder(.fixed)
        .disabled(store.trips.isEmpty)
    }

    @ViewBuilder
    private func dayButtons(for id: UUID) -> some View {
        if let trip = store.trip(id) {
            ForEach(0..<trip.dayCount, id: \.self) { d in
                let title = "\(d + 1)日目 \(DisplayFormat.shortMonthDayWeekday.string(from: trip.date(forDay: d)))"
                if trip.items.contains(where: { $0.day == d && $0.spot.id == spot.id }) {
                    Button(action: {}) {
                        SwiftUI.Label(title, systemImage: "checkmark")
                    }
                    .disabled(true)
                } else {
                    Button(title) {
                        store.addSpot(spot, to: id, day: d)
                    }
                }
            }
        }
    }
}
