//
//  LLDatabaseManager.swift
//  LearnLanguage
//
//  数据库管理类（WCDB）
//

import Foundation
import WCDBSwift

final class LLDatabaseManager {

    static let shared = LLDatabaseManager()

    private(set) var database: Database!
    private let dbPath: String
    private let wordListsTable = "word_lists"
    private let categoriesTable = "categories"
    private let wordsTable = "words"
    private let learningProgressTable = "learning_progress"
    private let learningHistoryTable = "learning_history"
    private let wordExamplesTable = "word_examples"

    init(path: String? = nil) {
        let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        dbPath = path ?? documentPath + "/LearnLanguage.db"

        LLLogger.info("\n" + String(repeating: "=", count: 60))
        LLLogger.info("📁 数据库路径：")
        LLLogger.info("   \(dbPath)")
        LLLogger.info(String(repeating: "=", count: 60) + "\n")

        // 注意：不在这里打开数据库，等待 LLDatabaseInitializer 完成文件准备
        // database = Database(withPath: dbPath)
        // createTables()
    }

    /// 打开数据库连接（在数据库文件准备好后调用）
    @discardableResult
    func openDatabase() -> Bool {
        guard database == nil else {
            LLLogger.warn("⚠️ 数据库已经打开")
            return true
        }

        database = Database(withPath: dbPath)

        // 注意：不需要 createTables()，因为数据库文件已经包含了所有表和数据
        // 只在数据库文件不存在时才需要创建表

        // 检查并创建学习进度表（如果不存在）
        do {
            try createLearningProgressTableIfNeeded()
            try createWordExamplesTableIfNeeded()
        } catch {
            LLLogger.error("数据库结构准备失败：\(error)")
            closeDatabase()
            return false
        }

        LLLogger.info("✅ 数据库连接已打开")
        return true
    }

    /// 关闭数据库连接（恢复备份前调用）
    func closeDatabase() {
        database?.close()
        database = nil
        LLLogger.info("✅ 数据库连接已关闭")
    }

    /// 重新打开数据库连接（恢复备份后调用）
    @discardableResult
    func reopenDatabase() -> Bool {
        closeDatabase()
        return openDatabase()
    }

    /// 检查并创建学习进度表和学习明细表（如果不存在）
    private func createLearningProgressTableIfNeeded() throws {
        try database.create(table: learningProgressTable, of: LLDBLearningProgress.self)
        try database.create(table: learningHistoryTable, of: LLDBLearningHistory.self)
    }

    /// 检查并创建全局例句表（如果不存在）
    private func createWordExamplesTableIfNeeded() throws {
        try database.create(table: wordExamplesTable, of: LLDBWordExample.self)
    }

    private func createTables() {
        do {
            // 创建分类表
            try database.create(table: categoriesTable, of: LLDBWordListCategory.self)
            LLLogger.info("✅ 分类表创建成功")

            // 创建词库表
            try database.create(table: wordListsTable, of: LLDBWordList.self)
            LLLogger.info("✅ 词库表创建成功")

            // 创建单词表
            try database.create(table: wordsTable, of: LLDBWord.self)
            LLLogger.info("✅ 单词表创建成功")

            // 初始化默认分类
            try initializeDefaultCategories()

        } catch {
            LLLogger.error("❌ 创建表失败：\(error)")
        }
    }

    // 初始化默认分类
    private func initializeDefaultCategories() throws {
        // 检查是否已经初始化
        let count = try database.getValue(on: LLDBWordListCategory.Properties.id.count(), fromTable: categoriesTable).int32Value
        if count > 0 {
            return // 已经初始化过了
        }

        // 创建默认分类
        let categories = [
            LLDBWordListCategory(name: "中国考试", description: "包含四六级、考研等", icon: "graduationcap.fill", color: "#FF6B6B", sortOrder: 1),
            LLDBWordListCategory(name: "国际考试", description: "包含托福、雅思等", icon: "globe", color: "#4ECDC4", sortOrder: 2),
            LLDBWordListCategory(name: "青少年英语", description: "适合青少年学习", icon: "book.fill", color: "#95E1D3", sortOrder: 3),
            LLDBWordListCategory(name: "代码练习", description: "编程相关词汇", icon: "chevron.left.forwardslash.chevron.right", color: "#F38181", sortOrder: 4),
            LLDBWordListCategory(name: "其他语言", description: "其他语言学习", icon: "character.bubble.fill", color: "#AA96DA", sortOrder: 5)
        ]
        try database.insert(objects: categories, intoTable: categoriesTable)
        LLLogger.info("✅ 默认分类初始化成功")
    }

