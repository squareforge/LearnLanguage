import Foundation
import WCDBSwift
import MMKV

@main
struct StorageIntegrationTests {
    static var assertions = 0
    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) rethrows {
        assertions += 1
        if try !condition() { fatalError(message) }
    }
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let settingsRoot = root.appendingPathComponent("mmkv-live", isDirectory: true)
        MMKV.initialize(rootDir: settingsRoot.path)
        defer { MMKV.default()?.close() }
        var settings = LLAppSettings.default
        settings.newWordsPerDay = -1
        LLSettingsStore.shared.settings = settings
        check(LLSettingsStore.shared.settings.newWordsPerDay == 1, "Invalid settings are clamped on save")
        let invalid = try JSONEncoder().encode(settings)
        MMKV.default()!.set(invalid, forKey: "LearnLanguage.LLAppSettings")
        check(LLSettingsStore.shared.settings.newWordsPerDay == 1, "Invalid persisted settings are clamped on read")
        settings.pronunciationRate = 2
        LLSettingsStore.shared.settings = settings
        check(LLSettingsStore.shared.settings.pronunciationRate == 2, "The supported 2x speech setting survives validation")
        settings.newWordsPerDay = 7
        LLSettingsStore.shared.settings = settings
        LLMMKVManager.shared.set(Data("course-before".utf8), forKey: "course-test")
        let snapshot = root.appendingPathComponent("mmkv-backup", isDirectory: true)
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        check(MMKV.backup(mmapID: "mmkv.default", rootPath: settingsRoot.path, dstDir: snapshot.path), "Actual MMKV snapshot succeeds")
        settings.newWordsPerDay = 99
        LLSettingsStore.shared.settings = settings
        LLMMKVManager.shared.set(Data("course-after".utf8), forKey: "course-test")
        try LLMMKVManager.shared.withExclusiveStorageAccess {
            MMKV.default()?.close()
            defer { _ = MMKV.default() }
            try LLFileReplacementTransaction.install([
                "mmkv.default": snapshot.appendingPathComponent("mmkv.default"),
                "mmkv.default.crc": snapshot.appendingPathComponent("mmkv.default.crc")
            ], in: settingsRoot, managedPaths: ["mmkv.default","mmkv.default.crc"])
        }
        check(LLSettingsStore.shared.settings.newWordsPerDay == 7, "Settings read the restored MMKV instead of an old mapping")
        check(LLMMKVManager.shared.data(forKey: "course-test") == Data("course-before".utf8), "Course data and settings restore together")

        let url = root.appendingPathComponent("integration.db")
        let database = LLDatabaseManager(path: url.path)
        database.openDatabase()
        defer { database.closeDatabase() }
        let a = LLDBWordList(categoryId: 1, name: "queue-A")
        let b = LLDBWordList(categoryId: 1, name: "queue-B")
        let aID = try database.insertWordList(a)
        let bID = try database.insertWordList(b)
        check(aID > 0 && bID > aID && a.id != nil, "Actual WCDB inserts populate generated primary keys")
        let aWord = LLDBWord(wordListId: Int(aID), word: "a-due", translation: "a")
        let bWord = LLDBWord(wordListId: Int(bID), word: "b-new", translation: "b")
        let bNext = LLDBWord(wordListId: Int(bID), word: "b-next", translation: "b next")
        let tomorrowWord = LLDBWord(wordListId: Int(bID), word: "b-tomorrow", translation: "tomorrow")
        try database.insertWords([aWord,bWord,bNext,tomorrowWord])
        check(aWord.id != nil && bWord.id != nil, "Word IDs are assigned by WCDB")
        func entry(_ word: LLDBWord) -> LLWordEntry {
            LLWordEntry(id: String(word.id!), wordListId: String(word.wordListId), text: word.word, meaning: word.translation, language: .english)
        }
        let listA = WordList(id: String(aID), name: "A", language: .english, entries: [entry(aWord)])
        let listB = WordList(id: String(bID), name: "B", language: .english, entries: [entry(bWord),entry(bNext),entry(tomorrowWord)])
        var date = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        let due = LLDBLearningProgress(wordId: String(aWord.id!), wordListId: listA.id, feedback: "know")
        due.createdAt = yesterday.timeIntervalSince1970
        due.nextReviewAt = date.timeIntervalSince1970
        let future = LLDBLearningProgress(wordId: String(tomorrowWord.id!), wordListId: listB.id, feedback: "know")
        future.createdAt = yesterday.timeIntervalSince1970
        future.nextReviewAt = tomorrow.timeIntervalSince1970
        try database.database.insert(objects: [due,future], intoTable: "learning_progress")
        var goal = 1
        let daily = LLDailyLearningManager(database: database, loadList: { $0 == listA.id ? listA : listB }, goal: { goal }, now: { date })
        daily.setup(listId: listB.id)
        check(daily.nextWord()?.id == String(bWord.id!), "Another library's due words cannot block this library")
        check(daily.reviewQueueCount == 0 && daily.newWordQueueCount == 1, "Only current library and goal are loaded")
        try check(database.getTodayNewWords(wordListId: listB.id, wordList: listB, limit: -1).isEmpty, "Negative limits are safe at repository boundary")
        let sql = try LLSQLiteConnection(url: url)
        try sql.execute("CREATE TRIGGER reject_history BEFORE INSERT ON learning_history BEGIN SELECT RAISE(ABORT,'injected history failure'); END")
        check(!daily.recordTypingResult(entry: entry(bWord), errorCount: 0), "A history write failure is returned to the caller")
        check(daily.nextWord()?.id == String(bWord.id!), "A failed write does not advance the queue")
        try check(database.getLearningProgress(wordId: String(bWord.id!), wordListId: listB.id) == nil, "Progress insert rolls back when history fails")
        try check(database.getAllLearningHistory(wordListId: listB.id).isEmpty, "Failed attempt leaves no history")
        try sql.execute("DROP TRIGGER reject_history")
        for _ in 0..<4 { check(daily.recordTypingResult(entry: entry(bWord), errorCount: 0), "Retry commits successfully") }
        let progress = try database.getLearningProgress(wordId: String(bWord.id!), wordListId: listB.id)
        check(progress?.learnCount == 4 && progress?.typingPracticeCount == 4 && progress?.reviewCount == 4, "Feedback and typing counts commit together once per attempt")
        try check(database.getAllLearningHistory(wordListId: listB.id).count == 4, "Each successful attempt has exactly one history entry")
        daily.setup(listId: listA.id)
        daily.setup(listId: listB.id)
        check(daily.nextWord() == nil, "Switching back does not refill an already reached daily goal")
        goal = 2
        daily.setup(listId: listB.id)
        check(daily.nextWord()?.id == String(bNext.id!), "Changing the daily goal refreshes the queue")
        date = tomorrow
        check(daily.nextWord()?.id == String(tomorrowWord.id!), "A resident app rebuilds the same library's queue across midnight")

        let pageList = LLDBWordList(categoryId: 1, name: "pages")
        let pageID = try database.insertWordList(pageList)
        let pageRecords = (0..<25).map { LLDBLearningProgress(wordId: "page-\($0)", wordListId: String(pageID), feedback: "know") }
        try database.database.insert(objects: pageRecords, intoTable: "learning_progress")
        let first = try database.getReviewRecords(wordListId: String(pageID), limit: 20, offset: 0)
        let second = try database.getReviewRecords(wordListId: String(pageID), limit: 20, offset: 20)
        check(first.count == 20 && second.count == 5, "SQL pagination reaches records after the twentieth")
        check(Set(first.compactMap(\.id)).isDisjoint(with: Set(second.compactMap(\.id))), "Stable SQL ordering produces disjoint pages")
        let pageWords = try database.getWords(ids: [aWord.id!,bWord.id!])
        check(pageWords.count == 2 && Set(pageWords.map(\.word)) == ["a-due", "b-new"], "Record pages fetch only their requested words across libraries")

        let dbSnapshot = root.appendingPathComponent("wcdb-snapshot.db")
        try LLSQLiteConnection.snapshot(from: url, to: dbSnapshot)
        try LLSQLiteConnection.validateDatabase(at: dbSnapshot)
        let snapshotConnection = try LLSQLiteConnection(url: dbSnapshot, readOnly: true)
        try check(snapshotConnection.query("SELECT learn_count FROM learning_progress WHERE word_id=?", arguments: [String(bWord.id!)]).first?["learn_count"] == "4", "A real WCDB WAL snapshot includes committed learning records")
        enum InjectedFailure: Swift.Error { case validation }
        let managed: Set<String> = ["integration.db", "integration.db-wal", "integration.db-shm"]
        do {
            try database.database.close(onClosed: {
                try LLFileReplacementTransaction.install(["integration.db":dbSnapshot], in: root, managedPaths: managed) { throw InjectedFailure.validation }
            })
            fatalError("Replacement should fail at injected validation")
        } catch InjectedFailure.validation {}
        try check(database.getLearningProgress(wordId: String(bWord.id!), wordListId: listB.id)?.learnCount == 4, "WCDB reopens the rolled-back original after replacement fails")
        try database.database.close(onClosed: {
            try LLFileReplacementTransaction.install(["integration.db":dbSnapshot], in: root, managedPaths: managed)
        })
        database.reopenDatabase()
        try check(database.getLearningProgress(wordId: String(bWord.id!), wordListId: listB.id)?.typingPracticeCount == 4, "WCDB sees the committed restored file and its typing counts")
        print("Passed \(assertions) integration checks with actual WCDB and MMKV.")
    }
}
