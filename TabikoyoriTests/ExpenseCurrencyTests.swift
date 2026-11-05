import Foundation
import Testing
@testable import Tabikoyori

@Suite("外貨の換算(CurrencyConversion)")
struct CurrencyConversionTests {

    @Test("外貨の金額 × レートを、四捨五入して円にする")
    func convertsAndRounds() throws {
        let amount = try #require(Decimal(string: "12.50"))
        let rate = try #require(Decimal(string: "162.45"))
        // 12.50 × 162.45 = 2030.625 → 2031円
        #expect(CurrencyConversion.yen(from: amount, rate: rate) == 2031)

        // 10 × 0.1149 = 1.149 → 1円(ウォンのような、1単位が1円より安い通貨)
        let won = try #require(Decimal(string: "10"))
        let wonRate = try #require(Decimal(string: "0.1149"))
        #expect(CurrencyConversion.yen(from: won, rate: wonRate) == 1)
    }

    @Test("入力された文字を数字に変える。数字でないものは nil")
    func parsesInput() {
        #expect(CurrencyConversion.parse("1,234.5") == Decimal(string: "1234.5"))
        #expect(CurrencyConversion.parse("") == nil)
        #expect(CurrencyConversion.parse("12a") == nil)
        #expect(CurrencyConversion.parse("1.2.3") == nil)
    }
}

@Suite("支出の保存データ(Expense)")
struct ExpenseDecodingTests {

    @Test("通貨の項目がない古いデータは、円として読み込む")
    func decodesOldDataAsYen() throws {
        let json = """
        {"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3301","title":"ランチ","amount":1200,"category":"food","date":0,"note":""}
        """
        let expense = try JSONDecoder().decode(Expense.self, from: Data(json.utf8))
        #expect(expense.amount == 1200)
        #expect(expense.currency == "JPY")
        #expect(expense.originalAmount == nil)
        #expect(!expense.isForeign)
    }

    @Test("外貨の支出は、保存して読み込み直しても同じ内容になる")
    func roundTripsForeignExpense() throws {
        var expense = Expense(title: "ランチ", amount: 2031, category: .food, date: Date(timeIntervalSinceReferenceDate: 0))
        expense.currency = "EUR"
        expense.originalAmount = Decimal(string: "12.50")
        expense.rate = Decimal(string: "162.45")

        let data = try JSONEncoder().encode(expense)
        let decoded = try JSONDecoder().decode(Expense.self, from: data)
        #expect(decoded == expense)
    }
}