    // MARK: - CRUD

    func insertWordList(_ wordList: LLDBWordList) throws -> Int64 {
        try database.insert(objects: wordList, intoTable: wordListsTable)
        // WCDB 会自动填充 id 字段
        return Int64(wordList.id ?? 0)
    }

    func insertWordLists(_ wordLists: [LLDBWordList]) throws {
        try database.insert(objects: wordLists, intoTable: wordListsTable)
    }

    func updateWordList(_ wordList: LLDBWordList, on properties: [LLDBWordList.CodingKeys]) throws {
        guard let id = wordList.id else { return }
        wordList.updatedAt = Date().timeIntervalSince1970
        try database.update(table: wordListsTable, on: properties + [.updatedAt], with: wordList, where: LLDBWordList.Properties.id == id)
    }

    func deleteWordList(id: Int) throws {
        try database.delete(fromTable: wordListsTable, where: LLDBWordList.Properties.id == id)
    }

    func getAllWordLists() throws -> [LLDBWordList] {
        return try database.getObjects(on: LLDBWordList.Properties.all, fromTable: wordListsTable)
    }

    func getWordListsSortedByLastStudied() throws -> [LLDBWordList] {
        return try database.getObjects(
            on: LLDBWordList.Properties.all,
            fromTable: wordListsTable,
            orderBy: [
                LLDBWordList.Properties.isFavorite.asOrder(by: .descending),
                LLDBWordList.Properties.createdAt.asOrder(by: .descending)
            ]
        )
    }

    func getWordList(id: Int) throws -> LLDBWordList? {
        return try database.getObject(on: LLDBWordList.Properties.all, fromTable: wordListsTable, where: LLDBWordList.Properties.id == id)
    }

    func getWordList(description: String) throws -> LLDBWordList? {
        return try database.getObject(
            on: LLDBWordList.Properties.all,
            fromTable: wordListsTable,
            where: LLDBWordList.Properties.description == description
        )
    }

    func getWordList(name: String) throws -> LLDBWordList? {
        return try database.getObject(
            on: LLDBWordList.Properties.all,
            fromTable: wordListsTable,
            where: LLDBWordList.Properties.name == name
        )
    }

    func getWordListByCategoryId(_ categoryId: Int) throws -> [LLDBWordList] {
        return try database.getObjects(
            on: LLDBWordList.Properties.all,
            fromTable: wordListsTable,
            where: LLDBWordList.Properties.categoryId == categoryId,
            orderBy: [LLDBWordList.Properties.createdAt.asOrder(by: .descending)]
        )
    }

    func updateWordListStats(id: Int, totalWords: Int? = nil, learnedWords: Int? = nil) throws {
        guard let wordList = try getWordList(id: id) else { return }
        if let total = totalWords { wordList.totalWords = total }
        if let learned = learnedWords {
            wordList.learnedWords = learned
        }
        try updateWordList(wordList, on: [.totalWords, .learnedWords])
    }

    func toggleWordListFavorite(id: Int) throws {
        guard let wordList = try getWordList(id: id) else { return }
        wordList.isFavorite = !wordList.isFavorite
        try updateWordList(wordList, on: [.isFavorite])
    }

    // MARK: - 分类管理

    func getAllCategories() throws -> [LLDBWordListCategory] {
        return try database.getObjects(
            on: LLDBWordListCategory.Properties.all,
            fromTable: categoriesTable,
            orderBy: [LLDBWordListCategory.Properties.sortOrder.asOrder(by: .ascending)]
        )
    }

