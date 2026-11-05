import SwiftUI

// MARK: - 支出を追加・編集

/// 支出を追加・編集するシート
struct ExpenseEditSheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID
    let expense: Expense?

    @State private var title = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .food
    @State private var date = Date()
    @State private var note = ""

    private var amount: Int { Int(amountText.filter(\.isNumber)) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("支出の内容") {
                    AppFieldCard {
                        AppTextField(prompt: "例：京都駅でランチ", text: $title, boxed: false)
                        AppFieldDivider()
                        AppTextField(prompt: "0", text: $amountText, label: "金額", keyboard: .numberPad, alignment: .trailing, suffix: "円", boxed: false)
                    }
                    .fieldRow()
                }
                Section("カテゴリー") {
                    Picker("種類", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { c in
                            Label(c.label, systemImage: c.symbol).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("日付") {
                    DatePicker("支出日", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }
                Section("メモ") {
                    AppTextField(prompt: "お店の名前や補足情報", text: $note, lines: 4...8)
                        .fieldRow()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(expense == nil ? "支出を追加" : "支出を編集")
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
                        .disabled(amount <= 0)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let expense {
            title = expense.title
            amountText = String(expense.amount)
            category = expense.category
            date = expense.date
            note = expense.note
        } else if let trip = store.trip(tripID) {
            let cal = Calendar.current
            let start = cal.startOfDay(for: trip.startDate)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: trip.endDate)) ?? trip.endDate
            let now = Date()
            date = (now >= start && now < end) ? now : trip.startDate
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var value = expense ?? Expense(title: "", amount: 0, category: category, date: date)
        value.title = trimmed.isEmpty ? category.label : trimmed
        value.amount = amount
        value.category = category
        value.date = date
        value.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        // 保存に失敗したときは、入力した内容を残したまま閉じない
        guard store.saveExpense(value, in: tripID) else { return }
        dismiss()
    }
}
