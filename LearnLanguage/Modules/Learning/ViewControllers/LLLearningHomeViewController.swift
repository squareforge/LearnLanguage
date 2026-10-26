import AppKit
import SnapKit

private final class LLLearningSourceCell: NSTableCellView {
    private let heading = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let preview = NSTextField(labelWithString: "")
    private let button = NSButton()
    var onStart: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = LLAppearanceManager.shared.colors.cardBackground.cgColor
        heading.font = .systemFont(ofSize: 14, weight: .semibold)
        heading.textColor = LLAppearanceManager.shared.colors.primaryText
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = LLAppearanceManager.shared.colors.tertiaryText
        preview.font = .systemFont(ofSize: 12)
        preview.textColor = LLAppearanceManager.shared.colors.secondaryText
        for label in [heading, detail, preview] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            addSubview(label)
        }
        button.target = self
        button.action = #selector(start)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12, weight: .medium)
        addSubview(button)
        heading.snp.makeConstraints { $0.leading.top.equalToSuperview().inset(16); $0.trailing.lessThanOrEqualTo(button.snp.leading).offset(-16) }
        detail.snp.makeConstraints { $0.leading.equalTo(heading); $0.top.equalTo(heading.snp.bottom).offset(4); $0.trailing.lessThanOrEqualTo(button.snp.leading).offset(-16) }
        preview.snp.makeConstraints { $0.leading.equalTo(heading); $0.top.equalTo(detail.snp.bottom).offset(8); $0.trailing.lessThanOrEqualTo(button.snp.leading).offset(-16) }
        button.snp.makeConstraints { $0.trailing.equalToSuperview().offset(-16); $0.centerY.equalToSuperview(); $0.width.equalTo(70) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(title: String, detail: String, preview: String, action: String) {
        heading.stringValue = title
        self.detail.stringValue = detail
        self.preview.stringValue = preview
        button.title = action
    }
    @objc private func start() { onStart?() }
}

