# Milestone 4 preparation and verification

Verified September 28–29, 2026 with Xcode 27.0 beta (27A5209h), macOS 27.2 on Apple silicon, and an iPhone 17 Pro simulator running iOS 26.0. Deployment remains iOS/macOS 26.

**Private iCloud sync is implemented but has not passed two-device acceptance.** The developer uses a free Personal Team, so container registration, provisioning and live CloudKit transfers remain pending. Normal schemes remain local and runnable. See `ICLOUD_SETUP.md` for activation and the uncompleted acceptance checklist.

## Completed checks

| Check | Result |
| --- | --- |
| Local native builds | Mac and iPhone Simulator pass |
| Separate cloud builds | Both `-iCloud` schemes compile unsigned; compiled Info.plists contain the enabled flag and expected container; iOS contains `remote-notification` background mode |
| Normal build isolation | Compiled normal Info.plists do not enable cloud; tests force local mode and do not access CloudKit accounts |
| 23 Swift Testing checks | Passed, including five new date/sync-preparation checks and the 18 existing inventory/attachment checks |
| Store migration | Real V1/V2/V3 disk stores upgrade to V4; purchase details, warranties, card links, defaults and attachment data survive |
| Before-cloud backup | A V3 store with a 2 MB external attachment is copied using Core Data; both source and backup reopen successfully as V4, with the main-photo relationship and contents intact |
| Backup retention | Subsequent calls do not overwrite the original snapshot after records are deleted from the source |
| Store location | Local and cloud configurations retain the same database URL and configuration name |
| Duplicate defaults | Synthetic duplicate list seeds converge, display once in selectors, preserve item links, support rename/archive and remain idempotent without deleting underlying records |
| Status events | Overlapping upload/download operations and independent failures remain visible; a successful download does not erase an upload error or claim everything is synchronized |
| Optional purchase date | Add, clear, save/relaunch and draft cancellation checks pass; an omitted date remains nil |
| Attachment consent removal | Mac and iPhone import workflows can save a named attachment without a consent checkbox; cover tools remain functional |
| Mac UI regression | Five workflows pass: inventory/coverage edit and persistence, cards/settings, photo import/cover/delete, PDF import/cancel/save and optional date/local storage status |
| iPhone UI regression | Four workflows pass: inventory persistence, card history/coverage, photo review and optional date/local storage status |

## Evidence

- `build/Milestone4-Mac-Isolated.xcresult`: **28 passed** (23 data tests + five UI workflows), zero failures/skips.
- `build/Milestone4-iOS-First.xcresult`: **four UI workflows passed**, zero failures/skips.
- `build/Milestone4-iOS-Calendar.xcresult`: final date/calendar workflow passed after fixing the clipped half-height calendar sheet. The complete month, Cancel and Set Date are visible in the inspected screenshot.
- `build/Milestone4-Mac-Calendar.xcresult`: final Mac date/calendar workflow passed after the shared scrolling adjustment.
- Cloud build logs: `/tmp/warranty-m4-cloud-final-macOS.log` and `/tmp/warranty-m4-cloud-final-iOS.log`; generated bundles live under `build/cloud-mac` and `build/cloud-ios`. Unsigned compilation is not validation of signing, schema creation or actual syncing.

Mac automation initially failed to find a window when testing under the same application identifier as an existing Xcode-launched copy. A direct isolated launch worked, and the full suite passed after giving the automated app a separate `.automation` bundle identity. The optional `WARRANTYTRACKER_TEST_BUNDLE_SUFFIX` build argument supports that isolation without changing normal app IDs. The main Mac window now also has a stable identifier and explicit launch presentation. See the test command in README.

Test result bundles, screenshots and synthetic fixtures are ignored by Git. Tests use isolated on-disk stores or an in-memory host; no personal inventory was used for verification. The source schemas V1–V3 remain unchanged.

## Remaining verification and limitations

- All live CloudKit acceptance remains pending: signed configuration, initial upload/merge, notifications, attachments, two-way edits, offline recovery, deletes, conflicting edits, account changes and quota failures. The first synced MVP is not yet accepted.
- Settings reports account/operation status, not a guarantee that every change reached every device. Upload/download timestamps are session-local. There is no custom conflict chooser; real framework conflict behavior still needs testing.
- The pre-cloud snapshot is made once, before opening the existing store with cloud enabled. It is not a rolling backup and has no user-facing Restore button.
- Receipt text recognition, AI extraction, automated warranty-policy research and share extensions are not part of this milestone. All coverage remains manually entered and editable.
- The supplied icon and prior attachment limits remain: 30 MB input, 20 PDF pages with a 32-million-pixel rendering budget; images max 4,096 pixels per side, PDF pages up to 144 dpi and 2,400 pixels per side. Review/redaction is manual. Covers permanently replace pixels in the saved copy, and source files remain unchanged.
- Physical iPhone camera capture/permission denial, macOS 26 runtime, landscape layouts and larger accessibility text still need hardware review.
- The beta toolchain reports debugger-version diagnostics and internal thread-priority warnings. The passing iPhone photo workflow retains a framework invalid-frame warning without an app source location (also present in milestone 3); the final date/calendar workflow has no runtime warnings. These diagnostics did not prevent the passing workflows, but should be rechecked on stable Xcode and devices.

Earlier milestone verification remains in Git.
