# WarrantyTracker

A native SwiftUI warranty inventory for iPhone and Mac. Development happens on `dev`; small verified changes are committed and pushed regularly.

## Current milestone

Milestone 3: local inventory, independent warranties, card history, scoped search, and reviewed photos/PDFs. Canada/CAD defaults remain editable. Existing records upgrade automatically. Your supplied icon is included on iPhone and Mac. AI and iCloud sync come in later milestones.

Requires iOS 26+ / macOS 26+ and Xcode 26+ with the appropriate SDK. Use current stable Xcode for everyday development. This first implementation is being verified with the already-installed Xcode 27 beta.

## Open and run

1. In Codex, open `/Users/babecassis/CodexProjects/warrantytracker`.
2. In Xcode, open `WarrantyTracker.xcodeproj` inside that folder.
3. For Mac, select the **WarrantyTracker-macOS** scheme, choose **My Mac**, and press **Command-R**.
4. For iPhone Simulator, install an iOS runtime in Xcode Settings → Components (called Platforms in some versions), select **WarrantyTracker-iOS**, choose an iPhone simulator, and press **Command-R**.
5. For your real iPhone, connect it, trust the Mac, enable Developer Mode, and select your Apple development team in the iOS target's Signing & Capabilities. Choose the phone as the run destination.

If command-line builds report that Xcode is missing, select full Xcode under Xcode Settings → Locations → Command Line Tools. Alternatively, set `DEVELOPER_DIR` for a command without changing global settings:

```sh
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project WarrantyTracker.xcodeproj -scheme WarrantyTracker-macOS -destination 'platform=macOS' -derivedDataPath build/mac build
```

## Verify milestone 3 yourself

1. Add an item. Directly below its name, choose **Add Receipt Photo or PDF**. On Mac use Photos or the file picker; on iPhone you can also take a photo.
2. In the review screen, enter a useful attachment name and choose its purpose. Zoom to read small text. Turn on **Cover areas** and drag over any full card numbers, security codes or other sensitive information. Turn covering off to scroll. Use the arrows to review every PDF page.
3. Check **I reviewed every page for sensitive information**, then choose **Use Reviewed Copy**. Save the item. Cancelling the item discards its pending attachments.
4. For an existing item, open **Photos & Documents → Attachments**. Add an item photo, serial-number photo and five or more extras. Open an image and choose **Use as Main Photo**; it should appear in the main inventory list.
5. Under an individual warranty, open **Documents** to attach that plan's photos or PDFs. Those documents belong to that specific coverage record.
6. Open an attachment to zoom/read it, edit its name/purpose, add further permanent covers, or delete it. Search by **Attachment names** to find its item (document contents are not searched yet).
7. Quit and reopen. Confirm that the images, covered areas, main photo and PDF pages remain. Cancel an import/edit and confirm the saved record is unchanged. Deleting a coverage removes its documents; deleting an item removes all of its documents.

Review is manual: the app does not detect sensitive numbers automatically or extract receipt/warranty information yet. It stores a newly rendered copy after review, with the covered pixels replaced and source image metadata removed. PDFs become image-only pages, so their original selectable text and editable annotations are not retained. Covers in a saved copy cannot be undone. Source files in Photos/Files remain unchanged.

Files must be no larger than 30 MB. PDFs support up to 20 pages, subject to a total rendered-page limit of 32 million pixels. Images are reduced to at most 4,096 pixels on their longest side; PDFs render at up to 144 dpi and 2,400 pixels per page side. Check fine print, barcodes and setup codes for legibility before saving. Split a large PDF into smaller files if needed. Attachments use local device storage; iCloud sync is milestone 4.

## Check the existing inventory features

