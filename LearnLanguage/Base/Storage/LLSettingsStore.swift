//
//  LLSettingsStore.swift
//  LearnLanguage
//

import Foundation
import MMKV

/// 设置本地存储（MMKV）
final class LLSettingsStore {
    static let shared = LLSettingsStore()
    private let key = "LearnLanguage.LLAppSettings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        // 初始化 MMKV
        MMKV.initialize(rootDir: nil)
        // 使用默认实例
        _ = MMKV.default()
    }

    var settings: LLAppSettings {
        get {
            guard let data = LLMMKVManager.shared.data(forKey: key),
                  let s = try? decoder.decode(LLAppSettings.self, from: data) else { return .default }
            return s.validated()
        }
        set {
            guard let data = try? encoder.encode(newValue.validated()) else { return }
            LLMMKVManager.shared.set(data, forKey: key)
        }
    }

    var currentLanguage: LLLearningLanguage {
        get { settings.currentLanguage }
        set { var s = settings; s.currentLanguage = newValue; settings = s }
    }

    var currentListId: String? {
        get { settings.currentListId }
        set { 
            var s = settings
            s.currentListId = newValue
            settings = s
            // 发送通知，让界面更新
            NotificationCenter.default.post(name: .learnLanguageCurrentListChanged, object: nil)
            NotificationCenter.default.post(name: .currentWordListChanged, object: nil)
        }
    }
    
    /// 获取当前正在学习的词库
    var currentWordList: WordList? {
        guard let listId = currentListId else { return nil }
        return LLWordListStorage.shared.list(byId: listId)
    }
    
    /// 获取当前词库的学习进度
    func getCurrentListProgress() -> (learned: Int, total: Int, percentage: Double) {
        guard let list = currentWordList else { return (0, 0, 0) }
        let total = list.entryCount
        let learned: Int
        do {
            let stats = try LLDatabaseManager.shared.getWordListProgressStats(wordListId: list.id)
            learned = stats.mastered
        } catch {
            learned = 0
        }
        let percentage = total > 0 ? Double(learned) / Double(total) * 100 : 0
        return (learned, total, percentage)
    }
    
    /// 获取当前词库今日学习数量
    func getCurrentListTodayCount() -> Int {
        guard let listId = currentListId else { return 0 }
        let count: Int
        do {
            count = try LLDatabaseManager.shared.getTodayLearnedCount(wordListId: listId)
        } catch {
            count = 0
        }
        return count
    }
}
