//
//  LLMainViewController.swift
//  LearnLanguage
//
//  主窗口：Finder 风格布局（左侧导航栏 + 右侧内容区）

import AppKit
import SnapKit

enum LLLearningLabRoute {
    case grammarNotes
    case similarWords
    case vocabularyAssessment
    case moreFeatures
}

final class LLMainSplitView: NSSplitView {
    override var dividerThickness: CGFloat { 0 }
}

/// 主窗口：Finder 风格的词库管理应用
final class LLMainViewController: NSViewController, SidebarViewControllerDelegate {

    private let splitView = LLMainSplitView()
    private let sidebarVC = LLSidebarViewController()
    private let contentVC = LLMainContentViewController()
    private let overlayContainerView = NSView()
    private let guideOverlayView = NSView()
    private let guideMaskView = NSView()
    private let guideHostView = NSView()
    private var welcomeGuideViewController: LLWelcomeGuideViewController?
    private var overlayStack: [NSViewController] = []
    private var isOverlayTransitioning = false
    private var hasAttemptedPresentWelcomeGuide = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1100, height: 620))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        presentWelcomeGuideIfNeeded()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = LLAppearanceManager.shared.colors.mainBackground.cgColor
        
        splitView.isVertical = true
        view.addSubview(splitView)
        
        splitView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalToSuperview()
        }
        
        // 左侧导航栏
        sidebarVC.delegate = self
        addChild(sidebarVC)
        splitView.addArrangedSubview(sidebarVC.view)
        sidebarVC.view.snp.makeConstraints { make in
            make.width.equalTo(256)
        }
        
        // 右侧内容区
        addChild(contentVC)
        contentVC.onOpenLearningLabRoute = { [weak self] route in
            self?.openLearningLabRoute(route)
        }
        splitView.addArrangedSubview(contentVC.view)
        
        splitView.setPosition(256, ofDividerAt: 0)
        
        overlayContainerView.wantsLayer = true
        overlayContainerView.layer?.backgroundColor = NSColor.white.cgColor
        overlayContainerView.isHidden = true
        view.addSubview(overlayContainerView)
        overlayContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        setupGuideOverlay()
    }
    
    private func setupGuideOverlay() {
        guideOverlayView.wantsLayer = true
        guideOverlayView.isHidden = true
        guideOverlayView.alphaValue = 0
        
        guideMaskView.wantsLayer = true
        guideMaskView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.34).cgColor
        
        guideHostView.wantsLayer = true
        guideHostView.alphaValue = 0
        
        view.addSubview(guideOverlayView)
        guideOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        guideOverlayView.addSubview(guideMaskView)
        guideMaskView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        guideOverlayView.addSubview(guideHostView)
        guideHostView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(620)
            make.height.equalTo(420)
        }
    }
    
    private func presentWelcomeGuideIfNeeded() {
        guard !hasAttemptedPresentWelcomeGuide else { return }
        hasAttemptedPresentWelcomeGuide = true
        guard LLGuideManager.shared.shouldShowWelcomeGuide else { return }
        guard welcomeGuideViewController == nil else { return }
        
        let guideVC = LLWelcomeGuideViewController()
        guideVC.onFinished = { [weak self] in
            self?.dismissWelcomeGuideOverlay(animated: true)
        }
        welcomeGuideViewController = guideVC
        
        addChild(guideVC)
        guideHostView.addSubview(guideVC.view)
        guideVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        guideOverlayView.isHidden = false
        guideOverlayView.alphaValue = 0
        guideHostView.alphaValue = 0
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.guideOverlayView.animator().alphaValue = 1
            self.guideHostView.animator().alphaValue = 1
        }
    }
    
    private func dismissWelcomeGuideOverlay(animated: Bool) {
        guard let guideVC = welcomeGuideViewController else { return }
        
        let cleanup = {
            guideVC.view.removeFromSuperview()
            guideVC.removeFromParent()
            self.welcomeGuideViewController = nil
            self.guideOverlayView.isHidden = true
            self.guideOverlayView.alphaValue = 0
            self.guideHostView.alphaValue = 0
        }
        
        guard animated else {
            cleanup()
            return
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.guideOverlayView.animator().alphaValue = 0
            self.guideHostView.animator().alphaValue = 0
        } completionHandler: {
            cleanup()
        }
    }
    
    private func openLearningLabRoute(_ route: LLLearningLabRoute) {
        let viewController: NSViewController
        
        switch route {
        case .grammarNotes:
            viewController = LLGrammarNotesHomeViewController { [weak self] in
                self?.popOverlayPage(animated: true)
            }
        case .similarWords:
            viewController = LLSimilarWordsHomeViewController { [weak self] in
                self?.popOverlayPage(animated: true)
            }
        case .vocabularyAssessment:
            viewController = LLVocabularyAssessmentViewController { [weak self] in
                self?.popOverlayPage(animated: true)
            }
        case .moreFeatures:
            viewController = LLMoreFeaturesHomeViewController { [weak self] in
                self?.popOverlayPage(animated: true)
            }
        }
        
        pushOverlayPage(viewController, animated: true)
    }
    
    private func pushOverlayPage(_ viewController: NSViewController, animated: Bool) {
        guard !isOverlayTransitioning else { return }
        isOverlayTransitioning = true
        
        let previousVC = overlayStack.last
        if overlayContainerView.isHidden {
            overlayContainerView.isHidden = false
        }
        
        addChild(viewController)
        overlayContainerView.addSubview(viewController.view)
        viewController.view.frame = overlayContainerView.bounds.offsetBy(dx: overlayContainerView.bounds.width, dy: 0)
        viewController.view.autoresizingMask = [.width, .height]
        
        let completeTransition = {
            previousVC?.view.frame = self.overlayContainerView.bounds.offsetBy(dx: -self.overlayContainerView.bounds.width * 0.28, dy: 0)
            viewController.view.frame = self.overlayContainerView.bounds
            self.overlayStack.append(viewController)
            self.isOverlayTransitioning = false
        }
        
        guard animated else {
            previousVC?.view.removeFromSuperview()
            completeTransition()
            return
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            previousVC?.view.animator().frame = self.overlayContainerView.bounds.offsetBy(dx: -self.overlayContainerView.bounds.width * 0.28, dy: 0)
            viewController.view.animator().frame = self.overlayContainerView.bounds
        } completionHandler: {
            completeTransition()
        }
    }
    
    private func popOverlayPage(animated: Bool) {
        guard overlayStack.count > 0, !isOverlayTransitioning else { return }
        isOverlayTransitioning = true
        
        let currentVC = overlayStack.removeLast()
        let previousVC = overlayStack.last
        
        if let previousVC, previousVC.view.superview == nil {
            overlayContainerView.addSubview(previousVC.view, positioned: .below, relativeTo: currentVC.view)
            previousVC.view.frame = overlayContainerView.bounds.offsetBy(dx: -overlayContainerView.bounds.width * 0.28, dy: 0)
            previousVC.view.autoresizingMask = [.width, .height]
        }
        
        let finish = {
            currentVC.view.removeFromSuperview()
            currentVC.removeFromParent()
            previousVC?.view.frame = self.overlayContainerView.bounds
            if self.overlayStack.isEmpty {
                self.overlayContainerView.isHidden = true
            }
            self.isOverlayTransitioning = false
        }
        
        guard animated else {
            finish()
            return
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.26
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            currentVC.view.animator().frame = self.overlayContainerView.bounds.offsetBy(dx: self.overlayContainerView.bounds.width, dy: 0)
            previousVC?.view.animator().frame = self.overlayContainerView.bounds
        } completionHandler: {
            finish()
        }
    }
    
    func openLearningHome() {
        _ = view
        guard !isOverlayTransitioning else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.openLearningHome() }
            return
        }
        while !overlayStack.isEmpty { popOverlayPage(animated: false) }
        sidebarVC.selectModule(.learning)
    }

    // MARK: - SidebarViewControllerDelegate
    
    func sidebarViewController(_ vc: LLSidebarViewController, didSelectModule module: SidebarModule) {
        saveSelectedModule(module)
        contentVC.switchModule(to: module)
    }
    
    func sidebarViewController(_ vc: LLSidebarViewController, didSelectCurrentWordList: WordList?) {
        saveSelectedModule(.wordList)
        contentVC.switchModule(to: .wordList)
    }
    
    func sidebarViewController(_ vc: LLSidebarViewController, didSelectWrongWords: ()) {
        saveSelectedModule(.learningRecord)
        contentVC.switchModule(to: .learningRecord)
        
        // 延迟一下，确保页面已经切换
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 切换到复习记录tab
            if let progressVC = self.contentVC.currentProgressTabViewController {
                progressVC.switchToReviewTab()
                // 设置时间筛选为"今天"
                progressVC.setTimeFilter(to: .today)
            }
        }
    }
    
    private func saveSelectedModule(_ module: SidebarModule) {
        var settings = LLSettingsStore.shared.settings
        settings.lastSelectedSidebarModule = module
        LLSettingsStore.shared.settings = settings
    }
}
