import Foundation
import CoreData

enum StoreBackup {
    static func destination(for store: URL) -> URL {
        store.deletingLastPathComponent().appending(path: "Before-iCloud", directoryHint: .isDirectory)
            .appending(path: store.lastPathComponent)
    }

    /// Called before opening a cloud-enabled container, while no app context has the store open.
    /// Core Data copies the SQLite store and its external assets; raw SQLite file copies are unsafe.
    static func beforeFirstCloudOpen(at store: URL) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: store.path) else { return }
        let backup = destination(for: store)
        let marker = backup.appendingPathExtension("complete")
        guard !manager.fileExists(atPath: marker.path) else { return }
        try manager.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
        try coordinator.replacePersistentStore(at: backup, destinationOptions: nil,
                                               withPersistentStoreFrom: store, sourceOptions: nil,
                                               ofType: NSSQLiteStoreType)
        try Data("Backup complete".utf8).write(to: marker, options: .atomic)
    }
}
