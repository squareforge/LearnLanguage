//
//  LLReviewContentView.swift
//  LearnLanguage
//
//  复习记录内容视图

import AppKit
import SnapKit

final class LLReviewContentView: NSView {
    
    private lazy var toolbar: NSView = {
        let view = NSView()
        view.wantsLayer = true
        return view
    }()
    
    private lazy var tableContainer: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = LLAppearanceManager.shared.colors.cardBackground.cgColor
        view.layer?.cornerRadius = 8
        view.layer?.borderWidth = 1
        view.layer?.borderColor = LLAppearanceManager.shared.colors.borderColor.withAlphaComponent(0.6).cgColor
        return view
    }()
    
    private lazy var scrollView: NSScrollView = {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        return scroll
    }()
    
    private var tableView: NSTableView!
    
    enum TimeFilter: String, CaseIterable {
        case all = "all"
        case today = "today"
        case week = "week"
        case month = "month"
        
        var displayName: String {
            switch self {
            case .all:
                return NSLocalizedString("Filter All", comment: "All time filter")
            case .today:
                return NSLocalizedString("Filter Today", comment: "Today time filter")
            case .week:
                return NSLocalizedString("Filter Week", comment: "Last 7 days time filter")
            case .month:
                return NSLocalizedString("Filter Month", comment: "Last 30 days time filter")
            }
        }
    }
    
    var currentTimeFilter: TimeFilter = .all {
        didSet {
            onTimeFilterChanged?(currentTimeFilter.displayName)
        }
    }
    
    private var records: [LLDBLearningProgress] = []
    private var wordsByID: [Int: LLDBWord] = [:]
    var onNextPage: (() -> Void)?
    var onPreviousPage: (() -> Void)?
    private let pageLabel = NSTextField(labelWithString: "第 1 页")
    private lazy var previousPageButton = NSButton(title: "上一页", target: self, action: #selector(previousPage))
    private lazy var nextPageButton = NSButton(title: "下一页", target: self, action: #selector(nextPage))

    func update(records: [LLDBLearningProgress], words: [LLDBWord]) {
        self.records = records
        wordsByID = Dictionary(words.compactMap { word in word.id.map { ($0, word) } }, uniquingKeysWith: { first, _ in first })
        tableView?.reloadData()
        scrollView.contentView.scroll(to: .zero)
    }

    func updatePagination(page: Int, hasNext: Bool, error: String? = nil) {
        pageLabel.stringValue = error ?? (records.isEmpty ? "暂无记录" : "第 \(page + 1) 页")
        previousPageButton.isEnabled = page > 0
        nextPageButton.isEnabled = hasNext
    }

    @objc private func previousPage() { onPreviousPage?() }
    @objc private func nextPage() { onNextPage?() }

    var onTimeFilterChanged: ((String) -> Void)?
    var onMarkAsKnown: ((String, String) -> Void)?
    var onReviewWord: ((String) -> Void)?
    var onPlayUS: ((String, String) -> Void)?
    var onPlayUK: ((String, String) -> Void)?
    var onPlayPronunciation: ((String, String) -> Void)?  // 新增：发音回调
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        wantsLayer = true
        
        addSubview(toolbar)
        toolbar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(40)
        }
        
        let filterLabel = NSTextField(labelWithString: NSLocalizedString("Time Range", comment: "Time range filter label"))
        filterLabel.font = NSFont.inter(13, .medium)
        filterLabel.textColor = LLAppearanceManager.shared.colors.secondaryText
        toolbar.addSubview(filterLabel)
        filterLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        
        let popup = NSPopUpButton()
        popup.bezelStyle = .rounded
        popup.font = NSFont.inter(13, .medium)
        TimeFilter.allCases.forEach { popup.addItem(withTitle: $0.displayName) }
        popup.target = self
        popup.action = #selector(timeFilterChanged(_:))
        toolbar.addSubview(popup)
        popup.snp.makeConstraints { make in
            make.leading.equalTo(filterLabel.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.width.equalTo(100)
        }
        
        let pagination = NSStackView(views: [previousPageButton, pageLabel, nextPageButton])
        pagination.orientation = .horizontal
        pagination.spacing = 10
        pageLabel.font = .systemFont(ofSize: 12)
        pageLabel.textColor = LLAppearanceManager.shared.colors.secondaryText
        previousPageButton.isEnabled = false
        nextPageButton.isEnabled = false
        toolbar.addSubview(pagination)
        pagination.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(popup.snp.trailing).offset(12)
        }

        addSubview(tableContainer)
        tableContainer.snp.makeConstraints { make in
            make.top.equalTo(toolbar.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(12)
        }
        
        tableView = NSTableView()
        tableView.style = .fullWidth
        tableView.rowHeight = 58
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        tableView.gridColor = LLAppearanceManager.shared.colors.borderColor
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .none  // 移除选中效果
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.headerView?.frame.size.height = 28
        
        setupTableColumns()
        tableView.delegate = self
        tableView.dataSource = self
        
        scrollView.documentView = tableView
        tableContainer.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(14)
        }
    }
    
    private func setupTableColumns() {
        let columns = [
            ("play", NSLocalizedString("Play", comment: "Play button column"), 50, 50),
            ("word", NSLocalizedString("Word", comment: "Word column"), 130, 100),
            ("meaning", NSLocalizedString("Meaning", comment: "Meaning column"), 180, 150),
            ("nextReview", NSLocalizedString("Next Review", comment: "Next review column"), 100, 90)
        ]
        
        for (id, title, width, minWidth) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.title = title
            column.width = CGFloat(width)
            column.minWidth = CGFloat(minWidth)
            
            // 设置"下次复习"列右对齐
            if id == "nextReview" {
                column.headerCell.alignment = .right
            }
            
            tableView.addTableColumn(column)
        }
    }
    
    @objc private func timeFilterChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < TimeFilter.allCases.count else { return }
        currentTimeFilter = TimeFilter.allCases[index]
    }
}

