//
//  LLDBWordList.swift
//  LearnLanguage
//
//  词库表模型（WCDB）
//

import Foundation
import WCDBSwift

/// 词库表模型
final class LLDBWordList: TableCodable {
    
    var id: Int? = nil                      // 自增ID
    var categoryId: Int? = nil              // 分类ID
    var name: String = ""                   // 词库名称
    var description: String? = nil          // 描述
    
    // 统计字段
    var totalWords: Int = 0                 // 总单词数
    var learnedWords: Int = 0               // 已学单词数
    
    // 标记字段
    var isFavorite: Bool = false            // 是否收藏
    
    // 时间字段
    var createdAt: TimeInterval = 0         // 创建时间
    var updatedAt: TimeInterval = 0         // 更新时间
    
    // WCDB 必需的属性
    var isAutoIncrement: Bool { id == nil }
    var lastInsertedRowID: Int64 {
        get { Int64(id ?? 0) }
        set { id = Int(exactly: newValue) }
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = LLDBWordList
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case id
        case categoryId = "category_id"
        case name
        case description
        case totalWords = "total_words"
        case learnedWords = "learned_words"
        case isFavorite = "is_favorite"
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
                "_category": IndexBinding(indexesBy: categoryId),
                "_favorite": IndexBinding(indexesBy: isFavorite)
            ]
        }
    }
    
    // 便利初始化方法
    init(categoryId: Int? = nil,
         name: String,
         description: String? = nil) {
        
        let now = Date().timeIntervalSince1970
        self.categoryId = categoryId
        self.name = name
        self.description = description
        self.createdAt = now
        self.updatedAt = now
    }
    
    // 计算进度百分比
    var progress: Double {
        guard totalWords > 0 else { return 0 }
        return Double(learnedWords) / Double(totalWords) * 100
    }
    

}

