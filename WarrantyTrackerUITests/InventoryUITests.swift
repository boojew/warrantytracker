import XCTest
import AppKit
import PDFKit

final class InventoryUITests: XCTestCase {
    @MainActor
    func testOptionalPurchaseDateAndLocalSyncStatus() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 10))
        app.typeKey("n", modifierFlags: .command)
        app.textFields["itemName"].click(); app.textFields["itemName"].typeText("Optional date")
        app.buttons["purchaseDate"].click()
        XCTAssertTrue(app.buttons["setPurchaseDate"].waitForExistence(timeout: 5))
        let calendarShot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        calendarShot.name = "Optional date calendar on Mac"; calendarShot.lifetime = .keepAlways; add(calendarShot)
        app.buttons["setPurchaseDate"].click()
        XCTAssertTrue(app.buttons["setPurchaseDate"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["clearPurchaseDate"].exists)
        app.buttons["saveItem"].click()
        app.terminate(); app.launch(); app.activate()
        let row = app.outlines.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Optional date")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.click()
        app.buttons["editItem"].click()
        XCTAssertTrue(app.buttons["clearPurchaseDate"].waitForExistence(timeout: 5))
        app.buttons["clearPurchaseDate"].click()
        XCTAssertFalse(app.buttons["clearPurchaseDate"].exists)
        app.buttons["saveItem"].click()
        app.buttons["editItem"].click()
        XCTAssertTrue(app.buttons["purchaseDate"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["clearPurchaseDate"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Optional purchase date on Mac"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Cancel"].click()
        app.typeKey(",", modifierFlags: .command)
        app.radioButtons["General"].click()
        app.buttons["Storage & Sync"].click()
        XCTAssertTrue(app.staticTexts["iCloud is not enabled in this build. Your inventory stays on this device and remains available offline."].waitForExistence(timeout: 5))
    }

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
        app.buttons["Remove"].firstMatch.click()
        app.sheets.buttons["Remove Coverage"].click()
        XCTAssertEqual(app.buttons.matching(identifier: "Edit Coverage").count, 1)
        XCTAssertTrue(app.staticTexts["Monthly protection"].exists)
        app.buttons["deleteItem"].click()
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Delete Item", "deleteItem")).firstMatch.click()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSettingsCardsAndOrganization() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 10))
        app.typeKey(",", modifierFlags: .command)
        let cards = app.radioButtons["Cards"]
        XCTAssertTrue(cards.waitForExistence(timeout: 5))
        cards.click()
        app.buttons["addCard"].click()
        for (id, value) in [("cardNickname", "Everyday"), ("cardBank", "Example Bank"),
                            ("cardProduct", "Privilege"), ("cardFirstFour", "1234"), ("cardLastFour", "5678")] {
            app.textFields[id].click(); app.textFields[id].typeText(value)
        }
        app.buttons["saveCard"].click()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Everyday")).firstMatch.waitForExistence(timeout: 5))
        app.radioButtons["Organization"].click()
        app.buttons["Usage locations"].click()
        app.buttons["addCatalogEntry"].click()
        app.textFields["catalogName"].click()
        app.textFields["catalogName"].typeText("Basement")
        app.buttons["saveCatalogEntry"].click()
        XCTAssertTrue(app.buttons["Basement"].waitForExistence(timeout: 5))
        app.buttons["addCatalogEntry"].click()
        app.textFields["catalogName"].click()
        app.textFields["catalogName"].typeText("basement")
        app.buttons["saveCatalogEntry"].click()
        XCTAssertTrue(app.sheets.buttons["OK"].waitForExistence(timeout: 5))
        app.sheets.buttons["OK"].click()
        app.buttons["Cancel"].click()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Mac organization settings"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }


    @MainActor
    func testReceiptImportReviewRelaunchAndDelete() throws {
        continueAfterFailure = false
        let folder = FileManager.default.temporaryDirectory.appending(path: "WarrantyAttachment-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = NSImage(size: NSSize(width: 600, height: 800), flipped: false) { rect in
            NSColor.white.setFill(); rect.fill()
            NSAttributedString(string: "SYNTHETIC RECEIPT\nExample Store\nItem: Camera\nPre-tax: CAD 99.99", attributes: [
                .font: NSFont.systemFont(ofSize: 24), .foregroundColor: NSColor.black
            ]).draw(in: CGRect(x: 35, y: 540, width: 530, height: 220))
            return true
        }
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        let url = folder.appending(path: "sample-receipt.png")
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 10))
        app.typeKey("n", modifierFlags: .command)
        app.textFields["itemName"].click(); app.textFields["itemName"].typeText("Camera")
        app.buttons["addReceipt"].click()
        app.buttons["chooseAttachmentFile"].click()
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(url.path)
        app.typeKey(.return, modifierFlags: [])
        app.sheets["open-panel"].buttons["OKButton"].click()
        let canvas = app.images["redactionCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["saveAttachment"].isEnabled)
        app.descendants(matching: .any)["coverAreas"].click()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05))
            .click(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.13)))
        XCTAssertTrue(app.buttons["undoCover"].isEnabled)
        let reviewShot = XCTAttachment(screenshot: app.screenshot())
        reviewShot.name = "Receipt review with permanent cover"; reviewShot.lifetime = .keepAlways; add(reviewShot)
        app.buttons["saveAttachment"].click()
        XCTAssertTrue(app.buttons["saveItem"].waitForExistence(timeout: 10))
        app.buttons["saveItem"].click()
        app.terminate(); app.launch(); app.activate()
        let item = app.outlines.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Camera")).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10)); item.click()
        app.scrollViews.containing(.button, identifier: "itemAttachments").firstMatch.scroll(byDeltaX: 0, deltaY: -350)
        app.buttons["itemAttachments"].click()
        let receipt = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Receipt")).firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 5)); receipt.click()
        XCTAssertTrue(app.images["savedImage"].waitForExistence(timeout: 5))
        app.buttons["useMainPhoto"].click()
        XCTAssertTrue(app.staticTexts["Main photo"].exists)
        let savedShot = XCTAttachment(screenshot: app.screenshot())
        savedShot.name = "Saved reviewed receipt after relaunch"; savedShot.lifetime = .keepAlways; add(savedShot)
        app.buttons["deleteAttachment"].click()
        app.sheets.buttons["Delete Attachment"].click()
        XCTAssertTrue(app.buttons["addAttachment"].waitForExistence(timeout: 5))
        XCTAssertFalse(receipt.exists)
    }

    @MainActor
    func testPDFReviewCancelAndSave() throws {
        continueAfterFailure = false
        let url = FileManager.default.temporaryDirectory.appending(path: "SyntheticPolicy-\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = PDFDocument()
        for page in 1...2 {
            let image = NSImage(size: NSSize(width: 600, height: 800), flipped: false) { rect in
                NSColor.white.setFill(); rect.fill()
                NSAttributedString(string: "SYNTHETIC POLICY\nPage \(page)", attributes: [
                    .font: NSFont.systemFont(ofSize: 24), .foregroundColor: NSColor.black
                ]).draw(in: CGRect(x: 30, y: 550, width: 540, height: 200))
                return true
            }
            pdf.insert(try XCTUnwrap(PDFPage(image: image)), at: page - 1)
        }
        try XCTUnwrap(pdf.dataRepresentation()).write(to: url)
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString]
        app.launch(); app.activate()
        for shouldSave in [false, true] {
            XCTAssertTrue(app.buttons["emptyAddItem"].waitForExistence(timeout: 10))
            app.typeKey("n", modifierFlags: .command)
            app.textFields["itemName"].click(); app.textFields["itemName"].typeText("PDF test")
            app.buttons["addReceipt"].click()
            app.buttons["chooseAttachmentFile"].click()
            app.typeKey("g", modifierFlags: [.command, .shift]); app.typeText(url.path)
            app.typeKey(.return, modifierFlags: [])
            app.sheets["open-panel"].buttons["OKButton"].click()
            XCTAssertTrue(app.images["redactionCanvas"].waitForExistence(timeout: 10))
            app.buttons["Next page"].click()
            let indicator = app.staticTexts["pageIndicator"]
            XCTAssertTrue("\(indicator.label) \(indicator.value ?? "")".contains("Page 2 of 2"))
            app.buttons["saveAttachment"].click()
            XCTAssertTrue(app.buttons["saveItem"].waitForExistence(timeout: 10))
            app.buttons[shouldSave ? "saveItem" : "Cancel"].click()
            app.terminate(); app.launch(); app.activate()
        }
        let item = app.outlines.buttons.matching(NSPredicate(format: "label CONTAINS %@", "PDF test")).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10)); item.click()
        app.scrollViews.containing(.button, identifier: "itemAttachments").firstMatch.scroll(byDeltaX: 0, deltaY: -350)
        app.buttons["itemAttachments"].click()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Receipt")).firstMatch.click()
        // PDFKit exposes its native document group rather than the SwiftUI wrapper identifier.
        XCTAssertTrue(app.groups["document"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Saved two-page PDF"; shot.lifetime = .keepAlways; add(shot)
    }
}