    func getCategoryById(_ id: Int) throws -> LLDBWordListCategory? {
        return try database.getObject(
            on: LLDBWordListCategory.Properties.all,
            fromTable: categoriesTable,
            where: LLDBWordListCategory.Properties.id == id
        )
    }

    // MARK: - 单词管理

    /// 批量插入单词
    func insertWords(_ words: [LLDBWord]) throws {
        try database.insert(objects: words, intoTable: wordsTable)
    }

    /// 插入单个单词
    func insertWord(_ word: LLDBWord) throws {
        try database.insert(objects: word, intoTable: wordsTable)
    }

    /// 获取词库的所有单词
    func getWords(forWordListId wordListId: Int) throws -> [LLDBWord] {
        return try database.getObjects(
            on: LLDBWord.Properties.all,
            fromTable: wordsTable,
            where: LLDBWord.Properties.wordListId == wordListId,
            orderBy: [LLDBWord.Properties.id.asOrder(by: .ascending)]
        )
    }

    /// Fetch only the words needed by a record page, without loading whole libraries.
    func getWords(ids: [Int]) throws -> [LLDBWord] {
        guard !ids.isEmpty else { return [] }
        return try database.getObjects(fromTable: wordsTable, where: LLDBWord.Properties.id.in(ids))
    }

    /// 获取词库的单词数量
    func getWordCount(forWordListId wordListId: Int) throws -> Int {
        let count = try database.getValue(
            on: LLDBWord.Properties.id.count(),
            fromTable: wordsTable,
            where: LLDBWord.Properties.wordListId == wordListId
        ).int32Value
        return Int(count)
    }

    /// 获取词库的已学习单词数量
    func getLearnedWordCount(forWordListId wordListId: Int) throws -> Int {
        let count = try database.getValue(
            on: LLDBWord.Properties.id.count(),
            fromTable: wordsTable,
            where: LLDBWord.Properties.wordListId == wordListId && LLDBWord.Properties.isLearned == true
        ).int32Value
        return Int(count)
    }

    /// 更新单词学习状态
    func updateWordLearningStatus(wordId: Int, isLearned: Bool) throws {
        // 先获取单词
        guard let word = try database.getObject(
            on: LLDBWord.Properties.all,
            fromTable: wordsTable,
            where: LLDBWord.Properties.id == wordId
        ) as LLDBWord? else {
            return
        }

        // 更新状态
        word.isLearned = isLearned
        word.lastReviewedAt = Date().timeIntervalSince1970

        // 写回数据库
        try database.update(
            table: wordsTable,
            on: [LLDBWord.Properties.isLearned, LLDBWord.Properties.lastReviewedAt],
            with: word,
            where: LLDBWord.Properties.id == wordId
        )
    }

    /// 删除词库的所有单词
    func deleteWords(forWordListId wordListId: Int) throws {
        try database.delete(
            fromTable: wordsTable,
            where: LLDBWord.Properties.wordListId == wordListId
        )
    }

    /// 搜索单词
    func searchWords(keyword: String, wordListId: Int? = nil) throws -> [LLDBWord] {
        var condition = LLDBWord.Properties.word.like("%\(keyword)%") || LLDBWord.Properties.translation.like("%\(keyword)%")

        if let listId = wordListId {
            condition = condition && LLDBWord.Properties.wordListId == listId
        }

        return try database.getObjects(
            on: LLDBWord.Properties.all,
            fromTable: wordsTable,
            where: condition,
            limit: 100
        )
    }

    func getWord(inWordListId wordListId: Int, word: String) throws -> LLDBWord? {
        return try database.getObject(
            on: LLDBWord.Properties.all,
            fromTable: wordsTable,
            where: LLDBWord.Properties.wordListId == wordListId && LLDBWord.Properties.word == word
        )
    }

    // MARK: - 例句管理

    func getExamples(
        forWordText wordText: String,
        difficultyLevel: Int? = nil,
        limit: Int = 3
    ) throws -> [LLDBWordExample] {
        let normalized = wordText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }

