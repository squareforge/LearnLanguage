//
//  LLTranslateViewModel.swift
//  LearnLanguage
//
//  浮动翻译窗口的 ViewModel - 纯 Swift 实现，使用回调驱动 UI 更新
//

import AppKit

final class LLTranslateViewModel {

    // MARK: - State

    private(set) var sourceString: String = ""
    private(set) var targetString: String = LLTranslateViewModel.placeholder
    private(set) var wordPhonetics: String? = nil
    private(set) var isTranslationCompleted: Bool = false
    private(set) var isPinned: Bool = false
    private(set) var isSpeaking: Bool = false

    static let placeholder = "..."

    // MARK: - UI Callbacks

    /// 翻译结果更新（text, phonetic, isCompleted）
    var onTranslationUpdated: ((String, String?, Bool) -> Void)?
    /// Pin 状态变化
    var onPinChanged: ((Bool) -> Void)?
    /// 朗读状态变化
    var onSpeakChanged: ((Bool) -> Void)?

    // MARK: - Settings

    var fontSize: CGFloat {
        LLSettingsStore.shared.settings.translateFontSize
    }

    var isLanguageReversed: Bool {
        LLSettingsStore.shared.settings.translateLanguageReversed
    }
    
    private var currentTranslationDirection: LLTranslationManager.Direction {
        let settings = LLSettingsStore.shared.settings
        return LLTranslationManager.Direction.preferred(
            for: settings.currentLanguage,
            reversed: settings.translateLanguageReversed
        )
    }

    // MARK: - Private

    private let clipboardMonitor = LLClipboardMonitor()
    private var mouseEventMonitor: Any?
    private var translationID: UUID?
    private var submittedDirection: LLTranslationManager.Direction?
    private var translationGeneration = 0
    private var contentGeneration = 0
    private var copyCount = 0
    private var lastCopyTime = Date()
    private var pinnedWindowPosition: NSPoint?

    // MARK: - Init

