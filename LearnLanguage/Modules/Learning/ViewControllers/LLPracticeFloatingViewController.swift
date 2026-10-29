import AppKit
import SnapKit

private final class LLPracticeInputView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?
    var onScrollWheel: ((NSEvent) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override var needsPanelToBecomeKey: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        // Labels and stack views belong to the typing surface. Only actual controls take clicks.
        var candidate: NSView? = hit
        while let view = candidate, view !== self {
            if view is NSButton || view is NSScroller { return hit }
            candidate = view.superview
        }
        return self
    }
    override var mouseDownCanMoveWindow: Bool { true }
    override func keyDown(with event: NSEvent) { onKeyDown?(event) }
    override func scrollWheel(with event: NSEvent) { onScrollWheel?(event) }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); super.mouseDown(with: event) }
}

final class LLPracticeFloatingViewController: NSViewController, NSPopoverDelegate {
    var onHide: (() -> Void)?
    var onChooseSource: (() -> Void)?
    var onNextCourse: ((LLSentenceCourse) -> Void)?
    private var session: LLPracticeSession?
    private let sourceLabel = NSTextField(labelWithString: "")
    private let positionLabel = NSTextField(labelWithString: "")
    private let meaningLabel = NSTextField(wrappingLabelWithString: "")
    private let phoneticLabel = NSTextField(wrappingLabelWithString: "")
    private let exampleLabel = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let textView = LLPracticeTextView()
    private let replayButton = NSButton()
    private let hintButton = NSButton()
    private let optionsButton = NSButton()
    private let continueButton = NSButton()
    private let nextCourseButton = NSButton(title: "下一课", target: nil, action: nil)
    private let completionActions = NSStackView()
    private var optionsPopover: NSPopover?
    private var speechGeneration = 0
    private var soundsEnabled: Bool { LLMMKVManager.shared.bool(forKey: "learning.practice_sounds", defaultValue: false) }
    private var automaticSpeech: Bool { LLMMKVManager.shared.bool(forKey: "learning.practice_auto_speech", defaultValue: true) }

    override func loadView() {
        let input = LLPracticeInputView(frame: NSRect(x: 0, y: 0, width: 480, height: 280))
        input.onKeyDown = { [weak self] in self?.handleKey($0) }
        input.onScrollWheel = { [weak self] in self?.textView.scrollWheel(with: $0) }
        view = input
    }

    override func viewDidLoad() { super.viewDidLoad(); setupUI() }

    func configure(session: LLPracticeSession) {
        stopAudio()
        self.session = session
        refresh()
    }

    func resume() {
        refresh()
        focusInput()
        if automaticSpeech && LLSettingsStore.shared.settings.pronunciationEnabled { speakCurrent() }
    }

    func stopAudio() {
        speechGeneration += 1
        LLPronunciationManager.shared.stop()
    }

