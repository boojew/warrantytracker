# Milestone 1 verification

Verified September 27, 2026 using the installed Xcode 27.0 beta (27A5209h).

| Check | Result |
| --- | --- |
| Native Mac build | Passed on Apple silicon, macOS 27.2 |
| iPhone Simulator build | Passed |
| Seven Swift Testing tests | Passed: exact price parsing, calendar days/leap years, inclusive warranty end dates, disk-store reopening, relationship updates/cascade deletion, draft isolation, defaults |
| Mac UI workflow | Passed: Command-N, add, cancel an edit, save an edit, relaunch, verify saved name/retailer/price, delete, relaunch with empty inventory |
| iPhone UI workflow | Passed on iPhone 17 Pro / iOS 26.0: add, save, relaunch, open detail, verify retailer and unknown warranty state |
| Visual review | Mac empty/editor/detail screens and iPhone detail screenshot inspected |
| Whitespace validation | `git diff --check` passed |

The data tests most recently passed in `build/Milestone1-Mac-Final.xcresult`. After correcting a Mac accessibility selector, the UI workflow passed in `build/Milestone1-MacUI-Complete.xcresult`. The iPhone workflow passed in `build/Milestone1-iOS-Verified.xcresult`. Result bundles and synthetic screenshots stay in the ignored build directory.

The simulator test found and verified a fix for an actual iPhone navigation problem: a list using the Mac sidebar selection binding selected rows without opening details. iPhone now uses explicit navigation destinations; Mac keeps sidebar selection.

The Mac test uses the app's Command-N shortcut. Xcode's default notification interruption handler incorrectly treated a desktop Calendar widget as a banner when clicking the empty-state button; the desktop configuration was not changed. Direct interaction with the empty-state button worked.

## Current limits

- Local storage only. iCloud, cards, multiple editable coverage records, attachments, AI, and share extensions belong to later milestones.
- Physical iPhone signing/install has not been verified; select your development team in Xcode before running on your phone.
- macOS 26 itself was not available for runtime testing; deployment is set to 26.0, with execution checked on macOS 27.2.
- The beta toolchain logs debugger-version diagnostics and an internal thread-priority warning during Mac UI testing. Tests passed; verify again with stable Xcode before public distribution.
- Global command-line tool selection was not changed. Shell builds used `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.
