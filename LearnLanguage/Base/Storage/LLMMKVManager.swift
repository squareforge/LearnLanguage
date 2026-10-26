//
//  LLMMKVManager.swift
//  LearnLanguage
//
//  MMKV 配置管理器（用于存储轻量级配置和用户偏好）
//

import Foundation
import MMKV

/// MMKV 配置管理器
final class LLMMKVManager {
    
    static let shared = LLMMKVManager()
    
    private var mmkv: MMKV? { MMKV.default() }
    private let storageLock = NSRecursiveLock()

    func withExclusiveStorageAccess<T>(_ operation: () throws -> T) rethrows -> T {
        storageLock.lock()
        defer { storageLock.unlock() }
        return try operation()
    }
    
    private init() {
        // 初始化 MMKV
        MMKV.initialize(rootDir: nil)
        _ = MMKV.default()
        
        LLLogger.info("✅ MMKV 初始化成功")
    }
    
    // MARK: - 通用方法
    
    @discardableResult
    func set<T>(_ value: T, forKey key: String) -> Bool {
        storageLock.lock()
        defer { storageLock.unlock() }
        switch value {
        case let v as Bool:
            return mmkv?.set(v, forKey: key) ?? false
        case let v as Int:
            guard let number = Int32(exactly: v) else { return false }
            return mmkv?.set(number, forKey: key) ?? false
        case let v as Int64:
            return mmkv?.set(v, forKey: key) ?? false
        case let v as Double:
            return mmkv?.set(v, forKey: key) ?? false
        case let v as String:
            return mmkv?.set(v, forKey: key) ?? false
        case let v as Data:
            return mmkv?.set(v, forKey: key) ?? false
        default:
            LLLogger.warn("⚠️ MMKV 不支持的类型：\(type(of: value))")
            return false
        }
    }
    
    func bool(forKey key: String, defaultValue: Bool = false) -> Bool {
        storageLock.lock(); defer { storageLock.unlock() }
        return mmkv?.bool(forKey: key, defaultValue: defaultValue) ?? defaultValue
    }
    
    func int(forKey key: String, defaultValue: Int = 0) -> Int {
        storageLock.lock(); defer { storageLock.unlock() }
        return Int(mmkv?.int32(forKey: key, defaultValue: Int32(clamping: defaultValue)) ?? Int32(clamping: defaultValue))
    }
    
    func int64(forKey key: String, defaultValue: Int64 = 0) -> Int64 {
        storageLock.lock(); defer { storageLock.unlock() }
        return mmkv?.int64(forKey: key, defaultValue: defaultValue) ?? defaultValue
    }
    
    func double(forKey key: String, defaultValue: Double = 0.0) -> Double {
        storageLock.lock(); defer { storageLock.unlock() }
        return mmkv?.double(forKey: key, defaultValue: defaultValue) ?? defaultValue
    }
    
    func string(forKey key: String, defaultValue: String = "") -> String {
        storageLock.lock(); defer { storageLock.unlock() }
        return mmkv?.string(forKey: key) ?? defaultValue
    }
    
    func data(forKey key: String) -> Data? {
        storageLock.lock(); defer { storageLock.unlock() }
        return mmkv?.data(forKey: key)
    }
    
    func remove(forKey key: String) {
        storageLock.lock(); defer { storageLock.unlock() }
        mmkv?.removeValue(forKey: key)
    }
    
    func clearAll() {
        storageLock.lock(); defer { storageLock.unlock() }
        mmkv?.clearAll()
        LLLogger.info("🗑️ MMKV 所有数据已清空")
    }
    
    func allKeys() -> [String] {
        storageLock.lock(); defer { storageLock.unlock() }
        return mmkv?.allKeys() as? [String] ?? []
    }
}



// MARK: - 便捷访问方法

extension LLMMKVManager {
    
    // MARK: - UI 设置
    
    /// 主题模式（auto/light/dark）
    var themeMode: String {
        get { string(forKey: LLMMKVKeys.themeMode, defaultValue: "auto") }
        set { set(newValue, forKey: LLMMKVKeys.themeMode) }
    }
    
    /// 字体大小
    var fontSize: Double {
        get { double(forKey: LLMMKVKeys.fontSize, defaultValue: 14.0) }
        set { set(newValue, forKey: LLMMKVKeys.fontSize) }
    }
    
