import SwiftUI
import SwiftData

struct CardsView: View {
    @Query(sort: \CardAccount.nickname) private var accounts: [CardAccount]
    @State private var adding = false
    @State private var showArchived = false
    var body: some View {
        List {
            if accounts.isEmpty { Text("Cards are optional. Save a card to link purchases and retain its replacement history.").foregroundStyle(.secondary) }
            ForEach(accounts.filter { showArchived || !$0.isArchived }) { account in
                NavigationLink {
                    CardDetailView(account: account)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.nickname + (account.isArchived ? " (archived)" : "")).font(.headline)
                        if let version = account.currentVersion {
                            Text("\(version.bank) · \(version.productName)").font(.subheadline)
                            Text(version.maskedNumber).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("\(account.purchases.count) purchases").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if accounts.contains(where: \.isArchived) { Toggle("Show archived cards", isOn: $showArchived) }
        }
        .navigationTitle("Credit Cards")
        #if os(macOS)
        .safeAreaInset(edge: .bottom) {
            HStack { addButton; Spacer() }.padding().background(.bar)
        }
        #else
        .toolbar { addButton }
        #endif
        .sheet(isPresented: $adding) { CardEditorView() }
    }
    private var addButton: some View {
        Button("Add Card", systemImage: "plus") { adding = true }.accessibilityIdentifier("addCard")
    }
}

struct CardDetailView: View {
    @Environment(\.modelContext) private var context
    let account: CardAccount
    @State private var editing = false
    @State private var error: String?

    var body: some View {
        List {
            Section("Card history") {
                ForEach(account.orderedVersions, id: \.id) { version in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(version.productName).font(.headline)
                        Text("\(version.bank) · \(version.network)")
                        Text(version.maskedNumber).monospaced()
                        Text(version.id == account.currentVersion?.id ? "Current card" : "Previous card").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
            }
            Section("Purchases across all card versions") {
                if account.purchases.isEmpty { Text("No linked purchases yet.").foregroundStyle(.secondary) }
                ForEach(account.purchases) { item in
                    NavigationLink { ItemDetailView(item: item) } label: {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text(item.purchaseCard?.maskedNumber ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                Button(account.isArchived ? "Restore Card" : "Archive Card") {
                    account.isArchived.toggle()
                    do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
                }
            } footer: { Text("Archived cards keep their purchase history and coverage records. Updating the card creates a new version when its details change.") }
        }
        .navigationTitle(account.nickname)
        #if os(macOS)
        .safeAreaInset(edge: .bottom) {
            HStack { updateButton; Spacer() }.padding().background(.bar)
        }
        #else
        .toolbar { updateButton }
        #endif
        .sheet(isPresented: $editing) { CardEditorView(account: account) }
        .formError($error)
    }
    private var updateButton: some View {
        Button("Update Card", systemImage: "pencil") { editing = true }.accessibilityIdentifier("updateCard")
    }
}

struct CardEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let account: CardAccount?
    @State private var draft: CardDraft
    @State private var error: String?

    init(account: CardAccount? = nil) {
        self.account = account
        _draft = State(initialValue: CardDraft(account: account))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Card details") {
                    TextField("Nickname", text: $draft.nickname).accessibilityIdentifier("cardNickname")
                    TextField("Issuing bank", text: $draft.bank).accessibilityIdentifier("cardBank")
                    TextField("Network (Visa, Mastercard…)", text: $draft.network).accessibilityIdentifier("cardNetwork")
                    TextField("Card product name", text: $draft.productName).accessibilityIdentifier("cardProduct")
                }
                Section {
                    TextField("First four digits", text: $draft.firstFour).accessibilityIdentifier("cardFirstFour")
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    TextField("Last four digits", text: $draft.lastFour).accessibilityIdentifier("cardLastFour")
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                } header: { Text("Identify this card") } footer: {
                    Text("Enter only the first four and last four digits. Never enter a full card number or a security code.")
                }
                if account != nil {
                    Section { Text("Changing bank, network, product, or digits creates a new card version. Existing purchases and warranty terms keep their original details.").foregroundStyle(.secondary) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(account == nil ? "Add Card" : "Update Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).keyboardShortcut(.defaultAction).accessibilityIdentifier("saveCard")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 470)
        #endif
        .interactiveDismissDisabled()
        .formError($error)
    }

    private func save() {
        do { try draft.validate() } catch { self.error = error.localizedDescription; return }
        do {
            let savedAccount = account ?? CardAccount(nickname: draft.nickname)
            if account == nil { context.insert(savedAccount) }
            try draft.apply(to: savedAccount)
            try context.save()
            dismiss()
        } catch { context.rollback(); self.error = error.localizedDescription }
    }
}
