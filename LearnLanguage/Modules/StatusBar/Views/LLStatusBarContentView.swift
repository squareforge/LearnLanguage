//
//  LLStatusBarContentView.swift
//  LearnLanguage
//
//  状态栏内容视图 - 自定义绘制单词、音标和释义
//

import AppKit
import SnapKit

final class LLStatusBarContentView: NSControl {
    
    // MARK: - Layout Constants
    
    private static let menuLeftInset: CGFloat = 6
    private static let menuIconSize: CGFloat = 14
    private static let menuToWordSpacing: CGFloat = 6
    private static let wordToIndicatorSpacing: CGFloat = 8
    private static let indicatorWidth: CGFloat = 4
    private static let indicatorHeight: CGFloat = 24
    private static let indicatorToMeaningSpacing: CGFloat = 8
    private static let rightInset: CGFloat = 8
    private static let feedbackWidth: CGFloat = 70
    private static let minimumWordSample = "WIDE"
    
    static func minimumRequiredWidth() -> CGFloat {
        let font = NSFont.menuBarFont(ofSize: 0)
        let sampleWidth = (minimumWordSample as NSString).size(withAttributes: [.font: font]).width
        
        return menuLeftInset
            + menuIconSize
            + menuToWordSpacing
            + sampleWidth
            + wordToIndicatorSpacing
            + indicatorWidth
            + indicatorToMeaningSpacing
            + feedbackWidth
            + rightInset
    }
    
    // MARK: - Properties
    
    var statusItem: NSStatusItem
    var clicked: Bool = false
    
    var wordText: String = "LearnLanguage"
    var phoneticText: String = ""
    var meaningText: String = ""
    private var vocabularyFeedbackEnabled = true
    
    // MARK: - UI Components
    
    private lazy var wordPhoneticView: LLWordPhoneticView = {
        let view = LLWordPhoneticView()
        view.wantsLayer = true
        return view
    }()
    
    private lazy var scrollingMeaningView: LLScrollingTextView = {
        let view = LLScrollingTextView(frame: .zero)
        view.wantsLayer = true
        return view
    }()
    
    private lazy var learnIndicatorView: LLStatusLearnIndicatorView = {
        let view = LLStatusLearnIndicatorView(frame: .zero)
        view.wantsLayer = true
        return view
    }()
    
    private lazy var feedbackView: LLStatusBarFeedbackView = {
        let view = LLStatusBarFeedbackView(frame: .zero)
        view.wantsLayer = true
        view.alphaValue = 0 // 默认隐藏
        view.isHidden = true // 完全隐藏
        view.onFeedback = { [weak self] feedback in
            self?.handleFeedback(feedback)
        }
        view.onShow = { [weak self] in
            self?.showMeaningTemporarily()
        }
        return view
    }()

