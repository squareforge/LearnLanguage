import Foundation
import CryptoKit

enum BackupError: Error, LocalizedError {
    case invalidFile, unsupportedVersion, decryptionFailed, storageUnavailable
    case recoveryFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidFile: return "备份内容不完整或格式不正确，原有数据未替换。"
        case .unsupportedVersion: return "备份版本不支持，请更新应用。"
        case .decryptionFailed: return "备份解密失败，文件可能已损坏。"
        case .storageUnavailable: return "无法读取或保存完整的学习数据，请检查磁盘空间后重试。"
        case .recoveryFailed(let path): return "恢复未完成，原始数据副本保留在：\(path)。请重新启动应用以重试恢复。"
        }
    }
}

/// Version 1 keeps its original wire format; version 2 requires a complete, checksummed manifest.
enum LLBackupArchive {
    static let version: UInt8 = 2
    static let databasePath = "LearnLanguage.db"
    static let requiredPaths: Set<String> = [databasePath, "mmkv/mmkv.default", "mmkv/mmkv.default.crc"]
    static let managedPaths = requiredPaths.union(["LearnLanguage.db-wal", "LearnLanguage.db-shm"])
    private static let allowedPaths = managedPaths.union(["manifest.json"])
    private static let magic = Data([0x4C, 0x4C, 0x42, 0x4B])

    struct Manifest: Codable {
        var version = 2
        var checksums: [String: String]
    }

    private struct Reader {
        let data: Data
        var offset = 0
        mutating func read(_ count: Int) throws -> Data {
            guard count >= 0, offset <= data.count, count <= data.count - offset else { throw BackupError.invalidFile }
            defer { offset += count }
            return data.subdata(in: offset..<(offset + count))
        }
        mutating func integer(bytes: Int) throws -> UInt64 {
            try read(bytes).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        }
        mutating func length(bytes: Int) throws -> Int {
            guard let value = Int(exactly: try integer(bytes: bytes)), value <= data.count - offset else { throw BackupError.invalidFile }
            return value
        }
        var isAtEnd: Bool { offset == data.count }
    }

    static func envelope(_ encrypted: Data) -> Data {
        var result = magic
        result.append(version)
        appendInteger(UInt64(encrypted.count), bytes: 8, to: &result)
        result.append(encrypted)
        return result
    }

    static func parseEnvelope(_ data: Data) throws -> (version: UInt8, encrypted: Data) {
        var reader = Reader(data: data)
        guard try reader.read(4) == magic else { throw BackupError.invalidFile }
        let version = UInt8(try reader.integer(bytes: 1))
        guard version == 1 || version == Self.version else { throw BackupError.unsupportedVersion }
        let length = try reader.length(bytes: 8)
        let encrypted = try reader.read(length)
        guard reader.isAtEnd, encrypted.count >= 28 else { throw BackupError.invalidFile }
        return (version, encrypted)
    }

    static func encode(_ files: [String: Data]) throws -> Data {
        guard Set(files.keys) == requiredPaths else { throw BackupError.invalidFile }
        var items = files
        items["manifest.json"] = try JSONEncoder().encode(Manifest(checksums: files.mapValues(checksum)))
        var result = Data()
        appendInteger(UInt64(items.count), bytes: 4, to: &result)
        for path in items.keys.sorted() {
            let name = Data(path.utf8)
            appendInteger(UInt64(name.count), bytes: 2, to: &result)
            result.append(name)
            let data = items[path]!
            appendInteger(UInt64(data.count), bytes: 8, to: &result)
            result.append(data)
        }
        return result
    }

    static func decode(_ packed: Data, version: UInt8) throws -> [String: Data] {
        var reader = Reader(data: packed)
        let count = try reader.integer(bytes: 4)
        guard count > 0, count <= allowedPaths.count else { throw BackupError.invalidFile }
        var files: [String: Data] = [:]
        for _ in 0..<count {
            let pathLength = try reader.length(bytes: 2)
            guard let path = String(data: try reader.read(pathLength), encoding: .utf8),
                  allowedPaths.contains(path), files[path] == nil else { throw BackupError.invalidFile }
            let size = try reader.length(bytes: 8)
            files[path] = try reader.read(size)
        }
        guard reader.isAtEnd, requiredPaths.isSubset(of: Set(files.keys)),
              (files["LearnLanguage.db-shm"] == nil || files["LearnLanguage.db-wal"] != nil) else { throw BackupError.invalidFile }
        if version >= 2 {
            guard let data = files.removeValue(forKey: "manifest.json"),
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data), manifest.version == 2,
                  Set(manifest.checksums.keys) == requiredPaths, Set(files.keys) == requiredPaths,
                  files.allSatisfy({ manifest.checksums[$0.key] == checksum($0.value) }) else { throw BackupError.invalidFile }
        } else if files["manifest.json"] != nil { throw BackupError.invalidFile }
        return files
    }

    nonisolated static func checksum(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func appendInteger(_ value: UInt64, bytes: Int, to data: inout Data) {
        for shift in (0..<bytes).reversed() { data.append(UInt8(truncatingIfNeeded: value >> (shift * 8))) }
    }
}
