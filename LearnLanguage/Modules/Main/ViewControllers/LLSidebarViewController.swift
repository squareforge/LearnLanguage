//
//  LLSidebarViewController.swift
//  LearnLanguage
//
//  Finder 风格左侧导航栏
//

import AppKit
import SnapKit

protocol SidebarViewControllerDelegate: AnyObject {
    func sidebarViewController(_ vc: LLSidebarViewController, didSelectModule module: SidebarModule)
    func sidebarViewController(_ vc: LLSidebarViewController, didSelectCurrentWordList: WordList?)
    func sidebarViewController(_ vc: LLSidebarViewController, didSelectWrongWords: ())
}

enum SidebarModule: String, Codable {
    case learning
    case wordList           // 词库管理
    case learningRecord     // 学习记录
    case settings          // 设置
    case dataManagement    // 数据管理
    
    var title: String {
        switch self {
        case .learning: return "学习"
        case .wordList: return "词库管理"
        case .learningRecord: return NSLocalizedString("Progress", comment: "Learning progress module")
        case .settings: return NSLocalizedString("Settings", comment: "Settings module")
        case .dataManagement: return "工具与数据"
        }
    }
    
    var icon: NSImage? {
        switch self {
        case .learning: return NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: nil)
        case .wordList: return NSImage(systemSymbolName: "books.vertical.fill", accessibilityDescription: nil)
        case .learningRecord: return NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: nil)
        case .settings: return NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
        case .dataManagement: return NSImage(systemSymbolName: "externaldrive.fill", accessibilityDescription: nil)
        }
    }
}

private final class LLFeedbackCardView: NSView {
    var onTap: (() -> Void)?

    private let iconWrap = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "意见反馈")
    private let subtitleLabel = NSTextField(labelWithString: "欢迎反馈体验问题与功能建议")
    private var tracking: NSTrackingArea?
    private var hovered = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.borderWidth = 1

        iconWrap.wantsLayer = true
        iconWrap.layer?.cornerRadius = 12
        iconWrap.layer?.backgroundColor = LLAppearanceManager.shared.colors.accentLightBackground.cgColor
        addSubview(iconWrap)

        iconView.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill", accessibilityDescription: nil)
        iconView.contentTintColor = LLAppearanceManager.shared.colors.accentColor
        iconView.imageScaling = .scaleProportionallyDown
        iconWrap.addSubview(iconView)

        titleLabel.font = NSFont.inter(13, .semiBold)
        titleLabel.textColor = LLAppearanceManager.shared.colors.primaryText
        addSubview(titleLabel)

        subtitleLabel.font = NSFont.inter(11, .medium)
        subtitleLabel.textColor = LLAppearanceManager.shared.colors.secondaryText.withAlphaComponent(0.75)
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping
        addSubview(subtitleLabel)

        iconWrap.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(38)
        }

        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(18)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.leading.equalTo(iconWrap.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-14)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(iconWrap.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-14)
            make.bottom.lessThanOrEqualToSuperview().offset(-14)
        }

        updateStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        updateStyle()
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        updateStyle()
    }

    override func mouseDown(with event: NSEvent) {
        onTap?()
    }

    private func updateStyle() {
        layer?.backgroundColor = (hovered
            ? NSColor.white.withAlphaComponent(0.72)
            : NSColor.white.withAlphaComponent(0.5)).cgColor
        layer?.borderColor = LLAppearanceManager.shared.colors.borderColor.withAlphaComponent(hovered ? 0.85 : 0.55).cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.06).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        layer?.shadowRadius = hovered ? 10 : 7
    }
}

final class LLSidebarViewController: NSViewController {
    
    // MARK: - Properties
    
    weak var delegate: SidebarViewControllerDelegate?
    private var selectedModule: SidebarModule = LLSettingsStore.shared.settings.lastSelectedSidebarModule
    private let modules: [SidebarModule] = [.learning, .wordList, .learningRecord, .dataManagement, .settings]
    
    // 数据源
    private var currentWordList: WordList?
    private var wrongWordCount: Int = 0
    
    // 导航项视图
    private var navigationItemViews: [LLSidebarNavigationItemView] = []
    
    // MARK: - UI Components
    
    private lazy var logoContainerView: NSView = {
        let view = NSView()
        return view
    }()
    
    private lazy var logoIconView: NSImageView = {
        let imageView = NSImageView()
        imageView.image = NSImage(named: "logo")
        imageView.contentTintColor = .white
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = LLAppearanceManager.shared.colors.primaryContainer.cgColor
        imageView.layer?.cornerRadius = 12
        return imageView
    }()
    
    private lazy var logoLabel: NSTextField = {
        let label = NSTextField(labelWithString: NSLocalizedString("App Name", comment: "Application name"))
        label.font = NSFont.interDisplay(16, .bold)
        label.textColor = LLAppearanceManager.shared.colors.accentColor
        return label
    }()
    
