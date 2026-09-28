# Milestone 3 verification

Verified September 28, 2026 with Xcode 27.0 beta (27A5209h), macOS 27.2 on Apple silicon, and an iPhone 17 Pro simulator running iOS 26.0. Deployment remains iOS/macOS 26.

## Completed checks

| Check | Result |
| --- | --- |
| Native builds and icon | Mac and iPhone Simulator builds pass; both generated bundles reference AppIcon, and the Mac bundle contains AppIcon.icns |
| 18 Swift Testing checks | Passed: existing purchase/warranty/card rules plus six attachment processing/storage tests |
| Existing-store upgrade | Real V1 and V2 disk stores upgrade to V3; purchases, warranty terms, card links, classifications and defaults remain |
| Attachment persistence | Main photo, five extras and a coverage PDF survive reopening; saved bytes and thumbnails match; deleting attachments/coverage/items preserves unrelated cards |
| Image processing | Covers replace the saved pixels and thumbnail pixels; source EXIF/GPS metadata is absent; image orientation is normalized |
| PDF processing | Multiple pages, rotation and visible annotations are retained as pixels; covered source text is no longer selectable; original annotations are absent from the saved PDF |
| Input limits | Empty, corrupt, oversized and over-20-page inputs are rejected; PDFs cannot be selected as the main item photo |
| Mac inventory/settings regression | Passed add/edit/cancel/relaunch/delete, independent coverage, card creation, and catalog duplicate validation |
| Mac image workflow | Passed native file import, required review, drawing a cover, save/relaunch, setting the main photo and confirmed deletion |
| Mac PDF workflow | Passed page navigation, cancelling an item with a pending PDF, importing again, saving/relaunching and native PDF viewing |
| iPhone inventory/card regression | Passed item create/relaunch and card history/independent monthly coverage workflows |
| iPhone attachment workflow | Passed Photos import, drawing a cover, required review confirmation, save/relaunch, setting the main photo, and cancelling camera/import |

Mac results: `build/Milestone3-Mac-Complete.xcresult` (18 data tests and three UI tests), plus `build/Milestone3-Mac-PDF-Verified.xcresult` (the added PDF/cancellation UI test). The two iPhone regression workflows passed in `build/Milestone3-iOS-Complete.xcresult`; the final photo workflow passed in `build/Milestone3-iOS-PhotoFinal.xcresult`. Together, 22 Mac checks and three iPhone UI workflows passed.

The Mac reviewed-image and saved-PDF screenshots and iPhone reviewed/saved-photo screenshots were inspected. Test result bundles and screenshots are ignored by Git. Native accessibility controls differ by platform: Mac static text often uses a value rather than a label, PDFKit exposes a document group, and the Photos grid uses image elements.

## Scope and limits

- This milestone remains local-only. Private iCloud sync is milestone 4 and completes the first MVP. OCR, AI suggestions, warranty-policy research and share extensions are not included.
- Review/redaction is manual. The app cannot guarantee that a user has covered every sensitive detail. Only the approved rendered copy enters the app's inventory; original files in Photos/Files are unchanged. Saved covers are permanent in that copy. This is not a secure-erasure guarantee for OS caches or older backups.
- Files are capped at 30 MB and PDFs at 20 pages plus a 32-million-pixel total rendering budget. Images are reduced to 4,096 pixels on the longest side; PDF pages render at up to 144 dpi and 2,400 pixels per side. Fine print and codes need a visual check before accepting the copy.
- Attachment names and purposes participate in search; text inside images/PDFs does not yet. No warranty dates or terms are inferred from an attachment.
- Physical iPhone camera capture, camera permission denial on hardware, macOS 26 runtime behavior, accessibility at larger text sizes and landscape layouts still need device review. This simulator exposes a camera interface, but opening it does not verify physical-device capture quality or permissions.
- Only first/last four card digits are accepted by card fields. Coverage remains manual and independent; historical card coverage is never recalculated automatically.
- The beta toolchain reports debugger-version diagnostics and an internal thread-priority warning during Mac UI testing. The passing iPhone photo workflow also reports an invalid-frame warning without an app source location. Its inspected screens render correctly, but the warning remains unresolved and should be rechecked on physical devices/stable Xcode. These diagnostics did not prevent the verified workflows from passing.
- UI tests use isolated on-disk inventories. Unit tests use temporary stores and an in-memory host. No personal receipts, credentials or test screenshots are committed. The iPhone photo test uses a simulator stock/synthetic photo; see README for seeding its library.

Earlier milestone verification remains in Git.