    /// 右侧菜单触发图标
    private lazy var menuIconView: NSImageView = {
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        let image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "菜单")?
                    .withSymbolConfiguration(config)
        let iv = NSImageView(image: image ?? NSImage())
        iv.contentTintColor = NSColor.white.withAlphaComponent(0.75)
        iv.wantsLayer = true
        return iv
    }()
    
    private var trackingArea: NSTrackingArea?
    private var temporaryMeaningWorkItem: DispatchWorkItem?
    private var isTemporaryMeaningVisible = false
    private let temporaryMeaningDuration: TimeInterval = 10
    
    // MARK: - Initialization
    
    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        let height = NSStatusBar.system.thickness
        let width = statusItem.length
        super.init(frame: NSMakeRect(0, 0, width, height))
        self.wantsLayer = true
        setupUI()
    }
    
    override var intrinsicContentSize: NSSize {
        let height = NSStatusBar.system.thickness
        let width = statusItem.length
        return NSSize(width: width, height: height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(wordPhoneticView)
        addSubview(learnIndicatorView)
        addSubview(scrollingMeaningView)
        addSubview(feedbackView)
        addSubview(menuIconView)
        
        // 菜单图标在最左侧，垂直居中
        menuIconView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Self.menuLeftInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.menuIconSize)
        }
        
        // 单词音标视图在图标右侧
        wordPhoneticView.snp.makeConstraints { make in
            make.left.equalTo(menuIconView.snp.right).offset(Self.menuToWordSpacing)
            make.centerY.equalToSuperview()
        }
        
        // 学习次数指示器在单词音标之后
        learnIndicatorView.snp.makeConstraints { make in
            make.left.equalTo(wordPhoneticView.snp.right).offset(Self.wordToIndicatorSpacing)
            make.centerY.equalToSuperview()
            make.width.equalTo(Self.indicatorWidth)
            make.height.equalTo(Self.indicatorHeight)
        }
        
        // 滚动视图填充剩余空间（为右侧反馈按钮预留固定宽度）
        scrollingMeaningView.snp.makeConstraints { make in
            make.left.equalTo(learnIndicatorView.snp.right).offset(Self.indicatorToMeaningSpacing)
            make.right.equalToSuperview().offset(-Self.rightInset)
            make.top.bottom.equalToSuperview()
        }
        
        // 反馈按钮固定在最右侧，覆盖在释义区域之上
        feedbackView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-Self.rightInset)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(Self.feedbackWidth)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let location = currentPointerLocation() ?? point
        guard bounds.contains(location) else { return nil }

        // Keep the feedback controls interactive; route all other clicks through mouseDown below.
        if !feedbackView.isHidden,
           feedbackView.alphaValue > 0.5,
           feedbackView.frame.contains(location) {
            return feedbackView
        }
        return self
    }

    private func currentPointerLocation() -> NSPoint? {
        guard let window else { return nil }
        let pointInWindow = window.convertFromScreen(
            NSRect(origin: NSEvent.mouseLocation, size: .zero)
        ).origin
        let point = convert(pointInWindow, from: nil)
        return bounds.contains(point) ? point : nil
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // 移除旧的追踪区域
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        // 创建新的追踪区域
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard !isTemporaryMeaningVisible else { return }
        showFeedbackView()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hideFeedbackView()
    }
    
    private func showFeedbackView() {
        guard vocabularyFeedbackEnabled else { return }
        // 显示反馈按钮，隐藏滚动视图
        feedbackView.isHidden = false
        scrollingMeaningView.isHidden = true
        
        // 淡入动画
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            feedbackView.animator().alphaValue = 1
        }
    }
    
    private func hideFeedbackView() {
        // 如果正在临时显示释义，不处理鼠标离开的隐藏逻辑
        guard !isTemporaryMeaningVisible else { return }
        
        // 淡出动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            feedbackView.animator().alphaValue = 0
        }, completionHandler: {
            // 动画完成后隐藏反馈按钮，按设置恢复释义显示
            self.feedbackView.isHidden = true
            self.restoreMeaningVisibilityBySettings()
        })
    }
    
    private func showMeaningTemporarily() {
        temporaryMeaningWorkItem?.cancel()
        isTemporaryMeaningVisible = true
        
        feedbackView.isHidden = true
        feedbackView.alphaValue = 0
        scrollingMeaningView.isHidden = false
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isTemporaryMeaningVisible = false
            if self.isMouseInsideView() {
                self.showFeedbackView()
            } else {
                self.feedbackView.alphaValue = 0
                self.feedbackView.isHidden = true
                self.restoreMeaningVisibilityBySettings()
            }
        }
        temporaryMeaningWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + temporaryMeaningDuration, execute: workItem)
    }
    
    private func restoreMeaningVisibilityBySettings() {
        let settings = LLSettingsStore.shared.settings
        scrollingMeaningView.isHidden = !settings.statusBarShowMeaning
    }
    
    private func isMouseInsideView() -> Bool {
        guard let window = window else { return false }
        let pointInWindow = window.mouseLocationOutsideOfEventStream
        let pointInSelf = convert(pointInWindow, from: nil)
        return bounds.contains(pointInSelf)
    }
    
    private func handleFeedback(_ feedback: LLWordFeedback) {
        guard vocabularyFeedbackEnabled else { return }
        // 通知 LLStatusBarManager 记录反馈
        LLStatusBarManager.shared.recordFeedback(feedback)
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 绘制背景
        if #available(macOS 10.14, *) {
            // 使用标准按钮属性代替废弃的方法
            if clicked {
                NSColor.selectedControlColor.withAlphaComponent(0.2).setFill()
                NSBezierPath(rect: bounds).fill()
            }
        } else {
            statusItem.drawStatusBarBackground(in: dirtyRect, withHighlight: clicked)
        }
    }
    
    override func updateLayer() {
        super.updateLayer()
        
        // 强制使用白色文字
        let textColor = NSColor.white
        
        // 更新所有子视图的颜色
        wordPhoneticView.textColor = textColor
        scrollingMeaningView.textColor = textColor.withAlphaComponent(0.9)
        menuIconView.contentTintColor = LLStatusBarPopoverPanel.shared.isShowing
            ? NSColor.white
            : NSColor.white.withAlphaComponent(0.6)
    }
    
    // MARK: - Public Methods
    
    func updateContent(word: String, phonetic: String, meaning: String, reviewCount: Int = 0, vocabularyFeedbackEnabled: Bool = true) {
        self.vocabularyFeedbackEnabled = vocabularyFeedbackEnabled
        learnIndicatorView.isHidden = !vocabularyFeedbackEnabled
        if !vocabularyFeedbackEnabled {
            feedbackView.isHidden = true
            feedbackView.alphaValue = 0
        }
        self.wordText = word
        self.phoneticText = phonetic
        self.meaningText = meaning
        
        // 始终更新内容（不清空文字）
        wordPhoneticView.word = word
        wordPhoneticView.phonetic = phonetic
        learnIndicatorView.reviewCount = reviewCount
        scrollingMeaningView.text = meaning
        
        // 获取设置
        let settings = LLSettingsStore.shared.settings
        
        // 分别控制单词、音标的毛玻璃遮罩
        wordPhoneticView.setWordBlurred(!settings.statusBarShowWord)
        wordPhoneticView.setPhoneticBlurred(!settings.statusBarShowPhoneticSymbol)
        
        // 根据设置控制释义的显示/隐藏
        if isTemporaryMeaningVisible {
            scrollingMeaningView.isHidden = false
        } else {
            scrollingMeaningView.isHidden = !settings.statusBarShowMeaning
        }
        
        // 根据设置控制是否启用滚动
        scrollingMeaningView.forcedScroll = settings.statusBarAutoScroll
        
        DispatchQueue.main.async {
            self.needsDisplay = true
            self.updateLayer()
        }
    }
}

// MARK: - NSMenuDelegate

extension LLStatusBarContentView: NSMenuDelegate {
    
    override func mouseDown(with event: NSEvent) {
        let eventLoc = convert(event.locationInWindow, from: nil)
        let loc = currentPointerLocation() ?? eventLoc

        // Menu icon is anchored at the left; do not use a sibling's frame for its hit area.
        let menuHitArea = NSRect(
            x: 0,
            y: 0,
            width: Self.menuLeftInset + Self.menuIconSize + Self.menuToWordSpacing,
            height: bounds.height
        )
        if menuHitArea.contains(loc) {
            LLStatusBarPopoverPanel.shared.toggle(relativeTo: self)
            return
        }
        
        if wordPhoneticView.frame.contains(loc) {
            LLStatusBarManager.shared.playCurrentWordPronunciation()
            return
        }
        
        // 点击其他区域也弹出 panel（保持原有行为）
        LLStatusBarPopoverPanel.shared.toggle(relativeTo: self)
    }

    func menuWillOpen(_ menu: NSMenu) {
        needsDisplay = true
        clicked = true
    }

    func menuDidClose(_ menu: NSMenu) {
        needsDisplay = true
        clicked = false
    }
}
