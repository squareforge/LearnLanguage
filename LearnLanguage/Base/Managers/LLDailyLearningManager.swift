import Foundation
import WCDBSwift

/// Owns a queue for one word list, local calendar day and daily goal.
final class LLDailyLearningManager {
    static let shared = LLDailyLearningManager()
    private var reviewQueue: [LLWordEntry] = []
    private var newWordQueue: [LLWordEntry] = []
    private var newLearnWordQueue: [LLWordEntry] = []
    private var currentListId: String?
    private var currentWordList: WordList?
    private var initializedDay: Date?
    private var initializedGoal: Int?
    private(set) var lastError: String?

    private let database: LLDatabaseManager
    private let loadList: (String) -> WordList?
    private let goal: () -> Int
    private let now: () -> Date

    init(database: LLDatabaseManager = .shared,
         loadList: @escaping (String) -> WordList? = { LLWordListStorage.shared.list(byId: $0) },
         goal: @escaping () -> Int = { LLSettingsStore.shared.settings.newWordsPerDay },
         now: @escaping () -> Date = Date.init) {
        self.database = database
        self.loadList = loadList
        self.goal = goal
        self.now = now
    }

    private var dailyGoal: Int { min(max(goal(), 1), 1000) }

    func setup(listId: String) {
        let day = Calendar.current.startOfDay(for: now())
        guard currentListId != listId || initializedDay != day || initializedGoal != dailyGoal else { return }
        currentListId = listId
        reload()
    }

    func invalidate() {
        initializedDay = nil
        initializedGoal = nil
        currentWordList = nil
        reviewQueue = []; newWordQueue = []; newLearnWordQueue = []
        lastError = nil
    }

    func reload() {
        guard let listId = currentListId else { return }
        let date = now()
        do {
            guard let list = loadList(listId) else {
                throw NSError(domain: "LLLearning", code: 1, userInfo: [NSLocalizedDescriptionKey: "词库暂时无法加载，请重试。"])
            }
            let entries = Dictionary(list.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let reviews = try database.getTodayReviewWords(wordListId: listId, at: date)
            let learnedToday = try database.getTodayLearnedProgress(wordListId: listId, at: date)
            let pendingToday = try database.getTodayNewLearnWords(wordListId: listId, at: date)
            let newWords = try database.getTodayNewWords(wordListId: listId, wordList: list, limit: max(0, dailyGoal - learnedToday.count))
            reviewQueue = reviews.compactMap { $0.wordId.flatMap { entries[$0] } }
            newWordQueue = newWords
            newLearnWordQueue = pendingToday.compactMap { $0.wordId.flatMap { entries[$0] } }
            currentWordList = list
            initializedDay = Calendar.current.startOfDay(for: date)
            initializedGoal = dailyGoal
            lastError = nil
        } catch {
            invalidate()
            lastError = error.localizedDescription
            LLLogger.error("加载学习任务失败：\(error)")
        }
    }

    func nextWord() -> LLWordEntry? {
        if let listId = currentListId { setup(listId: listId) }
        return reviewQueue.first ?? newWordQueue.first ?? newLearnWordQueue.first
    }

    @discardableResult
    func recordFeedback(_ feedback: LLWordFeedback, for entry: LLWordEntry, typingPractice: Bool = false) -> Bool {
        guard let current = nextWord(), current.id == entry.id, current.wordListId == entry.wordListId,
              entry.wordListId == currentListId else {
            lastError = "学习任务已更新，请重新开始当前练习。"
            return false
        }
        let fromReview = reviewQueue.first?.id == entry.id
        do {
            let count = try database.saveLearningFeedback(entry: entry, feedback: feedback, typingPractice: typingPractice, at: now())
            if fromReview { reviewQueue.removeFirst() }
            else if newWordQueue.first?.id == entry.id { newWordQueue.removeFirst() }
            else { newLearnWordQueue.removeFirst() }
            if feedback != .know || count < 4 {
                if fromReview { Self.appendIfNeeded(entry, to: &reviewQueue) }
                else { Self.appendIfNeeded(entry, to: &newLearnWordQueue) }
            } else {
                NotificationCenter.default.post(name: .wrongWordsCountChanged, object: nil)
            }
            lastError = nil
            return true
        } catch {
            lastError = "进度未保存，请重试：\(error.localizedDescription)"
            LLLogger.error("保存学习结果失败：\(error)")
            return false
        }
    }

    @discardableResult
    func recordTypingResult(entry: LLWordEntry, errorCount: Int) -> Bool {
        let feedback: LLWordFeedback = errorCount == 0 ? .know : errorCount == 1 ? .unclear : .unknown
        return recordFeedback(feedback, for: entry, typingPractice: true)
    }

    func restartTodayReview() {
        if let listId = currentListId { setup(listId: listId) }
        guard let listId = currentListId, let list = currentWordList else { return }
        do {
            let entries = Dictionary(list.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let records = try database.getTodayLearnedProgress(wordListId: listId, at: now())
            reviewQueue = []; newWordQueue = []
            newLearnWordQueue = records.compactMap { $0.wordId.flatMap { entries[$0] } }
            lastError = nil
        } catch { lastError = error.localizedDescription }
    }

    func learnAnotherBatch() {
        if let listId = currentListId { setup(listId: listId) }
        guard let listId = currentListId, let list = currentWordList else { return }
        do {
            let candidates = try database.getTodayNewWords(wordListId: listId, wordList: list, limit: dailyGoal)
            let existing = Set((reviewQueue + newWordQueue + newLearnWordQueue).map(\.id))
            newWordQueue.append(contentsOf: candidates.filter { !existing.contains($0.id) })
            lastError = nil
        } catch { lastError = error.localizedDescription }
    }

    var reviewQueueCount: Int { reviewQueue.count }
    var newWordQueueCount: Int { newWordQueue.count }
    var newLearnWordQueueCount: Int { newLearnWordQueue.count }
    var hasPendingTasks: Bool { nextWord() != nil }

    private static func appendIfNeeded(_ entry: LLWordEntry, to queue: inout [LLWordEntry]) {
        if !queue.contains(where: { $0.id == entry.id }) { queue.append(entry) }
    }
}
