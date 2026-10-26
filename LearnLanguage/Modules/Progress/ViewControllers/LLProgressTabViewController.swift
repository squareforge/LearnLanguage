//
//  LLProgressTabViewController.swift
//  LearnLanguage
//
//  学习记录模块 - 包含学习统计和错题记录两个子标签

import AppKit
import SnapKit
import UniformTypeIdentifiers

final class LLProgressTabViewController: NSViewController {
    /**
     1.状态栏反馈操作：
        情况1：如果是复习词汇，点击认识，就把review_count +1, 如果点击模糊就把review_count -1,如果点击不认识就把review_count = 0 只有当review_count >= 4的时候就把这个词汇重复习词汇里切出去，表示当前这个词汇已经复习过了，你记得要修改easeFactor 和 nextReviewAt
        情况2：如果是新词汇，点击认识，就把review_count + 1，如果点击模糊就把review_count -1,如果点击不认识就把review_count = 0 只有当review_count >= 4的时候就把这个词汇重复习词汇里切出去，表示当前这个词汇已经学习过了，你记得要修改easeFactor 和 nextReviewAt和learn_count+1操作，
     2.打字反馈操作：
        情况1:如果是复习词汇，一次就输入正确了，就把review_count +1, 如果错误一次才输入正确就把review_count -1，如果错误2次就把review_count = 0 只有当review_count >= 4的时候就把这个词汇重复习词汇里切出去，表示当前这个词汇已经复习过了，你记得要修改easeFactor 和 nextReviewAt
        情况2:如果这个词汇是新词汇，一次就输入正确了，就把review_count +1, 如果错误一次才输入正确就把review_count -1，如果错误2次就把review_count = 0 只有当review_count >= 4的时候就把这个词汇重复习词汇里切出去，表示当前这个词汇已经学习过了，你记得要修改easeFactor 和 nextReviewAt和learn_count+1操作，
     */
    // MARK: - Type Aliases
    
    typealias TimeFilter = LLReviewContentView.TimeFilter
    
