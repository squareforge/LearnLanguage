import Foundation
#if canImport(sqlcipher)
import sqlcipher
#else
import SQLite3
#endif

/// File-level operations use SQLite's snapshot API rather than copying a live WAL file set.
final class LLSQLiteConnection {
    let handle: OpaquePointer

    init(url: URL, readOnly: Bool = false, immutable: Bool = false) throws {
        var pointer: OpaquePointer?
        let path = immutable ? url.absoluteString + "?mode=ro&immutable=1" : url.path
        let flags = (readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE) | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI
        guard sqlite3_open_v2(path, &pointer, flags, nil) == SQLITE_OK, let opened = pointer else {
            if let pointer { sqlite3_close(pointer) }
            throw BackupError.storageUnavailable
        }
        handle = opened
        sqlite3_busy_timeout(handle, 3000)
    }

    deinit { sqlite3_close(handle) }

    func execute(_ sql: String, arguments: [String] = []) throws {
        _ = try query(sql, arguments: arguments)
    }

    func query(_ sql: String, arguments: [String] = []) throws -> [[String: String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw error(sql: sql) }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in arguments.enumerated() {
            guard sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient) == SQLITE_OK else { throw error() }
        }
        var rows: [[String: String]] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            var row: [String: String] = [:]
            for index in 0..<sqlite3_column_count(statement) {
                if let value = sqlite3_column_text(statement, index) {
                    row[String(cString: sqlite3_column_name(statement, index))] = String(cString: value)
                }
            }
            rows.append(row)
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw error(sql: sql) }
        return rows
    }

    func transaction(_ operation: () throws -> Void) throws {
        // The bundled SQLite also tries to write-lock read-only attached resources
        // for BEGIN IMMEDIATE. The first main-database write acquires our lock.
        try execute("BEGIN")
        do { try operation(); try execute("COMMIT") }
        catch { try? execute("ROLLBACK"); throw error }
    }

    private func error(sql: String? = nil) -> NSError {
        var info = [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(handle))]
        info[NSDebugDescriptionErrorKey] = sql
        return NSError(domain: "LLSQLite", code: Int(sqlite3_errcode(handle)), userInfo: info)
    }

    static func snapshot(from source: URL, to destination: URL, immutableSource: Bool = false) throws {
        let input = try LLSQLiteConnection(url: source, readOnly: true, immutable: immutableSource)
        let output = try LLSQLiteConnection(url: destination)
        guard let backup = sqlite3_backup_init(output.handle, "main", input.handle, "main") else { throw output.error() }
        var result: Int32 = SQLITE_BUSY
        for _ in 0..<300 {
            result = sqlite3_backup_step(backup, -1)
            if result != SQLITE_BUSY && result != SQLITE_LOCKED { break }
            Thread.sleep(forTimeInterval: 0.01)
        }
        let finished = sqlite3_backup_finish(backup)
        guard result == SQLITE_DONE, finished == SQLITE_OK else { throw output.error() }
        // A self-contained snapshot must not depend on a WAL sidecar.
        try output.execute("PRAGMA journal_mode=DELETE")
    }

    static func validateDatabase(at url: URL) throws {
        let connection = try LLSQLiteConnection(url: url, readOnly: true)
        let result = try connection.query("PRAGMA quick_check")
        guard result.count == 1, result.first?.values.first == "ok" else { throw BackupError.invalidFile }
        for sql in [
            "SELECT id, name FROM categories LIMIT 0",
            "SELECT id, category_id, name, total_words FROM word_lists LIMIT 0",
            "SELECT id, word_list_id, word, translation FROM words LIMIT 0"
        ] { try connection.execute(sql) }
    }
}