extension LLReviewContentView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return records.count
    }
}

extension LLReviewContentView: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < records.count else { return nil }
        
        let record = records[row]
        let columnId = tableColumn?.identifier.rawValue ?? ""
        
        let cellView = NSTableCellView()
        cellView.wantsLayer = true
        
        switch columnId {
        case "play":
            let playButton = NSButton(title: "🔊", target: self, action: #selector(didClickPlayButton(_:)))
            playButton.bezelStyle = .rounded
            playButton.controlSize = .small
            playButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            playButton.tag = row
            cellView.addSubview(playButton)
            playButton.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(30)
            }
            
        default:
            let textField = NSTextField(labelWithString: "")
            textField.isEditable = false
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.textColor = LLAppearanceManager.shared.colors.primaryText
            
            cellView.addSubview(textField)
            textField.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(8)
                make.trailing.equalToSuperview().offset(-8)
                make.centerY.equalToSuperview()
            }
            
            switch columnId {
            case "word":
                // 创建容器来放置两行文本
                let container = NSView()
                cellView.addSubview(container)
                container.snp.makeConstraints { make in
                    make.leading.trailing.equalToSuperview().inset(8)
                    make.centerY.equalToSuperview()
                }
                
                // 单词
                let wordLabel = NSTextField(labelWithString: getWordText(wordId: record.wordId ?? "", listId: record.wordListId ?? ""))
                wordLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
                wordLabel.textColor = LLAppearanceManager.shared.colors.primaryText
                container.addSubview(wordLabel)
                wordLabel.snp.makeConstraints { make in
                    make.top.leading.trailing.equalToSuperview()
                    make.height.equalTo(18)
                }
                
                // 音标
                let phoneticLabel = NSTextField(labelWithString: getPhonetic(wordId: record.wordId ?? "", listId: record.wordListId ?? ""))
                phoneticLabel.font = NSFont.systemFont(ofSize: 11)
                phoneticLabel.textColor = LLAppearanceManager.shared.colors.secondaryText
                container.addSubview(phoneticLabel)
                phoneticLabel.snp.makeConstraints { make in
                    make.top.equalTo(wordLabel.snp.bottom).offset(2)
                    make.leading.trailing.bottom.equalToSuperview()
                    make.height.equalTo(14)
                }
                
                textField.removeFromSuperview()
                
            case "meaning":
                textField.stringValue = getWordMeaning(wordId: record.wordId ?? "", listId: record.wordListId ?? "")
                textField.lineBreakMode = .byTruncatingTail
            case "nextReview":
                let interval = record.interval ?? 1
                textField.stringValue = String(format: NSLocalizedString("Days Later", comment: "Days until next review"), interval)
                textField.alignment = .right
                textField.textColor = LLAppearanceManager.shared.colors.accentColor
            default:
                break
            }
        }
        
        return cellView
    }
    
    @objc private func didClickPlayButton(_ sender: NSButton) {
        let row = sender.tag
        guard row < records.count else { return }
        
        let record = records[row]
        let word = getWordText(wordId: record.wordId ?? "", listId: record.wordListId ?? "")
        
        LLLogger.info("🔊 点击播放按钮，单词: \(word)")
        
        // 调用发音回调
        onPlayPronunciation?(word, record.wordListId ?? "")
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true  // 允许选中行
    }
    
    func tableView(_ tableView: NSTableView, didSelectRowAt rowIndexSet: IndexSet) {
        guard let row = rowIndexSet.first, row < records.count else { 
            LLLogger.info("⚠️ 行索引无效")
            return 
        }
        
        LLLogger.info("✅ 选中了第 \(row) 行")
        
        let record = records[row]
        let word = getWordText(wordId: record.wordId ?? "", listId: record.wordListId ?? "")
        
        LLLogger.info("📝 单词: \(word)")
        
        // 调用发音回调，传递单词和词库ID
        onPlayPronunciation?(word, record.wordListId ?? "")
        
        // 延迟 0.3 秒后取消选中
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tableView.deselectRow(row)
        }
    }
    
    private func word(wordId: String, listId: String) -> LLDBWord? {
        guard let id = Int(wordId), let word = wordsByID[id], String(word.wordListId) == listId else { return nil }
        return word
    }

    private func getWordText(wordId: String, listId: String) -> String {
        word(wordId: wordId, listId: listId)?.word ?? NSLocalizedString("Unknown Word", comment: "Unknown word placeholder")
    }

    private func getPhonetic(wordId: String, listId: String) -> String {
        let word = word(wordId: wordId, listId: listId)
        return word?.ukPhonetic ?? word?.usPhonetic ?? ""
    }

    private func getWordMeaning(wordId: String, listId: String) -> String {
        word(wordId: wordId, listId: listId)?.translation ?? ""
    }
}
