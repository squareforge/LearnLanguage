import Foundation
import WCDBSwift

final class LLDatabaseInitializer {
    static let shared = LLDatabaseInitializer()
    private let resourceOverride: URL?
    private let localOverride: URL?
    private let versionOverride: String?

    init(resourceURL: URL? = nil, localURL: URL? = nil, version: String? = nil) {
        resourceOverride = resourceURL
        localOverride = localURL
        versionOverride = version
    }

    private var localURL: URL {
        localOverride ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("LearnLanguage.db")
    }

    private func resource() throws -> (url: URL, version: String) {
        guard let url = resourceOverride ?? Bundle.main.url(forResource: "LearnLanguage", withExtension: "db") else {
            throw NSError(domain: "LLDatabase", code: 1, userInfo: [NSLocalizedDescriptionKey: "缺少初始词库，请重新安装完整应用。"])
        }
        if let versionOverride { return (url, versionOverride) }
        if let manifestURL = Bundle.main.url(forResource: "dictionary-manifest", withExtension: "json"),
           let object = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any],
           let hash = object["sha256"] as? String { return (url, hash) }
        return (url, LLBackupArchive.checksum(try Data(contentsOf: url, options: .mappedIfSafe)))
    }

    @discardableResult
    func initializeDatabase(forceUpdate: Bool = false) -> Bool {
        do {
            try prepareDatabase(at: localURL, forceUpdate: forceUpdate)
            return true
        } catch {
            LLLogger.error("数据库准备失败，将在下次启动重试：\(error)")
            return false
        }
    }

    /// Also prepares restored databases in a staging directory, before live files change.
    func prepareDatabase(at destination: URL, forceUpdate: Bool = false) throws {
        let source = try resource()
        let fm = FileManager.default
        if !fm.fileExists(atPath: destination.path) {
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let staged = destination.deletingLastPathComponent().appendingPathComponent(".initial-\(UUID().uuidString).db")
            defer { try? fm.removeItem(at: staged) }
            try LLSQLiteConnection.snapshot(from: source.url, to: staged, immutableSource: true)
            try LLSQLiteConnection.validateDatabase(at: staged)
            try LLContentMigrator.migrate(local: staged, resource: source.url, version: source.version, copiedFromResource: true)
            try fm.moveItem(at: staged, to: destination)
        } else {
            let savedVersion = try LLContentMigrator.version(at: destination)
            if forceUpdate || savedVersion != source.version {
                try LLSQLiteConnection.validateDatabase(at: destination)
                try LLContentMigrator.migrate(local: destination, resource: source.url, version: source.version)
            }
        }
    }

    @discardableResult
    func forceReinitialize() -> Bool {
        let fm = FileManager.default
        let temporary = fm.temporaryDirectory.appendingPathComponent("LLReset-\(UUID().uuidString)", isDirectory: true)
        do {
            try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: temporary) }
            let snapshot = temporary.appendingPathComponent("LearnLanguage.db")
            try prepareDatabase(at: snapshot)
            try LLFileReplacementTransaction.install(["LearnLanguage.db": snapshot], in: localURL.deletingLastPathComponent(), managedPaths: ["LearnLanguage.db", "LearnLanguage.db-wal", "LearnLanguage.db-shm"])
            return true
        } catch {
            LLLogger.error("重置数据库失败，保留原有数据：\(error)")
            return false
        }
    }

    private func getSavedVersion() -> String { (try? LLContentMigrator.version(at: localURL)) ?? "未完成升级" }

    /// 获取数据库统计信息
    func getDatabaseStats() {
        do {
            // 使用 LLDatabaseManager 已经打开的数据库连接
            let db = LLDatabaseManager.shared
            
            let categoryCount = try db.database.getValue(
                on: LLDBWordListCategory.Properties.id.count(),
                fromTable: "categories"
            ).int32Value
            
            let wordListCount = try db.database.getValue(
                on: LLDBWordList.Properties.id.count(),
                fromTable: "word_lists"
            ).int32Value
            
            let wordCount = try db.database.getValue(
                on: LLDBWord.Properties.id.count(),
                fromTable: "words"
            ).int32Value
            
            LLLogger.info("\n📊 数据库统计信息：")
            LLLogger.info("   - 分类数：\(categoryCount)")
            LLLogger.info("   - 词库数：\(wordListCount)")
            LLLogger.info("   - 单词数：\(wordCount)")
            LLLogger.info("   - 版本号：\(getSavedVersion())\n")
            
        } catch {
            LLLogger.error("❌ 获取统计信息失败：\(error)")
        }
    }
}
