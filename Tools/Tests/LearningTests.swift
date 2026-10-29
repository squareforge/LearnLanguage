import Foundation

@main
struct LearningTests {
    static var assertions = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        if !condition() { fatalError(message) }
    }

    static func type(_ text: String, into session: LLPracticeSession) {
        let words = LLPracticeSession.tokens(in: text)
        for (index, word) in words.enumerated() {
            for char in word { session.input(char) }
            if index < words.count - 1 { check(session.confirm(), "A completed token must advance") }
        }
    }

    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let courses = try JSONDecoder().decode([LLSentenceCourse].self, from: data)
        check(courses.count == 55, "Expected all 55 lessons")
        check(courses.reduce(0) { $0 + $1.words.count } == 8865, "Expected all 8865 items")
        check(courses[0].words.prefix(5).map(\.en) == ["I", "like", "I like", "the food", "I like the food"], "Preserve upstream progression")
        check(Set(courses.map(\.id)).count == 55, "Course IDs must be stable and unique")
        check(courses.allSatisfy { !$0.words.isEmpty && $0.words.allSatisfy { !LLPracticeSession.tokens(in: $0.en).isEmpty } }, "Every exercise must be typeable")

        let resourceDirectory = URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent()
        let repository = LLCourseRepository(resourceDirectory: resourceDirectory)
        let collections = try repository.collections()
        check(collections.map(\.courses.count) == [55, 72, 96, 60, 48], "All five collections decode with the expected lesson counts")
        let allCourses = try repository.courses()
        check(allCourses.count == 331, "All lessons are available to source restoration")
        for collection in collections {
            let afterLast = try repository.course(after: collection.courses.last!.id)
            let afterFirst = try repository.course(after: collection.courses[0].id)
            check(afterLast == nil, "Next lesson never crosses a collection boundary")
            check(afterFirst?.id == collection.courses[1].id, "Next lesson follows the selected collection order")
        }
        let imported = LLPracticeSession(source: LLCoursePracticeSource(course: collections[2].courses[0], repository: repository), showHint: true)
        type("Last week I went to the theatre", into: imported)
        check(imported.isItemComplete && imported.errorCount == 0 && imported.isMeaningRevealed, "New Concept punctuation is automatic and completing a sentence reveals its translation")
        imported.backspace()
        check(!imported.isMeaningRevealed && imported.typedCount == 6, "Backspace removes the last typed letter past automatic punctuation")
        imported.input("e")
        check(imported.confirm() && imported.item?.text == "I had a very good seat.", "One confirmation saves and advances a New Concept exercise")
        let punctuationCourse = LLSentenceCourse(id: "punctuation", category: "", title: "", words: [.init(en: "'Don't re-enter,' he said.", zh: "别再进来，他说。", ipa: nil)], collectionID: "new-concept-book-2")
        let punctuation = LLPracticeSession(source: LLCoursePracticeSource(course: punctuationCourse), showHint: true)
        punctuation.backspace()
        check(punctuation.typedCount == 1, "Backspace before any letter cannot expose a required opening quote")
        type("Don't re-enter he said", into: punctuation)
        check(punctuation.isItemComplete && punctuation.errorCount == 0, "Internal apostrophes and hyphens remain typeable while surrounding punctuation is automatic")
        var importedItemsVerified = 0
        for collection in collections.dropFirst() {
            for course in collection.courses {
                for (index, item) in course.words.enumerated() {
                    let isolated = LLSentenceCourse(id: "typing-check-\(course.id)-\(index)", category: course.category, title: course.title, words: [item], collectionID: collection.id)
                    let exercise = LLPracticeSession(source: LLCoursePracticeSource(course: isolated), showHint: true)
                    for (wordIndex, token) in exercise.tokens.enumerated() {
                        let characters = Array(token)
                        for i in characters.indices {
                            let char = characters[i]
                            let internalMark = (char == "'" || char == "-") && i > 0 && i + 1 < characters.count && characters[i - 1].isLetter && characters[i + 1].isLetter
                            if char.isLetter || char.isNumber || internalMark { exercise.input(char) }
                        }
                        if wordIndex + 1 < exercise.tokens.count { exercise.confirm() }
                    }
                    check(exercise.isItemComplete && exercise.errorCount == 0, "Every imported sentence can be completed without surrounding punctuation: \(isolated.id)")
                    importedItemsVerified += 1
                }
            }
        }
        check(importedItemsVerified == 4319, "All four books' 4319 sentences were verified through the input engine")

        let course = LLSentenceCourse(id: "test-transitions", category: "test", title: "测试", words: [
            .init(en: "I", zh: "我", ipa: nil),
            .init(en: "don't like", zh: "不喜欢", ipa: nil),
            .init(en: "I like the food", zh: "我喜欢这个食物", ipa: nil),
            .init(en: "I", zh: "我", ipa: nil)
        ])
        let source = LLCoursePracticeSource(course: course)
        let session = LLPracticeSession(source: source, showHint: false)
        session.input("i")
        check(session.isItemComplete, "Case-insensitive single word")
        check(LLCourseRepository.shared.progress(for: course.id).completedCount(total: 4) == 0, "Typing alone must not write progress")
        check(session.isMeaningRevealed && session.item?.text == "I", "Correct input reveals the meaning immediately without advancing")
        check(LLCourseRepository.shared.progress(for: course.id).completedCount(total: 4) == 0, "Reviewing the meaning must not write progress")
        session.backspace()
        check(!session.isMeaningRevealed && !session.confirm(), "Editing an answer hides the meaning and requires completing it again")
        session.input("i")
        check(session.isMeaningRevealed, "Correcting an edited answer reveals the meaning again")
        check(session.confirm(), "One confirmation saves the first word")
        check(!session.isMeaningRevealed, "A new item starts with its meaning hidden")
        check(!session.confirm(), "Duplicate confirmation must not skip an untyped item")
        check(session.item?.text == "don't like", "Word and phrase share one session")
        session.input("d"); session.input("x")
        check(session.typedCount == 0 && session.errorCount == 1, "Error resets only current token")
        type("don’t", into: session)
        check(session.isWordComplete && !session.isItemComplete, "Curly apostrophes match straight ones")
        session.confirm()
        session.input("l"); session.input("i"); session.backspace()
        check(session.wordIndex == 1 && session.typedCount == 1, "Backspace preserves completed words")
        session.toggleHint()
        check(session.showHint && session.usedHint, "Answer reveal tracked")
        session.skip()
        check(session.item?.text == "I like the food" && !session.showHint, "Skip advances and resets hint")
        type("I LIKE the food", into: session)
        check(session.isItemComplete && session.errorCount == 0, "Sentence advances token by token")
        check(session.isMeaningRevealed && session.item?.text == "I like the food", "The completed sentence stays in place for meaning review")
        session.confirm()
        let repeatedID = session.item!.id
        check(repeatedID != "course:test-transitions:0", "Repeated content retains its own identity")
        type("I", into: session); session.confirm()
        check(session.isFinished, "Final item ends the round")
        let progress = LLCourseRepository.shared.progress(for: course.id)
        check(progress.completedIndices == Set([0, 2, 3]), "Skip never counts as completion")
        let restored = LLPracticeSession(source: LLCoursePracticeSource(course: course), showHint: false)
        check(restored.item?.text == "don't like", "Reopening resumes uncompleted item")
        type("don't like", into: restored); restored.confirm()
        restored.replay()
        check(restored.item?.text == "I", "Fully completed course can replay from start")
        check(LLCourseRepository.shared.progress(for: course.id).completedCount(total: 4) == 4, "Replay does not inflate completed count")
        var invalid = LLCourseProgress(nextIndex: 999, completedIndices: [-1, 0, 40])
        check(invalid.completedCount(total: 2) == 1 && invalid.resumeIndex(total: 2) == 1, "Invalid cursor and stale indices recover safely")
        invalid.record(index: 500, total: 2, completed: true)
        check(invalid.completedCount(total: 2) == 1, "Out-of-range results are ignored")
        let roundTrip = try JSONDecoder().decode(LLCourseProgress.self, from: JSONEncoder().encode(progress))
        check(roundTrip.completedIndices == progress.completedIndices, "Progress survives serialization")

        let daily = LLDailyLearningManager.shared
        LLSettingsStore.shared.currentListId = "list-A"
        daily.entries = [TestEntry(id: "a", wordListId: "list-A", text: "mother-in-law"), TestEntry(id: "b", wordListId: "list-A", text: "next")]
        let vocabulary = LLPracticeSession(source: LLVocabularyPracticeSource(list: WordList(id: "list-A", name: "词库")), showHint: true)
        LLStatusBarManager.shared.onRefresh = { vocabulary.syncCurrentItem() }
        type("mother-in-law", into: vocabulary)
        vocabulary.confirm(); vocabulary.confirm()
        check(daily.recordedErrors == [0], "One confirmed item writes vocabulary feedback once, even during status bar sync")
        check(vocabulary.item?.text == "next", "Vocabulary uses existing daily queue")
        vocabulary.input("n")
        vocabulary.syncCurrentItem()
        check(vocabulary.typedCount == 1, "Unchanged source sync preserves in-flight input")
        LLSettingsStore.shared.currentListId = "list-B"
        vocabulary.skip()
        check(daily.recordedErrors == [0], "Switching libraries cannot write feedback into the old source")

        let retryCourse = LLSentenceCourse(id: "test-save-retry", category: "", title: "保存重试", words: [.init(en: "a", zh: "一", ipa: nil), .init(en: "b", zh: "二", ipa: nil)])
        let retry = LLPracticeSession(source: LLCoursePracticeSource(course: retryCourse), showHint: false)
        retry.applySettings(showHint: false, autoShowAnswerAfterErrors: 2)
        retry.input("x")
        check(!retry.showHint, "First error below the hint threshold stays hidden")
        retry.input("x")
        check(retry.showHint && retry.usedHint, "Configured error threshold reveals and tracks the hint")
        retry.applySettings(showHint: true, autoShowAnswerAfterErrors: 2)
        retry.applySettings(showHint: false, autoShowAnswerAfterErrors: 2)
        check(!retry.showHint && retry.errorCount == 2, "Dictation setting changes apply without discarding current input state")
        retry.input("a")
        LLMMKVManager.shared.rejectWrites = true
        check(!retry.confirm(), "A failed progress save is not reported as a confirmed item")
        check(retry.item?.text == "a" && retry.isItemComplete && retry.isMeaningRevealed && retry.errorMessage != nil, "Failed save preserves the reviewed answer and provides a retry error")
        check(LLCourseRepository.shared.progress(for: retryCourse.id).completedCount(total: 2) == 0, "Failed save does not change persisted course progress")
        LLMMKVManager.shared.rejectWrites = false
        check(retry.confirm() && retry.item?.text == "b" && retry.errorMessage == nil, "Retry saves the same answer and advances once")
        check(LLCourseRepository.shared.progress(for: retryCourse.id).completedIndices == [0], "Retry records the completed item once")
        retry.applySettings(showHint: false, autoShowAnswerAfterErrors: 999)
        for _ in 0..<5 { retry.input("x") }
        check(!retry.showHint, "The legacy never-show-answer option stays disabled")
        retry.applySettings(showHint: true, autoShowAnswerAfterErrors: 999)
        check(retry.showHint, "Turning dictation off immediately shows the current answer")

        let empty = LLPracticeSession(source: LLCoursePracticeSource(course: .init(id: "empty", category: "", title: "", words: [])), showHint: false)
        empty.input("x"); empty.confirm(); empty.skip()
        check(empty.isFinished, "Empty source is safe")
        print("Passed \(assertions) assertions; decoded 331 lessons, including all 4319 New Concept sentences and 8865 Xingrong exercises.")
    }
}
