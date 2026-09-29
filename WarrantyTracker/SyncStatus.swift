import Foundation
import Observation
import CloudKit
import CoreData
import Network

enum SyncMode: Equatable, Sendable {
    case local
    case privateCloud(String)
    var isEnabled: Bool { if case .privateCloud = self { true } else { false } }

    static func configured(bundle: Bundle = .main, isolated: Bool = false) -> SyncMode {
        let enabled = (bundle.object(forInfoDictionaryKey: "WarrantyCloudSyncEnabled") as? Bool) == true
        guard !isolated, enabled,
              let identifier = bundle.object(forInfoDictionaryKey: "WarrantyCloudContainer") as? String,
              !identifier.isEmpty else { return .local }
        return .privateCloud(identifier)
    }
}

enum SyncActivity: Int, Sendable { case setup = 0, download = 1, upload = 2 }
struct SyncEvent: Sendable {
    let id: UUID
    let activity: SyncActivity
    let finishedAt: Date?
    let succeeded: Bool
    let failure: String?
}

struct SyncProgress {
    private(set) var active: [UUID: SyncActivity] = [:]
    private(set) var failures: [SyncActivity: String] = [:]
    private(set) var lastUpload: Date?
    private(set) var lastDownload: Date?

    mutating func receive(_ event: SyncEvent) {
        guard let finished = event.finishedAt else { active[event.id] = event.activity; return }
        active[event.id] = nil
        if event.succeeded {
            failures[event.activity] = nil
            if event.activity == .upload { lastUpload = max(lastUpload ?? .distantPast, finished) }
            if event.activity == .download { lastDownload = max(lastDownload ?? .distantPast, finished) }
        } else {
            failures[event.activity] = event.failure ?? "iCloud could not finish this operation."
        }
    }
}

@MainActor @Observable
final class SyncStatus {
    let mode: SyncMode
    private(set) var progress = SyncProgress()
    private(set) var account: CKAccountStatus?
    private(set) var accountError: String?
    private(set) var online = true
    private(set) var checking = false
    private(set) var importRevision = 0
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var network: NWPathMonitor?

    init(mode: SyncMode) {
        self.mode = mode
        guard mode.isEnabled else { return }
        observers.append(NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification,
                                                               object: nil, queue: .main) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  let activity = SyncActivity(rawValue: event.type.rawValue) else { return }
            let error = event.error as NSError?
            let snapshot = SyncEvent(id: event.identifier, activity: activity, finishedAt: event.endDate,
                                     succeeded: event.succeeded,
                                     failure: error.map { "iCloud error \($0.domain) (\($0.code)). Changes will retry automatically." })
            Task { @MainActor [weak self] in
                self?.progress.receive(snapshot)
                if snapshot.finishedAt != nil && snapshot.succeeded && snapshot.activity == .download {
                    self?.importRevision += 1
                }
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refreshAccount() }
        })
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in self?.online = connected }
        }
        monitor.start(queue: DispatchQueue(label: "WarrantyTracker.connectivity"))
        network = monitor
    }

    func refreshAccount() async {
        guard case .privateCloud(let identifier) = mode, !checking else { return }
        checking = true
        defer { checking = false }
        do { account = try await CKContainer(identifier: identifier).accountStatus(); accountError = nil }
        catch { accountError = "Unable to check iCloud. Check your connection and try again." }
    }

    var summary: String {
        guard mode.isEnabled else { return "On this device" }
        if !online { return "Offline — changes saved locally" }
        if let accountError { return accountError }
        switch account {
        case .noAccount: return "Sign in to iCloud in system Settings"
        case .restricted: return "iCloud access is restricted"
        case .temporarilyUnavailable, .couldNotDetermine: return "iCloud is temporarily unavailable"
        case nil: return "Checking iCloud account…"
        default: break
        }
        if !progress.failures.isEmpty { return "iCloud needs attention" }
        if progress.active.values.contains(.upload) { return "Sending changes to iCloud…" }
        if progress.active.values.contains(.download) { return "Receiving changes from iCloud…" }
        if progress.active.values.contains(.setup) { return "Preparing iCloud…" }
        return "iCloud enabled — changes sync automatically"
    }
}