    // 页面标题
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: NSLocalizedString("Progress Module Title", comment: ""))
        label.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        label.textColor = LLAppearanceManager.shared.colors.moduleTitleText
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        return label
    }()
    
    // 标签按钮容器
    private lazy var tabContainer: NSView = {
        let view = NSView()
        view.wantsLayer = true
        return view
    }()
    
    // 子标签按钮
    private lazy var statTabButton: NSButton = makeTabButton(title: NSLocalizedString("Stat Tab", comment: ""), action: #selector(switchToStatTab))
    private lazy var todayRecordTabButton: NSButton = makeTabButton(title: NSLocalizedString("Today Record Tab", comment: ""), action: #selector(switchToTodayRecordTab))
    private lazy var reviewTabButton: NSButton = makeTabButton(title: NSLocalizedString("Review Tab", comment: ""), action: #selector(switchToReviewTabAction))

    // 页面容器
    private lazy var statContainer: NSView = { let v = NSView(); v.wantsLayer = true; return v }()
    private lazy var todayRecordContainer: NSView = { let v = NSView(); v.wantsLayer = true; v.isHidden = true; return v }()
    private lazy var reviewContainer: NSView = { let v = NSView(); v.wantsLayer = true; v.isHidden = true; return v }()

    // 内容视图
    private var statContentView: LLStatContentView!
    private var todayRecordContentView: LLTodayRecordContentView!
    private var reviewContentView: LLReviewContentView!

    // 当前选中的标签
    private enum Tab { case stat, todayRecord, review }
    private var currentTab: Tab = .stat

    private struct ExportPayload: Codable {
        let exportedAt: String
        let filter: String
        let records: [ExportRecord]
    }

    private struct ExportRecord: Codable {
        let wordId: String
        let wordListId: String
        let word: String
        let feedback: String
        let feedbackText: String
        let learnCount: Int
        let lastLearnedAt: String
    }
    
    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 450))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
        
        // 监听数据变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loadData),
            name: .learnLanguageRefreshStatus,
            object: nil
        )
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        loadData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        
        // 添加标题
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(28)
            make.leading.equalToSuperview().offset(28)
        }
        
        // 添加标签按钮容器
        view.addSubview(tabContainer)
        tabContainer.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(28)
            make.height.equalTo(28)
        }
        
        // 添加标签按钮
        tabContainer.addSubview(statTabButton)
        statTabButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.greaterThanOrEqualTo(80)
        }
        
        tabContainer.addSubview(todayRecordTabButton)
        todayRecordTabButton.snp.makeConstraints { make in
            make.leading.equalTo(statTabButton.snp.trailing).offset(4)
            make.top.bottom.equalToSuperview()
            make.width.greaterThanOrEqualTo(80)
        }
        
        tabContainer.addSubview(reviewTabButton)
        reviewTabButton.snp.makeConstraints { make in
            make.leading.equalTo(todayRecordTabButton.snp.trailing).offset(4)
            make.top.bottom.trailing.equalToSuperview()
            make.width.greaterThanOrEqualTo(80)
        }
        
        // 添加学习统计页面
        view.addSubview(statContainer)
        statContainer.snp.makeConstraints { make in
            make.top.equalTo(tabContainer.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(28)
            make.bottom.equalToSuperview().offset(-28)
        }
        
        statContentView = LLStatContentView()
        statContentView.onChangeWordListClicked = { [weak self] in
            self?.showWordListSelector()
        }
        statContainer.addSubview(statContentView)
        statContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 添加今日记录页面
        view.addSubview(todayRecordContainer)
        todayRecordContainer.snp.makeConstraints { make in
            make.top.equalTo(tabContainer.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(28)
            make.bottom.equalToSuperview().offset(-28)
        }
        
        todayRecordContentView = LLTodayRecordContentView()
        todayRecordContentView.onExportClicked = { [weak self] in
            self?.exportRecords()
        }
        todayRecordContentView.onFilterChanged = { [weak self] _ in
            self?.loadTodayRecords(listId: LLSettingsStore.shared.currentListId)
        }
        todayRecordContainer.addSubview(todayRecordContentView)
        todayRecordContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 添加复习记录页面
        view.addSubview(reviewContainer)
        reviewContainer.snp.makeConstraints { make in
            make.top.equalTo(tabContainer.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(28)
            make.bottom.equalToSuperview().offset(-28)
        }
        
        reviewContentView = LLReviewContentView()
        reviewContentView.onTimeFilterChanged = { [weak self] _ in
            self?.resetReviewPagination()
            self?.loadReviewRecords(listId: LLSettingsStore.shared.currentListId)
        }
        reviewContentView.onNextPage = { [weak self] in self?.loadNextReviewPage() }
        reviewContentView.onPreviousPage = { [weak self] in self?.loadPreviousReviewPage() }
        reviewContentView.onMarkAsKnown = { [weak self] wordId, listId in
            self?.markAsKnown(wordId: wordId, listId: listId)
        }
        reviewContentView.onReviewWord = { [weak self] wordId in
            self?.reviewWord(wordId: wordId)
        }
        reviewContentView.onPlayUS = { [weak self] word, listId in
            self?.playPronunciation(word: word, accent: .us)
        }
        reviewContentView.onPlayUK = { [weak self] word, listId in
            self?.playPronunciation(word: word, accent: .uk)
        }
        reviewContentView.onPlayPronunciation = { [weak self] word, listId in
            // 根据设置选择发音方式
            LLLogger.info("📢 点击了行，单词: \(word)")
            let accent = LLSettingsStore.shared.settings.pronunciationAccent
            self?.playPronunciation(word: word, accent: accent)
        }
        reviewContainer.addSubview(reviewContentView)
        reviewContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 默认选中学习统计
        updateTabButtonStyles()
    }
    
    @objc private func switchToStatTab() {
        currentTab = .stat
        updateTabButtonStyles()
        statContainer.isHidden = false
        todayRecordContainer.isHidden = true
        reviewContainer.isHidden = true
    }
    
    @objc private func switchToTodayRecordTab() {
        currentTab = .todayRecord
        updateTabButtonStyles()
        statContainer.isHidden = true
        todayRecordContainer.isHidden = false
        reviewContainer.isHidden = true
        loadTodayRecords(listId: LLSettingsStore.shared.currentListId)
    }
    
    @objc private func switchToReviewTabAction() {
        currentTab = .review
        updateTabButtonStyles()
        statContainer.isHidden = true
        todayRecordContainer.isHidden = true
        reviewContainer.isHidden = false
    }
    
    private func updateTabButtonStyles() {
        let active = LLAppearanceManager.shared.colors.accentColor
        let inactive = NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1)
        let pairs: [(NSButton, Tab)] = [
            (statTabButton, .stat),
            (todayRecordTabButton, .todayRecord),
            (reviewTabButton, .review)
        ]
        for (btn, tab) in pairs {
            btn.wantsLayer = true
            btn.layer?.backgroundColor = (tab == currentTab ? active : inactive).cgColor
            btn.contentTintColor = tab == currentTab ? .white : LLAppearanceManager.shared.colors.primaryText
        }
    }
    

    
    @objc private func exportRecords() {
        let items = todayRecordContentView.items
        guard !items.isEmpty else {
            showExportAlert(
                title: NSLocalizedString("Export Records Empty", comment: ""),
                message: NSLocalizedString("Export Records Empty Desc", comment: ""),
                style: .informational
            )
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "LearningRecords_\(exportFileDateString()).json"
        savePanel.message = NSLocalizedString("Export Records Message", comment: "")
        
        savePanel.begin { [weak self] response in
            if response == .OK, let url = savePanel.url {
                self?.writeExportRecords(items, to: url)
            }
        }
    }

    private func writeExportRecords(_ items: [LLTodayRecordItem], to url: URL) {
        do {
            let formatter = ISO8601DateFormatter()
            let payload = ExportPayload(
                exportedAt: formatter.string(from: Date()),
                filter: todayRecordContentView.currentFilter.rawValue,
                records: items.map { item in
                    ExportRecord(
                        wordId: item.wordId,
                        wordListId: item.wordListId,
                        word: item.wordText,
                        feedback: item.lastFeedback,
                        feedbackText: LLWordFeedback(rawValue: item.lastFeedback)?.displayName ?? item.lastFeedback,
                        learnCount: item.learnCount,
                        lastLearnedAt: formatter.string(from: Date(timeIntervalSince1970: item.lastLearnedAt))
                    )
                }
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(payload)
            try data.write(to: url, options: .atomic)

            showExportAlert(
                title: NSLocalizedString("Export Records Success", comment: ""),
                message: url.path,
                style: .informational
            )
            LLLogger.info("✅ 学习记录已导出到: \(url.path)")
        } catch {
            showExportAlert(
                title: NSLocalizedString("Export Records Failed", comment: ""),
                message: error.localizedDescription,
                style: .critical
            )
            LLLogger.error("❌ 导出学习记录失败：\(error)")
        }
    }

    private func showExportAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.runModal()
    }

    private func exportFileDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
    // MARK: - Public Methods
    
    func switchToReviewTab() {
        switchToReviewTabAction()
    }
    
    func setTimeFilter(to filter: TimeFilter) {
        reviewContentView?.currentTimeFilter = filter
        
        // 更新下拉框的选中项
        if let reviewView = reviewContentView {
            // 找到对应的下拉框并更新
            for subview in reviewView.subviews {
                if let popup = findPopupButton(in: subview) {
                    let index = TimeFilter.allCases.firstIndex(of: filter) ?? 0
                    popup.selectItem(at: index)
                    break
                }
            }
        }
        
        resetReviewPagination()
        loadReviewRecords(listId: LLSettingsStore.shared.currentListId)
    }
    
    private func findPopupButton(in view: NSView) -> NSPopUpButton? {
        if let popup = view as? NSPopUpButton {
            return popup
        }
        for subview in view.subviews {
            if let popup = findPopupButton(in: subview) {
                return popup
            }
        }
        return nil
    }
    
    @objc private func loadData() {
        guard isViewLoaded else { return }
        
        let listId = LLSettingsStore.shared.currentListId
        
        do {
            let todayCount = try LLDatabaseManager.shared.getTodayLearnedCount(wordListId: listId)
            let stats: (total: Int, learned: Int, mastered: Int, learning: Int)
            if let listId = listId {
                stats = try LLDatabaseManager.shared.getWordListProgressStats(wordListId: listId)
            } else {
                stats = (0, 0, 0, 0)
            }
            let totalWords = stats.learned
            let days = (try? LLDatabaseManager.shared.totalLearningDays(wordListId: listId)) ?? 0
            let trendPoints = recentTrendPoints(wordListId: listId)
            
            statContentView?.updateStatistics(
                totalWords: totalWords,
                days: days,
                todayCount: todayCount,
                todayGoal: LLSettingsStore.shared.settings.newWordsPerDay,
                trendPoints: trendPoints
            )
        } catch {
            LLLogger.error("❌ 加载统计数据失败：\(error)")
        }
        
        loadTodayRecords(listId: listId)
        loadReviewRecords(listId: listId)
    }
    
    private func recentTrendPoints(wordListId: String?) -> [LLTrendPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 6, to: today)
        }
        
        var countsByDay = Dictionary(uniqueKeysWithValues: days.map { ($0, 0) })
        do {
            let startTime = days.first?.timeIntervalSince1970 ?? today.timeIntervalSince1970
            let endTime = (calendar.date(byAdding: .day, value: 1, to: today) ?? Date()).timeIntervalSince1970
            let history = try LLDatabaseManager.shared.getLearningHistory(from: startTime, to: endTime, wordListId: wordListId)
            for item in history {
                guard let learnedAt = item.learnedAt else { continue }
                let day = calendar.startOfDay(for: Date(timeIntervalSince1970: learnedAt))
                countsByDay[day, default: 0] += 1
            }
        } catch {
            LLLogger.error("❌ 加载趋势数据失败：\(error)")
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return days.map { day in
            LLTrendPoint(label: formatter.string(from: day), count: countsByDay[day] ?? 0)
        }
    }
    
    private func loadTodayRecords(listId: String?) {
        do {
            let filter = todayRecordContentView?.currentFilter ?? .today
            let history: [LLDBLearningHistory]
            switch filter {
            case .today: history = try LLDatabaseManager.shared.getTodayLearningHistory(wordListId: listId)
            case .week:  history = try LLDatabaseManager.shared.getWeekLearningHistory(wordListId: listId)
            case .month: history = try LLDatabaseManager.shared.getMonthLearningHistory(wordListId: listId)
            case .all:   history = try LLDatabaseManager.shared.getAllLearningHistory(wordListId: listId)
            }
            
            // 按 wordId+wordListId 聚合，统计每个单词的学习次数
            var grouped: [String: [LLDBLearningHistory]] = [:]
            for h in history {
                let key = (h.wordId ?? "") + "_" + (h.wordListId ?? "")
                grouped[key, default: []].append(h)
            }
            
            let items: [LLTodayRecordItem] = grouped.values.compactMap { records in
                guard let first = records.first,
                      let wordId = first.wordId,
                      let wListId = first.wordListId else { return nil }
                let wordText = getWordText(wordId: wordId, listId: wListId)
                let sorted = records.sorted { ($0.learnedAt ?? 0) > ($1.learnedAt ?? 0) }
                let lastFeedback = sorted.first?.feedback ?? ""
                let lastLearnedAt = sorted.first?.learnedAt ?? 0
                return LLTodayRecordItem(
                    wordId: wordId,
                    wordListId: wListId,
                    wordText: wordText,
                    lastFeedback: lastFeedback,
                    learnCount: records.count,
                    lastLearnedAt: lastLearnedAt
                )
            }.sorted { $0.lastLearnedAt > $1.lastLearnedAt }
            
            todayRecordContentView?.updateItems(items)
        } catch {
            LLLogger.error("❌ 加载今日记录失败：\(error)")
            todayRecordContentView?.updateItems([])
        }
    }
    
    // MARK: - 分页相关
    
    private var reviewPageSize = 20
    private var reviewCurrentPage = 0
    private var reviewListID: String?
    
    private func loadReviewRecords(listId: String?) {
        if reviewListID != listId {
            reviewCurrentPage = 0
            reviewListID = listId
        }
        do {
            let now = Date()
            let calendar = Calendar.current
            let start: Date?
            switch reviewContentView?.currentTimeFilter ?? .all {
            case .all: start = nil
            case .today: start = calendar.startOfDay(for: now)
            case .week: start = calendar.date(byAdding: .day, value: -7, to: now)
            case .month: start = calendar.date(byAdding: .month, value: -1, to: now)
            }
            let page = try LLDatabaseManager.shared.getReviewRecords(
                startDate: start, endDate: start == nil ? nil : now,
                wordListId: listId, limit: reviewPageSize + 1,
                offset: reviewCurrentPage * reviewPageSize
            )
            if page.isEmpty && reviewCurrentPage > 0 {
                reviewCurrentPage -= 1
                loadReviewRecords(listId: listId)
                return
            }
            let records = Array(page.prefix(reviewPageSize))
            let words = try LLDatabaseManager.shared.getWords(ids: records.compactMap { Int($0.wordId ?? "") })
            reviewContentView?.update(records: records, words: words)
            reviewContentView?.updatePagination(page: reviewCurrentPage, hasNext: page.count > reviewPageSize)
        } catch {
            LLLogger.error("❌ 加载复习记录失败：\(error)")
            reviewContentView?.update(records: [], words: [])
            reviewContentView?.updatePagination(page: reviewCurrentPage, hasNext: false, error: "加载失败，请切换筛选后重试")
        }
    }

    // 重置分页
    private func resetReviewPagination() {
        reviewCurrentPage = 0
    }
    
    // 下一页
    private func loadNextReviewPage() {
        reviewCurrentPage += 1
        loadReviewRecords(listId: LLSettingsStore.shared.currentListId)
    }
    
    // 上一页
    private func loadPreviousReviewPage() {
        reviewCurrentPage = max(0, reviewCurrentPage - 1)
        loadReviewRecords(listId: LLSettingsStore.shared.currentListId)
    }
    
    @objc private func markAsKnown(wordId: String, listId: String) {
        do {
            guard let record = try LLDatabaseManager.shared.getLearningProgress(wordId: wordId, wordListId: listId) else {
                return
            }
            
            record.reviewCount = 0
            record.status = 2
            record.updatedAt = Date().timeIntervalSince1970
            
            try LLDatabaseManager.shared.recordLearningProgress(
                wordId: wordId,
                wordListId: listId,
                feedback: "know"
            )
            
            LLLogger.info("✅ 已标记为已掌握: \(wordId)")
            loadData()
        } catch {
            LLLogger.error("❌ 标记失败：\(error)")
        }
    }
    
    @objc private func reviewWord(wordId: String) {
        LLLogger.info("立即复习: \(wordId)")
    }
    
    private func playPronunciation(word: String, accent: LLPronunciationAccent) {
        let accentName = accent == .us ? "美式" : "英式"
        LLLogger.debug("🔊 播放\(accentName)发音：\(word)")
        
        LLPronunciationManager.shared.speak(word: word, accent: accent) { success, error in
            if let error = error {
                LLLogger.error("❌ 播放失败：\(error.localizedDescription)")
            } else if success {
                LLLogger.info("✅ 播放完成")
            }
        }
    }
    
    private func showWordListSelector() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Select List", comment: "")
        alert.informativeText = NSLocalizedString("Select List Desc", comment: "")
        
        // 获取所有词库
        let allLists = LLWordListStorage.shared.allLists()
        
        if allLists.isEmpty {
            alert.informativeText = NSLocalizedString("No Word List", comment: "")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.runModal()
            return
        }
        
        // 创建词库选择器
        let popUpButton = NSPopUpButton()
        popUpButton.frame = NSRect(x: 0, y: 0, width: 300, height: 26)
        
        for list in allLists {
            let title = "\(list.name) (\(list.entryCount) 词)"
            popUpButton.addItem(withTitle: title)
            popUpButton.lastItem?.representedObject = list.id
        }
        
        // 选中当前词库
        if let currentId = LLSettingsStore.shared.currentListId,
           let index = allLists.firstIndex(where: { $0.id == currentId }) {
            popUpButton.selectItem(at: index)
        }
        
        alert.accessoryView = popUpButton
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let selectedId = popUpButton.selectedItem?.representedObject as? String {
                LLSettingsStore.shared.currentListId = selectedId
                LLLogger.info("✅ 已切换到词库: \(popUpButton.titleOfSelectedItem ?? "")")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getWordText(wordId: String, listId: String) -> String {
        guard let list = LLWordListStorage.shared.list(byId: listId),
              let entry = list.entries.first(where: { $0.id == wordId }) else {
            return NSLocalizedString("Unknown Word", comment: "")
        }
        return entry.text
    }
    
    private func getWordInfo(wordId: String, listId: String) -> (text: String, meaning: String) {
        guard let list = LLWordListStorage.shared.list(byId: listId),
              let entry = list.entries.first(where: { $0.id == wordId }) else {
            return ("未知单词", "")
        }
        return (entry.text, entry.meaning)
    }
    
    private func getFeedbackIcon(feedback: LLWordFeedback) -> String {
        switch feedback {
        case .know:
            return "✔️"
        case .unclear:
            return "❓"
        case .unknown:
            return "❌"
        }
    }
    
    private func getFeedbackIconFromString(feedback: String) -> String {
        switch feedback {
        case "know":    return "✔️"
        case "unclear": return "❓"
        case "unknown": return "❌"
        default:        return "❓"
        }
    }
    
    private func makeTabButton(title: String, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.bezelStyle = .rounded
        btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6
        return btn
    }
}
