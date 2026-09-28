# WarrantyTracker

A native SwiftUI warranty inventory for iPhone and Mac. Development happens on `dev`; small verified changes are committed and pushed regularly.

## Current milestone

Milestone 1: local inventory. Add, edit, delete, and search items; record purchase details and a manufacturer warranty end date; change the Canada/CAD defaults. All data stays on the device. No card details, attachments, AI, or iCloud sync are implemented yet.

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

## Verify milestone 1 yourself

- Add a **Living room TV**, retailer **Costco**, price **999.99 CAD**, purchase date, and manufacturer end date. Check the detail view.
- Quit and reopen. The item and its details should still be there.
- Edit an item, then Cancel. Your original details should remain.
- Save an edit, restart, and check that it persists.
- Save an item with only a name. Its warranty must say **End date unknown**, not ongoing or lifetime.
- Try an invalid price or a warranty end date before the purchase date. A clear error should appear without losing your draft.
- Change defaults in Settings (Mac: Command-comma; iPhone: Settings tab). New items use the new defaults; existing items keep their original values.
- Delete an item and confirm. Reopen the app and check that it is still gone.

Dates are calendar days, not timestamps. The entered end date is inclusive. Prices are stored as exact decimal text; leave a price blank when unknown. Price entry accepts a decimal separator, without a currency symbol or thousands separators. Existing records never undergo currency conversion when defaults change.

## Automated checks

The Mac scheme contains Swift Testing unit/integration tests and an XCTest UI workflow. The UI test uses a separate on-disk store so relaunch tests do not affect your inventory.

```sh
xcodebuild -project WarrantyTracker.xcodeproj -scheme WarrantyTracker-macOS -destination 'platform=macOS' -derivedDataPath build/mac test
xcodebuild -project WarrantyTracker.xcodeproj -scheme WarrantyTracker-iOS -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios CODE_SIGNING_ALLOWED=NO build
```

UI tests may require permission for Xcode's test runner to control the Mac. Test stores are inside the app's local Application Support/UITests directory. Unit-test stores are temporary and removed by the tests.

## Structure

- `WarrantyTracker/`: shared native screens, editing drafts, calendar/money rules, versioned SwiftData models.
- `WarrantyTrackerTests/`: price/date validation, saved-store reopening, relationships, draft isolation, and defaults.
- `WarrantyTrackerUITests/`: add/edit/cancel/relaunch/delete workflow.
- `WarrantyTracker.xcodeproj/`: separate native iOS and macOS targets with shared source; no third-party dependencies.

The database is local-only explicitly (`cloudKitDatabase: .none`). Optional inverse relationships and default values prepare it for CloudKit, but synchronization is not enabled merely by that preparation. Versioned schema changes must preserve user data.

## Data hygiene

Do not put real receipts, card details, private exports, credentials, or signing certificates in this repository. `PrivateTestData/`, build outputs, and local Xcode state are ignored. Use synthetic data in tests and screenshots.
