import Foundation

// In-memory boundaries keep these tests independent of the user's database and MMKV.
final class LLMMKVManager {
    static let shared = LLMMKVManager()
    private var values: [String: Data] = [:]
    var rejectWrites = false
    @discardableResult
    func set(_ value: Data, forKey key: String) -> Bool {
        guard !rejectWrites else { return false }
        values[key] = value
        return true
    }
    func data(forKey key: String) -> Data? { values[key] }
}
struct WordList { let id: String; let name: String }
struct TestExample { let sentenceEn: String }
struct TestEntry {
    let id: String; let wordListId: String; let text: String
    var meaning = "释义"
    var phonetic: String? = nil
    var examples: [TestExample] = []
    func enrichedWithExamplesIfNeeded() -> TestEntry { self }
}
final class LLSettingsStore {
    static let shared = LLSettingsStore()
    var currentListId: String?
}
final class LLDailyLearningManager {
    static let shared = LLDailyLearningManager()
    var entries: [TestEntry] = []
    var recordedErrors: [Int] = []
    var lastError: String?
    var reviewQueueCount: Int { entries.count }
    var newWordQueueCount: Int { 0 }
    var newLearnWordQueueCount: Int { 0 }
    func setup(listId: String) {}
    func nextWord() -> TestEntry? { entries.first }
    func recordTypingResult(entry: TestEntry, errorCount: Int) -> Bool {
        recordedErrors.append(errorCount)
        entries.removeFirst()
        return true
    }
    func learnAnotherBatch() {}
}
final class LLStatusBarManager {
    static let shared = LLStatusBarManager()
    var onRefresh: (() -> Void)?
    func refreshStatusBar() { onRefresh?() }
}
