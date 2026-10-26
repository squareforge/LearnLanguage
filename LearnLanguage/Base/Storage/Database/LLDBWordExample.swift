//
//  LLDBWordExample.swift
//  LearnLanguage
//
//  单词例句表模型（WCDB）
//

import Foundation
import WCDBSwift

/// 全局例句库，按规范化后的单词拼写关联 words.word。
final class LLDBWordExample: TableCodable {

    var id: Int? = nil
    var wordText: String = ""
    var sentenceEn: String = ""
    var sentenceCn: String? = nil
    var heat: Int = 0
    var difficultyLevel: Int = 0
    var source: String? = nil
    var createdAt: TimeInterval = 0

    var isAutoIncrement: Bool { id == nil }
    var lastInsertedRowID: Int64 {
        get { Int64(id ?? 0) }
        set { id = Int(exactly: newValue) }
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = LLDBWordExample
        static let objectRelationalMapping = TableBinding(CodingKeys.self)

        case id
        case wordText = "word_text"
        case sentenceEn = "sentence_en"
        case sentenceCn = "sentence_cn"
        case heat
        case difficultyLevel = "difficulty_level"
        case source
        case createdAt = "created_at"

        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            [
                .id: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true)
            ]
        }

        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            [
                "_word_text": IndexBinding(indexesBy: wordText),
                "_word_level": IndexBinding(indexesBy: wordText, difficultyLevel),
                "_heat": IndexBinding(indexesBy: heat)
            ]
        }
    }

    init(
        wordText: String,
        sentenceEn: String,
        sentenceCn: String?,
        heat: Int = 0,
        difficultyLevel: Int = 0,
        source: String? = nil
    ) {
        self.wordText = wordText
        self.sentenceEn = sentenceEn
        self.sentenceCn = sentenceCn
        self.heat = heat
        self.difficultyLevel = difficultyLevel
        self.source = source
        self.createdAt = Date().timeIntervalSince1970
    }
}
