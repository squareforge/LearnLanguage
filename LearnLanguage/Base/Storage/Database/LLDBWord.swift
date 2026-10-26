//
//  LLDBWord.swift
//  LearnLanguage
//
//  单词表模型（WCDB）
//

import Foundation
import WCDBSwift

/// 单词表模型
final class LLDBWord: TableCodable {
    
    var id: Int? = nil                      // 自增ID
    var wordListId: Int = 0                 // 所属词库ID（关联 DBWordList.id）
    var word: String = ""                   // 单词原文（如 "apple"）
    var translation: String = ""                // 释义
    var usPhonetic: String? = nil           // 美式音标
    var ukPhonetic: String? = nil           // 英式音标
    
    // 学习状态
    var isLearned: Bool = false             // 是否已学习
    var reviewCount: Int = 0                // 复习次数
    var correctCount: Int = 0               // 正确次数
    var wrongCount: Int = 0                 // 错误次数
    
    // 时间字段
    var masteryLevel: Int = 0                 // 错误次数
    var lastReviewedAt: TimeInterval? = nil // 最近复习时间
    var nextReviewAt: TimeInterval? = nil   // 下次复习时间
    var createdAt: TimeInterval = 0         // 创建时间
    
    
    // WCDB 必需的属性
    var isAutoIncrement: Bool { id == nil }
    var lastInsertedRowID: Int64 {
        get { Int64(id ?? 0) }
        set { id = Int(exactly: newValue) }
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = LLDBWord
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case id
        case wordListId = "word_list_id"
        case word
        case translation
        case usPhonetic = "us_phonetic"
        case ukPhonetic = "uk_phonetic"
        case isLearned = "is_learned"
        case reviewCount = "review_count"
        case correctCount = "correct_count"
        case wrongCount = "wrong_count"
        case masteryLevel = "mastery_level"
        case lastReviewedAt = "last_reviewed_at"
        case nextReviewAt = "next_review_at"
        case createdAt = "created_at"
        
        // 配置主键和索引
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                .id: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true)
            ]
        }
        
        // 配置索引
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_word_list": IndexBinding(indexesBy: wordListId),
                "_word": IndexBinding(indexesBy: word),
                "_learned": IndexBinding(indexesBy: isLearned),
                "_next_review": IndexBinding(indexesBy: nextReviewAt)
            ]
        }
    }
    
    // 便利初始化方法
    init(wordListId: Int,
         word: String,
         translation: String,
         usPhonetic: String? = nil,
         ukPhonetic: String? = nil) {
        
        self.wordListId = wordListId
        self.word = word
        self.translation = translation
        self.usPhonetic = usPhonetic
        self.ukPhonetic = ukPhonetic
        self.createdAt = Date().timeIntervalSince1970
    }
    
    // 计算准确率
    var accuracy: Double {
        let total = correctCount + wrongCount
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total) * 100
    }
}

