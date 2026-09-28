import SwiftUI
import SwiftData

struct CoverageEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let item: Item
    let coverage: Coverage?
    @State private var draft: CoverageDraft
    @State private var error: String?

    init(item: Item, coverage: Coverage? = nil) {
        self.item = item; self.coverage = coverage
        _draft = State(initialValue: CoverageDraft(coverage: coverage, item: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Coverage") {
                    TextField("Plan name (optional)", text: $draft.name).accessibilityIdentifier("coverageName")
                    Picker("Type", selection: $draft.kind) {
                        ForEach(CoverageKind.allCases) { Text($0.label).tag($0) }
                    }.accessibilityIdentifier("coverageKind")
                    TextField("Provider", text: $draft.provider).accessibilityIdentifier("coverageProvider")
                    if draft.kind == .creditCard { CardVersionPicker(title: "Coverage card", selection: $draft.cardVersion) }
                }
                Section {
                    Picker("Duration", selection: $draft.duration) {
                        ForEach(CoverageDuration.allCases) { Text($0.label).tag($0) }
                    }.accessibilityIdentifier("coverageDuration")
                    Toggle("Start date known", isOn: $draft.hasStart)
                    if draft.hasStart { DatePicker("Starts on", selection: $draft.start, displayedComponents: .date) }
                    if draft.duration == .fixed { DatePicker("Covered through", selection: $draft.end, displayedComponents: .date) }
                    Toggle("Cancellation recorded", isOn: $draft.isCancelled).accessibilityIdentifier("coverageCancelled")
                    if draft.isCancelled { DatePicker("Final covered day", selection: $draft.cancellationEnd, displayedComponents: .date) }
                } header: { Text("Dates") } footer: {
                    Text(draft.duration == .ongoing
                         ? "Ongoing plans depend on continued eligibility and payment. The app does not verify payments. If cancelled, enter the final day covered, not the day you requested cancellation."
                         : "End dates include the entire day. An unknown date does not mean lifetime coverage.")
                }
                Section("Terms") {
                    TextField("Coverage or extension", text: $draft.terms, axis: .vertical).lineLimit(2...5)
                        .accessibilityIdentifier("coverageTerms")
                    TextField("Limits and exclusions", text: $draft.exclusions, axis: .vertical).lineLimit(2...5)
                    TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(2...5)
                }
                Section { Text("Enter terms from your policy documents. Separate warranties are not automatically added together.").foregroundStyle(.secondary) }
            }
            .formStyle(.grouped)
            .environment(\.calendar, Calendar(identifier: .gregorian))
            .navigationTitle(coverage == nil ? "Add Coverage" : "Edit Coverage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).keyboardShortcut(.defaultAction).accessibilityIdentifier("saveCoverage")
                }
            }
            .onChange(of: draft.kind) { _, kind in
                guard coverage == nil else { return }
                switch kind {
                case .manufacturer: draft.provider = item.manufacturer
                case .retailer: draft.provider = item.retailer
                case .creditCard: draft.provider = draft.cardVersion?.bank ?? ""
                case .other: draft.provider = ""
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
        .interactiveDismissDisabled()
        .formError($error)
    }

    private func save() {
        do { try draft.validate() } catch { self.error = error.localizedDescription; return }
        do {
            let record = coverage ?? Coverage()
            if coverage == nil {
                context.insert(record)
                record.item = item
            }
            try draft.apply(to: record)
            item.updatedAt = Date()
            try context.save()
            dismiss()
        } catch { context.rollback(); self.error = error.localizedDescription }
    }
}

struct CoverageSummary: View {
    let coverage: Coverage
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(coverage.title).font(.headline)
                Spacer()
                Text(CoverageStatus.status(of: coverage).label).font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("coverageStatus")
            }
            if !coverage.provider.isEmpty { Text(coverage.provider).foregroundStyle(.secondary) }
            Text(CoverageKind(rawValue: coverage.kind)?.label ?? "Warranty").font(.caption).foregroundStyle(.secondary)
            if let start = coverage.startsOn { LabeledContent("Starts on", value: CalendarDay.label(start)) }
            if coverage.duration == "ongoing" { Text("Ongoing / monthly").font(.subheadline) }
            if let end = coverage.endsOn { LabeledContent("Original end date", value: CalendarDay.label(end)) }
            if let finalDay = coverage.cancelledOn { LabeledContent("Final covered day", value: CalendarDay.label(finalDay)) }
            if let card = coverage.cardVersion { Text(card.label).font(.caption) }
            if !coverage.terms.isEmpty { Text(coverage.terms).textSelection(.enabled) }
            if !coverage.exclusions.isEmpty { Text("Limits: \(coverage.exclusions)").font(.subheadline).textSelection(.enabled) }
            if !coverage.notes.isEmpty { Text(coverage.notes).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled) }
        }
        .padding(.vertical, 6)
    }
}