    /// 侧边栏是否展开
    var sidebarExpanded: Bool {
        get { bool(forKey: LLMMKVKeys.sidebarExpanded, defaultValue: true) }
        set { set(newValue, forKey: LLMMKVKeys.sidebarExpanded) }
    }
    
    /// 侧边栏宽度
    var sidebarWidth: Double {
        get { double(forKey: LLMMKVKeys.sidebarWidth, defaultValue: 250.0) }
        set { set(newValue, forKey: LLMMKVKeys.sidebarWidth) }
    }
    
    /// 窗口位置和大小（NSRect 转 Data 存储）
    var windowFrame: NSRect? {
        get {
            guard let data = data(forKey: LLMMKVKeys.windowFrame) else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: data)?.rectValue
        }
        set {
            if let rect = newValue {
                let value = NSValue(rect: rect)
                if let data = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true) {
                    set(data, forKey: LLMMKVKeys.windowFrame)
                }
            } else {
                remove(forKey: LLMMKVKeys.windowFrame)
            }
        }
    }
    
    // MARK: - 学习设置
    
    /// 当前选中的词库 ID
    var currentListId: String? {
        get {
            let value = string(forKey: LLMMKVKeys.currentListId)
            return value.isEmpty ? nil : value
        }
        set {
            if let value = newValue {
                set(value, forKey: LLMMKVKeys.currentListId)
            } else {
                remove(forKey: LLMMKVKeys.currentListId)
            }
        }
    }
    
    /// 是否处于打字练习模式
    var isTypingPracticeMode: Bool {
        get { bool(forKey: LLMMKVKeys.isTypingPracticeMode, defaultValue: false) }
        set { set(newValue, forKey: LLMMKVKeys.isTypingPracticeMode) }
    }
    
    /// 每日学习目标（单词数）
    var dailyGoal: Int {
        get { int(forKey: LLMMKVKeys.dailyGoal, defaultValue: 50) }
        set { set(newValue, forKey: LLMMKVKeys.dailyGoal) }
    }
    
    /// 是否自动播放音频
    var autoPlayAudio: Bool {
        get { bool(forKey: LLMMKVKeys.autoPlayAudio, defaultValue: false) }
        set { set(newValue, forKey: LLMMKVKeys.autoPlayAudio) }
    }
    
    /// 复习间隔（小时）
    var reviewInterval: Int {
        get { int(forKey: LLMMKVKeys.reviewInterval, defaultValue: 24) }
        set { set(newValue, forKey: LLMMKVKeys.reviewInterval) }
    }
    
    // MARK: - 显示设置
    
    /// 状态栏是否显示音标
    var statusBarShowPhonetic: Bool {
        get { bool(forKey: LLMMKVKeys.statusBarShowPhonetic, defaultValue: true) }
        set { set(newValue, forKey: LLMMKVKeys.statusBarShowPhonetic) }
    }
    
    /// 状态栏是否显示释义
    var statusBarShowMeaning: Bool {
        get { bool(forKey: LLMMKVKeys.statusBarShowMeaning, defaultValue: false) }
        set { set(newValue, forKey: LLMMKVKeys.statusBarShowMeaning) }
    }
    
    /// 状态栏最大显示长度
    var statusBarMaxLength: Int {
        get { int(forKey: LLMMKVKeys.statusBarMaxLength, defaultValue: 20) }
        set { set(newValue, forKey: LLMMKVKeys.statusBarMaxLength) }
    }
    
    /// 浮动窗口透明度
    var floatingPanelAlpha: Double {
        get { double(forKey: LLMMKVKeys.floatingPanelAlpha, defaultValue: 0.95) }
        set { set(newValue, forKey: LLMMKVKeys.floatingPanelAlpha) }
    }
    
    /// 是否显示反馈按钮
    var showFeedbackButtons: Bool {
        get { bool(forKey: LLMMKVKeys.showFeedbackButtons, defaultValue: true) }
        set { set(newValue, forKey: LLMMKVKeys.showFeedbackButtons) }
    }
    
    // MARK: - 导入相关
    
    /// 是否已导入词库列表
    var hasImportedWordLists: Bool {
        get { bool(forKey: LLMMKVKeys.hasImportedWordLists, defaultValue: false) }
        set { set(newValue, forKey: LLMMKVKeys.hasImportedWordLists) }
    }
    
    /// 最后导入时间
    var lastImportTime: Date? {
        get {
            let timestamp = double(forKey: LLMMKVKeys.lastImportTime)
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set {
            if let date = newValue {
                set(date.timeIntervalSince1970, forKey: LLMMKVKeys.lastImportTime)
            } else {
                remove(forKey: LLMMKVKeys.lastImportTime)
            }
        }
    }
    
    /// 最后导入的版本号
    var lastImportVersion: String? {
        get {
            let value = string(forKey: LLMMKVKeys.lastImportVersion)
            return value.isEmpty ? nil : value
        }
        set {
            if let value = newValue {
                set(value, forKey: LLMMKVKeys.lastImportVersion)
            } else {
                remove(forKey: LLMMKVKeys.lastImportVersion)
            }
        }
    }
    
    // MARK: - 统计相关
    
    /// 总学习单词数
    var totalLearnedWords: Int {
        get { int(forKey: LLMMKVKeys.totalLearnedWords, defaultValue: 0) }
        set { set(newValue, forKey: LLMMKVKeys.totalLearnedWords) }
    }
    
    /// 总学习时长（秒）
    var totalStudyTime: Int64 {
        get { int64(forKey: LLMMKVKeys.totalStudyTime, defaultValue: 0) }
        set { set(newValue, forKey: LLMMKVKeys.totalStudyTime) }
    }
    
    /// 连续学习天数
    var continuousStudyDays: Int {
        get { int(forKey: LLMMKVKeys.continuousStudyDays, defaultValue: 0) }
        set { set(newValue, forKey: LLMMKVKeys.continuousStudyDays) }
    }
    
    /// 最后学习日期
    var lastStudyDate: Date? {
        get {
            let timestamp = double(forKey: LLMMKVKeys.lastStudyDate)
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set {
            if let date = newValue {
                set(date.timeIntervalSince1970, forKey: LLMMKVKeys.lastStudyDate)
            } else {
                remove(forKey: LLMMKVKeys.lastStudyDate)
            }
        }
    }
    
    // MARK: - 其他
    
    /// 是否已经启动过应用
    var hasLaunched: Bool {
        get { bool(forKey: LLMMKVKeys.hasLaunched, defaultValue: false) }
        set { set(newValue, forKey: LLMMKVKeys.hasLaunched) }
    }
    
    /// 首次启动日期
    var firstLaunchDate: Date? {
        get {
            let timestamp = double(forKey: LLMMKVKeys.firstLaunchDate)
            if timestamp > 0 {
                return Date(timeIntervalSince1970: timestamp)
            } else {
                // 首次启动，记录当前时间
                let now = Date()
                self.firstLaunchDate = now
                return now
            }
        }
        set {
            if let date = newValue {
                set(date.timeIntervalSince1970, forKey: LLMMKVKeys.firstLaunchDate)
            }
        }
    }
    
    /// 应用版本号
    var appVersion: String {
        get { string(forKey: LLMMKVKeys.appVersion, defaultValue: "1.0.0") }
        set { set(newValue, forKey: LLMMKVKeys.appVersion) }
    }
    
    /// 用户语言
    var userLanguage: String {
        get { string(forKey: LLMMKVKeys.userLanguage, defaultValue: "zh-Hans") }
        set { set(newValue, forKey: LLMMKVKeys.userLanguage) }
    }
}

// MARK: - 调试方法

extension LLMMKVManager {
    
    /// 打印所有配置（用于调试）
    func printAllConfigs() {
        storageLock.lock(); defer { storageLock.unlock() }
        LLLogger.debug("\n" + String(repeating: "=", count: 60))
        LLLogger.debug("📋 MMKV 所有配置：")
        LLLogger.debug(String(repeating: "=", count: 60))
        
        let keys = allKeys().sorted()
        for key in keys {
            if let value = mmkv?.object(of: NSObject.self, forKey: key) {
                LLLogger.debug("  \(key): \(value)")
            }
        }
        
        LLLogger.debug(String(repeating: "=", count: 60) + "\n")
    }
    
    /// 导出配置为字典（用于备份）
    func exportConfigs() -> [String: Any] {
        storageLock.lock(); defer { storageLock.unlock() }
        var configs: [String: Any] = [:]
        
        for key in allKeys() {
            if let value = mmkv?.object(of: NSObject.self, forKey: key) {
                configs[key] = value
            }
        }
        
        return configs
    }
}