    init() {
        setupClipboardMonitoring()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSettingsChanged),
            name: .learnLanguageRefreshStatus,
            object: nil
        )
    }

    deinit {
        stopMouseMonitoring()
        clipboardMonitor.stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Clipboard Monitoring

    private func setupClipboardMonitoring() {
        let settings = LLSettingsStore.shared.settings
        guard settings.translateDoubleCopyEnabled || settings.translateClipboardOCREnabled else {
            clipboardMonitor.stopMonitoring()
            return
        }

        clipboardMonitor.onTextDetected = { [weak self] text in
            guard LLSettingsStore.shared.settings.translateDoubleCopyEnabled else { return }
            self?.handleCopyEvent(text)
        }

        clipboardMonitor.onImageDetected = { [weak self] image in
            guard LLSettingsStore.shared.settings.translateClipboardOCREnabled else { return }
            if #available(macOS 13.0, *) {
                self?.handleClipboardImage(image)
            } else {
                // Fallback on earlier versions
            }
        }

        clipboardMonitor.startMonitoring()
        LLLogger.info("✅ 翻译剪贴板监听已启动")
    }

    private func handleCopyEvent(_ text: String) {
        let settings = LLSettingsStore.shared.settings
        let now = Date()
        let interval = settings.translateDoubleCopyInterval

        if now.timeIntervalSince(lastCopyTime) <= interval {
            copyCount += 1
            if copyCount == 2 {
                contentGeneration += 1
                sourceString = text
                targetString = LLTranslateViewModel.placeholder
                showWindowAtMouse()
                copyCount = 0
            }
        } else {
            copyCount = 1
        }
        lastCopyTime = now
    }

    @available(macOS 13.0, *)
    private func handleClipboardImage(_ image: NSImage) {
        contentGeneration += 1
        let generation = contentGeneration
        LLOCRService.recognizeText(from: image) { [weak self] text in
            guard let self, self.contentGeneration == generation,
                  let text,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            self.sourceString = text
            self.targetString = LLTranslateViewModel.placeholder
            self.showWindowAtMouse()
        }
    }

    // MARK: - Translation

    func triggerTranslation() {
        translationGeneration += 1
        let generation = translationGeneration
        LLTranslationManager.shared.cancel(translationID)
        let submittedText = sourceString
        isTranslationCompleted = false
        targetString = Self.placeholder
        wordPhonetics = nil
        onTranslationUpdated?(targetString, nil, false)

        let direction = currentTranslationDirection
        submittedDirection = direction

        translationID = LLTranslationManager.shared.translate(submittedText, direction: direction) { [weak self] result in
            guard let self, self.translationGeneration == generation, self.sourceString == submittedText else { return }
            self.translationID = nil
            switch result {
            case .success(let r):
                self.targetString = r.translatedText
                self.wordPhonetics = r.phonetics
                self.isTranslationCompleted = true
                self.onTranslationUpdated?(r.translatedText, r.phonetics, true)
                LLLogger.debug("✅ 翻译成功: \(r.translatedText)")
            case .failure(let error):
                self.targetString = error.localizedDescription
                self.isTranslationCompleted = false
                self.onTranslationUpdated?(error.localizedDescription, nil, false)
                LLLogger.error("❌ 翻译失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Speech

    func speakSource() {
        if LLSpeechService.shared.isSpeaking {
            stopSpeaking()
            return
        }
        
        let lang = currentTranslationDirection.speechLanguageCode
        if LLSpeechService.shared.speak(sourceString, language: lang, completion: { [weak self] _ in
            self?.isSpeaking = false
            self?.onSpeakChanged?(false)
        }) {
            isSpeaking = true
            onSpeakChanged?(true)
        }
    }

    func stopSpeaking() {
        LLSpeechService.shared.stop()
        isSpeaking = false
        onSpeakChanged?(false)
    }
    
    @discardableResult
    func addCurrentSourceToVocabularyNotebook() -> Bool {
        guard isTranslationCompleted,
              !sourceString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !targetString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        return LLWordListStorage.shared.addWordToVocabularyNotebook(
            text: sourceString,
            meaning: targetString,
            phonetic: wordPhonetics,
            language: LLSettingsStore.shared.currentLanguage
        )
    }
    
    var isCurrentSourceInVocabularyNotebook: Bool {
        LLWordListStorage.shared.containsWordInVocabularyNotebook(sourceString, language: LLSettingsStore.shared.currentLanguage)
    }

    // MARK: - Window Management

    func showWindowAtMouse() {
        LLTranslateWindowManager.shared.showWindow(viewModel: self)
    }

    func dismissWindow() {
        translationGeneration += 1
        contentGeneration += 1
        LLTranslationManager.shared.cancel(translationID)
        translationID = nil
        stopSpeaking()
        LLTranslateWindowManager.shared.dismissWindow()
        isPinned = false
        pinnedWindowPosition = nil
    }

    func togglePin() {
        if !isPinned {
            if let window = LLTranslateWindowManager.shared.currentWindow {
                pinnedWindowPosition = window.frame.origin
                window.collectionBehavior = [.canJoinAllSpaces]
                window.isMovable = true
                window.isMovableByWindowBackground = true
            }
        } else {
            pinnedWindowPosition = nil
            if let window = LLTranslateWindowManager.shared.currentWindow {
                window.collectionBehavior = []
                window.isMovable = false
                window.isMovableByWindowBackground = false
            }
        }
        isPinned.toggle()
        onPinChanged?(isPinned)
    }

    func pinnedPosition() -> NSPoint? { pinnedWindowPosition }

    // MARK: - Mouse Monitoring

    func setupMouseMonitoring() {
        guard mouseEventMonitor == nil else { return }
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, !self.isPinned else { return }
            guard let window = LLTranslateWindowManager.shared.currentWindow else { return }
            let click = NSEvent.mouseLocation
            let expanded = NSRect(
                x: window.frame.minX - 5, y: window.frame.minY - 5,
                width: window.frame.width + 10, height: window.frame.height + 10
            )
            if !expanded.contains(click) {
                self.dismissWindow()
            }
        }
    }

    func stopMouseMonitoring() {
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            mouseEventMonitor = nil
        }
    }

    // MARK: - Settings Observer

    @objc private func onSettingsChanged() {
        clipboardMonitor.stopMonitoring()
        setupClipboardMonitoring()
        let current = currentTranslationDirection
        if let previous = submittedDirection,
           previous.sourceIdentifier != current.sourceIdentifier || previous.targetIdentifier != current.targetIdentifier {
            contentGeneration += 1
            stopSpeaking()
            translationGeneration += 1
            LLTranslationManager.shared.cancel(translationID)
            translationID = nil
            isTranslationCompleted = false
            if LLTranslateWindowManager.shared.currentWindow != nil { triggerTranslation() }
        }
    }
}
