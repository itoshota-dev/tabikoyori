import SwiftUI

// MARK: - コレクション(旅の思い出)

/// コレクションタブ。すべての旅行の思い出を日付ごとに表示する
struct MemoriesView: View {
    @Environment(TripStore.self) private var store

    @State private var filter: MemoryFilter = .all
    @State private var showingAdd = false

    private var entries: [MemoryEntry] {
        store.entries(forFilter: filter)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ChipRow {
                        ForEach(MemoryFilter.allCases) { f in
                            Chip(title: f.title, selected: filter == f) { filter = f }
                        }
                    }
                    if entries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 38))
                                .foregroundStyle(Theme.sand)
                            Text("思い出はまだありません")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.text)
                            Text("右上の＋から、写真やメモを追加できます。")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.subText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 70)
                    } else {
                        MemoryTimeline(entries: entries, showsTripTitle: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { ScreenTitle(text: "旅の思い出") }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(store.trips.isEmpty)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddMemorySheet(tripID: nil)
            }
            .navigationDestination(for: TripScreen.self) { $0.destination }
        }
    }
}