    private lazy var topDivider: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = LLAppearanceManager.shared.colors.borderColor.cgColor
        return view
    }()
    
    private lazy var quickAccessContainerView: NSView = {
        let view = NSView()
        return view
    }()
    
    private lazy var currentWordLibIconView: NSImageView = {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: "book.fill", accessibilityDescription: nil)
        imageView.contentTintColor = LLAppearanceManager.shared.colors.secondaryText
        return imageView
    }()
    
    private lazy var quickAccessTitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "快速访问")
        label.font = NSFont.inter(11, .semiBold)
        label.textColor = LLAppearanceManager.shared.colors.secondaryText.withAlphaComponent(0.5)
        return label
    }()
    
    private lazy var currentWordListShortcutCardView: LLShortcutCardView = {
        let card = LLShortcutCardView(type: .wordList)
        card.onTap = { [weak self] in
            self?.didClickCurrentWordLib()
        }
        return card
    }()
    
    private lazy var wrongWordsIconView: NSImageView = {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)
        imageView.contentTintColor = LLAppearanceManager.shared.colors.secondaryText
        return imageView
    }()
    
    private lazy var menuSectionTitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "主菜单")
        label.font = NSFont.inter(11, .semiBold)
        label.textColor = LLAppearanceManager.shared.colors.secondaryText.withAlphaComponent(0.5)
        return label
    }()
    
    private lazy var reviewShortcutCardView: LLShortcutCardView = {
        let card = LLShortcutCardView(type: .wrongWords)
        card.onTap = { [weak self] in
            self?.didClickWrongWords()
        }
        return card
    }()
    
    private lazy var middleDivider: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = LLAppearanceManager.shared.colors.borderColor.cgColor
        return view
    }()
    
    private lazy var navigationContainerView: NSView = {
        let view = NSView()
        return view
    }()
    
    private lazy var feedbackCardView: LLFeedbackCardView = {
        let card = LLFeedbackCardView()
        card.onTap = { [weak self] in
            self?.onFeedbackButtonClicked()
        }
        return card
    }()
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 256, height: 400))
        view.wantsLayer = true
        view.layer?.backgroundColor = LLAppearanceManager.shared.colors.sidebarBackground.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNotifications()
        loadData()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        setupLogoSection()
        setupShortcutSection()
        setupBottomFeedbackButton()
        setupNavigationSection()
        topDivider.isHidden = true
        middleDivider.isHidden = true
        currentWordLibIconView.isHidden = true
        wrongWordsIconView.isHidden = true
    }
    
    private func setupLogoSection() {
        view.addSubview(logoContainerView)
        logoContainerView.addSubview(logoIconView)
        logoContainerView.addSubview(logoLabel)
        view.addSubview(topDivider)
        
        logoContainerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(44)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(64)
        }
        
        logoIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }
        
        logoLabel.snp.makeConstraints { make in
            make.leading.equalTo(logoIconView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(8)
        }
        
        topDivider.snp.makeConstraints { make in
            make.top.equalTo(logoContainerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
    }
    
    private func setupShortcutSection() {
        view.addSubview(quickAccessContainerView)
        quickAccessContainerView.addSubview(currentWordLibIconView)
        quickAccessContainerView.addSubview(quickAccessTitleLabel)
        quickAccessContainerView.addSubview(currentWordListShortcutCardView)
        quickAccessContainerView.addSubview(wrongWordsIconView)
        quickAccessContainerView.addSubview(reviewShortcutCardView)
        view.addSubview(middleDivider)
        
        quickAccessContainerView.snp.makeConstraints { make in
            make.top.equalTo(logoContainerView.snp.bottom).offset(28)
            make.leading.trailing.equalToSuperview().inset(18)
        }
        
        currentWordLibIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview()
            make.width.height.equalTo(0)
        }
        
        quickAccessTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(8)
            make.top.equalToSuperview()
            make.height.equalTo(16)
        }
        
        currentWordListShortcutCardView.snp.makeConstraints { make in
            make.top.equalTo(quickAccessTitleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
        }
        
        wrongWordsIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(currentWordListShortcutCardView.snp.bottom).offset(8)
            make.width.height.equalTo(0)
        }
        
        reviewShortcutCardView.snp.makeConstraints { make in
            make.top.equalTo(currentWordListShortcutCardView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        middleDivider.snp.makeConstraints { make in
            make.top.equalTo(quickAccessContainerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
    }
    
    private func setupNavigationSection() {
        view.addSubview(menuSectionTitleLabel)
        view.addSubview(navigationContainerView)
        
        menuSectionTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(quickAccessContainerView.snp.bottom).offset(30)
            make.leading.trailing.equalToSuperview().inset(26)
            make.height.equalTo(16)
        }
        
        navigationContainerView.snp.makeConstraints { make in
            make.top.equalTo(menuSectionTitleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(feedbackCardView.snp.top).offset(-20)
        }
        
        var previousView: NSView?
        
        for (index, module) in modules.enumerated() {
            let navItemView = LLSidebarNavigationItemView(module: module)
            navItemView.onTap = { [weak self] in
                self?.didSelectNavigation(at: index)
            }
            navigationItemViews.append(navItemView)
            navigationContainerView.addSubview(navItemView)
            
            navItemView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                
                if let previous = previousView {
                    make.top.equalTo(previous.snp.bottom)
                } else {
                    make.top.equalToSuperview()
                }
            }
            
            previousView = navItemView
        }
        
        updateNavigationSelection()
    }
    
    private func setupBottomFeedbackButton() {
        view.addSubview(feedbackCardView)
        feedbackCardView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
            make.height.equalTo(72)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onCurrentWordListChanged),
            name: .currentWordListChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onWrongWordsCountChanged),
            name: .wrongWordsCountChanged,
            object: nil
        )
    }
    
    // MARK: - Actions
    
    func selectModule(_ module: SidebarModule) {
        guard let index = modules.firstIndex(of: module) else { return }
        didSelectNavigation(at: index)
    }

    private func didSelectNavigation(at index: Int) {
        let module = modules[index]
        saveSelectedModule(module)
        selectedModule = module
        updateNavigationSelection()
        delegate?.sidebarViewController(self, didSelectModule: module)
    }
    
    private func updateNavigationSelection() {
        for (index, navItemView) in navigationItemViews.enumerated() {
            navItemView.isSelected = (modules[index] == selectedModule)
        }
    }
    
    private func didClickCurrentWordLib() {
        // 判断是否有当前词库
        if currentWordList == nil {
            // 没有词库：切换到词库管理 tab，显示词库管理页面
            saveSelectedModule(.wordList)
            selectedModule = .wordList
            updateNavigationSelection()
            delegate?.sidebarViewController(self, didSelectModule: .wordList)
        } else {
            // 有词库：直接显示词库详情
            saveSelectedModule(.wordList)
            selectedModule = .wordList
            updateNavigationSelection()
            delegate?.sidebarViewController(self, didSelectCurrentWordList: currentWordList)
        }
    }
    
    private func didClickWrongWords() {
        // 切换到学习记录 tab
        saveSelectedModule(.learningRecord)
        selectedModule = .learningRecord
        updateNavigationSelection()
        delegate?.sidebarViewController(self, didSelectModule: .learningRecord)
        delegate?.sidebarViewController(self, didSelectWrongWords: ())
    }
    
    private func saveSelectedModule(_ module: SidebarModule) {
        var settings = LLSettingsStore.shared.settings
        settings.lastSelectedSidebarModule = module
        LLSettingsStore.shared.settings = settings
    }
    
    @objc private func onFeedbackButtonClicked() {
        let email = "yjs_maoge@163.com"
        let alert = NSAlert()
        alert.messageText = "意见与建议反馈"
        alert.informativeText = "反馈邮箱：\(email)\n你可以先复制邮箱，或直接前往邮件客户端发送。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "复制")
        alert.addButton(withTitle: "发送")
        alert.addButton(withTitle: "取消")
        
        let result = alert.runModal()
        switch result {
        case .alertFirstButtonReturn:
            copyEmailToPasteboard(email)
        case .alertSecondButtonReturn:
            openMailClient(email)
        default:
            break
        }
    }
    
    private func copyEmailToPasteboard(_ email: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(email, forType: .string)
    }
    
    private func openMailClient(_ email: String) {
        guard let url = URL(string: "mailto:\(email)") else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc private func onCurrentWordListChanged() {
        loadCurrentWordList()
    }
    
    @objc private func onWrongWordsCountChanged() {
        loadWrongWordsCount()
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        loadCurrentWordList()
        loadWrongWordsCount()
    }
    
    private func loadCurrentWordList() {
        guard let currentId = LLSettingsStore.shared.currentListId,
              let list = LLWordListStorage.shared.list(byId: currentId) else {
            // 没有词库时显示空状态
            currentWordList = nil
            currentWordListShortcutCardView.updateContent(title: NSLocalizedString("No Word List", comment: "No word list placeholder"), badge: NSLocalizedString("Select List", comment: "Select list action"))
            return
        }
        
        currentWordList = list
        let learned: Int
        do {
            let stats = try LLDatabaseManager.shared.getWordListProgressStats(wordListId: currentId)
            learned = stats.learned
        } catch {
            LLLogger.error("❌ 获取学习进度失败：\(error)")
            learned = 0
        }
        let badgeText = "\(learned)/\(list.entries.count)"
        
        currentWordListShortcutCardView.updateContent(title: list.name, badge: badgeText)
    }
    
    private func loadWrongWordsCount() {
        do {
            // 获取今日需要复习的词汇数量（所有词库）
            let reviewRecords = try LLDatabaseManager.shared.getTodayReviewWords()
            wrongWordCount = reviewRecords.count
        } catch {
            LLLogger.error("❌ 获取复习词汇数量失败：\(error)")
            wrongWordCount = 0
        }
        
        let titleText = wrongWordCount == 0
            ? NSLocalizedString("No Reviews Due", comment: "No review words placeholder")
            : NSLocalizedString("Today's Review", comment: "Today's review section title")
        reviewShortcutCardView.updateContent(title: titleText, badge: "\(wrongWordCount)")
    }
}
