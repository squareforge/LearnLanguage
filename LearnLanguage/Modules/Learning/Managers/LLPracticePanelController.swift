import AppKit
import SnapKit

/// One floating surface for every practice source. Hiding it preserves the current input.
final class LLPracticePanelController: NSObject, NSWindowDelegate {
    static let shared = LLPracticePanelController()
    private var panel: FloatingPanel?
    private var controller: LLPracticeFloatingViewController?
    private(set) var session: LLPracticeSession?
    private var automaticSpeechSuspension: UUID?
    private var presentationGeneration = 0
    var isVisible: Bool { panel?.isVisible == true }
    var courseSession: LLPracticeSession? {
        guard session?.source is LLCoursePracticeSource else { return nil }
        return session
    }

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(applySettings), name: .floatingPanelSettingsChanged, object: nil)
    }

    /// Restore the selected mode without opening a window or starting speech.
    func restoreSelectedCourseIfNeeded() {
        guard session == nil else { return }
        let sourceID = LLMMKVManager.shared.string(forKey: "learning.last_source")
        guard sourceID.hasPrefix("course:"),
              let course = try? LLCourseRepository.shared.courses().first(where: { "course:\($0.id)" == sourceID }) else { return }
        session = LLPracticeSession(source: LLCoursePracticeSource(course: course), showHint: !LLSettingsStore.shared.settings.typingDictationMode)
    }

    func start(source: LLPracticeSource) {
        suspendVocabularyPlayback()
        session = LLPracticeSession(source: source, showHint: !LLSettingsStore.shared.settings.typingDictationMode)
        LLMMKVManager.shared.set(source.id, forKey: "learning.last_source")
        createPanelIfNeeded()
        panel?.title = "学习练习 · \(source.title)"
        if let session { controller?.configure(session: session) }
        show()
        NotificationCenter.default.post(name: .learningPracticeProgressChanged, object: nil)
    }

    func resumeOrStart() {
        if session != nil { show(); return }
        let sourceID = LLMMKVManager.shared.string(forKey: "learning.last_source")
        if sourceID.hasPrefix("course:"),
           let course = try? LLCourseRepository.shared.courses().first(where: { "course:\($0.id)" == sourceID }) {
            start(source: LLCoursePracticeSource(course: course))
        } else {
            let listID = sourceID.hasPrefix("wordlist:") ? String(sourceID.dropFirst(9)) : LLSettingsStore.shared.currentListId
            if let listID, let list = LLWordListStorage.shared.list(byId: listID) {
                LLSettingsStore.shared.currentListId = list.id
                start(source: LLVocabularyPracticeSource(list: list))
            } else {
                (NSApp.delegate as? LLAppDelegate)?.showLearningHome()
            }
        }
    }

    func show() {
        guard session != nil else { return }
        syncVocabulary()
        guard session != nil else {
            (NSApp.delegate as? LLAppDelegate)?.showLearningHome()
            return
        }
        createPanelIfNeeded()
        suspendVocabularyPlayback()
        presentationGeneration += 1
        let generation = presentationGeneration
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeFirstResponder(controller?.view)
        LLStatusBarManager.shared.isTypingPracticeMode = true
        // Finish the source button's tracking and the activation-policy change first.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentationGeneration == generation, self.isVisible else { return }
            self.panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            self.controller?.resume()
        }
    }

    func hide() {
        presentationGeneration += 1
        controller?.stopAudio()
        panel?.orderOut(nil)
        if let token = automaticSpeechSuspension {
            LLStatusBarManager.shared.resumeAutomaticPronunciation(token: token)
            automaticSpeechSuspension = nil
        }
        LLStatusBarManager.shared.isTypingPracticeMode = false
    }

    private func suspendVocabularyPlayback() {
        guard automaticSpeechSuspension == nil else { return }
        automaticSpeechSuspension = LLStatusBarManager.shared.suspendAutomaticPronunciation()
    }

    /// Menu-bar and global playback commands follow the selected practice source.
    func replayCoursePronunciation() {
        guard let item = courseSession?.item else { return }
        if isVisible { controller?.replayCurrentItem() }
        else {
            let rate = Float(LLMMKVManager.shared.double(forKey: "learning.practice_rate", defaultValue: 1))
            LLPronunciationManager.shared.speakSentence(item.text, rateMultiplier: rate)
        }
    }

    func skipCourseItem() {
        guard courseSession != nil else { return }
        if let controller { controller.skipCurrentItem() }
        else {
            session?.skip()
            LLStatusBarManager.shared.refreshStatusBar()
        }
    }

    func toggleVisibility() { isVisible ? hide() : resumeOrStart() }

    func resetAfterDataChange() {
        hide()
        session = nil
        panel?.delegate = nil
        panel?.close()
        panel = nil
        controller = nil
        LLStatusBarManager.shared.refreshStatusBar()
    }

    func syncVocabulary() {
        guard let session, let source = session.source as? LLVocabularyPracticeSource, !session.isAdvancing else { return }
        if source.listID != LLSettingsStore.shared.currentListId {
            guard let list = LLSettingsStore.shared.currentWordList else {
                hide()
                self.session = nil
                return
            }
            let replacement = LLPracticeSession(source: LLVocabularyPracticeSource(list: list), showHint: !LLSettingsStore.shared.settings.typingDictationMode)
            self.session = replacement
            panel?.title = "学习练习 · \(replacement.source.title)"
            LLMMKVManager.shared.set(replacement.source.id, forKey: "learning.last_source")
            controller?.configure(session: replacement)
            if isVisible { controller?.resume() }
            return
        }
        let previousID = session.item?.id
        session.syncCurrentItem()
        if previousID != session.item?.id {
            controller?.refresh()
            if isVisible { controller?.resume() }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { hide(); return false }
    func windowDidResignKey(_ notification: Notification) { controller?.stopAudio() }
    func windowDidBecomeKey(_ notification: Notification) { controller?.focusInput() }

    func windowDidResize(_ notification: Notification) {
        guard let panel else { return }
        var settings = LLSettingsStore.shared.settings
        settings.floatingPanelWidth = panel.contentLayoutRect.width
        settings.floatingPanelHeight = panel.contentLayoutRect.height
        LLSettingsStore.shared.settings = settings
    }

    @objc func applySettings() {
        let settings = LLSettingsStore.shared.settings
        panel?.alphaValue = min(max(settings.floatingPanelAlpha, 0.15), 1)
        if let panel {
            let size = NSSize(width: min(max(settings.floatingPanelWidth, panel.minSize.width), panel.maxSize.width),
                              height: min(max(settings.floatingPanelHeight, panel.minSize.height), panel.maxSize.height))
            if panel.contentLayoutRect.size != size { panel.setContentSize(size) }
        }
        controller?.refresh()
    }

    private func createPanelIfNeeded() {
        guard panel == nil else { applySettings(); return }
        let settings = LLSettingsStore.shared.settings
        let size = NSSize(width: min(max(360, settings.floatingPanelWidth), 900), height: min(max(240, settings.floatingPanelHeight), 600))
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
        panel.becomesKeyOnlyIfNeeded = false
        panel.minSize = NSSize(width: 360, height: 240)
        panel.maxSize = NSSize(width: 900, height: 600)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.setFrameAutosaveName("LLUnifiedPracticePanel")
        if !panel.setFrameUsingName("LLUnifiedPracticePanel") { panel.center() }

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true
        panel.contentView = effect

        let controller = LLPracticeFloatingViewController()
        controller.onHide = { [weak self] in self?.hide() }
        controller.onChooseSource = { [weak self] in
            self?.hide()
            (NSApp.delegate as? LLAppDelegate)?.showLearningHome()
        }
        effect.addSubview(controller.view)
        panel.initialFirstResponder = controller.view
        controller.view.snp.makeConstraints { $0.edges.equalToSuperview() }
        self.panel = panel
        self.controller = controller
        if let session {
            panel.title = "学习练习 · \(session.source.title)"
            controller.configure(session: session)
        }
        applySettings()
    }
}
