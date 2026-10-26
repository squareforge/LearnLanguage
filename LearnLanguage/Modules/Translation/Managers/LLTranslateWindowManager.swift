//
//  LLTranslateWindowManager.swift
//  LearnLanguage
//
//  浮动翻译窗口管理器 - 纯 AppKit 实现
//

import AppKit

final class LLTranslateWindowManager {

    static let shared = LLTranslateWindowManager()
    private init() {}

    // MARK: - Properties

    private(set) var currentWindow: NSPanel?
    private var contentView: LLTranslateContentView?
    private let windowWidth: CGFloat = LLTranslateContentView.windowWidth

    // MARK: - Public

    func showWindow(viewModel: LLTranslateViewModel) {
        if let existing = currentWindow, viewModel.isPinned {
            existing.makeKeyAndOrderFront(nil)
            contentView?.showLoading()
            viewModel.triggerTranslation()
            return
        }
        closeWindow()
        createWindow(viewModel: viewModel)
    }

    func dismissWindow() { closeWindow() }

    // MARK: - Private

    private func createWindow(viewModel: LLTranslateViewModel) {
        // 创建内容视图
        let cv = LLTranslateContentView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: 120))
        cv.showLoading()

        // 绑定按钮回调
        cv.onPin = { [weak viewModel] in viewModel?.togglePin() }
        cv.onSpeak = { [weak viewModel] in viewModel?.speakSource() }
        cv.onCopy = { [weak self, weak viewModel] in
            guard let text = viewModel?.targetString, !text.isEmpty else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
            self?.contentView?.showCopiedFeedback()
        }
        cv.onAddVocabulary = { [weak self, weak viewModel] in
            guard let self, let viewModel else { return }
            if LLGuideManager.shared.shouldShowTip(.translateAddToVocabulary) {
                self.contentView?.showGuideTip(
                    title: "翻译结果可以直接加入生词本",
                    message: "把临时查到的不会词沉淀下来，后续就能集中复习。"
                )
                LLGuideManager.shared.markTipShown(.translateAddToVocabulary)
            }
            let added = viewModel.addCurrentSourceToVocabularyNotebook()
            if added || viewModel.isCurrentSourceInVocabularyNotebook {
                self.contentView?.showAddedToVocabularyFeedback()
            }
        }

        // 绑定 ViewModel 回调
        viewModel.onTranslationUpdated = { [weak cv, weak viewModel] text, phonetic, completed in
            guard let cv, let vm = viewModel else { return }
            if completed {
                cv.showResult(text: text, phonetic: phonetic, fontSize: vm.fontSize)
            } else if text == LLTranslateViewModel.placeholder {
                cv.showLoading()
            } else {
                cv.showError(text: text, fontSize: vm.fontSize)
            }
        }
        viewModel.onPinChanged = { [weak cv] isPinned in
            cv?.updatePinState(isPinned)
        }
        viewModel.onSpeakChanged = { [weak cv] isSpeaking in
            cv?.updateSpeakState(isSpeaking)
        }

        // 创建窗口
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.transient]
        window.contentView = cv

        contentView = cv
        currentWindow = window

        // 定位
        positionWindow(window, viewModel: viewModel)
        window.orderFront(nil)

        // 触发翻译
        viewModel.triggerTranslation()

        // 启动鼠标点击外部关闭监听
        viewModel.setupMouseMonitoring()

        LLLogger.debug("🪟 翻译窗口已显示")
    }

    private func positionWindow(_ window: NSWindow, viewModel: LLTranslateViewModel) {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let winH = window.frame.height

        if viewModel.isPinned, let pinned = viewModel.pinnedPosition() {
            let x = max(screenFrame.minX, min(pinned.x, screenFrame.maxX - windowWidth))
            let y = max(screenFrame.minY, min(pinned.y, screenFrame.maxY - winH))
            window.setFrameOrigin(NSPoint(x: x, y: y))
            return
        }

        let mouse = NSEvent.mouseLocation
        var x = mouse.x - windowWidth / 2
        var y = mouse.y + 12

        x = max(screenFrame.minX, min(x, screenFrame.maxX - windowWidth))
        if y + winH > screenFrame.maxY { y = mouse.y - winH - 12 }
        if y < screenFrame.minY { y = screenFrame.minY }

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func closeWindow() {
        contentView = nil
        currentWindow?.orderOut(nil)
        currentWindow = nil
        LLLogger.debug("🪟 翻译窗口已关闭")
    }
}
