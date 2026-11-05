import SwiftUI
import PhotosUI
import MapKit

// MARK: - 旅行の作成・編集

/// 旅行を作成・編集するシート
struct TripEditSheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var editing: Trip? = nil

    @State private var title = ""
    @State private var destination = ""
    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var coverName: String?
    @State private var pickerItem: PhotosPickerItem?
    /// この画面で新しく保存した写真(保存しなかったときや、使わなかったものは閉じるときに消す)
    @State private var addedPhotos: [String] = []
    @State private var loaded = false
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section("旅行の名前") {
                    AppTextField(prompt: "例：京都の旅", text: $title)
                        .fieldRow()
                }
                Section("行き先") {
                    AppTextField(prompt: "例：京都、モンゴル、イタリア", text: $destination)
                        .fieldRow()
                }
                Section("日程") {
                    DatePicker("出発", selection: $start, displayedComponents: .date)
                    DatePicker("帰着", selection: $end, in: start..., displayedComponents: .date)
                }
                Section("カバー写真") {
                    if let coverName {
                        StoredPhoto(name: coverName)
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    // PhotosPicker の見た目を作る部分は、別のスレッドからも呼べる形(Sendable)になっている。
                    // そこから画面の状態を直接読まないよう、文字を先に決めてから渡す
                    let pickerTitle = coverName == nil ? "写真を選ぶ" : "写真を変更"
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(pickerTitle, systemImage: "photo")
                    }
                    if coverName != nil {
                        Button("写真を外す", role: .destructive) { coverName = nil }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(editing == nil ? "新しい旅" : "旅行を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "作成" : "保存") { save() }
                        .fontWeight(.semibold)
                        // 写真の読み込み中は保存できない(読み込みが終わる前に閉じないように)
                        .disabled(pickerItem != nil)
                }
            }
            .onAppear(perform: loadIfNeeded)
            // キャンセル・下にスワイプして閉じたときは、この画面で追加した写真を消す
            .onDisappear {
                if !didSave { PhotoStorage.delete(addedPhotos) }
            }
            // 保存に失敗したときは画面を閉じないので、ここでもお知らせを出す
            .storageProblemAlert()
            .onChange(of: start) { _, newValue in
                if end < newValue { end = newValue }
            }
            // 写真を選んだら読み込む(選び直したときは、前の読み込みを取り消して読み込み直す)
            .task(id: pickerItem) { await loadPickedPhoto() }
        }
    }

    /// 選んだ写真を読み込んで保存し、カバー写真にする。
    /// 画面のメソッドなのでメインスレッドで動き、画面の状態(coverName)を安全に書き換えられる
    private func loadPickedPhoto() async {
        guard let item = pickerItem else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let name = PhotoStorage.save(data) {
            // 読み込みの途中で画面を閉じたり選び直したりしたときは、この写真は使わないので消す
            guard !Task.isCancelled else {
                PhotoStorage.delete([name])
                return
            }
            addedPhotos.append(name)
            coverName = name
        }
        pickerItem = nil
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let editing {
            title = editing.title
            destination = editing.destination.isEmpty ? editing.region.name : editing.destination
            start = editing.startDate
            end = editing.endDate
            coverName = editing.coverPhoto
        }
    }

    private func save() {
        let dest = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = Region.match(dest) ?? editing?.region ?? .kyoto
        let finalTitle = title.trimmingCharacters(in: .whitespaces).isEmpty
            ? (dest.isEmpty ? "新しい旅" : "\(dest)の旅")
            : title
        let savedID: UUID
        let saved: Bool
        if var trip = editing {
            trip.title = finalTitle
            trip.region = region
            trip.destination = dest
            if dest != editing?.destination { trip.destCenter = nil; trip.destSpan = nil }
            trip.startDate = start
            trip.endDate = end
            trip.coverPhoto = coverName
            savedID = trip.id
            // 前の表紙の写真は、保存できたときに TripStore が消す
            saved = store.updateInfo(trip)
        } else {
            let trip = Trip(
                title: finalTitle,
                region: region,
                destination: dest,
                startDate: start,
                endDate: end,
                coverPhoto: coverName
            )
            savedID = trip.id
            saved = store.addTrip(trip)
        }
        // 保存に失敗したときは、入力した内容を残したまま画面を閉じない(お知らせが出る)
        guard saved else { return }

        // この画面で追加したけれど、表紙にしなかった写真を消す
        PhotoStorage.delete(addedPhotos.filter { $0 != coverName })
        didSave = true

        // 組み込みの地域に当てはまらない行き先は、地図で検索して中心と広さを保存する
        if !dest.isEmpty, Region.match(dest) == nil {
            let id = savedID
            let store = store
            Task { await Self.geocode(dest, tripID: id, store: store) }
        }
        dismiss()
    }

    /// 行き先を地図で検索して、中心と広さを保存する。
    /// 検索している間に行き先が変わっていたら、TripStore 側で保存しない(古い検索の結果なので)
    private static func geocode(_ text: String, tripID: UUID, store: TripStore) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        guard let response = try? await MKLocalSearch(request: request).start() else { return }
        let box = response.boundingRegion
        let center = Coordinate(box.center)
        let span = min(max(box.span.latitudeDelta, 0.05), 40)
        await MainActor.run {
            // 保存できたか(行き先が変わっていなかったか)の結果は、ここでは使わない
            _ = store.setDestinationGeo(center: center, span: span, forDestination: text, of: tripID)
        }
    }
}
