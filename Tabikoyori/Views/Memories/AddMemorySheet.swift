import SwiftUI
import PhotosUI

// MARK: - 思い出を追加

/// 思い出を追加・編集するシート
struct AddMemorySheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID?
    /// 編集する思い出(nil のときは新しく追加する)
    var editing: Memory? = nil

    @State private var selectedTripID: UUID?
    /// 編集を始めたときにあった写真(キャンセルしたときに消さないように覚えておく)
    @State private var originalPhotos: [String] = []
    /// 編集中に外した、もともとの写真(保存したときに消す)
    @State private var removedOriginals: [String] = []
    @State private var loaded = false
    @State private var date = Date()
    @State private var spotID: String?
    @State private var note = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var photoNames: [String] = []
    @State private var isLoading = false
    @State private var didSave = false

    private var currentTrip: Trip? {
        let id = tripID ?? selectedTripID ?? store.tripsByStart.first?.id
        guard let id else { return nil }
        return store.trip(id)
    }

    private var spotOptions: [Spot] {
        guard let trip = currentTrip else { return [] }
        var result: [Spot] = []
        var seen = Set<String>()
        for item in trip.sortedItems where !seen.contains(item.spot.id) {
            seen.insert(item.spot.id)
            result.append(item.spot)
        }
        return result
    }

    /// 旅程から外したスポットの思い出を編集するときも、元のスポットを選べるようにする
    private var keepsOriginalSpot: Bool {
        guard let editing, let id = editing.spotID else { return false }
        return !spotOptions.contains { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            Form {
                if tripID == nil {
                    Section("旅行") {
                        Picker("旅行", selection: Binding(
                            get: { currentTrip?.id ?? UUID() },
                            set: { selectedTripID = $0; spotID = nil }
                        )) {
                            ForEach(store.tripsByStart) { trip in
                                Text(trip.title).tag(trip.id)
                            }
                        }
                    }
                }
                Section("いつ・どこで") {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    Picker("スポット", selection: $spotID) {
                        Text("指定なし").tag(String?.none)
                        if keepsOriginalSpot, let editing, let id = editing.spotID {
                            Text(editing.spotName ?? "スポット").tag(Optional(id))
                        }
                        ForEach(spotOptions) { spot in
                            Text(spot.name).tag(Optional(spot.id))
                        }
                    }
                }
                Section("メモ") {
                    AppTextEditor(prompt: "そのとき感じたことを書き留めましょう", text: $note)
                        .fieldRow()
                }
                Section("写真") {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                        Label("写真を選ぶ", systemImage: "photo.badge.plus")
                    }
                    if isLoading {
                        ProgressView()
                    }
                    if !photoNames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photoNames, id: \.self) { name in
                                    StoredPhoto(name: name)
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(alignment: .topTrailing) {
                                            Button {
                                                remove(name)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(.white, Color.black.opacity(0.55))
                                                    .accessibilityLabel("この写真を外す") 
                                            }
                                            .buttonStyle(.plain)
                                            .padding(4)
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(editing == nil ? "思い出を追加" : "思い出を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            // 写真を選んだら読み込む(画面を閉じたら、読み込みは自動で取り消される)
            .task(id: pickerItems) { await importPhotos(pickerItems) }
            // キャンセル・下にスワイプして閉じたときは、この画面で追加した写真を消す(もともとの写真は残す)
            .onDisappear {
                if !didSave { PhotoStorage.delete(photoNames.filter { !originalPhotos.contains($0) }) }
            }
            // 保存に失敗したときは画面を閉じないので、ここでもお知らせを出す
            .storageProblemAlert()
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let editing {
                    // 編集するときは、投稿した内容を読み込む
                    date = editing.date
                    spotID = editing.spotID
                    note = editing.note
                    photoNames = editing.photos
                    originalPhotos = editing.photos
                } else if let trip = currentTrip {
                    date = defaultDate(for: trip)
                }
            }
        }
    }

    /// 保存できるか(旅行が決まっていて、メモか写真がある。写真の読み込み中は保存できない)
    private var canSave: Bool {
        let hasNote = !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPhotos = !photoNames.isEmpty || !(editing?.artworks.isEmpty ?? true)
        return currentTrip != nil && (hasNote || hasPhotos) && !isLoading
    }

    private func defaultDate(for trip: Trip) -> Date {
        let now = Date()
        let cal = Calendar.current
        let start = cal.startOfDay(for: trip.startDate)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: trip.endDate)) ?? trip.endDate
        return (now >= start && now < end) ? now : trip.startDate
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let name = PhotoStorage.save(data) else { continue }
            // 読み込みの途中で画面を閉じたときは、この写真は使わないので消して終わる
            guard !Task.isCancelled else {
                PhotoStorage.delete([name])
                return
            }
            photoNames.append(name)
        }
        pickerItems = []
    }

    private func remove(_ name: String) {
        photoNames.removeAll { $0 == name }
        if originalPhotos.contains(name) {
            // もともとの写真は、保存するまで消さない(キャンセルしたら元に戻せるように)
            removedOriginals.append(name)
        } else {
            PhotoStorage.delete([name])
        }
    }

    /// 閉じる(この画面で追加した写真は、onDisappear で消す)
    private func cancel() {
        dismiss()
    }

    private func save() {
        guard let trip = currentTrip else { return }
        let spot = spotOptions.first { $0.id == spotID }
        if var memory = editing {
            memory.date = date
            if let spot {
                memory.spotID = spot.id
                memory.spotName = spot.name
            } else if spotID == nil {
                memory.spotID = nil
                memory.spotName = nil
            }
            memory.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            memory.photos = photoNames
            // 保存に失敗したときは、入力した内容を残したまま画面を閉じない(お知らせが出る)
            guard store.updateMemory(memory, in: trip.id) else { return }
            // 保存できたので、外したもともとの写真を消す
            PhotoStorage.delete(removedOriginals)
            didSave = true
            dismiss()
            return
        }
        let memory = Memory(
            date: date,
            spotID: spot?.id,
            spotName: spot?.name,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            photos: photoNames
        )
        guard store.addMemory(memory, to: trip.id) else { return }
        didSave = true
        dismiss()
    }
}
