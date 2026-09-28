import XCTest

final class iOSInventoryUITests: XCTestCase {
    @MainActor
    func testCreateAndReopenPurchase() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 15))
        app.buttons["emptyAddItem"].tap()
        let name = app.textFields["itemName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Kobo Clara")
        let retailer = app.textFields["retailer"]
        retailer.tap()
        retailer.typeText("Best Buy")
        app.buttons["saveItem"].tap()
        app.terminate()
        app.launch()
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Kobo Clara")).firstMatch
        let title = app.staticTexts["Kobo Clara"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10) || row.waitForExistence(timeout: 5))
        if title.exists { title.tap() } else { row.tap() }
        XCTAssertTrue(app.buttons["editItem"].waitForExistence(timeout: 5))
        let store = app.descendants(matching: .any)["purchaseStore"]
        XCTAssertTrue("\(store.label) \(store.value ?? "")".contains("Best Buy"))
        let status = app.descendants(matching: .any)["coverageStatus"]
        XCTAssertTrue("\(status.label) \(status.value ?? "")".contains("End date unknown"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "iPhone saved purchase"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testCardAndMonthlyCoverage() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Credit Cards"].tap()
        app.buttons["addCard"].tap()
        for (id, value) in [("cardNickname", "Travel"), ("cardBank", "Example Bank"),
                            ("cardProduct", "Privilege"), ("cardFirstFour", "1234"), ("cardLastFour", "5678")] {
            let field = app.textFields[id]
            if !field.isHittable { app.swipeUp() }
            field.tap(); field.typeText(value)
        }
        app.buttons["saveCard"].tap()
        let card = app.staticTexts["Travel"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.staticTexts["Current card"].exists)
        app.buttons["updateCard"].tap()
        let lastFour = app.textFields["cardLastFour"]
        if !lastFour.isHittable { app.swipeUp() }
        lastFour.tap()
        lastFour.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "9012")
        app.buttons["saveCard"].tap()
        XCTAssertTrue(app.staticTexts["Previous card"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Items"].tap()
        app.buttons["addItem"].tap()
        app.textFields["itemName"].tap()
        app.textFields["itemName"].typeText("Apple Watch")
        app.buttons["purchaseCardPicker"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT label CONTAINS %@", "9012", "Purchased with")).firstMatch.tap()
        app.buttons["saveItem"].tap()
        app.staticTexts["Apple Watch"].firstMatch.tap()
        let addCoverage = app.buttons["addCoverage"]
        if !addCoverage.isHittable { app.swipeUp() }
        addCoverage.tap()
        app.textFields["coverageName"].tap()
        app.textFields["coverageName"].typeText("AppleCare+")
        app.buttons["coverageDuration"].tap()
        app.buttons["Ongoing / monthly"].tap()
        app.buttons["saveCoverage"].tap()
        if !app.staticTexts["AppleCare+"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["AppleCare+"].exists)
        XCTAssertTrue(app.staticTexts["Ongoing / monthly"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "iPhone multiple coverage records"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate(); app.launch()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Credit Cards"].tap()
        app.staticTexts["Travel"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Apple Watch"].waitForExistence(timeout: 5))
        app.staticTexts["Apple Watch"].tap()
        XCTAssertTrue(app.buttons["editItem"].waitForExistence(timeout: 5))
    }

}