        var condition = LLDBWordExample.Properties.wordText == normalized
        if let difficultyLevel {
            condition = condition && LLDBWordExample.Properties.difficultyLevel == difficultyLevel
        }

        return try database.getObjects(
            on: LLDBWordExample.Properties.all,
            fromTable: wordExamplesTable,
            where: condition,
            orderBy: [
                LLDBWordExample.Properties.heat.asOrder(by: .descending),
                LLDBWordExample.Properties.id.asOrder(by: .ascending)
            ],
            limit: limit
        )
    }

    // MARK: - 错题记录管理（已迁移到 learning_progress）

    /// 获取复习记录（learnCount > 0 的学习进度）
    /// 支持按时间范围和词库筛选
    func getReviewRecords(
        startDate: Date? = nil,
        endDate: Date? = nil,
        wordListId: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) throws -> [LLDBLearningProgress] {
        let calendar = Calendar.current

        // 构建时间条件 - 只要求 learnCount > 0
        var condition = LLDBLearningProgress.Properties.learnCount > 0

        if let start = startDate {
            let startTimestamp = calendar.startOfDay(for: start).timeIntervalSince1970
            condition = condition && LLDBLearningProgress.Properties.updatedAt >= startTimestamp
        }

        if let end = endDate {
            let endTimestamp = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!.timeIntervalSince1970
            condition = condition && LLDBLearningProgress.Properties.updatedAt < endTimestamp
        }

        if let wordListId, !wordListId.isEmpty {
            condition = condition && LLDBLearningProgress.Properties.wordListId == wordListId
        }

        return try database.getObjects(
            on: LLDBLearningProgress.Properties.all,
            fromTable: learningProgressTable,
            where: condition,
            orderBy: [
                LLDBLearningProgress.Properties.learnCount.asOrder(by: .descending),
                LLDBLearningProgress.Properties.updatedAt.asOrder(by: .descending),
                LLDBLearningProgress.Properties.id.asOrder(by: .descending)
            ],
            limit: limit.map { max(1, $0) },
            offset: offset.map { max(0, $0) }
        )
    }

    /// 获取今日复习记录
    func getTodayReviewRecords(wordListId: String? = nil) throws -> [LLDBLearningProgress] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return try getReviewRecords(startDate: today, endDate: Date(), wordListId: wordListId)
    }

    /// 获取本周复习记录
    func getWeekReviewRecords(wordListId: String? = nil) throws -> [LLDBLearningProgress] {
        let calendar = Calendar.current
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        return try getReviewRecords(startDate: weekAgo, endDate: today, wordListId: wordListId)
    }

    /// 获取本月复习记录
    func getMonthReviewRecords(wordListId: String? = nil) throws -> [LLDBLearningProgress] {
        let calendar = Calendar.current
        let today = Date()
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today)!
        return try getReviewRecords(startDate: monthAgo, endDate: today, wordListId: wordListId)
    }

    /// 总学习天数（learning_history 表中有记录的不重复日期数）
    func totalLearningDays(wordListId: String? = nil) throws -> Int {
        let all = try getAllLearningHistory(wordListId: wordListId)
        let cal = Calendar.current
        let uniqueDays = Set(all.compactMap { $0.learnedAt }.map { cal.startOfDay(for: Date(timeIntervalSince1970: $0)) })
        return uniqueDays.count
    }

    /// 获取所有复习记录
    func getAllReviewRecords(wordListId: String? = nil) throws -> [LLDBLearningProgress] {
        return try getReviewRecords(wordListId: wordListId)
    }

    // MARK: - Learning History 查询

    /// 今日学习明细（按 learnedAt 在今天）
    func getTodayLearningHistory(wordListId: String? = nil) throws -> [LLDBLearningHistory] {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date()).timeIntervalSince1970
        let endOfDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!.timeIntervalSince1970
        return try getLearningHistory(from: startOfDay, to: endOfDay, wordListId: wordListId)
    }

    /// 本周学习明细
    func getWeekLearningHistory(wordListId: String? = nil) throws -> [LLDBLearningHistory] {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date())!.timeIntervalSince1970
        let now = Date().timeIntervalSince1970
        return try getLearningHistory(from: weekAgo, to: now, wordListId: wordListId)
    }

    /// 本月学习明细
    func getMonthLearningHistory(wordListId: String? = nil) throws -> [LLDBLearningHistory] {
        let cal = Calendar.current
        let monthAgo = cal.date(byAdding: .month, value: -1, to: Date())!.timeIntervalSince1970
        let now = Date().timeIntervalSince1970
        return try getLearningHistory(from: monthAgo, to: now, wordListId: wordListId)
    }

    /// 全部学习明细
    func getAllLearningHistory(wordListId: String? = nil) throws -> [LLDBLearningHistory] {
        return try getLearningHistory(from: nil, to: nil, wordListId: wordListId)
    }

    /// 基础查询方法
    func getLearningHistory(from startTime: TimeInterval?, to endTime: TimeInterval?, wordListId: String?) throws -> [LLDBLearningHistory] {
        let order = [LLDBLearningHistory.Properties.learnedAt.asOrder(by: .descending)]

        let hasTime = startTime != nil && endTime != nil
        let hasListId = wordListId != nil

        if !hasTime && !hasListId {
            return try database.getObjects(
                on: LLDBLearningHistory.Properties.all,
                fromTable: learningHistoryTable,
                orderBy: order
            ) as [LLDBLearningHistory]
        } else if hasTime && !hasListId {
            let cond = LLDBLearningHistory.Properties.learnedAt >= startTime! &&
                       LLDBLearningHistory.Properties.learnedAt < endTime!
            return try database.getObjects(
                on: LLDBLearningHistory.Properties.all,
                fromTable: learningHistoryTable,
                where: cond,
                orderBy: order
            ) as [LLDBLearningHistory]
        } else if !hasTime && hasListId {
            let cond = LLDBLearningHistory.Properties.wordListId == wordListId!
            return try database.getObjects(
                on: LLDBLearningHistory.Properties.all,
                fromTable: learningHistoryTable,
                where: cond,
                orderBy: order
            ) as [LLDBLearningHistory]
        } else {
            let cond = LLDBLearningHistory.Properties.learnedAt >= startTime! &&
                       LLDBLearningHistory.Properties.learnedAt < endTime! &&
                       LLDBLearningHistory.Properties.wordListId == wordListId!
            return try database.getObjects(
                on: LLDBLearningHistory.Properties.all,
                fromTable: learningHistoryTable,
                where: cond,
                orderBy: order
            ) as [LLDBLearningHistory]
        }
    }

    // MARK: - 学习进度管理

    /// Commit one feedback and its history/typing statistics before the queue advances.
    func saveLearningFeedback(entry: LLWordEntry, feedback: LLWordFeedback, typingPractice: Bool = false, at date: Date = Date()) throws -> Int {
        try saveLearningFeedback(wordId: entry.id, wordListId: entry.wordListId, feedback: feedback, typingPractice: typingPractice, at: date)
    }

    private func saveLearningFeedback(wordId: String, wordListId: String, feedback: LLWordFeedback, typingPractice: Bool = false, at date: Date = Date()) throws -> Int {
        var savedReviewCount = 0
        try database.run(transaction: {
            let listId = wordListId
            let existing = try getLearningProgress(
                wordId: wordId,
                wordListId: listId
            )

            let now = date.timeIntervalSince1970

            if let record = existing {
                // 已有记录：更新
                var easeFactor = record.easeFactor ?? 2.0
                var interval = record.interval ?? 1

                switch feedback {
                case .know:
                    // 正常 SM-2 计算
                    interval = max(1, Int(Double(interval) * easeFactor))
                    record.correctCount = (record.correctCount ?? 0) + 1
                    record.reviewCount = (record.reviewCount ?? 0) + 1

                    if record.reviewCount ?? 0 >= 4 {
                        easeFactor = min(2.0, easeFactor + 0.1)
                        interval = max(1, Int(Double(interval) * easeFactor))
                        record.nextReviewAt = Calendar.current.date(byAdding: .day, value: interval, to: date)?.timeIntervalSince1970 ?? now
                    }
                    record.status = (record.reviewCount ?? 0) >= 4 ? 2 : 1
                case .unclear:
                    // 小幅下降，今天继续
                    easeFactor = max(1.3, easeFactor - 0.1)
                    interval = max(1, interval - 1)
                    record.unclearCount = (record.unclearCount ?? 0) + 1
                    record.reviewCount = max(0, (record.reviewCount ?? 0) - 1)
                    if record.status == 2 { record.status = 1 }
                    record.nextReviewAt = now  // 今天内继续

                case .unknown:
                    // 重置
                    easeFactor = 1.3
                    interval = 1
                    record.wrongCount = (record.wrongCount ?? 0) + 1
                    record.reviewCount = 0
                    record.status = 1
                    record.nextReviewAt = now  // 今天内继续
                }

                record.easeFactor = easeFactor
                record.interval = interval
                record.lastReviewAt = now
                record.lastFeedback = feedback.rawValue
                record.learnCount = (record.learnCount ?? 0) + 1
                record.lastSeenAt = now
                record.updatedAt = now

                try database.update(
                    table: "learning_progress",
                    on: [
                        LLDBLearningProgress.Properties.easeFactor,
                        LLDBLearningProgress.Properties.interval,
                        LLDBLearningProgress.Properties.nextReviewAt,
                        LLDBLearningProgress.Properties.lastReviewAt,
                        LLDBLearningProgress.Properties.lastFeedback,
                        LLDBLearningProgress.Properties.reviewCount,
                        LLDBLearningProgress.Properties.status,
                        LLDBLearningProgress.Properties.correctCount,
                        LLDBLearningProgress.Properties.unclearCount,
                        LLDBLearningProgress.Properties.wrongCount,
                        LLDBLearningProgress.Properties.learnCount,
                        LLDBLearningProgress.Properties.lastSeenAt,
                        LLDBLearningProgress.Properties.updatedAt
                    ],
                    with: record,
                    where: LLDBLearningProgress.Properties.id == (record.id ?? 0)
                )

                // 插入学习明细记录
                let history = LLDBLearningHistory(wordId: wordId, wordListId: listId, feedback: feedback.rawValue, sessionType: "review")
                history.learnedAt = now
                try database.insert(objects: [history], intoTable: "learning_history")
                savedReviewCount = record.reviewCount ?? 0
            } else {
                // 无记录：首次学习，插入新记录
                let newRecord = LLDBLearningProgress(
                    wordId: wordId,
                    wordListId: listId,
                    feedback: feedback.rawValue
                )

                newRecord.firstSeenAt = now
                newRecord.lastSeenAt = now
                newRecord.createdAt = now
                newRecord.updatedAt = now
                newRecord.lastReviewAt = now
                // All new items stay in today's round until four successful recalls.
                newRecord.nextReviewAt = now

                try database.insert(
                    objects: [newRecord],
                    intoTable: "learning_progress"
                )

                // 首次学习，更新词库已学数量
                try recalculateWordListLearnedCount(wordListId: listId)

                // 插入学习明细记录
                let history = LLDBLearningHistory(wordId: wordId, wordListId: listId, feedback: feedback.rawValue, sessionType: "learn")
                history.learnedAt = now
                try database.insert(objects: [history], intoTable: "learning_history")

                savedReviewCount = newRecord.reviewCount ?? 0
            }
            if typingPractice {
                try recordTypingPractice(wordId: wordId, wordListId: wordListId, at: date)
            }
        })
        return savedReviewCount
    }

    /// Compatibility entry point; every feedback uses the same transactional learning rules.
    func recordLearningProgress(wordId: String, wordListId: String, feedback: String) throws {
        guard let feedback = LLWordFeedback(rawValue: feedback) else {
            throw NSError(domain: "LLLearning", code: 4, userInfo: [NSLocalizedDescriptionKey: "无法识别学习反馈。"])
        }
        _ = try saveLearningFeedback(wordId: wordId, wordListId: wordListId, feedback: feedback)
    }

    /// 重新计算词库的已学习单词数（完整计算）
    func recalculateWordListLearnedCount(wordListId: String) throws {
        let count = try database.getValue(
            on: LLDBLearningProgress.Properties.id.count(),
            fromTable: learningProgressTable,
            where: LLDBLearningProgress.Properties.wordListId == wordListId
        ).int32Value

        guard let listId = Int(wordListId),
              let wordList = try getWordList(id: listId) else {
            return
        }

        wordList.learnedWords = Int(count)
        try updateWordList(wordList, on: [.learnedWords])
    }

    /// 获取某个词库的学习进度统计
    func getWordListProgressStats(wordListId: String) throws -> (total: Int, learned: Int, mastered: Int, learning: Int) {
        // 总单词数
        guard let listId = Int(wordListId) else {
            return (0, 0, 0, 0)
        }
        let total = try getWordCount(forWordListId: listId)

        // 已学习数（有学习记录的）
        let learned = try database.getValue(
            on: LLDBLearningProgress.Properties.id.count(),
            fromTable: learningProgressTable,
            where: LLDBLearningProgress.Properties.wordListId == wordListId
        ).int32Value

        // 已掌握数（status = 2）
        let mastered = try database.getValue(
            on: LLDBLearningProgress.Properties.id.count(),
            fromTable: learningProgressTable,
            where: LLDBLearningProgress.Properties.wordListId == wordListId && LLDBLearningProgress.Properties.status == 2
        ).int32Value

        // 学习中（status = 1）
        let learning = try database.getValue(
            on: LLDBLearningProgress.Properties.id.count(),
            fromTable: learningProgressTable,
            where: LLDBLearningProgress.Properties.wordListId == wordListId && LLDBLearningProgress.Properties.status == 1
        ).int32Value

        return (total, Int(learned), Int(mastered), Int(learning))
    }

    /// 获取某个单词的学习进度
    func getLearningProgress(wordId: String, wordListId: String) throws -> LLDBLearningProgress? {
        return try database.getObject(
            on: LLDBLearningProgress.Properties.all,
            fromTable: learningProgressTable,
            where: LLDBLearningProgress.Properties.wordId == wordId && LLDBLearningProgress.Properties.wordListId == wordListId
        )
    }

    /// 获取某个词库的所有学习记录
    func getAllLearningProgress(wordListId: String) throws -> [LLDBLearningProgress] {
        return try database.getObjects(
            on: LLDBLearningProgress.Properties.all,
            fromTable: learningProgressTable,
            where: LLDBLearningProgress.Properties.wordListId == wordListId,
            orderBy: [LLDBLearningProgress.Properties.lastSeenAt.asOrder(by: .descending)]
        )
    }

    /// 获取今日学习的单词数
    func getTodayLearnedCount(wordListId: String? = nil) throws -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayTimestamp = today.timeIntervalSince1970

        var condition = LLDBLearningProgress.Properties.lastSeenAt >= todayTimestamp
        if let listId = wordListId {
            condition = condition && LLDBLearningProgress.Properties.wordListId == listId
        }

        let count = try database.getValue(
            on: LLDBLearningProgress.Properties.id.count(),
            fromTable: learningProgressTable,
            where: condition
        ).int32Value

        return Int(count)
    }

    // MARK: - 每日学习任务

    /// 获取今日需要复习的词汇（nextReviewAt <= 今天结束时间戳，且 createdAt 不是今天，即历史学过的词）
    func getTodayReviewWords(wordListId: String? = nil, at date: Date = Date()) throws -> [LLDBLearningProgress] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date).timeIntervalSince1970
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!.timeIntervalSince1970

        var condition = LLDBLearningProgress.Properties.nextReviewAt < endOfDay
            && LLDBLearningProgress.Properties.createdAt < startOfDay  // 排除今天新学的词
        if let wordListId {
            condition = condition && LLDBLearningProgress.Properties.wordListId == wordListId
        }

        return try database.getObjects(
            on: LLDBLearningProgress.Properties.all,
            fromTable: learningProgressTable,
            where: condition,
            orderBy: [LLDBLearningProgress.Properties.nextReviewAt.asOrder(by: .ascending)]
        )
    }

    /// 获取今日新学习的词汇(createdAt <= 今天结束时间戳 && >= 今天开始时间戳，且reviewCount < 4的词汇)
    func getTodayNewLearnWords(wordListId: String? = nil, at date: Date = Date()) throws -> [LLDBLearningProgress] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date).timeIntervalSince1970
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!.timeIntervalSince1970

        var condition = LLDBLearningProgress.Properties.createdAt >= startOfDay
            && LLDBLearningProgress.Properties.createdAt < endOfDay
            && LLDBLearningProgress.Properties.reviewCount < 4
        if let wordListId {
            condition = condition && LLDBLearningProgress.Properties.wordListId == wordListId
        }

        return try database.getObjects(
            on: LLDBLearningProgress.Properties.all,
            fromTable: learningProgressTable,
            where: condition,
            orderBy: [LLDBLearningProgress.Properties.createdAt.asOrder(by: .descending)]
        )
    }

    /// 获取今日已学习的词汇（createdAt 在今天范围内）
    func getTodayLearnedProgress(wordListId: String, at date: Date = Date()) throws -> [LLDBLearningProgress] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date).timeIntervalSince1970
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!.timeIntervalSince1970

        return try database.getObjects(
            on: LLDBLearningProgress.Properties.all,
            fromTable: learningProgressTable,
            where: LLDBLearningProgress.Properties.wordListId == wordListId
                && LLDBLearningProgress.Properties.createdAt >= startOfDay
                && LLDBLearningProgress.Properties.createdAt < endOfDay,
            orderBy: [LLDBLearningProgress.Properties.updatedAt.asOrder(by: .descending)]
        )
    }

    /// 获取今日需要学习的新词汇（在 learning_progress 中没有记录的词，按原始顺序取 limit 个）
    func getTodayNewWords(wordListId: String, wordList: WordList, limit: Int) throws -> [LLWordEntry] {
        guard limit > 0 else { return [] }
        // 取出该词库所有已有学习记录的 wordId
        let progressList = try database.getObjects(
            on: [LLDBLearningProgress.Properties.wordId],
            fromTable: learningProgressTable,
            where: LLDBLearningProgress.Properties.wordListId == wordListId
        ) as [LLDBLearningProgress]

        let learnedIds = Set(progressList.compactMap { $0.wordId })

        // 从词库中过滤出未学习的词，按原始顺序取 limit 个
        let newWords = wordList.entries
            .filter { !learnedIds.contains($0.id) }
            .prefix(limit)

        return Array(newWords)
    }

    /// 删除某个词库的所有学习记录
    func deleteLearningProgress(wordListId: String) throws {
        try database.delete(
            fromTable: learningProgressTable,
            where: LLDBLearningProgress.Properties.wordListId == wordListId
        )
    }

    /// 删除某个词库的所有学习明细
    func deleteLearningHistory(wordListId: String) throws {
        try database.delete(
            fromTable: learningHistoryTable,
            where: LLDBLearningHistory.Properties.wordListId == wordListId
        )
    }

    /// 记录打字练习
    func recordTypingPractice(wordId: String, wordListId: String, at date: Date = Date()) throws {
        guard let record = try getLearningProgress(wordId: wordId, wordListId: wordListId) else {
            return
        }

        let now = date.timeIntervalSince1970
        record.typingPracticeCount = (record.typingPracticeCount ?? 0) + 1
        record.lastTypingAt = now
        record.updatedAt = now

        try database.update(
            table: learningProgressTable,
            on: [
                LLDBLearningProgress.Properties.typingPracticeCount,
                LLDBLearningProgress.Properties.lastTypingAt,
                LLDBLearningProgress.Properties.updatedAt
            ],
            with: record,
            where: LLDBLearningProgress.Properties.id == record.id ?? 0
        )
    }
}
