import SwiftUI
import SwiftData

@main
struct WarrantyTrackerApp: App {
    private let container: ModelContainer?
    private let startupError: String?

    init() {
        do {
            // UI tests use an isolated on-disk store; a relaunch tests real persistence.
            let arguments = ProcessInfo.processInfo.arguments
            var storeURL: URL?
            if let index = arguments.firstIndex(of: "--ui-test-store"), arguments.indices.contains(index + 1) {
                let directory = URL.applicationSupportDirectory.appending(path: "UITests", directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let identifier = arguments[index + 1].filter { $0.isLetter || $0.isNumber || $0 == "-" }
                storeURL = directory.appending(path: "\(identifier).store")
            }
            container = try Persistence.container(url: storeURL)
            startupError = nil
        } catch {
            container = nil
            startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                InventoryView()
                    .modelContainer(container)
                    .tint(.teal)
            } else {
                ContentUnavailableView {
                    Label("Unable to open your inventory", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved data has not been deleted. Quit and reopen the app to try again.\n\n\(startupError ?? "Storage is unavailable.")")
                }
                .padding()
            }
        }
        #if os(macOS)
        .defaultSize(width: 1040, height: 720)
        #endif
        #if os(macOS)
        Settings {
            if let container {
                SettingsView().modelContainer(container)
            }
        }
        #endif
    }
}
