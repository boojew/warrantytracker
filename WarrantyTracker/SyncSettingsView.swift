import SwiftUI

struct SyncSettingsView: View {
    @Environment(SyncStatus.self) private var sync
    var body: some View {
        Form {
            Section("Inventory storage") {
                Label(sync.summary, systemImage: sync.mode.isEnabled ? "icloud" : "internaldrive")
                    .accessibilityIdentifier("syncStatus")
                if sync.mode.isEnabled {
                    Text("Your inventory and attachments sync through your private iCloud account. Use the same account on your iPhone and Mac. Changes may take time to appear on another device.")
                    if let date = sync.progress.lastUpload {
                        LabeledContent("Last completed upload", value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let date = sync.progress.lastDownload {
                        LabeledContent("Last completed download", value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                    ForEach(sync.progress.failures.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { activity in
                        Text(sync.progress.failures[activity] ?? "").foregroundStyle(.secondary)
                    }
                    Button("Check iCloud Status") { Task { await sync.refreshAccount() } }.disabled(sync.checking)
                    Text("This checks account availability; Apple schedules transfers. Completion times do not guarantee that every device has received every change.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("iCloud is not enabled in this build. Your inventory stays on this device and remains available offline.")
                }
            }
        }.formStyle(.grouped).navigationTitle("Storage & Sync")
    }
}
