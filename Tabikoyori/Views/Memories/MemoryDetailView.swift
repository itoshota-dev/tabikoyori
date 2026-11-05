import SwiftUI

// MARK: - 思い出の詳細(メモを全部読むページ)

/// 思い出の詳細(メモの全文と写真)
struct MemoryDetailView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID
    let memoryID: UUID

    @State private var viewer: PhotoViewerTarget?
    @State private var editing = false
    @State private var confirmDelete = false

    private var trip: Trip? { store.trip(tripID) }
    private var memory: Memory? { trip?.memories.first { $0.id == memoryID } }

    var body: some View {
        Group {
            if let trip, let memory {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(DisplayFormat.monthDayWeekday.string(from: memory.date))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memory.spotName ?? "メモ")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.text)
                            if let id = memory.spotID, let spot = store.spot(id: id) {
                                AreaLabel(text: spot.area)
                            }
                            AreaLabel(text: trip.title)
                        }
                        if !memory.media.isEmpty {
                            photos(memory.media)
                        }
                        if !memory.note.isEmpty {
                            Text(memory.note)
                                .font(.system(size: 15))
                                .lineSpacing(6)
                                .foregroundStyle(Theme.text)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .cardStyle(radius: 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            } else {
                ContentUnavailableView("思い出が見つかりません", systemImage: "photo.on.rectangle.angled")
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("思い出")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if memory != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("編集", systemImage: "pencil") { editing = true }
                        Button("削除", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .accessibilityLabel("思い出のメニュー")
                    }
                }
            }
        }
        .fullScreenCover(item: $viewer) { target in
            PhotoViewer(target: target)
        }
        .sheet(isPresented: $editing) {
            if let memory {
                AddMemorySheet(tripID: tripID, editing: memory)
            }
        }
        .confirmationDialog("この思い出を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                store.deleteMemory(memoryID, from: tripID)
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func photos(_ media: [MemoryMedia]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
            ForEach(Array(media.enumerated()), id: \.element.id) { index, item in
                MediaTile(media: item)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture {
                        viewer = PhotoViewerTarget(media: media, index: index)
                    }
            }
        }
    }
}
