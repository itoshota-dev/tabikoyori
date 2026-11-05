import SwiftUI

// MARK: - 予算の設定(全体 + カテゴリーごと)

/// 旅行全体の予算と、カテゴリーごとの予算を設定するシート
struct BudgetEditSheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID

    @State private var totalText = ""
    @State private var categoryTexts: [ExpenseCategory: String] = [:]

    private func amount(_ text: String) -> Int {
        Int(text.filter(\.isNumber)) ?? 0
    }

    private func binding(_ category: ExpenseCategory) -> Binding<String> {
        Binding(
            get: { categoryTexts[category] ?? "" },
            set: { categoryTexts[category] = $0 }
        )
    }

    private var categorySum: Int {
        ExpenseCategory.allCases.reduce(0) { $0 + amount(categoryTexts[$1] ?? "") }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("旅行全体の予算") {
                    AppFieldCard {
                        AppTextField(prompt: "例：100000", text: $totalText, label: "全体", keyboard: .numberPad, alignment: .trailing, suffix: "円", boxed: false)
                    }
                    .fieldRow()
                }
                Section {
                    AppFieldCard {
                        ForEach(Array(ExpenseCategory.allCases.enumerated()), id: \.element.id) { index, category in
                            if index > 0 { AppFieldDivider() }
                            AppTextField(prompt: "未設定", text: binding(category), label: category.label, keyboard: .numberPad, alignment: .trailing, suffix: "円", boxed: false)
                        }
                    }
                    .fieldRow()
                } header: {
                    Text("カテゴリーごとの予算(任意)")
                } footer: {
                    Text("カテゴリーごとの予算の合計: \(DisplayFormat.yen(categorySum))。全体の予算とは別に設定できます。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("予算を設定")
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
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let trip = store.trip(tripID) else { return }
        totalText = trip.budget > 0 ? String(trip.budget) : ""
        for category in ExpenseCategory.allCases {
            let value = trip.categoryBudget(category)
            categoryTexts[category] = value > 0 ? String(value) : ""
        }
    }

    private func save() {
        var categories: [ExpenseCategory: Int] = [:]
        for category in ExpenseCategory.allCases {
            categories[category] = amount(categoryTexts[category] ?? "")
        }
        // 保存に失敗したときは、入力した内容を残したまま閉じない
        guard store.setBudgets(total: amount(totalText), categories: categories, for: tripID) else { return }
        dismiss()
    }
}
