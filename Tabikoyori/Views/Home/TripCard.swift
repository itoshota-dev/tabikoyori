import SwiftUI

/// 旅行の一覧に並べる、1つの旅行のカード
struct TripCard: View {
    let trip: Trip

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cover
            LinearGradient(colors: [.clear, Color.black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.title)
                    .font(.serif(26, bold: true))
                    .foregroundStyle(.white)
                Text(trip.dateRangeText)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 172)
        .overlay(alignment: .bottomTrailing) {
            Text(trip.status.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    (trip.status == .ongoing ? Theme.accent : Theme.accentDark.opacity(0.55)),
                    in: Capsule()
                )
                .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.accentDark.opacity(0.18), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private var cover: some View {
        if let name = trip.coverPhoto {
            StoredPhoto(name: name)
        } else {
            SpotArt(style: trip.region.coverStyle, variant: trip.region == .okinawa ? 1 : 0)
        }
    }
}
