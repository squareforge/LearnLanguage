//
//  LLDBLearningProgress.swift
//  LearnLanguage
//
//  学习进度记录表模型（WCDB）
//

import Foundation
import WCDBSwift

/// 学习进度记录表模型
final class LLDBLearningProgress: TableCodable {
    
    var id: Int? = nil                      // 自增ID
    var wordId: String? = nil               // 单词ID
    var wordListId: String? = nil           // 词库ID
    
    // 学习状态
    var status: Int? = nil                  // 学习状态：0=未学习, 1=学习中, 2=已掌握
    var lastFeedback: String? = nil         // 最后一次反馈：know/unclear/unknown
    
    // 学习统计
    var learnCount: Int? = nil              // 学习次数
    var correctCount: Int? = nil            // 标记为"认识"的次数
    var unclearCount: Int? = nil            // 标记为"模糊"的次数
    var wrongCount: Int? = nil              // 标记为"不认识"的次数
    
    // 时间记录
    var firstSeenAt: TimeInterval? = nil    // 首次学习时间
    var lastSeenAt: TimeInterval? = nil     // 最后学习时间
    
    // 打字练习相关
    var typingPracticeCount: Int? = nil     // 打字练习次数
    var lastTypingAt: TimeInterval? = nil   // 最后打字练习时间
    
    // 复习调度相关（SM-2算法）
    var nextReviewAt: TimeInterval? = nil   // 下次复习时间
    var reviewCount: Int? = nil             // 已复习次数
    var easeFactor: Double? = 1.3           // 难度系数（初始1.3）
    var interval: Int? = 1                  // 当前复习间隔（天数）
    var lastReviewAt: TimeInterval? = nil   // 上次复习时间
    
    // 时间字段
    var createdAt: TimeInterval? = nil      // 创建时间
    var updatedAt: TimeInterval? = nil      // 更新时间
    
    // WCDB 必需的属性
    var isAutoIncrement: Bool { id == nil }
    var lastInsertedRowID: Int64 {
        get { Int64(id ?? 0) }
        set { id = Int(exactly: newValue) }
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = LLDBLearningProgress
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        // 自定义表名
        static var tableName: String {
            return "learning_progress"
        }
        
        case id
        case wordId = "word_id"
        case wordListId = "word_list_id"
        case status
        case lastFeedback = "last_feedback"
        case learnCount = "learn_count"
        case correctCount = "correct_count"
        case unclearCount = "unclear_count"
        case wrongCount = "wrong_count"
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
        case typingPracticeCount = "typing_practice_count"
        case lastTypingAt = "last_typing_at"
        case nextReviewAt = "next_review_at"
        case reviewCount = "review_count"
        case easeFactor = "ease_factor"
        case interval
        case lastReviewAt = "last_review_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        
        // 配置主键和索引
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                .id: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true)
            ]
        }
        
        // 配置索引
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_word_list": IndexBinding(indexesBy: wordId, wordListId),
                "_list": IndexBinding(indexesBy: wordListId),
                "_status": IndexBinding(indexesBy: status),
                "_last_seen": IndexBinding(indexesBy: lastSeenAt),
                "_next_review": IndexBinding(indexesBy: nextReviewAt)
            ]
        }
        
        // 配置唯一约束（同一个词库的同一个单词只能有一条记录）
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return [
                "unique_word_list": MultiUniqueBinding(indexesBy: wordId, wordListId)
            ]
        }
    }
    
    // 便利初始化方法
    init(wordId: String,
         wordListId: String,
         feedback: String) {
        
        let now = Date().timeIntervalSince1970
        self.wordId = wordId
        self.wordListId = wordListId
        self.lastFeedback = feedback
        self.learnCount = 1
        
        // 根据反馈设置状态和计数
        switch feedback {
        case "know":
            self.status = 1  // 学习中，累计 4 次认识后才算掌握
            self.correctCount = 1
            self.reviewCount = 1
        case "unclear":
            self.status = 1  // 学习中
            self.unclearCount = 1
            self.reviewCount = 0
        case "unknown":
            self.status = 1  // 学习中
            self.wrongCount = 1
            self.reviewCount = 0
        default:
            self.status = 0
            self.reviewCount = 0
        }
        
        self.firstSeenAt = now
        self.lastSeenAt = now
        self.createdAt = now
        self.updatedAt = now
        
        // 初始化复习调度字段
        self.easeFactor = 1.3
        self.interval = 1
        self.nextReviewAt = now + 86400  // 默认明天复习
    }
}
