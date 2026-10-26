//
//  LLDBLearningHistory.swift
//  LearnLanguage
//
//  学习明细记录表模型（每次学习一条，不更新只插入）
//

import Foundation
import WCDBSwift

/// 学习明细记录表 - 记录每一次学习事件
final class LLDBLearningHistory: TableCodable {
    
    var id: Int? = nil                      // 自增ID
    var wordId: String? = nil               // 单词ID
    var wordListId: String? = nil           // 词库ID
    var feedback: String? = nil             // 本次反馈：know/unclear/unknown
    var sessionType: String? = nil          // 学习类型：learn=新学, review=复习
    var learnedAt: TimeInterval? = nil      // 本次学习时间戳
    
    var isAutoIncrement: Bool { id == nil }
    var lastInsertedRowID: Int64 {
        get { Int64(id ?? 0) }
        set { id = Int(exactly: newValue) }
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = LLDBLearningHistory
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        static var tableName: String { "learning_history" }
        
        case id
        case wordId = "word_id"
        case wordListId = "word_list_id"
        case feedback
        case sessionType = "session_type"
        case learnedAt = "learned_at"
        
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [.id: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true)]
        }
        
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_word_list": IndexBinding(indexesBy: wordId, wordListId),
                "_learned_at": IndexBinding(indexesBy: learnedAt),
                "_list_date": IndexBinding(indexesBy: wordListId, learnedAt)
            ]
        }
    }
    
    init(wordId: String, wordListId: String, feedback: String, sessionType: String = "learn") {
        self.wordId = wordId
        self.wordListId = wordListId
        self.feedback = feedback
        self.sessionType = sessionType
        self.learnedAt = Date().timeIntervalSince1970
    }
}
