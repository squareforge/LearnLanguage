//
//  LLAppInitializer.swift
//  LearnLanguage
//
//  应用初始化管理器
//  统一管理所有初始化操作，便于扩展和维护
//

import Foundation
import AppKit
import UserNotifications
import WCDBSwift

final class LLAppInitializer {
    
    static let shared = LLAppInitializer()
    
    private init() {}
    
    // MARK: - 公开方法
    
    /// 执行应用启动时的所有初始化操作
    func performStartupInitialization() -> Bool {
        // 0. 初始化日志系统（最优先）
        LLLogger.setup()
        do {
            let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try LLFileReplacementTransaction.recoverIfNeeded(in: root, managedPaths: LLBackupArchive.managedPaths)
        } catch {
            let alert = NSAlert()
            alert.messageText = "数据恢复尚未完成"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
        
        LLLogger.info("\n" + String(repeating: "=", count: 60))
        LLLogger.info("🚀 开始应用初始化...")
        LLLogger.info(String(repeating: "=", count: 60))
        
        // 1. 初始化 MMKV（会自动从 UserDefaults 迁移数据）
        initializeMMKV()
        
        // 2. 初始化数据库（首次安装或版本更新）
        guard initializeDatabase() else {
            let alert = NSAlert()
            alert.messageText = "学习数据暂时无法打开"
            alert.informativeText = "词库准备失败，原有进度已保留。请检查磁盘空间并重新启动应用。"
            alert.runModal()
            return false
        }
        
        // 3. 初始化键盘快捷键
        initializeKeyboardShortcuts()
        
        // 4. 初始化用户设置（如果需要）
        initializeUserSettings()
        
        // 5. 初始化外观设置
        initializeAppearance()
        
        // TODO: 未来可以在这里添加更多初始化操作
        // - 检查更新
        // - 初始化网络服务
        // - 初始化统计分析
        // - 初始化通知服务
        // 等等...
        
        LLLogger.info(String(repeating: "=", count: 60))
        LLLogger.info("✅ 应用初始化完成")
        LLLogger.info(String(repeating: "=", count: 60) + "\n")
        return true
    }
    
    // MARK: - 私有初始化方法
    
    /// 初始化 MMKV 存储
    private func initializeMMKV() {
        LLLogger.info("\n📦 初始化 MMKV...")
        _ = LLMMKVManager.shared
        LLLogger.info("✅ MMKV 初始化完成")
    }
    
    /// 初始化数据库
    private func initializeDatabase() -> Bool {
        LLLogger.info("\n🗄️ 初始化数据库...")
        
        // 1. 先初始化数据库文件（复制、版本检查等）
        guard LLDatabaseInitializer.shared.initializeDatabase() else { return false }
        
        // 2. 然后打开数据库连接
        guard LLDatabaseManager.shared.openDatabase() else { return false }
        
        // 3. 最后打印数据库统计信息
        LLDatabaseInitializer.shared.getDatabaseStats()
        return true
    }
    
    /// 初始化键盘快捷键
    private func initializeKeyboardShortcuts() {
        LLLogger.info("\n⌨️ 初始化键盘快捷键...")
        LLKeyboardShortcutManager.shared.registerAll()
        LLLogger.info("✅ 键盘快捷键初始化完成")
    }
    
    /// 初始化外观设置
    private func initializeAppearance() {
        LLLogger.info("\n🎨 初始化外观设置...")
        // 设置应用跟随系统外观
        LLAppearanceManager.shared.setTheme(.system)
        LLLogger.info("✅ 外观设置初始化完成")
    }
    
    /// 初始化用户设置
    private func initializeUserSettings() {
        LLLogger.info("\n⚙️ 初始化用户设置...")
        
        // 检查是否是首次启动
        let isFirstLaunch = !LLMMKVManager.shared.hasLaunched
        
        if isFirstLaunch {
            LLLogger.info("   🎉 首次启动，设置默认配置...")
            
            // 随机选择一个普通词库作为首次推荐学习内容
            setRandomDefaultWordList()
            
            // 标记已启动
            LLMMKVManager.shared.hasLaunched = true
            LLMMKVManager.shared.firstLaunchDate = Date()
            
            LLLogger.info("   ✅ 默认配置已设置")
        } else {
            LLLogger.info("   ℹ️ 非首次启动，跳过默认配置")
        }
    }
    
    /// 随机设置一个普通词库作为首次学习推荐
    private func setRandomDefaultWordList() {
        do {
            let db = LLDatabaseManager.shared
            let wordLists = try db.getAllWordLists()
                .filter { $0.description != LLWordListStorage.vocabularyNotebookDescription }
            
            guard let randomList = wordLists.randomElement(), let id = randomList.id else { return }
            LLSettingsStore.shared.currentListId = String(id)
        } catch {
            LLLogger.warn("   ⚠️ 设置首次推荐词库失败：\(error)")
        }
    }
    
    /// 执行重置（清除所有数据并重新初始化数据库）
    func performReset() {
        LLLogger.warn("\n⚠️ 开始重置所有数据...")
        LLPracticePanelController.shared.hide()
        LLPronunciationManager.shared.stop()
        
        LLDatabaseManager.shared.closeDatabase()
        guard LLDatabaseInitializer.shared.forceReinitialize() else {
            LLDatabaseManager.shared.openDatabase()
            showNotification(title: "重置失败", message: "原有数据已保留，请重试")
            return
        }
        clearLearningRecords()
        clearSettings()
        LLDatabaseManager.shared.openDatabase()
        setRandomDefaultWordList()
        LLDailyLearningManager.shared.invalidate()
        LLPracticePanelController.shared.resetAfterDataChange()
        LLWordEntry.invalidateExampleCache()
        notifyLearningDataChanged()
        
        LLLogger.info("✅ 重置完成")
        showNotification(title: "重新初始化完成", message: "所有数据已重置")
    }
    
    /// 清除学习记录
    private func clearLearningRecords() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LearnLanguage", isDirectory: true)
        let recordsFile = appSupportURL.appendingPathComponent("learning_records.json")
        
        if fileManager.fileExists(atPath: recordsFile.path) {
            try? fileManager.removeItem(at: recordsFile)
            LLLogger.info("   🗑️ 已清除学习记录")
        }
    }
    
