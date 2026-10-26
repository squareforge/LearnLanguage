import Foundation

// Only presentation/logging boundaries are stubbed; WCDB, MMKV, settings and the daily queue are production code.
enum SidebarModule: String, Codable { case learning, wordList, learningRecord, settings, dataManagement }
enum LLTranslationManager {
    enum Direction { case enToZh, zhToEn, jaToEn, enToJa, koToEn, enToKo }
}
enum LLLogger {
    static func info(_ message: @autoclosure () -> String) {}
    static func debug(_ message: @autoclosure () -> String) {}
    static func warn(_ message: @autoclosure () -> String) {}
    static func error(_ message: @autoclosure () -> String) {}
}
