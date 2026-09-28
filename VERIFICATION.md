# Milestone 2 verification

Verified September 28, 2026 with Xcode 27.0 beta (27A5209h), macOS 27.2 on Apple silicon, and an iPhone 17 Pro simulator running iOS 26.0.

| Check | Result |
| --- | --- |
| Native Mac and iPhone Simulator builds | Passed |
| 12 Swift Testing data/rules tests | Passed |
| Existing-store upgrade | Created a real V1 disk store, upgraded to V2, reopened twice; retained IDs, purchase fields, warranty relationship/dates/provider and custom defaults |
| Card history | Changed card digits, reopened the disk store, checked old/new purchase links, original card coverage, account rename/archive and deletion behavior |
| Coverage rules | Checked unknown, ongoing, future start, inclusive cancellation day, invalid dates and independent coverage terms |
| Catalog/search rules | Checked one-time defaults, case-insensitive duplicate rejection, archive/rename links, all-field vs Store scope, amount/notes and historical card-digit search |
| Mac inventory UI | Passed add/edit/cancel/relaunch, adding monthly coverage, retaining saved details, removing one coverage while retaining the other, and deleting an item |
| Mac Settings UI | Passed card creation, adding a usage location and showing a duplicate-name error in the editor |
| iPhone UI | Both workflows passed: add/relaunch/detail and card creation/replacement, purchase linking, monthly coverage, and navigating from a card to its purchase after relaunch |
| Visual review | Mac multiple-coverage detail, organization settings and iPhone purchase/coverage screenshots inspected |

All 14 Mac data/UI checks passed in `build/Milestone2-Mac-Final.xcresult`. The final Mac Settings selector was then verified in `build/Milestone2-Settings-Final.xcresult`. iPhone results: `build/Milestone2-iOS-First.xcresult`; the final shared source also passed an iPhone Simulator build. These result bundles and synthetic screenshots are ignored by Git.

The tests found and fixed case-sensitive duplicate catalog names. Mac Settings uses a native segmented section selector and clearly labelled Add/Update buttons at the bottom of its pages. The tests use the actual native accessibility controls, including scoping confirmation buttons to sheets to exclude duplicate Touch Bar actions.

## Scope and limits

- Milestone 2 remains local-only. Attachments are milestone 3; private iCloud sync completes the first MVP in milestone 4. AI and share extensions follow later.
- Card number fields accept exactly four ASCII digits each. No full-number or security-code field exists. Replacing card details creates a new version; nickname changes do not. Historical coverage is never recalculated when a card or purchase changes.
- Coverage terms remain manual. Ongoing does not verify payment or eligibility. Cancellation records the final covered day, inclusive.
- Archived cards and classifications retain existing links. Archiving is reversible. Removing coverage and deleting items require confirmation.
- Physical iPhone install and macOS 26 runtime behavior still require device testing. Deployment remains iOS/macOS 26; the simulator exercises iOS 26.0.
- The beta toolchain reports debugger-version diagnostics and an internal thread-priority warning during Mac UI testing. These did not prevent the verified workflows from passing.
- UI test data uses isolated disk stores. The hosted unit-test app uses an in-memory store via a test-only scheme environment setting; data tests create their own temporary stores. The tests do not modify the user's inventory. No user receipts, real card information, credentials or screenshots are committed.

Milestone 1 verification history remains in Git.