/// Unified content entry point; both source types open the same floating practice panel.
final class LLLearningHomeViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let titleLabel = NSTextField(labelWithString: "学习")
    private let subtitleLabel = NSTextField(labelWithString: "选择词库或课程，在悬浮面板中练习。")
    private let resumeLabel = NSTextField(labelWithString: "")
    private let resumeButton = NSButton(title: "继续学习", target: nil, action: nil)
    private let tabs = NSSegmentedControl(labels: ["词库练习", "星荣句式"], trackingMode: .selectOne, target: nil, action: nil)
    private let search = NSSearchField()
    private let summary = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let footer = NSButton(title: "课程来源：Earthworm / 星荣课程", target: nil, action: nil)
    private let emptyLabel = NSTextField(wrappingLabelWithString: "")
    private var lists: [WordList] = []
    private var courses: [LLSentenceCourse] = []
    private var visibleListIndices: [Int] = []
    private var visibleCourseIndices: [Int] = []
    private var courseError: String?
    private var showingCourses: Bool { tabs.selectedSegment == 1 }

    override func loadView() { view = NSView(frame: NSRect(x: 0, y: 0, width: 644, height: 600)) }
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        let last = LLMMKVManager.shared.string(forKey: "learning.last_source")
        tabs.selectedSegment = last.hasPrefix("course:") ? 1 : 0
        NotificationCenter.default.addObserver(self, selector: #selector(reloadSources), name: .learningPracticeProgressChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadSources), name: .learnLanguageReloadWordLists, object: nil)
        reloadSources()
    }
    override func viewDidAppear() { super.viewDidAppear(); reloadSources() }
    deinit { NotificationCenter.default.removeObserver(self) }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = LLAppearanceManager.shared.colors.mainBackground.cgColor
        titleLabel.font = .systemFont(ofSize: 25, weight: .bold)
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = LLAppearanceManager.shared.colors.secondaryText
        let resumeCard = NSView()
        resumeCard.wantsLayer = true
        resumeCard.layer?.cornerRadius = 12
        resumeCard.layer?.backgroundColor = LLAppearanceManager.shared.colors.accentLightBackground.withAlphaComponent(0.55).cgColor
        resumeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        resumeLabel.lineBreakMode = .byTruncatingTail
        resumeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        resumeButton.target = self
        resumeButton.action = #selector(resumeLastSource)
        resumeButton.bezelStyle = .rounded
        resumeButton.bezelColor = LLAppearanceManager.shared.colors.accentColor
        resumeButton.contentTintColor = .white
        resumeCard.addSubview(resumeLabel)
        resumeCard.addSubview(resumeButton)
        resumeLabel.snp.makeConstraints { $0.leading.equalToSuperview().offset(16); $0.centerY.equalToSuperview(); $0.trailing.lessThanOrEqualTo(resumeButton.snp.leading).offset(-12) }
        resumeButton.snp.makeConstraints { $0.trailing.equalToSuperview().offset(-12); $0.centerY.equalToSuperview() }
        tabs.target = self
        tabs.action = #selector(changeTab)
        search.placeholderString = "搜索词库或课号"
        search.delegate = self
        summary.font = .systemFont(ofSize: 11)
        summary.textColor = LLAppearanceManager.shared.colors.tertiaryText

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("source"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 95
        tableView.intercellSpacing = NSSize(width: 0, height: 8)
        tableView.selectionHighlightStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = LLAppearanceManager.shared.colors.secondaryText
        emptyLabel.alignment = .center
        footer.isBordered = false
        footer.font = .systemFont(ofSize: 10)
        footer.contentTintColor = LLAppearanceManager.shared.colors.tertiaryText
        footer.target = self
        footer.action = #selector(openCredits)

        for element in [titleLabel, subtitleLabel, resumeCard, tabs, search, summary, scroll, emptyLabel, footer] { view.addSubview(element) }
        titleLabel.snp.makeConstraints { $0.top.equalToSuperview().offset(28); $0.leading.equalToSuperview().offset(28) }
        subtitleLabel.snp.makeConstraints { $0.top.equalTo(titleLabel.snp.bottom).offset(6); $0.leading.equalTo(titleLabel) }
        resumeCard.snp.makeConstraints { $0.leading.trailing.equalToSuperview().inset(28); $0.top.equalTo(subtitleLabel.snp.bottom).offset(20); $0.height.equalTo(54) }
        tabs.snp.makeConstraints { $0.leading.equalTo(titleLabel); $0.top.equalTo(resumeCard.snp.bottom).offset(22); $0.width.equalTo(220) }
        search.snp.makeConstraints { $0.trailing.equalToSuperview().offset(-28); $0.centerY.equalTo(tabs); $0.leading.greaterThanOrEqualTo(tabs.snp.trailing).offset(16); $0.width.equalTo(180).priority(.high) }
        summary.snp.makeConstraints { $0.leading.equalTo(titleLabel); $0.top.equalTo(tabs.snp.bottom).offset(12) }
        scroll.snp.makeConstraints { $0.leading.trailing.equalToSuperview().inset(28); $0.top.equalTo(summary.snp.bottom).offset(12); $0.bottom.equalTo(footer.snp.top).offset(-8) }
        emptyLabel.snp.makeConstraints { $0.center.equalTo(scroll); $0.width.equalTo(scroll).offset(-32) }
        footer.snp.makeConstraints { $0.leading.equalTo(titleLabel); $0.bottom.equalToSuperview().offset(-14) }
    }

    @objc private func reloadSources() {
        lists = LLWordListStorage.shared.allLists().filter { $0.entryCount > 0 }
        do { courses = try LLCourseRepository.shared.courses(); courseError = nil }
        catch { courseError = error.localizedDescription }
        let last = LLPracticePanelController.shared.session?.source.id ?? LLMMKVManager.shared.string(forKey: "learning.last_source")
        if let course = courses.first(where: { "course:\($0.id)" == last }) {
            let progress = LLCourseRepository.shared.progress(for: course.id)
            resumeLabel.stringValue = "星荣句式 · \(course.title) · 已完成 \(progress.completedCount(total: course.words.count))/\(course.words.count)"
        } else if let list = (lists.first(where: { "wordlist:\($0.id)" == last }) ?? lists.first(where: { $0.id == LLSettingsStore.shared.currentListId })) {
            resumeLabel.stringValue = "词库练习 · \(list.name)"
        } else { resumeLabel.stringValue = "从一个词库或第一课开始" }
        resumeButton.isEnabled = !lists.isEmpty || !courses.isEmpty
        applyFilter()
    }

    @objc private func changeTab() { search.stringValue = ""; applyFilter(); if tableView.numberOfRows > 0 { tableView.scrollRowToVisible(0) } }
    func controlTextDidChange(_ obj: Notification) { applyFilter() }

    private func applyFilter() {
        let query = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        visibleListIndices = lists.indices.filter { query.isEmpty || lists[$0].name.localizedCaseInsensitiveContains(query) || lists[$0].category.contains(query) }
        visibleCourseIndices = courses.indices.filter { query.isEmpty || courses[$0].title.contains(query) || String($0 + 1) == query }
        if showingCourses {
            summary.stringValue = "\(courses.count) 课 · \(courses.reduce(0) { $0 + $1.words.count }) 个递进练习项 · 顺序练习，自动续接"
        } else { summary.stringValue = "\(lists.count) 个词库 · 按每日新词与复习计划练习" }
        footer.isHidden = !showingCourses
        let isEmpty = showingCourses ? visibleCourseIndices.isEmpty : visibleListIndices.isEmpty
        emptyLabel.isHidden = !isEmpty
        emptyLabel.stringValue = showingCourses && courseError != nil ? courseError! : query.isEmpty ? "暂无学习内容，请先到词库管理添加词库。" : "没有找到匹配内容，请换个关键词。"
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { showingCourses ? visibleCourseIndices.count : visibleListIndices.count }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("learningSourceCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? LLLearningSourceCell ?? LLLearningSourceCell()
        cell.identifier = identifier
        if showingCourses {
            let course = courses[visibleCourseIndices[row]]
            let progress = LLCourseRepository.shared.progress(for: course.id)
            let count = progress.completedCount(total: course.words.count)
            cell.configure(title: course.title, detail: "\(course.words.count) 项 · 已完成 \(count) 项", preview: course.preview, action: count == course.words.count ? "再练" : count > 0 ? "继续" : "开始")
            cell.onStart = { [weak self] in self?.startCourse(course) }
        } else {
            let list = lists[visibleListIndices[row]]
            cell.configure(title: list.name, detail: "\(list.category) · \(list.entryCount) 项", preview: list.isVocabularyNotebook ? "练习你收集的单词与短语" : "按每日学习计划复习与巩固", action: "练习")
            cell.onStart = { [weak self] in self?.startList(list) }
        }
        return cell
    }

    private func startList(_ list: WordList) {
        LLSettingsStore.shared.currentListId = list.id
        hideMainWindow()
        LLPracticePanelController.shared.start(source: LLVocabularyPracticeSource(list: list))
    }
    private func startCourse(_ course: LLSentenceCourse) {
        hideMainWindow()
        LLPracticePanelController.shared.start(source: LLCoursePracticeSource(course: course))
    }
    private func hideMainWindow() {
        view.window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func resumeLastSource() {
        if LLPracticePanelController.shared.session != nil {
            hideMainWindow()
            LLPracticePanelController.shared.show()
            return
        }
        let last = LLMMKVManager.shared.string(forKey: "learning.last_source")
        if let course = courses.first(where: { "course:\($0.id)" == last }) { startCourse(course) }
        else if let list = (lists.first(where: { "wordlist:\($0.id)" == last }) ?? lists.first(where: { $0.id == LLSettingsStore.shared.currentListId })) { startList(list) }
        else if showingCourses, let course = courses.first { startCourse(course) }
        else if let list = lists.first { startList(list) }
        else if let course = courses.first { startCourse(course) }
    }
    @objc private func openCredits() {
        let alert = NSAlert()
        alert.messageText = "星荣课程来源"
        alert.informativeText = "课程文字、释义、音标与顺序来自 cuixueshe / Earthworm。\n\n上游采用 GNU AGPL v3.0，课程保留原始顺序。"
        alert.addButton(withTitle: "查看上游")
        alert.addButton(withTitle: "查看许可证")
        alert.addButton(withTitle: "关闭")
        let result = alert.runModal()
        if result == .alertFirstButtonReturn, let url = URL(string: "https://github.com/cuixueshe/earthworm/tree/eb7afc945def0b4b71c64a21354c1b60970e2495/packages/xingrong-courses") { NSWorkspace.shared.open(url) }
        if result == .alertSecondButtonReturn, let url = Bundle.main.url(forResource: "Earthworm-LICENSE", withExtension: "txt") { NSWorkspace.shared.open(url) }
    }
}
