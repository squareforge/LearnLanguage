import AppKit

// Keep real AppKit controllers, session, sources and status-bar routing. Isolate storage, audio and menu drawing.
enum SidebarModule: String, Codable { case learning, wordList, learningRecord, settings, dataManagement }
enum LLTranslationManager { enum Direction { case enToZh, zhToEn, jaToEn, enToJa, koToEn, enToKo } }
final class LLSettingsStore {
    static let shared = LLSettingsStore()
    var settings = LLAppSettings.default
    var currentListId: String? {
        get { settings.currentListId }
        set { settings.currentListId = newValue }
    }
    var currentWordList: WordList? { LLWordListStorage.shared.list(byId: currentListId ?? "") }
}
final class LLMMKVManager {
    static let shared = LLMMKVManager()
    private var values: [String: Any] = [:]
    @discardableResult func set<T>(_ value: T, forKey key: String) -> Bool { values[key] = value; return true }
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func string(forKey key: String) -> String { values[key] as? String ?? "" }
    func bool(forKey key: String, defaultValue: Bool) -> Bool { values[key] as? Bool ?? defaultValue }
    func double(forKey key: String, defaultValue: Double) -> Double { values[key] as? Double ?? defaultValue }
}
struct WordList {
    let id: String
    let name: String
    var category = "测试"
    var entryCount = 1
    var isVocabularyNotebook = false
}
struct LLWordEntry {
    let id: String
    let wordListId: String
    let text: String
    var meaning = "词库释义"
    var phonetic: String? = nil
    struct Example { let sentenceEn: String }
    var examples: [Example] = []
    func enrichedWithExamplesIfNeeded() -> LLWordEntry { self }
}
final class LLWordListStorage {
    static let shared = LLWordListStorage()
    var lists = [WordList(id: "vocabulary", name: "测试词库")]
    func allLists() -> [WordList] { lists }
    func list(byId id: String) -> WordList? { lists.first { $0.id == id } }
}
final class LLDailyLearningManager {
    static let shared = LLDailyLearningManager()
    var entries = [LLWordEntry(id: "vocab-item", wordListId: "vocabulary", text: "unrelated-vocabulary")]
    var lastError: String?
    var recordedFeedback = 0
    var reviewQueueCount: Int { entries.count }
    var newWordQueueCount: Int { 0 }
    var newLearnWordQueueCount: Int { 0 }
    func setup(listId: String) {}
    func nextWord() -> LLWordEntry? { entries.first }
    func recordTypingResult(entry: LLWordEntry, errorCount: Int) -> Bool { recordedFeedback += 1; return true }
    func recordFeedback(_ feedback: LLWordFeedback, for entry: LLWordEntry) -> Bool { recordedFeedback += 1; return true }
    func learnAnotherBatch() {}
}
final class LLDatabaseManager {
    static let shared = LLDatabaseManager()
    struct Progress { var reviewCount = 0 }
    func getLearningProgress(wordId: String, wordListId: String) throws -> Progress? { Progress() }
}
final class LLPronunciationManager {
    static let shared = LLPronunciationManager()
    var spoken: [String] = []
    var isSpeaking = false
    var stopped = 0
    func stop() { stopped += 1; isSpeaking = false }
    func speakSentence(_ text: String, rateMultiplier: Float = 1, completion: ((Bool, Error?) -> Void)? = nil) { spoken.append(text); isSpeaking = true }
    func speakEnglishManually(word: String) { spoken.append(word); isSpeaking = true }
    func speak(entry: LLWordEntry, completion: ((Bool, Error?) -> Void)? = nil) { spoken.append(entry.text); isSpeaking = true }
}
final class LLTypingSoundManager {
    static let shared = LLTypingSoundManager()
    func playLetterSound(for character: Character) {}
    func playKeySound() {}
    func playWrongSound() {}
    func playCompleteSound() {}
}
final class LLAppearanceManager {
    static let shared = LLAppearanceManager()
    struct Colors {
        let cardBackground = NSColor.windowBackgroundColor
        let primaryText = NSColor.labelColor
        let tertiaryText = NSColor.tertiaryLabelColor
        let secondaryText = NSColor.secondaryLabelColor
        let mainBackground = NSColor.windowBackgroundColor
        let accentLightBackground = NSColor.controlAccentColor
        let accentColor = NSColor.controlAccentColor
    }
    let colors = Colors()
    static func appFont(name: String, size: CGFloat, fallbackWeight: NSFont.Weight) -> NSFont { .systemFont(ofSize: size, weight: fallbackWeight) }
}
final class LLStatusBarContentView: NSView {
    static var displayedWord = ""
    static var allowsFeedback = true
    init(statusItem: NSStatusItem) { super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }
    static func minimumRequiredWidth() -> CGFloat { 150 }
    func updateContent(word: String, phonetic: String, meaning: String, reviewCount: Int = 0, vocabularyFeedbackEnabled: Bool = true) {
        Self.displayedWord = word
        Self.allowsFeedback = vocabularyFeedbackEnabled
    }
}
final class LLAppDelegate: NSObject, NSApplicationDelegate {
    func showLearningHome() {}
}
enum LLLogger {
    static func info(_ message: String) {}
    static func debug(_ message: String) {}
    static func warn(_ message: String) {}
    static func error(_ message: String) {}
}
