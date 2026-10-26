//
//  LLSearchWordView.swift
//  LearnLanguage
//
//  状态栏下拉菜单中的查词视图 - 纯 AppKit 实现
//

import AppKit
import SnapKit

final class LLSearchWordView: NSView {

    // MARK: - Constants

    static let viewWidth: CGFloat  = 280
    static let viewHeight: CGFloat = 48  // 初始高度：top(8) + inputContainer(32) + bottom(8)

    // MARK: - UI

    private lazy var inputContainer: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 14
        v.layer?.borderWidth = 1
        return v
    }()

    private lazy var searchIcon: NSImageView = {
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        iv.contentTintColor = .tertiaryLabelColor
        return iv
    }()

    private lazy var searchField: NSTextField = {
        let tf = NSTextField()
        tf.isBezeled = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        tf.placeholderString = "查询（回车翻译）"
        tf.textColor = NSColor.labelColor.withAlphaComponent(0.9)
        tf.delegate = self
        return tf
    }()

    private lazy var clearButton: NSButton = {
        let btn = NSButton()
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "清空")
        btn.contentTintColor = .tertiaryLabelColor
        btn.isHidden = true
        btn.target = self
        btn.action = #selector(clearSearch)
        return btn
    }()

    private lazy var loadingIndicator: NSProgressIndicator = {
        let pi = NSProgressIndicator()
        pi.style = .spinning
        pi.controlSize = .small
        pi.isHidden = true
        return pi
    }()

    private lazy var divider: NSBox = {
        let box = NSBox()
        box.boxType = .separator
        box.isHidden = true
        return box
    }()

    private lazy var resultContainer: NSView = {
        let v = NSView()
        v.isHidden = true
        return v
    }()

    private lazy var phoneticLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.font = NSFont.systemFont(ofSize: 11)
        tf.textColor = .tertiaryLabelColor
        tf.isHidden = true
        return tf
    }()

    private lazy var resultLabel: NSTextField = {
        let tf = NSTextField(wrappingLabelWithString: "")
        tf.font = NSFont.systemFont(ofSize: 13)
        tf.textColor = .secondaryLabelColor
        tf.maximumNumberOfLines = 5
        tf.isSelectable = true
        return tf
    }()

    private lazy var speakButton: NSButton = {
        let btn = NSButton()
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "朗读")
        btn.contentTintColor = .tertiaryLabelColor
        btn.isHidden = true
        btn.target = self
        btn.action = #selector(speakWord)
        return btn
    }()

    private lazy var addVocabularyButton: NSButton = {
        let btn = NSButton(title: "添加生词", target: self, action: #selector(addToVocabularyNotebook))
        btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        btn.contentTintColor = NSColor.systemOrange
        btn.isHidden = true
        return btn
    }()

    // MARK: - State

    private var translationID: UUID?
    private var translationGeneration = 0
    private var lastSearchedText = ""
    private var lastTranslatedText = ""
    private var lastSearchSucceeded = false
    private var lastPhonetics: String?
    private var lastDirection: LLTranslationManager.Direction?
    
    private var currentTranslationDirection: LLTranslationManager.Direction {
        let settings = LLSettingsStore.shared.settings
        return LLTranslationManager.Direction.preferred(
            for: settings.currentLanguage,
            reversed: settings.translateLanguageReversed
        )
    }

    /// 高度变化回调，菜单项需要监听此回调来更新尺寸
    var onHeightChanged: ((CGFloat) -> Void)?

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        updateAppearance()
    }

    // MARK: - Setup

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func languageSettingsChanged() {
        guard let previous = lastDirection else { return }
        let current = currentTranslationDirection
        guard previous.sourceIdentifier != current.sourceIdentifier || previous.targetIdentifier != current.targetIdentifier else { return }
        cancelSearch()
        lastSearchedText = ""
        lastSearchSucceeded = false
        lastDirection = nil
        hideResult()
    }

    private func setupUI() {
        NotificationCenter.default.addObserver(self, selector: #selector(languageSettingsChanged), name: .learnLanguageRefreshStatus, object: nil)
        // 输入框容器
        addSubview(inputContainer)
        inputContainer.addSubview(searchIcon)
        inputContainer.addSubview(searchField)
        inputContainer.addSubview(clearButton)
        inputContainer.addSubview(loadingIndicator)

        inputContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(18)
            make.trailing.equalToSuperview().offset(-18)
            make.height.equalTo(42)
        }

        searchIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        searchField.snp.makeConstraints { make in
            make.leading.equalTo(searchIcon.snp.trailing).offset(10)
            make.trailing.equalTo(clearButton.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
        }

        clearButton.snp.makeConstraints { make in
            make.trailing.equalTo(loadingIndicator.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }

        // 分割线
        addSubview(divider)
        divider.snp.makeConstraints { make in
            make.top.equalTo(inputContainer.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }

        // 结果区域
        addSubview(resultContainer)
        resultContainer.addSubview(phoneticLabel)
        resultContainer.addSubview(resultLabel)
        resultContainer.addSubview(speakButton)
        resultContainer.addSubview(addVocabularyButton)

        resultContainer.snp.makeConstraints { make in
            make.top.equalTo(divider.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
        }

        speakButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.trailing.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        addVocabularyButton.snp.makeConstraints { make in
            make.centerY.equalTo(speakButton)
            make.trailing.equalTo(speakButton.snp.leading).offset(-8)
        }

        phoneticLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.lessThanOrEqualTo(addVocabularyButton.snp.leading).offset(-8)
        }

        resultLabel.snp.makeConstraints { make in
            make.top.equalTo(phoneticLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    // MARK: - Appearance

    private func updateAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        inputContainer.layer?.backgroundColor = (isDark
            ? NSColor.white.withAlphaComponent(0.14)
            : NSColor.white.withAlphaComponent(0.22)).cgColor
        inputContainer.layer?.borderColor = (isDark
            ? NSColor.white.withAlphaComponent(0.22)
            : NSColor(calibratedWhite: 0.42, alpha: 0.18)).cgColor
        inputContainer.layer?.shadowColor = NSColor.white.withAlphaComponent(isDark ? 0.06 : 0.18).cgColor
        inputContainer.layer?.shadowOpacity = 1
        inputContainer.layer?.shadowRadius = 10
        inputContainer.layer?.shadowOffset = CGSize(width: 0, height: -1)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    // MARK: - Actions

    private func cancelSearch() {
        translationGeneration += 1
        LLTranslationManager.shared.cancel(translationID)
        translationID = nil
        showLoading(false)
    }

    @objc private func clearSearch() {
        cancelSearch()
        searchField.stringValue = ""
        lastSearchedText = ""
        clearButton.isHidden = true
        hideResult()
        LLSpeechService.shared.stop()
    }

    @objc private func speakWord() {
        let word = lastSearchedText
        guard !word.isEmpty else { return }
        let lang = (lastDirection ?? currentTranslationDirection).speechLanguageCode
        LLSpeechService.shared.speak(word, language: lang)
    }
    
    @objc private func addToVocabularyNotebook() {
        guard lastSearchSucceeded else { return }
        if LLGuideManager.shared.shouldShowTip(.translateAddToVocabulary) {
            LLInlineGuideTipView.show(
                in: self,
                title: "翻译结果可以直接加入生词本",
                message: "把临时查到的不会词沉淀下来，后续就能集中复习。",
                topInset: 56,
                autoDismissAfter: 2.2
            )
            LLGuideManager.shared.markTipShown(.translateAddToVocabulary)
        }
        
        let added = LLWordListStorage.shared.addWordToVocabularyNotebook(
            text: lastSearchedText,
            meaning: lastTranslatedText,
            phonetic: lastPhonetics,
            language: LLSettingsStore.shared.currentLanguage
        )
        if added || LLWordListStorage.shared.containsWordInVocabularyNotebook(lastSearchedText, language: LLSettingsStore.shared.currentLanguage) {
            addVocabularyButton.title = "已添加"
            addVocabularyButton.contentTintColor = .secondaryLabelColor
            addVocabularyButton.isEnabled = false
        }
    }

    // MARK: - Search

    private func performSearch() {
        let text = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard text != lastSearchedText || translationID == nil else { return }
        cancelSearch()
        let generation = translationGeneration

        lastSearchedText = text
        lastSearchSucceeded = false
        showLoading(true)
        hideResult()

        let direction = currentTranslationDirection
        lastDirection = direction

        translationID = LLTranslationManager.shared.translate(text, direction: direction) { [weak self] result in
            guard let self, self.translationGeneration == generation else { return }
            self.translationID = nil
            self.showLoading(false)

            switch result {
            case .success(let r):
                self.showResult(translated: r.translatedText, phonetics: r.phonetics)
            case .failure(let error):
                self.showResult(translated: error.localizedDescription, phonetics: nil, successful: false)
            }
        }
    }

    // MARK: - UI State

    private func showLoading(_ loading: Bool) {
        if loading {
            loadingIndicator.isHidden = false
            loadingIndicator.startAnimation(nil)
        } else {
            loadingIndicator.stopAnimation(nil)
            loadingIndicator.isHidden = true
        }
    }

    private func showResult(translated: String, phonetics: String?, successful: Bool = true) {
        lastSearchSucceeded = successful
        lastTranslatedText = translated
        lastPhonetics = phonetics
        resultLabel.stringValue = translated

        if let p = phonetics, !p.isEmpty {
            phoneticLabel.stringValue = p
            phoneticLabel.isHidden = false
        } else {
            phoneticLabel.stringValue = ""
            phoneticLabel.isHidden = true
        }

        let canAdd = successful && !lastSearchedText.isEmpty && !translated.isEmpty && !translated.hasPrefix("翻译失败")
        let exists = LLWordListStorage.shared.containsWordInVocabularyNotebook(lastSearchedText, language: LLSettingsStore.shared.currentLanguage)
        addVocabularyButton.title = exists ? "已添加" : "添加生词"
        addVocabularyButton.contentTintColor = exists ? .secondaryLabelColor : .systemOrange
        addVocabularyButton.isEnabled = canAdd && !exists
        addVocabularyButton.isHidden = !canAdd

        speakButton.isHidden = false
        divider.isHidden = false
        resultContainer.isHidden = false

        // 通知父级更新高度
        DispatchQueue.main.async {
            self.layoutSubtreeIfNeeded()
            let newHeight = self.calculatedHeight()
            self.onHeightChanged?(newHeight)
        }
    }

    /// 根据当前内容计算视图所需总高度
    private func calculatedHeight() -> CGFloat {
        // 输入框区域：top 8 + 高度 42 + bottom 8 = 58（固定）
        let inputH: CGFloat = 58

        // 没有结果时直接返回输入框高度
        guard !resultContainer.isHidden else { return inputH }

        // 分割线：8（间距）+ 1（线）= 9
        let dividerH: CGFloat = 9

        // 音标行高度（隐藏时为 0，且不计 resultLabel top 的 4pt offset）
        let phoneticH: CGFloat
        if phoneticLabel.isHidden || phoneticLabel.stringValue.isEmpty {
            phoneticH = 0
        } else {
            phoneticH = phoneticLabel.fittingSize.height + 4  // +4 = resultLabel top offset
        }

        // 翻译结果文字高度（按宽度换行，最多 5 行）
        let labelWidth = LLSearchWordView.viewWidth - 24  // leading 12 + trailing 12
        let font = resultLabel.font ?? NSFont.systemFont(ofSize: 13)
        let singleLineH = "A".boundingRect(
            with: CGSize(width: labelWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).height
        let maxResultH = ceil(singleLineH) * 5  // maximumNumberOfLines = 5

        let resultH: CGFloat
        let text = resultLabel.stringValue
        if text.isEmpty {
            resultH = ceil(singleLineH)  // 至少保留一行高度
        } else {
            let rect = text.boundingRect(
                with: CGSize(width: labelWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            resultH = min(ceil(rect.height), maxResultH)
        }

        // 结果容器：top 8 + (phonetic含间距 或 0) + result + bottom 8
        // 注意：phoneticLabel 隐藏时 resultLabel top 约束仍有 4pt，需额外补上
        let topGap: CGFloat = phoneticH > 0 ? 0 : 4  // phoneticLabel.bottom + 4 = resultLabel.top
        let resultContainerH: CGFloat = 8 + phoneticH + topGap + resultH + 8

        return inputH + dividerH + resultContainerH
    }

    private func hideResult() {
        lastSearchSucceeded = false
        resultContainer.isHidden = true
        divider.isHidden = true
        speakButton.isHidden = true
        addVocabularyButton.isHidden = true
        phoneticLabel.isHidden = true
        resultLabel.stringValue = ""
        lastTranslatedText = ""
        lastPhonetics = nil
        lastDirection = nil
        onHeightChanged?(LLSearchWordView.viewHeight)
    }

    // MARK: - Focus

    /// 让输入框获取焦点
    func focusSearchField() {
        if let window = self.window {
            window.makeFirstResponder(searchField)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else { return }
                window.makeFirstResponder(self.searchField)
            }
        }
    }

    /// 菜单关闭时清理状态
    func reset() {
        cancelSearch()
        searchField.stringValue = ""
        lastSearchedText = ""
        clearButton.isHidden = true
        LLSpeechService.shared.stop()
        hideResult()
    }
}

// MARK: - NSTextFieldDelegate

extension LLSearchWordView: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        let text = searchField.stringValue
        clearButton.isHidden = text.isEmpty
        // 输入变化时重置 lastSearchedText，允许重新搜索
        if text != lastSearchedText {
            cancelSearch()
            lastSearchedText = ""
            hideResult()
        }
        // 文本清空时隐藏结果区域并恢复初始高度
        if text.isEmpty {
            hideResult()
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            performSearch()
            return true
        }
        return false
    }
}
