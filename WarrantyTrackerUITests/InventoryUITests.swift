import XCTest

final class InventoryUITests: XCTestCase {
    @MainActor
    func testAddEditCancelRelaunchAndDelete() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 10))
        app.buttons["emptyAddItem"].click()
        let name = app.textFields["itemName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("Living room TV")
        app.textFields["retailer"].click()
        app.textFields["retailer"].typeText("Costco")
        app.textFields["price"].click()
        app.textFields["price"].typeText("999.99")
        app.buttons["saveItem"].click()
        XCTAssertTrue(app.buttons["editItem"].waitForExistence(timeout: 5))
        app.buttons["editItem"].click()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Unsaved name")
        app.buttons["Cancel"].click()
        XCTAssertFalse(app.staticTexts["Unsaved name"].exists)
        app.buttons["editItem"].click()
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Bedroom TV")
        app.buttons["saveItem"].click()
        app.terminate()
        app.launch()
        let row = app.staticTexts["Bedroom TV"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        XCTAssertTrue(app.buttons["editItem"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Costco"].firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved item after relaunch"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["deleteItem"].click()
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Delete Item", "deleteItem")).firstMatch.click()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 10))
    }
}