    func refresh() {
        guard isViewLoaded, let session else { return }
        let settings = LLSettingsStore.shared.settings
        session.applySettings(showHint: !settings.typingDictationMode, autoShowAnswerAfterErrors: settings.autoShowAnswerAfterErrors)
        sourceLabel.stringValue = session.source.title
        positionLabel.stringValue = session.source.positionText
        textView.isHidden = session.isFinished
        exampleLabel.isHidden = session.isFinished || session.item?.example == nil
        phoneticLabel.stringValue = session.item?.phonetic ?? ""
        phoneticLabel.toolTip = session.showHint || session.isItemComplete ? session.item?.phonetic : nil
        phoneticLabel.isHidden = session.isFinished || phoneticLabel.stringValue.isEmpty || (!session.showHint && !session.isItemComplete)
        meaningLabel.stringValue = session.item?.meaning ?? "本轮练习完成"
        meaningLabel.isHidden = !session.isFinished && (session.reviewsMeaningBeforeAdvancing ? !session.isMeaningRevealed : !settings.typingPracticeShowMeaning)
        meaningLabel.toolTip = meaningLabel.isHidden ? nil : session.item?.meaning
        meaningLabel.font = .systemFont(ofSize: session.isFinished ? 22 : 15, weight: .medium)
        exampleLabel.stringValue = session.item?.example ?? ""
        continueButton.isHidden = !session.isFinished
        continueButton.title = session.source is LLCoursePracticeSource ? "继续未完成项 / 再练一遍" : "再学一组"
        completionActions.isHidden = !session.isFinished
        let nextCourse = (session.source as? LLCoursePracticeSource)?.nextCourse
        nextCourseButton.isHidden = !session.isFinished || session.errorMessage != nil || nextCourse == nil
        nextCourseButton.toolTip = nextCourse.map { "开始\($0.title)" }
        hintButton.isEnabled = !session.isFinished
        replayButton.isEnabled = !session.isFinished
        if let error = session.errorMessage {
            statusLabel.stringValue = error
            if session.isFinished {
                meaningLabel.stringValue = "学习任务暂时无法加载"
                continueButton.title = "重新加载"
            }
        } else if session.isFinished {
            statusLabel.stringValue = "进度已保存 · Esc 隐藏"
        } else if session.isItemComplete {
            statusLabel.stringValue = "完成！按 Space 或 Enter 保存并继续"
        } else if session.lastInputWasError {
            statusLabel.stringValue = "这个词再试一次 · ⌘/ 显示答案"
        } else {
            statusLabel.stringValue = "逐词输入 · Space 确认 · ⌘R 重播 · Esc 隐藏"
        }
        statusLabel.textColor = session.lastInputWasError || session.errorMessage != nil ? .systemRed : .secondaryLabelColor
        textView.render(session)
    }

