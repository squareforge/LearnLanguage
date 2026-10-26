//
//  LLDBWordListCategory.swift
//  LearnLanguage
//
//  词库分类表模型（WCDB）
//

import Foundation
import WCDBSwift

/// 词库分类表模型
final class LLDBWordListCategory: TableCodable {
    
    var id: Int? = nil                      // 自增ID
    var name: String = ""                   // 分类名称（如：中国考试）
    var description: String? = nil          // 分类描述
    var icon: String? = nil                 // 图标名称
    var color: String? = nil                // 文本颜色
    var sortOrder: Int? = nil              // 是否启用
    var createdAt: TimeInterval = 0        // 创建时间
    
    // WCDB 必需的属性
    var isAutoIncrement: Bool { id == nil }
    var lastInsertedRowID: Int64 {
        get { Int64(id ?? 0) }
        set { id = Int(exactly: newValue) }
    }

    enum CodingKeys: String, CodingTableKey {
        typealias Root = LLDBWordListCategory
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case id
        case name
        case description
        case icon
        case color
        case sortOrder = "sort_order"
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
                "_sort": IndexBinding(indexesBy: sortOrder)
            ]
        }
    }
    
    // 便利初始化方法
    init(name: String,
         description: String? = nil,
         icon: String? = nil,
         color: String? = nil,
         sortOrder: Int? = nil) {
        
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.sortOrder = sortOrder
        self.createdAt = Date().timeIntervalSince1970
    }
}

