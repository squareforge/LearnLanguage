import AppKit

// Controlled service boundaries: no clipboard, OCR, system translation, sound or persistent storage.
struct TranslationTestSettings {
    var translateFontSize: CGFloat = 14
    var translateLanguageReversed = false
    var currentLanguage = "en"
    var translateDoubleCopyEnabled = true
    var translateClipboardOCREnabled = true
    var translateDoubleCopyInterval: Double = 3
}
final class LLSettingsStore {
    static let shared = LLSettingsStore()
    var settings = TranslationTestSettings()
    var currentLanguage: String { settings.currentLanguage }
}
final class LLClipboardMonitor {
    static weak var latest: LLClipboardMonitor?
    var onTextDetected: ((String) -> Void)?
    var onImageDetected: ((NSImage) -> Void)?
    init() { Self.latest = self }
    func startMonitoring() {}
    func stopMonitoring() {}
    func copy(_ text: String) { onTextDetected?(text); onTextDetected?(text) }
}
enum LLOCRService {
    static var callbacks: [(String?) -> Void] = []
    static func recognizeText(from image: NSImage, completion: @escaping (String?) -> Void) { callbacks.append(completion) }
}
final class LLTranslationManager {
    static let shared = LLTranslationManager()
    struct TranslationResult { let translatedText: String; let phonetics: String? }
    struct Direction {
        let sourceIdentifier: String
        let targetIdentifier: String
        var speechLanguageCode: String { sourceIdentifier }
        static func preferred(for language: String, reversed: Bool) -> Direction {
            .init(sourceIdentifier: reversed ? "zh" : language, targetIdentifier: reversed ? language : "zh")
        }
    }
    var requests: [(UUID, String, (Result<TranslationResult, Error>) -> Void)] = []
    var cancelled: Set<UUID> = []
    func cancel(_ id: UUID?) { if let id { cancelled.insert(id) } }
    func translate(_ text: String, direction: Direction, completion: @escaping (Result<TranslationResult, Error>) -> Void) -> UUID? {
        let id = UUID()
        requests.append((id,text,completion))
        return id
    }
}
final class LLSpeechService {
    static let shared = LLSpeechService()
    var isSpeaking = false
    private var completion: ((Bool) -> Void)?
    func speak(_ text: String, language: String, completion: ((Bool) -> Void)? = nil) -> Bool {
        self.completion = completion
        isSpeaking = true
        return true
    }
    func stop() { isSpeaking = false; completion?(false); completion = nil }
}
final class LLWordListStorage {
    static let shared = LLWordListStorage()
    var added: [(String,String)] = []
    func addWordToVocabularyNotebook(text: String, meaning: String, phonetic: String?, language: String) -> Bool { added.append((text,meaning)); return true }
    func containsWordInVocabularyNotebook(_ text: String, language: String) -> Bool { false }
}
final class LLTranslateWindowManager {
    static let shared = LLTranslateWindowManager()
    var currentWindow: NSPanel?
    func showWindow(viewModel: LLTranslateViewModel) { viewModel.triggerTranslation() }
    func dismissWindow() {}
}
enum LLLogger {
    static func info(_ message: String) {}
    static func debug(_ message: String) {}
    static func error(_ message: String) {}
}
