import SwiftUI

/// スポットの一覧の1行
struct SpotRow: View {
    @Environment(TripStore.self) private var store
    let spot: Spot

    var body: some View {
        HStack(spacing: 12) {
            SpotArt(style: spot.art)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(spot.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    BookmarkButton(spot: spot)
                }
                RatingLabel(spot: spot)
                CategoryTag(text: spot.category.label)
                AreaLabel(text: spot.area)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 20)
    }
}