- Your milestone-1 items should still appear, with their original purchase details and warranty dates.
- Open **Settings** (Mac: Command-comma; iPhone: Settings tab). Under **Cards**, add a synthetic card with first four **1234** and last four **5678**, bank, network, product name, and nickname. No full-number or security-code field exists.
- Add a TV from Costco. Choose its purchase card, category, usage location and tags. Enter the manufacturer warranty end date from your own documents.
- Open the TV and choose **Add Coverage**. Add a separate retailer plan with a fixed end date. Editing the item must not change either warranty.
- Add a pool pump with a separate credit-card warranty. Enter its extension, limits and exclusions manually; no policy terms are inferred.
- Add an Apple Watch and an **AppleCare+** coverage record with **Ongoing / monthly** duration. Record a cancellation with its final covered day. It shows cancellation scheduled through that day, then cancelled.
- Add a Kobo with an unknown end date. It must say **End date unknown**, never lifetime or ongoing.
- Update your card's last four digits to **9012** in Settings. Earlier purchases stay linked to **5678**. New purchases can use **9012**. Open the card to see purchases across both versions.
- In Settings, add/rename/archive a tag or location. Renaming updates its linked items; archiving preserves existing links and removes the choice from new selections. Restore it using **Show archived entries**.
- Search **Home**, then change **Search in** to **Store**. Results should include Home Depot but exclude an item matching only a Home location or name.
- Quit and reopen. Check that the items, card history, organization and all coverage records remain.
- Cancel an item/card/coverage edit and confirm that nothing changed. Remove one coverage record and confirm that other warranties remain. Deleting an item removes its coverages but keeps the card and category lists.

Card and list management are in Settings. Cards are optional, and archiving a card keeps its history. Each warranty has independent dates; extensions are never automatically added together. These are your recorded terms, not verification of eligibility or payment.

Dates are calendar days, not timestamps. The entered end date is inclusive. Prices are stored as exact decimal text; leave a price blank when unknown. Price entry accepts a decimal separator, without a currency symbol or thousands separators. Existing records never undergo currency conversion when defaults change.

## Automated checks

The Mac scheme includes Swift Testing checks for storage upgrades, purchase/warranty rules, attachment persistence and image/PDF processing, plus native UI workflows. The iOS scheme includes inventory, card/coverage and photo-review UI workflows. UI tests use separate on-disk stores so relaunch tests do not affect your inventory.

```sh
xcodebuild -project WarrantyTracker.xcodeproj -scheme WarrantyTracker-macOS -destination 'platform=macOS' -derivedDataPath build/mac test
xcodebuild -project WarrantyTracker.xcodeproj -scheme WarrantyTracker-iOS -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios CODE_SIGNING_ALLOWED=NO build
xcodebuild -project WarrantyTracker.xcodeproj -scheme WarrantyTracker-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' -derivedDataPath build/ios -parallel-testing-enabled NO test
```

UI tests may require permission for Xcode's test runner to control the Mac. Test stores are inside the app's local Application Support/UITests directory. Unit-test stores are temporary and removed by the tests; their host app uses a separate in-memory store.

The iPhone photo UI test needs at least one synthetic or stock photo in the simulator library. To add one, run `xcrun simctl addmedia booted /path/to/synthetic-receipt.png` with the simulator booted. Do not use personal receipts for tests. Use a simulator device name and OS version installed on your Mac. An iOS 26.0 runtime and iPhone 17 Pro simulator were installed and used for this milestone. The Mac UI test also exercises Command-N to create an item.

## Structure

- `WarrantyTracker/`: shared native screens, editing drafts, calendar/money rules, versioned SwiftData models, attachment review/processing and app-icon assets.
- `WarrantyTrackerTests/`: price/date validation, saved-store reopening, relationships, draft isolation, and defaults.
- `WarrantyTrackerUITests/`: add/edit/cancel/relaunch/delete workflow.
- `WarrantyTracker.xcodeproj/`: separate native iOS and macOS targets with shared source; no third-party dependencies.

The database is local-only explicitly (`cloudKitDatabase: .none`). Optional inverse relationships and default values prepare it for CloudKit, but synchronization is not enabled merely by that preparation. Versioned schema changes must preserve user data.

## Data hygiene

Do not put real receipts, card details, private exports, credentials, or signing certificates in this repository. `PrivateTestData/`, build outputs, and local Xcode state are ignored. Use synthetic data in tests and screenshots.
