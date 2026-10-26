import Foundation
import CryptoKit
import MMKV
import WCDBSwift

final class LLBackupManager {
    static let shared = LLBackupManager()
    static let fileExtension = "llbak"
    private let queue = DispatchQueue(label: "com.learnlanguage.backup", qos: .userInitiated)
    private init() {}

    // Retained solely for compatibility with existing .llbak files, not a user-specific secret.
    private var symmetricKey: SymmetricKey {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.ruijia.LearnLanguage"
        let material = Data((bundleId + "LearnLanguage.BackupKey.v1.@ruijia#2026").utf8)
        return SymmetricKey(data: SHA256.hash(data: material))
    }
    private var documentsURL: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    private func report(_ value: Double, to progress: ((Double) -> Void)?) {
        DispatchQueue.main.async { progress?(value) }
    }

    func exportBackup(to destinationURL: URL, progress: ((Double) -> Void)? = nil, completion: @escaping (String?) -> Void) {
        queue.async {
            do {
                let staging = try self.makeStagingDirectory()
                defer { try? FileManager.default.removeItem(at: staging) }
                self.report(0.05, to: progress)
                let snapshot = staging.appendingPathComponent(LLBackupArchive.databasePath)
                try LLSQLiteConnection.snapshot(from: self.documentsURL.appendingPathComponent(LLBackupArchive.databasePath), to: snapshot)
                try LLSQLiteConnection.validateDatabase(at: snapshot)
                let settings = staging.appendingPathComponent("mmkv", isDirectory: true)
                try FileManager.default.createDirectory(at: settings, withIntermediateDirectories: true)
                let backedUp = LLMMKVManager.shared.withExclusiveStorageAccess {
                    MMKV.backup(mmapID: "mmkv.default", rootPath: nil, dstDir: settings.path)
                }
                guard backedUp else { throw BackupError.storageUnavailable }
                self.report(0.5, to: progress)
                var files: [String: Data] = [:]
                for path in LLBackupArchive.requiredPaths {
                    files[path] = try Data(contentsOf: staging.appendingPathComponent(path))
                }
                let packed = try LLBackupArchive.encode(files)
                guard let encrypted = try AES.GCM.seal(packed, using: self.symmetricKey).combined else { throw BackupError.decryptionFailed }
                self.report(0.85, to: progress)
                try LLBackupArchive.envelope(encrypted).write(to: destinationURL, options: .atomic)
                self.report(1, to: progress)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                LLLogger.error("备份失败：\(error)")
                DispatchQueue.main.async { completion("备份失败：\(error.localizedDescription)") }
            }
        }
    }

    func restoreBackup(from sourceURL: URL, progress: ((Double) -> Void)? = nil, completion: @escaping (String?) -> Void) {
        queue.async {
            do {
                let envelope = try LLBackupArchive.parseEnvelope(Data(contentsOf: sourceURL, options: .mappedIfSafe))
                let packed: Data
                do { packed = try AES.GCM.open(AES.GCM.SealedBox(combined: envelope.encrypted), using: self.symmetricKey) }
                catch { throw BackupError.decryptionFailed }
                let files = try LLBackupArchive.decode(packed, version: envelope.version)
                self.report(0.25, to: progress)
                let staging = try self.makeStagingDirectory()
                defer { try? FileManager.default.removeItem(at: staging) }
                for (path, data) in files where path != "LearnLanguage.db-shm" {
                    let target = staging.appendingPathComponent(path)
                    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: target)
                }
                let normalized = staging.appendingPathComponent("normalized.db")
                // Normalize legacy WAL backups into a standalone, validated database.
                try LLSQLiteConnection.snapshot(from: staging.appendingPathComponent(LLBackupArchive.databasePath), to: normalized)
                try LLSQLiteConnection.validateDatabase(at: normalized)
                try LLDatabaseInitializer.shared.prepareDatabase(at: normalized)
                let stagedDatabase = LLDatabaseManager(path: normalized.path)
                guard stagedDatabase.openDatabase() else { throw BackupError.invalidFile }
                stagedDatabase.closeDatabase()
                let ready = staging.appendingPathComponent("ready.db")
                try LLSQLiteConnection.snapshot(from: normalized, to: ready)
                try LLSQLiteConnection.validateDatabase(at: ready)
                let settings = staging.appendingPathComponent("mmkv", isDirectory: true)
                guard MMKV.isFileValid(for: "mmkv.default", rootPath: settings.path) else { throw BackupError.invalidFile }
                self.report(0.65, to: progress)
                var replacements = Dictionary(uniqueKeysWithValues: LLBackupArchive.requiredPaths.map { ($0, staging.appendingPathComponent($0)) })
                replacements[LLBackupArchive.databasePath] = ready
                // Existing learning operations run on main. WCDB blocks any other handles while files change.
                try DispatchQueue.main.sync {
                    LLPracticePanelController.shared.hide()
                    LLPronunciationManager.shared.stop()
                    try LLMMKVManager.shared.withExclusiveStorageAccess {
                        MMKV.default()?.close()
                        defer { _ = MMKV.default() }
                        guard let database = LLDatabaseManager.shared.database else { throw BackupError.storageUnavailable }
                        try database.close(onClosed: {
                            try LLFileReplacementTransaction.install(replacements, in: self.documentsURL, managedPaths: LLBackupArchive.managedPaths) {
                                try LLSQLiteConnection.validateDatabase(at: self.documentsURL.appendingPathComponent(LLBackupArchive.databasePath))
                            }
                        })
                    }
                    LLDatabaseManager.shared.reopenDatabase()
                    LLDailyLearningManager.shared.invalidate()
                    LLPracticePanelController.shared.resetAfterDataChange()
                    LLWordEntry.invalidateExampleCache()
                    NotificationCenter.default.post(name: .learnLanguageCurrentListChanged, object: nil)
                    NotificationCenter.default.post(name: .floatingPanelSettingsChanged, object: nil)
                    NotificationCenter.default.post(name: .learnLanguageRefreshStatus, object: nil)
                    NotificationCenter.default.post(name: .learnLanguageReloadWordLists, object: nil)
                }
                self.report(1, to: progress)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                LLLogger.error("恢复失败：\(error)")
                DispatchQueue.main.async { completion("恢复失败：\(error.localizedDescription)") }
            }
        }
    }

    private func makeStagingDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LLBackup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