    private func setupUI() {
        sourceLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        sourceLabel.textColor = .secondaryLabelColor
        sourceLabel.lineBreakMode = .byTruncatingMiddle
        positionLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        positionLabel.textColor = .tertiaryLabelColor
        meaningLabel.alignment = .center
        meaningLabel.maximumNumberOfLines = 3
        phoneticLabel.font = .systemFont(ofSize: 11)
        phoneticLabel.textColor = .tertiaryLabelColor
        phoneticLabel.alignment = .center
        phoneticLabel.maximumNumberOfLines = 3
        phoneticLabel.lineBreakMode = .byTruncatingTail
        phoneticLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        exampleLabel.alignment = .center
        exampleLabel.font = .systemFont(ofSize: 12)
        exampleLabel.textColor = .secondaryLabelColor
        exampleLabel.maximumNumberOfLines = 2
        statusLabel.font = .systemFont(ofSize: 10)
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byTruncatingTail
        for label in [sourceLabel, meaningLabel, exampleLabel, statusLabel] {
            label.isSelectable = false
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        configureIcon(replayButton, symbol: "speaker.wave.2", title: "朗读当前内容（⌘R）", action: #selector(replayAudio))
        configureIcon(hintButton, symbol: "eye", title: "显示 / 隐藏答案（⌘/）", action: #selector(toggleHint))
        configureIcon(optionsButton, symbol: "slider.horizontal.3", title: "透明度与朗读设置", action: #selector(showOptions))
        let closeButton = NSButton()
        configureIcon(closeButton, symbol: "xmark", title: "隐藏面板（Esc）", action: #selector(hidePanel))
        let buttons = NSStackView(views: [replayButton, hintButton, optionsButton, closeButton])
        buttons.spacing = 3
        let header = NSView()
        header.addSubview(sourceLabel)
        header.addSubview(positionLabel)
        header.addSubview(buttons)
        sourceLabel.snp.makeConstraints { $0.leading.top.equalToSuperview(); $0.trailing.lessThanOrEqualTo(buttons.snp.leading).offset(-8) }
        positionLabel.snp.makeConstraints { $0.leading.equalToSuperview(); $0.top.equalTo(sourceLabel.snp.bottom).offset(3) }
        buttons.snp.makeConstraints { $0.top.trailing.equalToSuperview(); $0.height.equalTo(25) }

        continueButton.target = self
        continueButton.action = #selector(replaySession)
        continueButton.bezelStyle = .rounded
        nextCourseButton.target = self
        nextCourseButton.action = #selector(startNextCourse)
        nextCourseButton.bezelStyle = .rounded
        completionActions.spacing = 8
        completionActions.addArrangedSubview(continueButton)
        completionActions.addArrangedSubview(nextCourseButton)
        let content = NSStackView(views: [exampleLabel, textView, phoneticLabel, meaningLabel, completionActions])
        content.orientation = .vertical
        content.alignment = .centerX
        content.spacing = 8
        for element in [exampleLabel, textView, phoneticLabel, meaningLabel] {
            element.snp.makeConstraints { $0.width.equalTo(content) }
        }
        textView.snp.makeConstraints { $0.height.equalTo(88).priority(.high); $0.height.greaterThanOrEqualTo(46) }
        view.addSubview(header)
        view.addSubview(content)
        view.addSubview(statusLabel)
        header.snp.makeConstraints { $0.top.equalToSuperview().offset(12); $0.leading.trailing.equalToSuperview().inset(14); $0.height.equalTo(32) }
        statusLabel.snp.makeConstraints { $0.leading.trailing.equalToSuperview().inset(12); $0.bottom.equalToSuperview().offset(-11) }
        content.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.centerY.equalToSuperview().offset(10)
            $0.top.greaterThanOrEqualTo(header.snp.bottom).offset(10)
            $0.bottom.lessThanOrEqualTo(statusLabel.snp.top).offset(-10)
        }
    }

    private func configureIcon(_ button: NSButton, symbol: String, title: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = title
        button.target = self
        button.action = action
        button.snp.makeConstraints { $0.width.height.equalTo(25) }
    }

    private func handleKey(_ event: NSEvent) {
        guard let session else { return }
        if event.keyCode == 53 { onHide?(); return }
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if event.modifierFlags.contains(.command) {
            if key == "r" { replayAudio() }
            if key == "/" { toggleHint() }
            return
        }
        if event.modifierFlags.contains(.control) {
            if key == "'" { replayAudio() }
            if key == ";" { toggleHint() }
            return
        }
        if event.keyCode == 51 { session.backspace(); refresh(); return }
        if event.keyCode == 36 && event.modifierFlags.contains(.option) {
            skipCurrentItem(); return
        }
        if event.keyCode == 49 || event.keyCode == 36 {
            guard !event.isARepeat else { return }
            if session.isFinished { replaySession(); return }
            let previousItemID = session.item?.id
            if session.confirm(), previousItemID != session.item?.id { changedItem() } else { refresh() }
            return
        }
        guard !event.modifierFlags.contains(.option), let chars = event.characters else { return }
        for char in chars where !char.isNewline && !char.isWhitespace {
            if LLSettingsStore.shared.settings.typingFollowLetterSoundEnabled {
                LLTypingSoundManager.shared.playLetterSound(for: char)
            }
            switch session.input(char) {
            case .correct: if soundsEnabled { LLTypingSoundManager.shared.playKeySound() }
            case .incorrect: if soundsEnabled { LLTypingSoundManager.shared.playWrongSound() }
            case .itemCompleted:
                if session.reviewsMeaningBeforeAdvancing || soundsEnabled { LLTypingSoundManager.shared.playCompleteSound() }
            case .ignored: break
            }
        }
        refresh()
    }

    private func changedItem() {
        stopAudio()
        refresh()
        LLStatusBarManager.shared.refreshStatusBar()
        if automaticSpeech && LLSettingsStore.shared.settings.pronunciationEnabled { speakCurrent() }
    }

    func focusInput() { view.window?.makeFirstResponder(view) }
    func replayCurrentItem() { speakCurrent(); focusInput() }
    func skipCurrentItem() { session?.skip(); changedItem(); focusInput() }
    @objc private func hidePanel() { onHide?() }
    @objc private func toggleHint() { session?.toggleHint(); refresh(); focusInput() }
    @objc private func replayAudio() { speakCurrent(); focusInput() }
    @objc private func replaySession() { session?.replay(); changedItem(); focusInput() }
    @objc private func startNextCourse() {
        guard let session, session.isFinished, session.errorMessage == nil,
              let nextCourse = (session.source as? LLCoursePracticeSource)?.nextCourse else { return }
        onNextCourse?(nextCourse)
    }

    private func speakCurrent() {
        guard let item = session?.item, view.window?.isVisible == true else { return }
        speechGeneration += 1
        let generation = speechGeneration
        let rate = Float(LLMMKVManager.shared.double(forKey: "learning.practice_rate", defaultValue: 1))
        LLPronunciationManager.shared.speakSentence(item.text, rateMultiplier: rate) { [weak self] success, _ in
            guard let self, self.speechGeneration == generation else { return }
            if !success { self.statusLabel.stringValue = "未能播放，请点击扬声器重试" }
        }
    }

    @objc private func showOptions() {
        let popover = NSPopover()
        popover.delegate = self
        popover.behavior = .transient
        let controller = NSViewController()
        controller.view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 245))
        let settings = LLSettingsStore.shared.settings
        let alphaLabel = NSTextField(labelWithString: "不透明度  \(Int(settings.floatingPanelAlpha * 100))%")
        let alpha = NSSlider(value: settings.floatingPanelAlpha, minValue: 0.15, maxValue: 1, target: self, action: #selector(changeOpacity(_:)))
        alpha.tag = 701
        alpha.isContinuous = true
        alpha.setAccessibilityLabel("面板不透明度")
        alphaLabel.tag = 702
        let speech = NSButton(checkboxWithTitle: "自动朗读英文", target: self, action: #selector(changeAutomaticSpeech(_:)))
        speech.state = automaticSpeech ? .on : .off
        let sound = NSButton(checkboxWithTitle: session?.reviewsMeaningBeforeAdvancing == true ? "按键与错误音效" : "练习音效", target: self, action: #selector(changeSounds(_:)))
        sound.state = soundsEnabled ? .on : .off
        let rate = NSPopUpButton()
        rate.addItems(withTitles: ["慢速 0.7×", "正常 1.0×", "快速 1.2×"])
        let savedRate = LLMMKVManager.shared.double(forKey: "learning.practice_rate", defaultValue: 1)
        rate.selectItem(at: savedRate < 0.9 ? 0 : savedRate > 1.1 ? 2 : 1)
        rate.target = self
        rate.action = #selector(changeRate(_:))
        let choose = NSButton(title: "选择词库或课程", target: self, action: #selector(chooseSource))
        choose.bezelStyle = .rounded
        let skip = NSTextField(labelWithString: "⌥Enter 跳过；课程保留为未完成")
        skip.font = .systemFont(ofSize: 10)
        skip.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [alphaLabel, alpha, speech, sound, rate, choose, skip])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        controller.view.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
        alpha.snp.makeConstraints { $0.width.equalTo(218) }
        popover.contentViewController = controller
        optionsPopover = popover
        popover.show(relativeTo: optionsButton.bounds, of: optionsButton, preferredEdge: .maxY)
    }

    func popoverDidClose(_ notification: Notification) { focusInput() }

    @objc private func changeOpacity(_ sender: NSSlider) {
        var settings = LLSettingsStore.shared.settings
        settings.floatingPanelAlpha = sender.doubleValue
        LLSettingsStore.shared.settings = settings
        if let label = sender.superview?.viewWithTag(702) as? NSTextField { label.stringValue = "不透明度  \(Int(sender.doubleValue * 100))%" }
        LLPracticePanelController.shared.applySettings()
    }
    @objc private func changeAutomaticSpeech(_ sender: NSButton) {
        LLMMKVManager.shared.set(sender.state == .on, forKey: "learning.practice_auto_speech")
        if sender.state == .off { stopAudio() }
    }
    @objc private func changeSounds(_ sender: NSButton) { LLMMKVManager.shared.set(sender.state == .on, forKey: "learning.practice_sounds") }
    @objc private func changeRate(_ sender: NSPopUpButton) {
        LLMMKVManager.shared.set([0.7, 1.0, 1.2][sender.indexOfSelectedItem], forKey: "learning.practice_rate")
    }
    @objc private func chooseSource() { optionsPopover?.close(); onChooseSource?() }
}
