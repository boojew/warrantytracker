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
}
