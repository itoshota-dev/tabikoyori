import SwiftUI

private struct CategoryTotal: Identifiable {
    let category: ExpenseCategory
    let amount: Int
    var id: String { category.rawValue }
}

private let overBudgetColor = Color(hex: 0xB84A3A)

/// 旅のお金の画面(予算・カテゴリー別の支出・支出の記録)
struct TripMoneyView: View {
    @Environment(TripStore.self) private var store

    let tripID: UUID

    @State private var showingNew = false
    @State private var editing: Expense?
    @State private var deleting: Expense?
    @State private var showingBudget = false

    private var trip: Trip? { store.trip(tripID) }

    var body: some View {
        Group {
            if let trip {
                ScrollView {
                    LazyVStack(spacing: 22) {
                        budgetCard(trip)
                        categoryCard(trip)
                        recordsSection(trip)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            } else {
                ContentUnavailableView("旅行が見つかりません", systemImage: "airplane")
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("旅のお金")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("支出を追加")
                }            }
        }
        .sheet(isPresented: $showingNew) {
            ExpenseEditSheet(tripID: tripID, expense: nil)
        }
        .sheet(item: $editing) { expense in
            ExpenseEditSheet(tripID: tripID, expense: expense)
        }
        .sheet(isPresented: $showingBudget) {
            BudgetEditSheet(tripID: tripID)
        }
        .confirmationDialog("この支出を削除しますか？", isPresented: Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                if let deleting { store.deleteExpense(deleting.id, from: tripID) }
                deleting = nil
            }
            Button("キャンセル", role: .cancel) { deleting = nil }
        }
    }

    // MARK: 予算カード

