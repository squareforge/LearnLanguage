import AppKit

@main
struct TranslationTests {
    static var assertions = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        if !condition() { fatalError(message) }
    }
    static func main() {
        let model = LLTranslateViewModel()
        let clipboard = LLClipboardMonitor.latest!
        let service = LLTranslationManager.shared
        var displayed = ""
        model.onTranslationUpdated = { text, _, _ in displayed = text }
        clipboard.copy("first")
        check(service.requests.count == 1, "One accepted double-copy starts one translation")
        clipboard.copy("second")
        check(service.requests.count == 2 && service.cancelled.contains(service.requests[0].0), "New content cancels the previous translation")
        service.requests[0].2(.success(.init(translatedText: "旧结果", phonetics: nil)))
        check(!model.isTranslationCompleted && displayed == "...", "A late old result cannot finish the current content")
        service.requests[1].2(.success(.init(translatedText: "新结果", phonetics: "/new/")))
        check(model.sourceString == "second" && displayed == "新结果" && model.wordPhonetics == "/new/", "Only the latest translation updates the view")
        check(model.addCurrentSourceToVocabularyNotebook(), "Successful translation can be saved")
        check(LLWordListStorage.shared.added.last?.0 == "second" && LLWordListStorage.shared.added.last?.1 == "新结果", "Saved vocabulary pairs the original with its own translation")
        clipboard.copy("third")
        model.dismissWindow()
        service.requests[2].2(.success(.init(translatedText: "关闭后结果", phonetics: nil)))
        check(!model.isTranslationCompleted && model.targetString == "...", "Dismissal invalidates a pending translation")
        check(!model.addCurrentSourceToVocabularyNotebook(), "Pending or cancelled text cannot be saved as a translation")
        clipboard.onImageDetected?(NSImage(size: NSSize(width: 1, height: 1)))
        clipboard.copy("newer than image")
        LLOCRService.callbacks[0]("stale OCR")
        check(model.sourceString == "newer than image" && service.requests.count == 4, "Late OCR cannot overwrite newer accepted clipboard text")
        let unsupported = NSError(domain: "TranslationTest", code: 1, userInfo: [NSLocalizedDescriptionKey:"翻译功能需要 macOS 15.0 或更高版本"])
        service.requests[3].2(.failure(unsupported))
        check(displayed == unsupported.localizedDescription && !model.isTranslationCompleted, "Service capability errors are delivered to the visible error state")
        check(!model.addCurrentSourceToVocabularyNotebook(), "Error text cannot be added to the notebook")
        clipboard.copy("language change")
        LLSettingsStore.shared.settings.translateLanguageReversed = true
        NotificationCenter.default.post(name: .learnLanguageRefreshStatus, object: nil)
        service.requests[4].2(.success(.init(translatedText: "wrong direction", phonetics: nil)))
        check(!model.isTranslationCompleted, "A direction change invalidates results from the old direction")
        print("Passed \(assertions) translation ordering and cancellation checks.")
    }
}
