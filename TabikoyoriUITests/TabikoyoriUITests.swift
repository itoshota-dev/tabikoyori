import XCTest

/// アプリを実際に起動して、ボタンを押したり文字を入力したりして確かめるテスト(UI テスト)
final class TripCreationUITests: XCTestCase {

    override func setUpWithError() throws {
        // 途中で失敗したら、そこでテストを止める(画面がずれたまま操作を続けないように)
        continueAfterFailure = false
    }

    @MainActor
    func testCreatingTripShowsItOnHome() throws {
        // 端末のデータを使わず、空の状態で起動する(アプリ側で保存先をメモリに切り替える)
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        // 1. 右下の＋で、旅行の作成画面を開く
        let addButton = app.buttons["新しい旅行を作成"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // 2. 行き先が空のあいだは、「作成」を押せない
        let createButton = app.buttons["作成"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        XCTAssertFalse(createButton.isEnabled)

        // 3. 行き先に「沖縄」と入力すると、「作成」を押せるようになる
        let destinationField = app.textFields.matching(
            NSPredicate(format: "placeholderValue == %@", "例：京都、モンゴル、イタリア")
        ).firstMatch
        XCTAssertTrue(destinationField.waitForExistence(timeout: 5))
        destinationField.tap()
        destinationField.typeText("沖縄")
        XCTAssertTrue(createButton.isEnabled)

        // 4. 作成すると、ホームに「沖縄」の旅行が表示される
        createButton.tap()
        let tripCard = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "沖縄")
        ).firstMatch
        XCTAssertTrue(tripCard.waitForExistence(timeout: 5))
    }
}
