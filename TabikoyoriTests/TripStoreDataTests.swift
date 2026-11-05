import Foundation
import Testing
@testable import Tabikoyori

// MARK: - 予算と支出

@Suite("予算と支出の操作(TripStore)")
struct TripStoreMoneyTests {

    @Test("予算を保存する。0 以下のカテゴリーは未設定にし、全体の予算はマイナスにしない")
    func savesBudgets() throws {
        let trip = Fixtures.trip()
        let store = Fixtures.store(with: [trip])

        store.setBudgets(total: -500, categories: [.food: 20_000, .shopping: 0, .transport: -1], for: trip.id)

        let saved = try #require(store.trip(trip.id))
        #expect(saved.budget == 0)
        #expect(saved.categoryBudget(.food) == 20_000)
        #expect(saved.categoryBudgets[ExpenseCategory.shopping.rawValue] == nil)
        #expect(saved.categoryBudgets[ExpenseCategory.transport.rawValue] == nil)
    }

    @Test("同じ ID の支出を保存すると、追加ではなく書き換える")
    func updatesExistingExpense() throws {
        let trip = Fixtures.trip()
        let store = Fixtures.store(with: [trip])
        var expense = Fixtures.expense(1_000)

        store.saveExpense(expense, in: trip.id)
        expense.amount = 1_500
        store.saveExpense(expense, in: trip.id)

        let saved = try #require(store.trip(trip.id))
        #expect(saved.expenses.count == 1)
        #expect(saved.totalSpent == 1_500)
    }

    @Test("支出を削除すると、合計から消える")
    func deletesExpense() throws {
        let trip = Fixtures.trip()
        let store = Fixtures.store(with: [trip])
        let lunch = Fixtures.expense(1_000)
        let dinner = Fixtures.expense(3_000)
        store.saveExpense(lunch, in: trip.id)
        store.saveExpense(dinner, in: trip.id)

        store.deleteExpense(lunch.id, from: trip.id)

        #expect(store.trip(trip.id)?.totalSpent == 3_000)
    }

    @Test("存在しない旅行には保存できず、false を返す")
    func failsForUnknownTrip() {
        let store = Fixtures.store()
        #expect(store.saveExpense(Fixtures.expense(1_000), in: UUID()) == false)
    }
}

// MARK: - 持ち物

@Suite("持ち物の操作(TripStore)")
struct TripStorePackingTests {

    @Test("チェックを付けて、もう一度押すと外れる")
    func togglesPacking() {
        var trip = Fixtures.trip()
        let toothbrush = PackingItem(name: "歯ブラシ", category: .toiletries)
        trip.packing = [toothbrush]
        let store = Fixtures.store(with: [trip])

        store.togglePacking(toothbrush.id, in: trip.id)
        #expect(store.trip(trip.id)?.packedCount == 1)

        store.togglePacking(toothbrush.id, in: trip.id)
        #expect(store.trip(trip.id)?.packedCount == 0)
    }

    @Test("テンプレートを追加すると、すでにある名前の持ち物は飛ばし、追加した数を返す")
    func addsTemplateWithoutDuplicates() throws {
        var trip = Fixtures.trip()
        trip.packing = [PackingItem(name: "充電器", category: .electronics)]
        let store = Fixtures.store(with: [trip])
        let template = PackingTemplate.domestic

        let added = store.addTemplate(template, to: trip.id)

        let names = try #require(store.trip(trip.id)).packing.map(\.name)
        #expect(added == template.entries.count - 1)          // 充電器の分だけ少ない
        #expect(names.filter { $0 == "充電器" }.count == 1)    // 充電器は1つのまま
    }

    @Test("別の旅行の持ち物を、チェックを外した新しい持ち物としてコピーする")
    func copiesPackingUnchecked() throws {
        var previous = Fixtures.trip(title: "前の旅行")
        let camera = PackingItem(name: "カメラ", category: .electronics, checked: true)
        previous.packing = [camera]
        let next = Fixtures.trip(title: "次の旅行")
        let store = Fixtures.store(with: [previous, next])

        let added = store.copyPacking(from: previous.id, to: next.id)

        let copied = try #require(store.trip(next.id)?.packing.first)
        #expect(added == 1)
        #expect(copied.name == "カメラ")
        #expect(copied.checked == false)
        #expect(copied.id != camera.id)
    }
}

// MARK: - お気に入り

@Suite("お気に入りの操作(TripStore)")
struct TripStoreBookmarkTests {

    @Test("お気に入りに入れて、もう一度押すと外れる")
    func togglesBookmark() {
        let store = Fixtures.store()
        let spot = Fixtures.spot()

        store.toggleBookmark(spot)
        #expect(store.bookmarks.contains(spot.id))

        store.toggleBookmark(spot)
        #expect(!store.bookmarks.contains(spot.id))
    }
}
