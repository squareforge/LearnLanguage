import Foundation

extension Notification.Name {
    static let learningPracticeProgressChanged = Notification.Name("LLLearningPracticeProgressChanged")
}

final class LLCourseRepository {
    static let shared = LLCourseRepository()
    private let progressKey = "learning.course_progress.v1"
    private var cachedCourses: [LLSentenceCourse]?

    func courses() throws -> [LLSentenceCourse] {
        if let cachedCourses { return cachedCourses }
        guard let url = Bundle.main.url(forResource: "xingrong_courses", withExtension: "json") else {
            throw NSError(domain: "LLCourse", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到星荣课程，请重新安装应用。"])
        }
        let courses = try JSONDecoder().decode([LLSentenceCourse].self, from: Data(contentsOf: url))
        guard !courses.isEmpty, Set(courses.map(\.id)).count == courses.count,
              courses.allSatisfy({ !$0.words.isEmpty && $0.words.allSatisfy({ !$0.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) }) else {
            throw NSError(domain: "LLCourse", code: 2, userInfo: [NSLocalizedDescriptionKey: "课程内容不完整，请重新安装应用。"])
        }
        cachedCourses = courses
        return courses
    }

    func progress(for courseID: String) -> LLCourseProgress {
        allProgress()[courseID] ?? LLCourseProgress()
    }

    func course(after courseID: String) throws -> LLSentenceCourse? {
        let courses = try courses()
        guard let index = courses.firstIndex(where: { $0.id == courseID }),
              courses.indices.contains(index + 1) else { return nil }
        return courses[index + 1]
    }

    func save(_ progress: LLCourseProgress, for courseID: String) throws {
        var all = allProgress()
        all[courseID] = progress
        let data = try JSONEncoder().encode(all)
        guard LLMMKVManager.shared.set(data, forKey: progressKey) else {
            throw NSError(domain: "LLCourse", code: 3, userInfo: [NSLocalizedDescriptionKey: "课程进度未保存，请重试。"])
        }
        NotificationCenter.default.post(name: .learningPracticeProgressChanged, object: nil)
    }

    private func allProgress() -> [String: LLCourseProgress] {
        guard let data = LLMMKVManager.shared.data(forKey: progressKey),
              let progress = try? JSONDecoder().decode([String: LLCourseProgress].self, from: data) else { return [:] }
        return progress
    }
}

final class LLVocabularyPracticeSource: LLPracticeSource {
    let listID: String
    let title: String
    var id: String { "wordlist:\(listID)" }
    var errorMessage: String? { LLDailyLearningManager.shared.lastError }

    init(list: WordList) {
        listID = list.id
        title = list.name
        LLDailyLearningManager.shared.setup(listId: list.id)
    }

    var positionText: String {
        let manager = LLDailyLearningManager.shared
        let remaining = manager.reviewQueueCount + manager.newWordQueueCount + manager.newLearnWordQueueCount
        return "今日待练 \(remaining) 项"
    }

    var currentItem: LLLearningItem? {
        guard LLSettingsStore.shared.currentListId == listID,
              let entry = LLDailyLearningManager.shared.nextWord()?.enrichedWithExamplesIfNeeded(), entry.wordListId == listID else { return nil }
        return LLLearningItem(
            id: "\(id):\(entry.id)", text: entry.text, meaning: entry.meaning,
            phonetic: entry.phonetic, example: entry.examples.first?.sentenceEn,
            kind: entry.text.contains(" ") ? .phrase : .word
        )
    }

    func advance(result: LLPracticeResult) throws {
        guard LLSettingsStore.shared.currentListId == listID,
              let entry = LLDailyLearningManager.shared.nextWord(), entry.wordListId == listID, result.itemID == "\(id):\(entry.id)" else {
            throw NSError(domain: "LLLearning", code: 2, userInfo: [NSLocalizedDescriptionKey: "词库或学习任务已切换，请重试。"])
        }
        let errors = result.skipped ? max(2, result.errorCount) : result.usedHint ? max(1, result.errorCount) : result.errorCount
        guard LLDailyLearningManager.shared.recordTypingResult(entry: entry, errorCount: errors) else {
            throw NSError(domain: "LLLearning", code: 3, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "进度未保存，请重试。"])
        }
        LLStatusBarManager.shared.refreshStatusBar()
        NotificationCenter.default.post(name: .learningPracticeProgressChanged, object: nil)
    }

    func replay() { LLDailyLearningManager.shared.learnAnotherBatch() }
}

final class LLCoursePracticeSource: LLPracticeSource {
    let course: LLSentenceCourse
    private let repository: LLCourseRepository
    private var index: Int
    var id: String { "course:\(course.id)" }
    var title: String { "星荣句式 · \(course.title)" }
    var positionText: String { "\(min(index + 1, course.words.count)) / \(course.words.count)" }
    var nextCourse: LLSentenceCourse? { try? repository.course(after: course.id) }

    init(course: LLSentenceCourse, repository: LLCourseRepository = .shared) {
        self.course = course
        self.repository = repository
        index = repository.progress(for: course.id).resumeIndex(total: course.words.count)
    }

    var currentItem: LLLearningItem? {
        guard course.words.indices.contains(index) else { return nil }
        let item = course.words[index]
        let tokenCount = LLPracticeSession.tokens(in: item.en).count
        return LLLearningItem(
            id: "\(id):\(index)", text: item.en, meaning: item.zh, phonetic: item.ipa,
            example: nil, kind: tokenCount == 1 ? .word : tokenCount < 4 ? .phrase : .sentence
        )
    }

    func advance(result: LLPracticeResult) throws {
        guard result.itemID == "\(id):\(index)" else {
            throw NSError(domain: "LLCourse", code: 4, userInfo: [NSLocalizedDescriptionKey: "课程题目已切换，请重新开始本题。"])
        }
        var progress = repository.progress(for: course.id)
        progress.record(index: index, total: course.words.count, completed: !result.skipped)
        try repository.save(progress, for: course.id)
        index += 1
    }

    func replay() {
        index = repository.progress(for: course.id).resumeIndex(total: course.words.count)
    }
}
