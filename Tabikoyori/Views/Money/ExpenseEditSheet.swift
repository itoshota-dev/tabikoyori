import SwiftUI

// MARK: - 支出を追加・編集

/// 支出を追加・編集するシート。外貨で入力したときは、支出日のレートで円に換算して保存する
struct ExpenseEditSheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID
    let expense: Expense?
    /// レートを取る係(テストやプレビューでは差し替えられる)
    var rates: any ExchangeRateProviding = ExchangeRates.shared

    @State private var title = ""
    @State private var amountText = ""
    @State private var currencyCode = Currency.yenCode
    /// 外貨1単位が何円か。支出日のレートを自動で入れる(手で書き換えてもよい)
    @State private var rateText = ""
    @State private var category: ExpenseCategory = .food
    @State private var date = Date()
    @State private var note = ""

    @State private var rateStatus: RateStatus = .idle
    /// 自動で入れたレートの文字。利用者が書き換えたら、自動では上書きしない
    @State private var autoRateText = ""
    /// 編集を開いたときは、保存してあるレートをそのまま使う(最初の1回だけ取りに行かない)
    @State private var skipNextFetch = false
    /// 「再試行」を押した回数。変わると、レートを取り直す
    @State private var retryCount = 0

    private enum RateStatus: Equatable {
        case idle
        case loading
        case loaded(String?)
        case failed(String)
    }

    private var currency: Currency { Currency(code: currencyCode) }
    /// 入力した金額(選んだ通貨の単位)
    private var inputAmount: Decimal? { CurrencyConversion.parse(amountText) }
    private var rate: Decimal? { CurrencyConversion.parse(rateText) }

    /// 保存する円の金額。外貨はレートで換算する。計算できないときは 0(保存できない)
    private var yenAmount: Int {
        guard let inputAmount else { return 0 }
        if currency.isYen { return CurrencyConversion.yen(from: inputAmount, rate: 1) }
        guard let rate, rate > 0 else { return 0 }
        return CurrencyConversion.yen(from: inputAmount, rate: rate)
    }

    /// 通貨・支出日・再試行のどれかが変わったら、レートを取り直す
    private var rateRequestID: String {
        "\(currencyCode)|\(RateDay.string(for: date))|\(retryCount)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("支出の内容") {
                    AppFieldCard {
                        AppTextField(prompt: "例：京都駅でランチ", text: $title, boxed: false)
                        AppFieldDivider()
                        AppTextField(
                            prompt: "0",
                            text: $amountText,
                            label: "金額",
                            keyboard: currency.isYen ? .numberPad : .decimalPad,
                            alignment: .trailing,
                            suffix: currency.isYen ? "円" : currency.code,
                            boxed: false
                        )
                    }
                    .fieldRow()
                }
                Section("通貨") {
                    Picker("通貨", selection: $currencyCode) {
                        ForEach(Currency.common) { c in
                            Text("\(c.name)(\(c.code))").tag(c.code)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if !currency.isYen {
                    Section("レート") {
                        // 「支出の内容」と同じく、1枚のカードにレートの入力・換算した金額・取得の状態を並べる
                        AppFieldCard {
                            AppTextField(
                                prompt: "例：162.45",
                                text: $rateText,
                                label: "1 \(currency.code) =",
                                keyboard: .decimalPad,
                                alignment: .trailing,
                                suffix: "円",
                                boxed: false
                            )
                            AppFieldDivider()
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("円に換算")
                                        .font(.body)
                                        .foregroundStyle(Theme.text)
                                    Text("合計や予算は、この金額で計算します")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.subText)
                                }
                                Spacer()
                                Text(yenAmount > 0 ? "≈ \(DisplayFormat.yen(yenAmount))" : "—")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.accentDark)
                            }
                            .padding(.horizontal, FieldMetrics.horizontalPadding)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, minHeight: FieldMetrics.height)
                            AppFieldDivider()
                            rateStatusRow
                        }
                        .fieldRow()
                    }
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
                        // 金額が入っていない、または外貨でレートが入っていないときは保存できない
                        .disabled(yenAmount <= 0)
                }
            }
            .onAppear(perform: load)
            // 通貨や支出日を変えると、前の問い合わせは取り消され、新しく取り直す
            .task(id: rateRequestID) { await fetchRate() }
        }
    }

    // MARK: レートの取得

    /// レートを取得している状態を、カードのいちばん下に出す
    @ViewBuilder
    private var rateStatusRow: some View {
        HStack(spacing: 8) {
            switch rateStatus {
            case .idle:
                Text("レートを入力してください")
            case .loading:
                ProgressView().controlSize(.small)
                Text("支出日のレートを取得中…")
            case .loaded(let day):
                if rateText == autoRateText {
                    Image(systemName: "checkmark.circle")
                    Text("\((day ?? RateDay.string(for: date)).replacingOccurrences(of: "-", with: "/")) のレート(Frankfurter)")
                } else {
                    Image(systemName: "pencil")
                    Text("手入力したレートを使います")
                }
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle")
                Text("\(message)。手入力もできます")
                Spacer()
                Button("再試行") { retryCount += 1 }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.accentDark)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.subText)
        .padding(.horizontal, FieldMetrics.horizontalPadding)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
    }

    /// 支出日のレートを取って、レートの欄に入れる
    private func fetchRate() async {
        guard !currency.isYen else {
            rateStatus = .idle
            return
        }
        if skipNextFetch {
            skipNextFetch = false
            rateStatus = rateText.isEmpty ? .idle : .loaded(nil)
            return
        }
        // 自動で入れていた前のレートは、取り直すあいだ消しておく(違う通貨のレートで保存しないように)
        if rateText == autoRateText {
            rateText = ""
            autoRateText = ""
        }
        rateStatus = .loading
        do {
            let result = try await rates.rate(for: currencyCode, on: date)
            // 待っているあいだに通貨や日付が変わっていたら、この古い結果は使わない
            guard !Task.isCancelled else { return }
            let text = NSDecimalNumber(decimal: result.rate).stringValue
            // 利用者がレートを書き換えていたら、上書きしない
            if rateText.isEmpty {
                rateText = text
                autoRateText = text
            }
            rateStatus = .loaded(result.date)
        } catch is CancellationError {
            // 新しい問い合わせに切り替わった
        } catch let error as ExchangeRateError {
            rateStatus = .failed(error.message)
        } catch {
            rateStatus = .failed(ExchangeRateError.invalidResponse.message)
        }
    }

    // MARK: 読み込みと保存

    private func load() {
        if let expense {
            title = expense.title
            category = expense.category
            date = expense.date
            note = expense.note
            currencyCode = expense.currency
            if expense.isForeign, let original = expense.originalAmount {
                amountText = NSDecimalNumber(decimal: original).stringValue
                rateText = expense.rate.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
                // 保存してあるレートをそのまま使う。支出日などを変えたときは、自動で取り直す
                autoRateText = rateText
                skipNextFetch = true
            } else {
                amountText = String(expense.amount)
            }
        } else if let trip = store.trip(tripID) {
            let cal = Calendar.current
            let start = cal.startOfDay(for: trip.startDate)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: trip.endDate)) ?? trip.endDate
            let now = Date()
            date = (now >= start && now < end) ? now : trip.startDate
            // その旅行で最後に使った通貨を、最初から選んでおく(イタリア旅行なら、2件目からユーロになる)
            currencyCode = trip.expenses.last?.currency ?? Currency.yenCode
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var value = expense ?? Expense(title: "", amount: 0, category: category, date: date)
        value.title = trimmed.isEmpty ? category.label : trimmed
        value.amount = yenAmount
        value.currency = currencyCode
        value.originalAmount = currency.isYen ? nil : inputAmount
        value.rate = currency.isYen ? nil : rate
        value.category = category
        value.date = date
        value.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        // 保存に失敗したときは、入力した内容を残したまま閉じない
        guard store.saveExpense(value, in: tripID) else { return }
        dismiss()
    }
}