    /// 清除设置
    private func clearSettings() {
        LLMMKVManager.shared.clearAll()
        LLLogger.info("   🗑️ 已清除所有设置")
    }
    
    /// 显示系统通知
    private func showNotification(title: String, message: String) {
        if #available(macOS 10.14, *) {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    LLLogger.warn("⚠️ 通知发送失败：\(error)")
                }
            }
        } else {
            // macOS 10.13 及以下使用旧 API
            let notification = NSUserNotification()
            notification.title = title
            notification.informativeText = message
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
    
    // MARK: - 数据库维护方法
    
    /// 检查数据库完整性，返回检查结果字符串
    @discardableResult
    func checkDatabaseIntegrity() -> String {
        LLLogger.info("\n🔍 检查数据库完整性...")
        
        do {
            let db = LLDatabaseManager.shared
            var lines: [String] = []
            let databaseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("LearnLanguage.db")
            try LLSQLiteConnection.validateDatabase(at: databaseURL)
            let connection = try LLSQLiteConnection(url: databaseURL, readOnly: true)
            let integrity = try connection.query("PRAGMA integrity_check")
            guard integrity.count == 1, integrity.first?.values.first == "ok" else { throw BackupError.invalidFile }
            lines.append("SQLite 完整性检查：通过")
            
            // 检查分类数量
            let categories = try db.getAllCategories()
            lines.append("分类数量：\(categories.count)")
            
            // 检查词库数量
            let wordLists = try db.getAllWordLists()
            lines.append("词库数量：\(wordLists.count)")
            lines.append("")
            
            // 检查每个分类下的词库及单词数
            for category in categories {
                guard let categoryId = category.id else { continue }
                let lists = try db.getWordListByCategoryId(categoryId)
                var categoryWords = 0
                for list in lists {
                    if let id = list.id {
                        categoryWords += try db.getWordCount(forWordListId: id)
                    }
                }
                lines.append("【\(category.name)】\(lists.count) 个词库，共 \(categoryWords) 个单词")
            }
            
            lines.append("")
            
            // 检查有单词的词库数量
            var wordListsWithWords = 0
            var totalWords = 0
            for wordList in wordLists {
                guard let id = wordList.id else { continue }
                let count = try db.getWordCount(forWordListId: id)
                if count > 0 {
                    wordListsWithWords += 1
                    totalWords += count
                }
            }
            
            lines.append("有单词的词库：\(wordListsWithWords) / \(wordLists.count)")
            lines.append("总单词数：\(totalWords)")
            
            if wordListsWithWords == 0 {
                lines.append("")
                lines.append("⚠️ 警告：没有词库包含单词数据！")
            }
            
            let result = lines.joined(separator: "\n")
            LLLogger.info("✅ 数据库完整性检查完成\n")
            return result
            
        } catch {
            LLLogger.error("❌ 数据库完整性检查失败：\(error)\n")
            return "检查失败：\(error.localizedDescription)"
        }
    }
    
    /// 修复数据库（尝试重新导入数据）
    func repairDatabase() {
        LLLogger.info("\n🔧 开始修复数据库...")
        
        let alert = NSAlert()
        alert.messageText = "修复数据库"
        alert.informativeText = "这将尝试从资源文件重新导入缺失的数据。现有数据不会丢失。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "开始修复")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            LLPracticePanelController.shared.hide()
            LLPronunciationManager.shared.stop()
            // 强制重新初始化数据库（增量更新）
            let database = LLDatabaseManager.shared.database
            var success = false
            database?.close(onClosed: {
                success = LLDatabaseInitializer.shared.initializeDatabase(forceUpdate: true)
            })
            guard success else {
                showNotification(title: "修复未完成", message: "原有数据已保留，请检查磁盘空间后重试")
                return
            }
            LLDailyLearningManager.shared.invalidate()
            LLPracticePanelController.shared.resetAfterDataChange()
            LLWordEntry.invalidateExampleCache()
            notifyLearningDataChanged()
            
            // 检查修复结果
            checkDatabaseIntegrity()
            
            showNotification(title: "修复完成", message: "数据库修复操作已完成")
        }
    }
    
    private func notifyLearningDataChanged() {
        for name in [Notification.Name.learnLanguageCurrentListChanged, .learnLanguageRefreshStatus, .learnLanguageReloadWordLists, .learningPracticeProgressChanged, .floatingPanelSettingsChanged] {
            NotificationCenter.default.post(name: name, object: nil)
        }
    }

    /// 导出数据库统计信息
    func exportDatabaseStats() -> String {
        var stats = "LearnLanguage 数据库统计\n"
        stats += "生成时间：\(Date())\n"
        stats += String(repeating: "=", count: 50) + "\n\n"
        
        do {
            let db = LLDatabaseManager.shared
            
            // 分类统计
            let categories = try db.getAllCategories()
            stats += "分类数量：\(categories.count)\n\n"
            
            for category in categories {
                guard let categoryId = category.id else { continue }
                let lists = try db.getWordListByCategoryId(categoryId)
                stats += "【\(category.name)】\n"
                stats += "  词库数：\(lists.count)\n"
                
                var totalWords = 0
                for list in lists {
                    if let id = list.id {
                        totalWords += try db.getWordCount(forWordListId: id)
                    }
                }
                stats += "  单词数：\(totalWords)\n\n"
            }
            
            // 总计
            let allLists = try db.getAllWordLists()
            var grandTotal = 0
            for list in allLists {
                if let id = list.id {
                    grandTotal += try db.getWordCount(forWordListId: id)
                }
            }
            
            stats += String(repeating: "=", count: 50) + "\n"
            stats += "总词库数：\(allLists.count)\n"
            stats += "总单词数：\(grandTotal)\n"
            
        } catch {
            stats += "错误：\(error)\n"
        }
        
        return stats
    }
}
