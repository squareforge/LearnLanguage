//
//  LLMainContentViewController.swift
//  LearnLanguage
//
//  主内容容器，根据侧边栏选择显示不同的模块
//

import AppKit
import SnapKit

final class LLMainContentViewController: NSViewController {
    
    var onOpenLearningLabRoute: ((LLLearningLabRoute) -> Void)?
    
    private let containerView = NSView()
    private let emptyView = NSView()
    
    private var currentModule: SidebarModule = LLSettingsStore.shared.settings.lastSelectedSidebarModule
    private var currentViewController: NSViewController?
    
    // 各个模块的视图控制器（复用）
    private lazy var learningVC = LLLearningHomeViewController()
    private lazy var wordListVC = LLWordListTabViewController()
    private lazy var learningRecordVC = LLProgressTabViewController()
    private lazy var settingsVC = LLSettingsTabViewController()
    private lazy var dataManagementVC = LLDataTabViewController()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 450))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataManagementVC.onOpenLearningLabRoute = { [weak self] route in
            self?.onOpenLearningLabRoute?(route)
        }
        setupUI()
        switchModule(to: LLSettingsStore.shared.settings.lastSelectedSidebarModule)
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.white.cgColor
        
        view.addSubview(containerView)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func switchModule(to module: SidebarModule) {
        // 如果是同一个模块且已经有视图控制器，则不重复切换
        guard module != currentModule || currentViewController == nil else { return }
        
        currentModule = module
        let nextVC: NSViewController
        
        switch module {
        case .learning:
            nextVC = learningVC
        case .wordList:
            nextVC = wordListVC
        case .learningRecord:
            nextVC = learningRecordVC
        case .settings:
            nextVC = settingsVC
        case .dataManagement:
            nextVC = dataManagementVC
        }
        
        transition(to: nextVC)
    }
    
    private func transition(to nextVC: NSViewController) {
        if let currentVC = currentViewController {
            currentVC.removeFromParent()
            currentVC.view.removeFromSuperview()
        }
        
        addChild(nextVC)
        containerView.addSubview(nextVC.view)
        
        nextVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        currentViewController = nextVC
    }
    
    // MARK: - Public Methods
    
    var currentProgressTabViewController: LLProgressTabViewController? {
        return currentViewController as? LLProgressTabViewController
    }
}