    private func budgetCard(_ trip: Trip) -> some View {
        let spent = trip.totalSpent
        let remaining = trip.remainingBudget
        let ratio = trip.budget > 0 ? min(Double(spent) / Double(trip.budget), 1) : 0
        let over = trip.budget > 0 && remaining < 0

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.accentDark)
                Text("旅行予算")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button("予算を設定") {
                    showingBudget = true
                }
                .font(.system(size: 14))
                .foregroundStyle(Theme.accentDark)
            }

            Text(over ? "予算オーバー" : "残りの予算")
                .font(.system(size: 12))
                .foregroundStyle(over ? overBudgetColor : Theme.subText)
                .padding(.top, 14)

            Text(trip.budget > 0 ? DisplayFormat.yen(remaining) : "未設定")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(over ? overBudgetColor : Theme.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.top, 6)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("支出合計")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.subText)
                    Text(DisplayFormat.yen(spent))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("設定予算")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.subText)
                    Text(trip.budget > 0 ? DisplayFormat.yen(trip.budget) : "—")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
            }
            .padding(.top, 14)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule()
                        .fill(over ? overBudgetColor : Theme.accent)
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 4)
            .padding(.top, 14)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 24)
    }

    // MARK: カテゴリー別

    private func categoryCard(_ trip: Trip) -> some View {
        let totals = ExpenseCategory.allCases.map { category in
            CategoryTotal(
                category: category,
                amount: trip.expenses.filter { $0.category == category }.reduce(0) { $0 + $1.amount }
            )
        }
        let visible = totals.filter { $0.amount > 0 }
        let grandTotal = totals.reduce(0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 18) {
            Text("カテゴリー別支出")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)

            if visible.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.sand)
                    Text("支出を追加すると、ここにグラフが表示されます")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                DonutChart(slices: visible.map { DonutSlice(id: $0.id, color: $0.category.color, value: Double($0.amount)) })
                    .frame(height: 220)
                    // グラフと下の一覧のあいだを少しあける
                    .padding(.bottom, 14)
            }

            // グラフの色と対応する凡例(色の帯 + アイコン + 名前 + 割合 + 金額)
            VStack(spacing: 12) {
                ForEach(totals) { entry in
                    let percent = grandTotal > 0 ? Int((Double(entry.amount) / Double(grandTotal) * 100).rounded()) : 0
                    let budget = trip.categoryBudget(entry.category)
                    let overCategory = budget > 0 && entry.amount > budget
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(entry.category.color)
                            .frame(width: 6, height: 32)
                        Image(systemName: entry.category.symbol)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.text)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.category.label)
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            Text("\(percent)%")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.subText)
                        }
                        .frame(width: 52, alignment: .leading)

                        // 予算の欄(どのカテゴリーも同じ幅にして、バーの長さをそろえる)
                        Group {
                            if budget > 0 {
                                VStack(alignment: .leading, spacing: 3) {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.black.opacity(0.08))
                                            Capsule()
                                                .fill(entry.category.color)
                                                .frame(width: geo.size.width * min(Double(entry.amount) / Double(budget), 1))
                                        }
                                    }
                                    .frame(height: 4)
                                    .padding(.bottom, 1)
                                    Text("予算 \(DisplayFormat.yen(budget))")
                                }
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.subText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                // 文字の上下の余白の分、見た目が上に寄るので、少し下げて行の真ん中にそろえる
                                .padding(.top, 5)
                            } else {
                                Color.clear.frame(height: 1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(DisplayFormat.yen(entry.amount))
                            .font(.system(size: 15, weight: entry.amount > 0 ? .semibold : .regular))
                            .foregroundStyle(overCategory ? overBudgetColor : (entry.amount > 0 ? Theme.accentDark : Theme.subText))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 24)
    }

    // MARK: 支出の記録

    /// 日ごとに古い日が上。同じ日の中は、カテゴリーの並び(食費→交通費→宿泊費→観光費→買い物→その他)、
    /// 同じカテゴリーなら登録の古い順(保存している並び順のまま)。
    private func recordsSection(_ trip: Trip) -> some View {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: trip.expenses) { cal.startOfDay(for: $0.date) }
        let days = grouped.keys.sorted()
        let order = Dictionary(uniqueKeysWithValues: ExpenseCategory.allCases.enumerated().map { ($1, $0) })

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("支出の記録")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button {
                    showingNew = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("追加")
                            .font(.system(size: 15))
                    }
                    .foregroundStyle(Theme.accentDark)
                }
            }

            if days.isEmpty {
                Text("まだ支出がありません。右上の＋から追加できます。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.subText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }

            ForEach(days, id: \.self) { day in
                let list = (grouped[day] ?? []).enumerated()
                    .sorted { lhs, rhs in
                        let lo = order[lhs.element.category] ?? 0
                        let ro = order[rhs.element.category] ?? 0
                        return lo != ro ? lo < ro : lhs.offset < rhs.offset
                    }
                    .map { $0.element }
                VStack(spacing: 10) {
                    HStack(alignment: .bottom) {
                        HStack(spacing: 10) {
                            Text(DisplayFormat.yearMonthDaySpaced.string(from: day))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.accentDark)
                            Text(phase(of: day, trip: trip))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.accentDark)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.sandLight, in: Capsule())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("この日の合計")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.subText)
                            Text(DisplayFormat.yen(list.reduce(0) { $0 + $1.amount }))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.text)
                        }
                    }
                    ForEach(list) { expense in
                        expenseRow(expense)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func phase(of day: Date, trip: Trip) -> String {
        let cal = Calendar.current
        if day < cal.startOfDay(for: trip.startDate) { return "旅行前" }
        if day > cal.startOfDay(for: trip.endDate) { return "旅行後" }
        return "旅行中"
    }

    private func expenseRow(_ expense: Expense) -> some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.symbol)
                .font(.system(size: 16))
                .foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38)
                .background(Theme.sandLight.opacity(0.8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(expense.category.label) · \(DisplayFormat.yearMonthDay.string(from: expense.date))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.subText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 6) {
                Text(DisplayFormat.yen(expense.amount))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accentDark)
                Menu {
                    Button("編集", systemImage: "pencil") { editing = expense }
                    Button("削除", systemImage: "trash", role: .destructive) { deleting = expense }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.accent)
                        .accessibilityLabel("\(expense.title)のメニュー") 
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardStyle(radius: 22)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        // 左へスワイプすると削除ボタンが出る
        .swipeToDelete(id: expense.id) {
            store.deleteExpense(expense.id, from: tripID)
        }
    }
}
