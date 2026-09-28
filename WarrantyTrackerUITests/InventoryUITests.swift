import XCTest

final class InventoryUITests: XCTestCase {
    @MainActor
    func testAddEditCancelRelaunchAndDelete() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch()
        app.activate()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 10))
        // Exercise the native New Item shortcut as well as the editor controls.
        app.typeKey("n", modifierFlags: .command)
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
        app.buttons["editItem"].click()
        XCTAssertEqual(name.value as? String, "Living room TV")
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Bedroom TV")
        app.buttons["saveItem"].click()
        // Add an independent ongoing plan through the native editor.
        app.buttons["addCoverage"].click()
        let planName = app.textFields["coverageName"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.click(); planName.typeText("Monthly protection")
        app.popUpButtons["coverageDuration"].click()
        app.menuItems["Ongoing / monthly"].click()
        app.buttons["saveCoverage"].click()
        XCTAssertTrue(app.staticTexts["Monthly protection"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.activate()
        let row = app.outlines.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bedroom TV")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        XCTAssertTrue(app.buttons["editItem"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Monthly protection"].waitForExistence(timeout: 5))
        app.buttons["editItem"].click()
        XCTAssertEqual(app.textFields["retailer"].value as? String, "Costco")
        XCTAssertEqual(app.textFields["price"].value as? String, "999.99")
        app.buttons["Cancel"].click()
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
