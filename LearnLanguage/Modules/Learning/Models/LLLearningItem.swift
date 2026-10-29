import Foundation

/// A practice item is independent of the library, course, window, and storage that supply it.
struct LLLearningItem: Equatable {
    enum Kind { case word, phrase, sentence }
    let id: String
    let text: String
    let meaning: String
    let phonetic: String?
    let example: String?
    let kind: Kind
}

struct LLPracticeResult {
    let itemID: String
    let errorCount: Int
    let usedHint: Bool
    let skipped: Bool
}

/// Sources own ordering and progress. The shared session owns only input and feedback.
protocol LLPracticeSource: AnyObject {
    var id: String { get }
    var title: String { get }
    var positionText: String { get }
    var currentItem: LLLearningItem? { get }
    var errorMessage: String? { get }
    func advance(result: LLPracticeResult) throws
    func replay()
}

extension LLPracticeSource {
    var errorMessage: String? { nil }
}

struct LLSentenceCourse: Decodable, Identifiable {
    struct Item: Decodable {
        let en: String
        let zh: String
        let ipa: String?
    }
    let id: String
    let category: String
    let title: String
    let words: [Item]
    var collectionID: String? = nil
    var collectionTitle: String? = nil
    var sourceTitle: String { collectionTitle ?? "星荣句式" }

    var preview: String {
        words.first(where: { $0.en.split(separator: " ").count >= 4 })?.en ?? words.first?.en ?? ""
    }
}

struct LLCourseCollection: Decodable, Identifiable {
    let id: String
    let title: String
    let courses: [LLSentenceCourse]
}

struct LLCourseProgress: Codable {
    var nextIndex = 0
    var completedIndices: Set<Int> = []
    var updatedAt = Date.distantPast

    func completedCount(total: Int) -> Int {
        completedIndices.filter { (0..<total).contains($0) }.count
    }

    func resumeIndex(total: Int) -> Int {
        guard total > 0 else { return 0 }
        if completedCount(total: total) == total { return 0 }
        if (0..<total).contains(nextIndex), !completedIndices.contains(nextIndex) { return nextIndex }
        return (0..<total).first(where: { !completedIndices.contains($0) }) ?? 0
    }

    mutating func record(index: Int, total: Int, completed: Bool) {
        guard (0..<total).contains(index) else { return }
        if completed { completedIndices.insert(index) }
        nextIndex = index + 1
        updatedAt = Date()
    }
}
