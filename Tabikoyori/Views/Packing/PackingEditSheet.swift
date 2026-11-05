import SwiftUI

// MARK: - 持ち物を追加・編集

/// 持ち物を追加・編集するシート
struct PackingEditSheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID
    let item: PackingItem?

    @State private var name = ""
    @State private var quantity = 1
    @State private var category: PackingCategory = .other
    @State private var bagID: UUID?
    @State private var note = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var bags: [PackingBag] { store.trip(tripID)?.bags ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                Section("持ち物") {
                    AppFieldCard {
                        AppTextField(prompt: "例：モバイルバッテリー", text: $name, boxed: false)
                        AppFieldDivider()
                        AppStepperRow(title: "数量：\(quantity)", value: $quantity)
                    }
                    .fieldRow()
                }
                Section("カテゴリー") {
                    Picker("種類", selection: $category) {
                        ForEach(PackingCategory.allCases) { c in
                            Label(c.label, systemImage: c.symbol).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if !bags.isEmpty {
                    Section("カバン") {
                        Picker("入れるカバン", selection: $bagID) {
                            Text("指定なし").tag(UUID?.none)
                            ForEach(bags) { b in
                                Label(b.name, systemImage: b.kind.symbol).tag(Optional(b.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section("メモ") {
                    AppTextField(prompt: "補足情報など", text: $note, lines: 3...6)
                        .fieldRow()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(item == nil ? "持ち物を追加" : "持ち物を編集")
            // 保存に失敗したときは閉じないので、ここでもお知らせを出す
            .storageProblemAlert()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                if let item {
                    name = item.name
                    quantity = item.quantity
                    category = item.category
                    bagID = item.bagID
                    note = item.note
                }
            }
        }
    }

    private func save() {
        var value = item ?? PackingItem(name: "", category: category)
        value.name = trimmedName
        value.quantity = quantity
        value.category = category
        value.bagID = bagID
        value.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        // 保存に失敗したときは、入力した内容を残したまま閉じない
        guard store.savePacking(value, in: tripID) else { return }
        dismiss()
    }
}
