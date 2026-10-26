import Foundation
import CryptoKit

@main
struct StorageCoreTests {
    static var assertions = 0
    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) rethrows {
        assertions += 1
        if try !condition() { fatalError(message) }
    }
    static func rejects(_ action: () throws -> Void, _ message: String) {
        assertions += 1
        do { try action(); fatalError(message) } catch { }
    }
    enum Injected: Error { case failure }
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let files = Dictionary(uniqueKeysWithValues: LLBackupArchive.requiredPaths.map { ($0, Data(("saved-" + $0).utf8)) })
        let packed = try LLBackupArchive.encode(files)
        try check(LLBackupArchive.decode(packed, version: 2) == files, "Complete archive round trip")
        let key = SymmetricKey(size: .bits256)
        let box = try AES.GCM.seal(packed, using: key).combined!
        let envelope = try LLBackupArchive.parseEnvelope(LLBackupArchive.envelope(box))
        try check(LLBackupArchive.decode(AES.GCM.open(AES.GCM.SealedBox(combined: envelope.encrypted), using: key), version: envelope.version) == files, "Encrypted round trip")
        var huge = Data([0x4c,0x4c,0x42,0x4b,2]); huge.append(Data(repeating: 255, count: 8))
        rejects({ _ = try LLBackupArchive.parseEnvelope(huge) }, "Oversized length throws instead of trapping")
        var trailing = LLBackupArchive.envelope(box); trailing.append(0)
        rejects({ _ = try LLBackupArchive.parseEnvelope(trailing) }, "Trailing envelope data rejected")
        rejects({ _ = try LLBackupArchive.decode(packed.dropLast(), version: 2) }, "Truncated archive rejected")
        func legacy(_ records: [(String,Data)]) -> Data {
            func append(_ n: UInt64, _ bytes: Int, _ data: inout Data) {
                for i in (0..<bytes).reversed() { data.append(UInt8(truncatingIfNeeded: n >> (8*i))) }
            }
            var data = Data(); append(UInt64(records.count),4,&data)
            for (path,body) in records {
                append(UInt64(path.utf8.count),2,&data); data.append(Data(path.utf8))
                append(UInt64(body.count),8,&data); data.append(body)
            }
            return data
        }
        let records = files.map { ($0.key,$0.value) }
        try check(LLBackupArchive.decode(legacy(records), version: 1) == files, "Version 1 archives remain readable")
        rejects({ _ = try LLBackupArchive.decode(legacy(records + [("../outside",Data())]), version: 1) }, "Traversal rejected before any write")
        rejects({ _ = try LLBackupArchive.decode(legacy(records + [records[0]]), version: 1) }, "Duplicate paths rejected")
        rejects({ _ = try LLBackupArchive.encode(["LearnLanguage.db": Data()]) }, "Incomplete backup cannot be exported")
        var corrupted = packed; corrupted[corrupted.count - 1] ^= 1
        rejects({ _ = try LLBackupArchive.decode(corrupted, version: 2) }, "Checksum mismatch rejected")

        let destination = root.appendingPathComponent("replacement", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("old-a".utf8).write(to: destination.appendingPathComponent("a"))
        try Data("old-b".utf8).write(to: destination.appendingPathComponent("b"))
        let source = root.appendingPathComponent("new-a"); try Data("new-a".utf8).write(to: source)
        rejects({
            try LLFileReplacementTransaction.install(["a":source,"b":root.appendingPathComponent("missing")], in: destination, managedPaths: ["a","b"])
        }, "A later write failure rolls the earlier write back")
        try check(String(contentsOf: destination.appendingPathComponent("a"), encoding: .utf8) == "old-a", "Earlier destination restored")
        try check(String(contentsOf: destination.appendingPathComponent("b"), encoding: .utf8) == "old-b", "Later destination preserved")
        rejects({
            try LLFileReplacementTransaction.install(["a":source], in: destination, managedPaths: ["a","b"]) { throw Injected.failure }
        }, "Post-install validation failure rolls all files back")
        try check(String(contentsOf: destination.appendingPathComponent("b"), encoding: .utf8) == "old-b", "Removed sidecar restored on failure")
        // Simulate interruption after mutation and before commit, then exercise startup recovery.
        let journal = destination.appendingPathComponent(".LearnLanguageRestore")
        try FileManager.default.createDirectory(at: journal.appendingPathComponent("old"), withIntermediateDirectories: true)
        try Data("before-crash".utf8).write(to: journal.appendingPathComponent("old/a"))
        try Data("{\"paths\":[\"a\"],\"originals\":[\"a\"],\"committed\":false}".utf8).write(to: journal.appendingPathComponent("state.json"))
        try Data("after-crash".utf8).write(to: destination.appendingPathComponent("a"))
        try LLFileReplacementTransaction.recoverIfNeeded(in: destination, managedPaths: ["a","b"])
        try check(String(contentsOf: destination.appendingPathComponent("a"), encoding: .utf8) == "before-crash", "Startup rolls back an interrupted restore")
        try check(String(contentsOf: destination.appendingPathComponent("b"), encoding: .utf8) == "old-b", "Recovery touches only the journal's managed files")
        try LLFileReplacementTransaction.install(["a":source], in: destination, managedPaths: ["a","b"])
        try check(String(contentsOf: destination.appendingPathComponent("a"), encoding: .utf8) == "new-a", "Successful replacement commits")
        check(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("b").path), "Obsolete WAL sidecars are removed")

        let live = root.appendingPathComponent("live.db")
        let db = try LLSQLiteConnection(url: live)
        try db.execute("PRAGMA journal_mode=WAL")
        try db.execute("PRAGMA wal_autocheckpoint=0")
        try db.execute("CREATE TABLE progress(id INTEGER)")
        try db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        try db.execute("INSERT INTO progress VALUES(1)")
        let snapshot = root.appendingPathComponent("snapshot.db")
        try LLSQLiteConnection.snapshot(from: live, to: snapshot)
        try db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        let copy = try LLSQLiteConnection(url: snapshot, readOnly: true)
        try check(copy.query("SELECT COUNT(*) AS n FROM progress").first?["n"] == "1", "Snapshot includes committed WAL data")
        check(!FileManager.default.fileExists(atPath: snapshot.path + "-wal"), "Snapshot is self contained")

        let local = root.appendingPathComponent("legacy.db")
        let resource = root.appendingPathComponent("resource.db")
        try LLContentMigrator.migrate(local: local, resource: resource, version: "v1")
        let localDB = try LLSQLiteConnection(url: local)
        try check(localDB.query("SELECT word FROM words WHERE word_list_id=10 ORDER BY word").compactMap { $0["word"] } == ["apple","new-apple"], "Library A receives only A's words")
        try check(localDB.query("SELECT word FROM words WHERE word_list_id=20").first?["word"] == "banana", "Library B in the same category stays separate")
        try check(localDB.query("SELECT COUNT(*) AS n FROM words WHERE word_list_id=30").first?["n"] == "0", "User-created empty notebook is untouched")
        try check(localDB.query("SELECT COUNT(*) AS n FROM word_lists WHERE name='new-library'").first?["n"] == "1", "New library in an existing category is imported")
        try check(localDB.query("SELECT translation FROM words WHERE id=101").first?["translation"] == "updated apple", "Existing word ID survives content update")
        try check(localDB.query("SELECT marker FROM preserved_progress WHERE word_id=101").first?["marker"] == "learned", "User progress remains attached")
        try check(localDB.query("SELECT COUNT(*) AS n FROM word_examples").first?["n"] == "1", "Examples migrate for existing installations")
        let sourceDB = try LLSQLiteConnection(url: resource)
        try sourceDB.execute("INSERT INTO words(word_list_id,word,translation) VALUES(1,'rollback-word','rollback')")
        rejects({ try LLContentMigrator.migrate(local: local, resource: resource, version: "v2") { throw Injected.failure } }, "Injected migration failure rolls back")
        try check(LLContentMigrator.version(at: local) == "v1", "Failed migration never advances version")
        try check(localDB.query("SELECT COUNT(*) AS n FROM words WHERE word='rollback-word'").first?["n"] == "0", "Failed migration leaves no partial content")
        try LLContentMigrator.migrate(local: local, resource: resource, version: "v2")
        try check(LLContentMigrator.version(at: local) == "v2", "Migration can be retried")
        try check(localDB.query("SELECT COUNT(*) AS n FROM words WHERE word='rollback-word'").first?["n"] == "1", "Retry inserts new words once")
        try check(localDB.query("SELECT COUNT(*) AS n FROM word_examples").first?["n"] == "1", "Retry does not duplicate examples")
        try localDB.execute("DELETE FROM words WHERE word_list_id IN (SELECT local_id FROM ll_resource_word_lists WHERE source_id=3)")
        try localDB.execute("DELETE FROM word_lists WHERE id IN (SELECT local_id FROM ll_resource_word_lists WHERE source_id=3)")
        try LLContentMigrator.migrate(local: local, resource: resource, version: "v3")
        try check(localDB.query("SELECT w.word FROM words w JOIN ll_resource_word_lists m ON m.local_id=w.word_list_id WHERE m.source_id=3").first?["word"] == "cherry", "Repair replaces a missing resource library even when a stale mapping exists")
        if CommandLine.arguments.count > 2 {
            let bundled = URL(fileURLWithPath: CommandLine.arguments[2])
            let full = root.appendingPathComponent("full-legacy.db")
            try LLSQLiteConnection.snapshot(from: bundled, to: full, immutableSource: true)
            let original = try LLSQLiteConnection(url: bundled, readOnly: true, immutable: true)
            try LLContentMigrator.migrate(local: full, resource: bundled, version: "full-size-test")
            let upgraded = try LLSQLiteConnection(url: full, readOnly: true)
            for table in ["word_lists", "words", "word_examples"] {
                try check(upgraded.query("SELECT COUNT(*) AS n FROM \(table)").first?["n"] == original.query("SELECT COUNT(*) AS n FROM \(table)").first?["n"], "Full dictionary migration preserves the \(table) content count")
            }
            try check(LLContentMigrator.version(at: full) == "full-size-test", "Full dictionary migration commits its version")
        }
        print("Passed \(assertions) storage core checks (SQLite, archive, rollback and migration).")
    }
}
