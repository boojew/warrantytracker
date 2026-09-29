import SwiftUI
import SwiftData

@main
struct WarrantyTrackerApp: App {
    private let container: ModelContainer?
    private let startupError: String?
    @State private var sync: SyncStatus
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @UIApplicationDelegateAdaptor(SyncAppDelegate.self) private var delegate
    #endif

    init() {
        let isolated = ProcessInfo.processInfo.arguments.contains("--ui-test-store") || ProcessInfo.processInfo.environment["WARRANTYTRACKER_TEST_HOST"] == "1"
        let mode = SyncMode.configured(isolated: isolated)
        _sync = State(initialValue: SyncStatus(mode: mode))
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
            // Hosted unit tests launch the app too. Keep their host away from real inventory.
            let isolatedTestHost = ProcessInfo.processInfo.environment["WARRANTYTRACKER_TEST_HOST"] == "1"
            container = try Persistence.container(url: storeURL, inMemory: isolatedTestHost && storeURL == nil, sync: mode)
            startupError = nil
        } catch {
            container = nil
            startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup("WarrantyTracker", id: "inventory") {
            if let container {
                InventoryView()
                    .modelContainer(container)
                    .tint(.teal)
                    .environment(sync)
                    .task {
                        #if os(macOS)
                        if sync.mode.isEnabled { NSApplication.shared.registerForRemoteNotifications() }
                        #endif
                        await sync.refreshAccount()
                    }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active { Task { await sync.refreshAccount() } }
                    }
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
        .defaultLaunchBehavior(.presented)
        #endif
        #if os(macOS)
        Settings {
            if let container {
                SettingsView().modelContainer(container).environment(sync)
            }
        }
        #endif
    }
}

#if os(macOS)
import AppKit
#else
import UIKit
final class SyncAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if shouldRegisterForCloudNotifications { application.registerForRemoteNotifications() }
        return true
    }
}
#endif

@MainActor private var shouldRegisterForCloudNotifications: Bool {
    SyncMode.configured(isolated: ProcessInfo.processInfo.arguments.contains("--ui-test-store") || ProcessInfo.processInfo.environment["WARRANTYTRACKER_TEST_HOST"] == "1").isEnabled
}
