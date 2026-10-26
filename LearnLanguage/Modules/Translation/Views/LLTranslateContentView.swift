//
//  LLTranslateContentView.swift
//  LearnLanguage
//
//  浮动翻译窗口内容视图 - 纯 AppKit 实现
//

import AppKit
import SnapKit

final class LLTranslateContentView: NSView {

    // MARK: - Constants

    static let windowWidth: CGFloat = 300
    private let maxTextHeight: CGFloat = 500
    private let toolbarHeight: CGFloat = 36

    // MARK: - Callbacks

    var onPin: (() -> Void)?
    var onSpeak: (() -> Void)?
    var onCopy: (() -> Void)?
    var onAddVocabulary: (() -> Void)?

    // MARK: - UI

    /// 背景层（圆角半透明黑色，与 TranslateP 保持一致）
    private lazy var backgroundView: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        v.layer?.cornerRadius = 10
        v.layer?.masksToBounds = true
        return v
    }()

    /// 翻译结果文字
    private lazy var resultLabel: NSTextField = {
        let tf = NSTextField(wrappingLabelWithString: "")
        tf.font = NSFont.systemFont(ofSize: 14)
        tf.textColor = .white
        tf.isSelectable = true
        tf.drawsBackground = false
        tf.isBezeled = false
        tf.maximumNumberOfLines = 0
        return tf
    }()

    /// 音标标签
    private lazy var phoneticLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.font = NSFont.systemFont(ofSize: 11)
        tf.textColor = NSColor.white.withAlphaComponent(0.6)
        tf.isHidden = true
        return tf
    }()

    /// 朗读按钮
    private lazy var speakButton: NSButton = {
        let btn = NSButton()
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: nil)
        btn.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        btn.target = self
        btn.action = #selector(didTapSpeak)
        btn.isHidden = true
        return btn
    }()

    /// 复制按钮
    private lazy var copyButton: NSButton = {
        let btn = NSButton()
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: "document.on.document", accessibilityDescription: nil)
        btn.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        btn.target = self
        btn.action = #selector(didTapCopy)
        btn.isHidden = true
        return btn
    }()

    private lazy var addVocabularyButton: NSButton = {
        let btn = NSButton(title: "生词", target: self, action: #selector(didTapAddVocabulary))
        btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        btn.contentTintColor = NSColor.systemOrange
        btn.isHidden = true
        return btn
    }()

    /// Pin 按钮
    private lazy var pinButton: NSButton = {
        let btn = NSButton()
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: "pin", accessibilityDescription: nil)
        btn.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        btn.target = self
        btn.action = #selector(didTapPin)
        return btn
    }()

    /// 工具栏容器
    private lazy var toolbarView: NSView = {
        let v = NSView()
        return v
    }()

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        wantsLayer = true

        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(resultLabel)
        resultLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
        }

        addSubview(phoneticLabel)
        phoneticLabel.snp.makeConstraints { make in
            make.top.equalTo(resultLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
        }

        addSubview(toolbarView)
        toolbarView.snp.makeConstraints { make in
            make.top.equalTo(phoneticLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(toolbarHeight)
            make.bottom.equalToSuperview()
        }

        toolbarView.addSubview(speakButton)
        toolbarView.addSubview(copyButton)
        toolbarView.addSubview(addVocabularyButton)
        toolbarView.addSubview(pinButton)

        speakButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        copyButton.snp.makeConstraints { make in
            make.leading.equalTo(speakButton.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        addVocabularyButton.snp.makeConstraints { make in
            make.leading.equalTo(copyButton.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
        }

        pinButton.snp.makeConstraints { make in
            make.leading.equalTo(addVocabularyButton.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
    }

    // MARK: - Public Update

    /// 显示翻译中占位
    func showLoading() {
        resultLabel.stringValue = "..."
        resultLabel.textColor = NSColor.white.withAlphaComponent(0.4)
        phoneticLabel.isHidden = true
        speakButton.isHidden = true
        copyButton.isHidden = true
        addVocabularyButton.isHidden = true
        updateScrollViewHeight()
    }

    /// 显示翻译结果
    func showResult(text: String, phonetic: String?, fontSize: CGFloat) {
        resultLabel.font = NSFont.systemFont(ofSize: fontSize)
        resultLabel.stringValue = text
        resultLabel.textColor = .white

        if let p = phonetic, !p.isEmpty {
            phoneticLabel.stringValue = p
            phoneticLabel.isHidden = false
        } else {
            phoneticLabel.isHidden = true
        }

        speakButton.isHidden = false
        copyButton.isHidden = false
        addVocabularyButton.isHidden = false
        setVocabularyButtonAdded(false)
        updateScrollViewHeight()
        layoutSubtreeIfNeeded()
    }

    func showError(text: String, fontSize: CGFloat) {
        showLoading()
        resultLabel.stringValue = text
        resultLabel.font = .systemFont(ofSize: fontSize)
        resultLabel.textColor = .systemOrange
        updateScrollViewHeight()
    }

    /// 更新 pin 按钮状态
    func updatePinState(_ isPinned: Bool) {
        let name = isPinned ? "pin.fill" : "pin"
        pinButton.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        pinButton.contentTintColor = isPinned ? .controlAccentColor : .secondaryLabelColor
    }

    /// 更新朗读按钮状态
    func updateSpeakState(_ isSpeaking: Bool) {
        let name = isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2"
        speakButton.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    /// 显示复制成功反馈
    func showCopiedFeedback() {
        copyButton.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyButton.image = NSImage(systemSymbolName: "document.on.document", accessibilityDescription: nil)
        }
    }
    
    func showAddedToVocabularyFeedback() {
        addVocabularyButton.title = "已添加"
        addVocabularyButton.contentTintColor = NSColor.white.withAlphaComponent(0.55)
        addVocabularyButton.isEnabled = false
    }
    
    func showGuideTip(title: String, message: String) {
        LLInlineGuideTipView.show(in: self, title: title, message: message, topInset: 10, autoDismissAfter: 2.2)
    }
    
    func setVocabularyButtonAdded(_ added: Bool) {
        addVocabularyButton.title = added ? "已添加" : "生词"
        addVocabularyButton.contentTintColor = added ? NSColor.white.withAlphaComponent(0.55) : NSColor.systemOrange
        addVocabularyButton.isEnabled = !added
    }

    // MARK: - Actions

    @objc private func didTapSpeak() { onSpeak?() }
    @objc private func didTapCopy()  { onCopy?() }
    @objc private func didTapAddVocabulary() { onAddVocabulary?() }
    @objc private func didTapPin()   { onPin?() }

    // MARK: - Layout Helper

    private func updateScrollViewHeight() {
        guard let font = resultLabel.font else { return }
        let contentWidth = LLTranslateContentView.windowWidth - 24
        let str = resultLabel.stringValue
        let rect = str.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let textH = max(44, ceil(rect.height) + 24)
        let clampedH = min(textH, maxTextHeight)
        resultLabel.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.height.equalTo(clampedH)
        }
        layoutSubtreeIfNeeded()
        // 通知窗口更新尺寸
        window?.setContentSize(fittingSize)
    }

    override var fittingSize: NSSize {
        layoutSubtreeIfNeeded()
        let phoneticH: CGFloat = phoneticLabel.isHidden ? 0 : (phoneticLabel.fittingSize.height + 4)
        let labelH = resultLabel.frame.height
        let totalH = 12 + labelH + phoneticH + 4 + toolbarHeight
        return NSSize(width: LLTranslateContentView.windowWidth, height: totalH)
    }
}
