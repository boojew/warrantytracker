import XCTest

final class iOSInventoryUITests: XCTestCase {
    @MainActor
    func testOptionalPurchaseDateAndLocalSyncStatus() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 10))
        app.buttons["emptyAddItem"].tap()
        app.textFields["itemName"].tap(); app.textFields["itemName"].typeText("Optional date")
        if !app.buttons["purchaseDate"].isHittable { app.swipeUp() }
        app.buttons["purchaseDate"].tap()
        XCTAssertTrue(app.buttons["setPurchaseDate"].waitForExistence(timeout: 5))
        let calendarShot = XCTAttachment(screenshot: app.screenshot())
        calendarShot.name = "Optional date calendar on iPhone"; calendarShot.lifetime = .keepAlways; add(calendarShot)
        app.buttons["setPurchaseDate"].tap()
        XCTAssertTrue(app.buttons["setPurchaseDate"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["clearPurchaseDate"].exists)
        app.buttons["clearPurchaseDate"].tap()
        XCTAssertFalse(app.buttons["clearPurchaseDate"].exists)
        app.buttons["saveItem"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Optional date"].firstMatch.waitForExistence(timeout: 10))
        app.staticTexts["Optional date"].firstMatch.tap()
        app.buttons["editItem"].tap()
        if !app.buttons["purchaseDate"].isHittable { app.swipeUp() }
        XCTAssertFalse(app.buttons["clearPurchaseDate"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Optional purchase date on iPhone"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Cancel"].tap()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Storage & Sync"].tap()
        XCTAssertTrue(app.staticTexts["iCloud is not enabled in this build. Your inventory stays on this device and remains available offline."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReceiptPhotoReview() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 15))
        app.buttons["emptyAddItem"].tap()
        app.textFields["itemName"].tap(); app.textFields["itemName"].typeText("Test camera")
        app.buttons["addReceipt"].tap()
        XCTAssertTrue(app.buttons["choosePhoto"].waitForExistence(timeout: 5))
        app.buttons["choosePhoto"].tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 5))
        // Use a simulator with stock photos, or seed a synthetic image with simctl addmedia.
        let photo = app.images["PXGGridLayout-Info"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5), "Add a synthetic photo to the simulator before running this test.")
        // Photos exposes its grid thumbnails as non-hittable images on this simulator.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let canvas = app.images["redactionCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["saveAttachment"].isEnabled)
        app.descendants(matching: .any)["coverAreas"].tap()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.15)))
        XCTAssertTrue(app.buttons["undoCover"].isEnabled)
        let reviewShot = XCTAttachment(screenshot: app.screenshot())
        reviewShot.name = "iPhone reviewed photo"; reviewShot.lifetime = .keepAlways; add(reviewShot)
        app.buttons["saveAttachment"].tap()
        XCTAssertTrue(app.buttons["choosePhoto"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["saveItem"].waitForExistence(timeout: 10))
        app.buttons["saveItem"].tap()
        XCTAssertTrue(app.buttons["saveItem"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Test camera"].firstMatch.waitForExistence(timeout: 10))
        app.staticTexts["Test camera"].firstMatch.tap()
        if !app.buttons["itemAttachments"].isHittable { app.swipeUp() }
        app.buttons["itemAttachments"].tap()
        app.staticTexts["Receipt"].firstMatch.tap()
        XCTAssertTrue(app.images["savedImage"].waitForExistence(timeout: 5))
        app.buttons["useMainPhoto"].tap()
        XCTAssertTrue(app.staticTexts["Main photo"].exists)
        let savedShot = XCTAttachment(screenshot: app.screenshot())
        savedShot.name = "iPhone saved photo"; savedShot.lifetime = .keepAlways; add(savedShot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["addAttachment"].tap()
        XCTAssertTrue(app.buttons["takeAttachmentPhoto"].waitForExistence(timeout: 5))
        app.buttons["takeAttachmentPhoto"].tap()
        if app.alerts["Unable to import"].waitForExistence(timeout: 2) {
            app.alerts.buttons["OK"].tap()
        } else {
            XCTAssertTrue(app.buttons["PhotoCapture"].waitForExistence(timeout: 5))
            app.buttons["DismissImagePickerButton"].tap()
            XCTAssertTrue(app.buttons["PhotoCapture"].waitForNonExistence(timeout: 5))
        }
        app.navigationBars["Add Attachment"].buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["addAttachment"].waitForExistence(timeout: 5))
    }

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
