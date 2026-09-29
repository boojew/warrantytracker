# Approved development direction

Native iPhone and Mac app, iOS/macOS 26 minimum, English UI first. Default Canada/CAD with editable per-purchase country/currency. Public App Store distribution is the eventual goal. Local storage and private iCloud are the only planned hosted inventory storage; no custom server or third-party AI service.

Milestones 1–3 are implemented. Milestone 4 code and local checks are prepared, but activation and real two-device acceptance are pending: the developer currently uses a free Personal Team. Normal schemes stay local and runnable. See `ICLOUD_SETUP.md` for the paid-account setup and remaining acceptance checks, `VERIFICATION.md` for evidence, and `README.md` for hands-on steps. Stop at this boundary; milestone 5 needs a separate go-ahead. The first synced MVP is not yet accepted.

## Milestones

1. **Local foundation:** runnable Mac/iPhone app, basic item details, manual manufacturer end date, durable SwiftData storage.
2. **Coverage, cards, search:** multiple independent manufacturer/retailer/card warranties; fixed, unknown, ongoing and cancelled terms; optional card accounts with purchase-time versions; category, tags and locations; all-field search with field scopes.
3. **Attachments:** item/receipt/serial photo, at least five extras, coverage photos/PDFs, native import/capture and document review/redaction before persistent saving.
4. **Private iCloud sync — first MVP:** preserve earlier local records; sync settings, inventory and attachments between physical iPhone and Mac; test offline edits, deletes, conflicts and unavailable iCloud.
5. **Receipt assistance:** Vision OCR followed by optional on-device Foundation Models suggestions, with English/French receipts, multi-item selection, explicit user review and a complete manual fallback.
6. **Sharing:** iOS/macOS share extensions, reviewed import inbox in an App Group, supported image/PDF attachments from other apps. Main app processes imports.
7. **Public release:** TestFlight, accessibility, migration tests, deletion/export, privacy/support pages, App Store metadata and device checks.

Automated warranty-policy research is explicitly deferred to a separate design task. Do not substitute model recollection for official policy evidence. Receipt extraction and future policy research must remain separate services; every suggestion remains editable and does not overwrite confirmed user values.

## Required invariants

- Coverage provider and duration are distinct. Unknown dates do not mean ongoing coverage. Ongoing monthly plans end when a user records cancellation; the app does not charge or verify payments.
- Only a card's first four and last four digits may be saved. No full numbers or security codes. Preserve card versions and prior coverage when cards change.
- No required card onboarding. Used cards can be archived without breaking purchase history.
- Use native system controls for Liquid Glass and accessibility. Native Mac settings/sidebar; iPhone tabs/forms.
- SwiftData schema must remain compatible with future CloudKit: stable IDs, default/optional attributes, optional inverse relationships, no uniqueness constraints.
- Money must remain exact, calendar dates must survive time-zone changes, and changing defaults must not rewrite or convert older purchases.
- AI is optional. On supported systems, token counts are processing statistics, not a credit balance.
- No household sharing, reminders, claim submission, or monetization implementation in the initial MVP.

## Git workflow

Work on `dev`. Commit coherent, checked increments and push to `origin/dev` regularly, including each verified milestone. Do not commit personal test data or credentials, and do not merge into `main` without a separate request.
