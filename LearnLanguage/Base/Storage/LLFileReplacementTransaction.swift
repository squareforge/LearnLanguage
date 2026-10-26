import Foundation

/// A recovery journal survives interruption; uncommitted replacements restore the original file set at startup.
enum LLFileReplacementTransaction {
    private struct Journal: Codable {
        let paths: [String]
        let originals: [String]
        var committed: Bool
    }
    private static let journalName = ".LearnLanguageRestore"

    static func recoverIfNeeded(in root: URL, managedPaths: Set<String>) throws {
        let fm = FileManager.default
        let journalURL = root.appendingPathComponent(journalName, isDirectory: true)
        guard fm.fileExists(atPath: journalURL.path) else { return }
        let stateURL = journalURL.appendingPathComponent("state.json")
        guard fm.fileExists(atPath: stateURL.path) else {
            // No destination is touched before the journal is fully prepared.
            try fm.removeItem(at: journalURL)
            return
        }
        do {
            let journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: stateURL))
            guard Set(journal.paths).isSubset(of: managedPaths), Set(journal.originals).isSubset(of: Set(journal.paths)) else { throw BackupError.invalidFile }
            if !journal.committed {
                // Validate all recovery sources before touching a destination.
                for path in journal.originals {
                    guard fm.fileExists(atPath: journalURL.appendingPathComponent("old/" + path).path) else { throw BackupError.invalidFile }
                }
                for path in journal.paths {
                    let destination = root.appendingPathComponent(path)
                    if journal.originals.contains(path) {
                        try copyAtomically(from: journalURL.appendingPathComponent("old/" + path), to: destination)
                    } else if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
                }
            }
            try fm.removeItem(at: journalURL)
        } catch { throw BackupError.recoveryFailed(journalURL.path) }
    }

    static func install(_ sources: [String: URL], in root: URL, managedPaths: Set<String>, afterInstall: () throws -> Void = {}) throws {
        let fm = FileManager.default
        guard Set(sources.keys).isSubset(of: managedPaths) else { throw BackupError.invalidFile }
        try recoverIfNeeded(in: root, managedPaths: managedPaths)
        let journalURL = root.appendingPathComponent(journalName, isDirectory: true)
        try fm.createDirectory(at: journalURL, withIntermediateDirectories: true)
        let originals = managedPaths.sorted().filter { fm.fileExists(atPath: root.appendingPathComponent($0).path) }
        do {
            for path in originals {
                let target = journalURL.appendingPathComponent("old/" + path)
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: root.appendingPathComponent(path), to: target)
            }
            var journal = Journal(paths: managedPaths.sorted(), originals: originals, committed: false)
            let stateURL = journalURL.appendingPathComponent("state.json")
            try JSONEncoder().encode(journal).write(to: stateURL, options: .atomic)
            for path in managedPaths.sorted() {
                let destination = root.appendingPathComponent(path)
                if let source = sources[path] {
                    try copyAtomically(from: source, to: destination)
                } else if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
            }
            try afterInstall()
            journal.committed = true
            try JSONEncoder().encode(journal).write(to: stateURL, options: .atomic)
            try? fm.removeItem(at: journalURL)
        } catch {
            try recoverIfNeeded(in: root, managedPaths: managedPaths)
            throw error
        }
    }

    private static func copyAtomically(from source: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contentsOf: source, options: .mappedIfSafe).write(to: destination, options: .atomic)
    }
}
