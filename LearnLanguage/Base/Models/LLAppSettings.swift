//
//  LLAppSettings.swift
//  LearnLanguage
//

import Foundation

// MARK: - Global Constants

/// 可用的字体列表
let LLAvailableFonts = [
    "Bangers-Regular",
    "BitcountGridSingleInk",
    "Capriola-Regular",
    "CaveatBrush-Regular",
    "ChakraPetch-Regular",
    "Chango-Regular",
    "Englebert-Regular",
    "GothamRnd-Md",
    "HachiMaruPop-Regular",
    "IndieFlower-Regular",
    "Jura-VariableFont_wght",
    "LondrinaShadow-Regular",
    "MomoTrustDisplay-Regular",
    "MontserratAlternates-Regular",
    "Oswald-VariableFont_wght",
    "PermanentMarker-Regular",
    "Rajdhani-Regular",
    "Schoolbell-Regular",
    "Srisakdi-Regular",
    "Unkempt-Regular"
]

/// 可用的字号列表
let LLAvailableFontSizes: [CGFloat] = [24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64, 72]

/// 支持学习的语言（先占定 3 类，后续可扩展）
enum LLLearningLanguage: String, CaseIterable, Codable {
    case english = "英语"
    case japanese = "日语"
    case korean = "韩语"

    /// 对应的翻译方向（学习语言 → 英语，英语学习者则是 英语 → 中文）
    var translationDirection: LLTranslationManager.Direction {
        switch self {
        case .english:  return .enToZh
        case .japanese: return .jaToEn
        case .korean:   return .koToEn
        }
    }

    /// 朗读该语言时使用的语言代码
    var speechLanguageCode: String {
        switch self {
        case .english:  return "en-US"
        case .japanese: return "ja-JP"
        case .korean:   return "ko-KR"
        }
    }
}

/// 应用显示语言
enum LLDisplayLanguage: String, CaseIterable, Codable {
    // case english = "English"
    case simplifiedChinese = "简体中文"
    // case japanese = "日本語"
    // case korean = "한국어"
    
    var displayName: String {
        switch self {
        // case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        // case .japanese: return "日本語"
        // case .korean: return "한국어"
        }
    }
    
    var languageCode: String {
        switch self {
        // case .english: return "en"
        case .simplifiedChinese: return "zh-Hans"
        // case .japanese: return "ja"
        // case .korean: return "ko"
        }
    }
}

/// 发音提供者类型
enum LLPronunciationProvider: String, Codable, CaseIterable {
    case local = "local"           // 本地 TTS
    case youdao = "youdao"         // 有道词典
    
    var displayName: String {
        switch self {
        case .local: return NSLocalizedString("Pronunciation Local", comment: "")
        case .youdao: return NSLocalizedString("Pronunciation Youdao", comment: "")
        }
    }
}

/// 发音口音类型
enum LLPronunciationAccent: String, Codable, CaseIterable {
    case us = "us"     // 美式英语
    case uk = "uk"     // 英式英语
    
    var displayName: String {
        switch self {
        case .us: return NSLocalizedString("Accent US", comment: "")
        case .uk: return NSLocalizedString("Accent UK", comment: "")
        }
    }
    
    var flag: String {
        switch self {
        case .us: return "🇺🇸"
        case .uk: return "🇬🇧"
        }
    }
}

/// 英文和中文释义都启用时的朗读顺序
enum LLPronunciationOrder: String, Codable, CaseIterable {
    case chineseThenEnglish = "chinese_then_english"
    case englishThenChinese = "english_then_chinese"
    
    var displayName: String {
        switch self {
        case .chineseThenEnglish: return NSLocalizedString("Pronunciation Order Chinese Then English", comment: "")
        case .englishThenChinese: return NSLocalizedString("Pronunciation Order English Then Chinese", comment: "")
        }
    }
    
    static var allDisplayNames: [String] {
        allCases.map { $0.displayName }
    }
}

/// 打字练习输入框样式
enum LLTypingInputStyle: String, Codable, CaseIterable {
    case perLetter = "per_letter"     // 每个字母一个下划线
    case wholeWord = "whole_word"     // 整个单词一个下划线
    
    var displayName: String {
        switch self {
        case .perLetter: return NSLocalizedString("Typing Per Letter", comment: "")
        case .wholeWord: return NSLocalizedString("Typing Whole Word", comment: "")
        }
    }
}

/// 自动显示答案配置
enum LLAutoShowAnswerOption: Int, CaseIterable, Codable {
    case after1Error = 1
    case after2Errors = 2
    case after3Errors = 3
    case after4Errors = 4
    case after5Errors = 5
    case never = 999
    
    var displayName: String {
        switch self {
        case .after1Error: return NSLocalizedString("Auto Show After 1 Error", comment: "")
        case .after2Errors: return NSLocalizedString("Auto Show After 2 Errors", comment: "")
        case .after3Errors: return NSLocalizedString("Auto Show After 3 Errors", comment: "")
        case .after4Errors: return NSLocalizedString("Auto Show After 4 Errors", comment: "")
        case .after5Errors: return NSLocalizedString("Auto Show After 5 Errors", comment: "")
        case .never: return NSLocalizedString("Auto Show Never", comment: "")
        }
    }
    
    static var allDisplayNames: [String] {
        allCases.map { $0.displayName }
    }
    
    // 从错误次数获取对应的选项
    static func from(errorCount: Int) -> LLAutoShowAnswerOption {
        switch errorCount {
        case 1: return .after1Error
        case 2: return .after2Errors
        case 3: return .after3Errors
        case 4: return .after4Errors
        case 5: return .after5Errors
        default: return .never
        }
    }
}

/// 记录到错题本配置
enum LLAddToWrongBookOption: Int, CaseIterable, Codable {
    case after1Error = 1
    case after2Errors = 2
    case after3Errors = 3
    case after4Errors = 4
    case after5Errors = 5
    case never = 999
    
    var displayName: String {
        switch self {
        case .after1Error: return NSLocalizedString("Wrong Book After 1 Error", comment: "")
        case .after2Errors: return NSLocalizedString("Wrong Book After 2 Errors", comment: "")
        case .after3Errors: return NSLocalizedString("Wrong Book After 3 Errors", comment: "")
        case .after4Errors: return NSLocalizedString("Wrong Book After 4 Errors", comment: "")
        case .after5Errors: return NSLocalizedString("Wrong Book After 5 Errors", comment: "")
        case .never: return NSLocalizedString("Wrong Book Never", comment: "")
        }
    }
    
    static var allDisplayNames: [String] {
        allCases.map { $0.displayName }
    }
    
    // 从错误次数获取对应的选项
    static func from(errorCount: Int) -> LLAddToWrongBookOption {
        switch errorCount {
        case 1: return .after1Error
        case 2: return .after2Errors
        case 3: return .after3Errors
        case 4: return .after4Errors
        case 5: return .after5Errors
        default: return .never
        }
    }
}

/// 语速配置
enum LLSpeechRate: Float, CaseIterable, Codable {
    case slow = 0.25
    case normal = 0.5
    case standard = 1.0
    case fast = 1.5
    case veryFast = 2.0
    
    var displayName: String {
        switch self {
        case .slow:     return NSLocalizedString("Speech Rate Slow", comment: "")
        case .normal:   return NSLocalizedString("Speech Rate Normal", comment: "")
        case .standard: return NSLocalizedString("Speech Rate Standard", comment: "")
        case .fast:     return NSLocalizedString("Speech Rate Fast", comment: "")
        case .veryFast: return NSLocalizedString("Speech Rate Very Fast", comment: "")
        }
    }
    
    static var allDisplayNames: [String] {
        allCases.map { $0.displayName }
    }
    
    static func from(rate: Float) -> LLSpeechRate {
        return allCases.min(by: { abs($0.rawValue - rate) < abs($1.rawValue - rate) }) ?? .standard
    }
}

/// 播放间隔配置
enum LLPlaybackInterval: Int, CaseIterable, Codable {
    case once = 0           // 只播放1次
    case every5s = 5        // 5秒播放一次
    case every10s = 10      // 10秒播放一次
    case every20s = 20      // 20秒播放一次
    case every60s = 60      // 60秒播放一次
    
    var displayName: String {
        switch self {
        case .once:      return NSLocalizedString("Playback Once", comment: "")
        case .every5s:   return NSLocalizedString("Playback Every 5s", comment: "")
        case .every10s:  return NSLocalizedString("Playback Every 10s", comment: "")
        case .every20s:  return NSLocalizedString("Playback Every 20s", comment: "")
        case .every60s:  return NSLocalizedString("Playback Every 60s", comment: "")
        }
    }
    
    static var allDisplayNames: [String] {
        allCases.map { $0.displayName }
    }
    
    // 从秒数获取对应的选项
    static func from(seconds: Int) -> LLPlaybackInterval {
        switch seconds {
        case 0: return .once
        case 5: return .every5s
        case 10: return .every10s
        case 20: return .every20s
        case 60: return .every60s
        default: return .once
        }
    }
}

/// 快捷键组合
struct LLKeyCombo: Codable, Equatable {
    var keyCode: UInt32      // 虚拟键码
    var modifiers: UInt32    // Carbon modifier flags
    var displayString: String // 显示字符串，如 "⌘⇧L"
    
    static let empty = LLKeyCombo(keyCode: 0, modifiers: 0, displayString: "")
    
    var isEmpty: Bool { displayString.isEmpty }
}

/// 所有可配置的快捷键动作
struct LLShortcutConfig: Codable {
    var showMainWindow: LLKeyCombo
    var nextWord: LLKeyCombo
    var markKnow: LLKeyCombo
    var markUnclear: LLKeyCombo
    var markUnknown: LLKeyCombo
    var playPronunciation: LLKeyCombo
    var toggleTypingMode: LLKeyCombo
    
    static let `default` = LLShortcutConfig(
        showMainWindow:   LLKeyCombo(keyCode: 37, modifiers: 0x0100 | 0x0200, displayString: "⌘⇧L"),
        nextWord:         LLKeyCombo(keyCode: 45, modifiers: 0x0100 | 0x0200, displayString: "⌘⇧N"),
        markKnow:         LLKeyCombo(keyCode: 40, modifiers: 0x0100 | 0x0200, displayString: "⌘⇧K"),
        markUnclear:      LLKeyCombo(keyCode: 32, modifiers: 0x0100 | 0x0200, displayString: "⌘⇧U"),
        markUnknown:      LLKeyCombo(keyCode: 38, modifiers: 0x0100 | 0x0200, displayString: "⌘⇧J"),
        playPronunciation:LLKeyCombo(keyCode: 35, modifiers: 0x0100 | 0x0200, displayString: "⌘⇧P"),
        toggleTypingMode: LLKeyCombo(keyCode: 17, modifiers: 0x0100 | 0x0200, displayString: "⌘⇧T")
    )
}

extension LLShortcutConfig {
    init(from decoder: Decoder) throws {
        let fallback = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        showMainWindow = container.decodeOrDefault(LLKeyCombo.self, forKey: .showMainWindow, default: fallback.showMainWindow)
        nextWord = container.decodeOrDefault(LLKeyCombo.self, forKey: .nextWord, default: fallback.nextWord)
        markKnow = container.decodeOrDefault(LLKeyCombo.self, forKey: .markKnow, default: fallback.markKnow)
        markUnclear = container.decodeOrDefault(LLKeyCombo.self, forKey: .markUnclear, default: fallback.markUnclear)
        markUnknown = container.decodeOrDefault(LLKeyCombo.self, forKey: .markUnknown, default: fallback.markUnknown)
        playPronunciation = container.decodeOrDefault(LLKeyCombo.self, forKey: .playPronunciation, default: fallback.playPronunciation)
        toggleTypingMode = container.decodeOrDefault(LLKeyCombo.self, forKey: .toggleTypingMode, default: fallback.toggleTypingMode)
    }
}

/// 应用设置（本地存储）
struct LLAppSettings: Codable {
    static let dailyWordRange = 1...1000

    /// Validate persisted values as well as values coming from settings controls.
    func validated() -> LLAppSettings {
        var value = self
        value.newWordsPerDay = min(max(value.newWordsPerDay, Self.dailyWordRange.lowerBound), Self.dailyWordRange.upperBound)
        value.reviewCountPerDay = min(max(value.reviewCountPerDay, 0), 10000)
        value.statusBarMaxLength = min(max(value.statusBarMaxLength, 1), 200)
        value.statusBarContentWidth = min(max(value.statusBarContentWidth, 135), 300)
        value.floatingPanelAlpha = value.floatingPanelAlpha.isFinite ? min(max(value.floatingPanelAlpha, 0.15), 1) : 0.55
        value.floatingPanelWidth = value.floatingPanelWidth.isFinite ? min(max(value.floatingPanelWidth, 360), 900) : 480
        value.floatingPanelHeight = value.floatingPanelHeight.isFinite ? min(max(value.floatingPanelHeight, 240), 600) : 280
        value.floatingPanelFontSize = value.floatingPanelFontSize.isFinite ? min(max(value.floatingPanelFontSize, 12), 72) : 24
        value.pronunciationRate = value.pronunciationRate.isFinite ? min(max(value.pronunciationRate, 0.25), 2) : 1
        value.appAudioVolume = value.appAudioVolume.isFinite ? min(max(value.appAudioVolume, 0), 1) : 1
        value.pronunciationLanguageInterval = value.pronunciationLanguageInterval.isFinite ? min(max(value.pronunciationLanguageInterval, 0), 5) : 0.5
        value.statusBarPlaybackInterval = min(max(value.statusBarPlaybackInterval, 0), 3600)
        value.autoShowAnswerAfterErrors = max(0, value.autoShowAnswerAfterErrors)
        value.translateDoubleCopyInterval = value.translateDoubleCopyInterval.isFinite ? min(max(value.translateDoubleCopyInterval, 0.1), 3) : 0.5
        value.translateFontSize = value.translateFontSize.isFinite ? min(max(value.translateFontSize, 10), 40) : 14
        return value
    }

    var displayLanguage: LLDisplayLanguage  // 应用显示语言
    var lastSelectedSidebarModule: SidebarModule
    var currentLanguage: LLLearningLanguage
    var currentListId: String?
    var statusBarShowPhonetic: Bool
    var statusBarMaxLength: Int
    var statusBarShowContent: Bool  // 状态栏是否显示内容
    var statusBarContentWidth: Int  // 状态栏显示内容的宽度（135-300）
    var showFeedbackButtons: Bool   // 是否显示反馈按钮
    
    // 新增：状态栏显示内容细分控制
    var statusBarShowWord: Bool      // 是否显示单词
    var statusBarShowPhoneticSymbol: Bool  // 是否显示音标
    var statusBarShowMeaning: Bool   // 是否显示释义
    var statusBarAutoScroll: Bool    // 释义不够显示时是否自动滚动
    var statusBarPlaybackInterval: Int  // 播放间隔（秒）
    
    var floatingPanelAlpha: Double
    var floatingPanelWidth: CGFloat   // 浮窗宽度
    var floatingPanelHeight: CGFloat  // 浮窗高度
    var floatingPanelFontName: String  // 浮窗字体名称
    var floatingPanelFontSize: CGFloat  // 浮窗字体大小
    var pronunciationEnabled: Bool
    var chineseMeaningPronunciationEnabled: Bool
    var exampleSentencePronunciationEnabled: Bool
    var exampleSentenceTranslationPronunciationEnabled: Bool
    var randomPronunciationEnabled: Bool
    var pronunciationOrder: LLPronunciationOrder
    var pronunciationLanguageInterval: Double  // 英文和中文释义连续朗读时的间隔（秒）
    var pronunciationProvider: LLPronunciationProvider
    var pronunciationAccent: LLPronunciationAccent
    var pronunciationRate: Float  // 语速 0.0-1.0
    var appAudioVolume: Float  // 应用内播放音量 0.0-1.0
    var newWordsPerDay: Int
    var reviewCountPerDay: Int
    var reminderEnabled: Bool
    var reminderTime: Date
    var typingPracticeShowMeaning: Bool
    var typingFollowLetterSoundEnabled: Bool
    var typingDictationMode: Bool  // 听写模式（隐藏单词）
    var typingInputStyle: LLTypingInputStyle  // 打字练习输入框样式
    var autoShowAnswerAfterErrors: Int  // 自动显示答案（错误N次后）
    var launchAtLogin: Bool
    var shortcutConfig: LLShortcutConfig

    // MARK: - 翻译设置
    /// 是否开启连续两次 ⌘+C 触发翻译
    var translateDoubleCopyEnabled: Bool
    /// 两次 ⌘+C 触发翻译的时间间隔（秒）
    var translateDoubleCopyInterval: Double
    /// 是否开启剪贴板截图 OCR 翻译
    var translateClipboardOCREnabled: Bool
    /// 翻译方向是否反转（true: 中文→英文，false: 英文→中文）
    var translateLanguageReversed: Bool
    /// 翻译结果字体大小
    var translateFontSize: CGFloat

    static let `default` = LLAppSettings(
        displayLanguage: .simplifiedChinese,
        lastSelectedSidebarModule: .learning,
        currentLanguage: .english,
        currentListId: nil,
        statusBarShowPhonetic: false,
        statusBarMaxLength: 20,
        statusBarShowContent: true,
        statusBarContentWidth: 150,
        showFeedbackButtons: true,
        statusBarShowWord: true,
        statusBarShowPhoneticSymbol: true,
        statusBarShowMeaning: true,
        statusBarAutoScroll: true,
        statusBarPlaybackInterval: 0,
        floatingPanelAlpha: 0.55,
        floatingPanelWidth: 480,
        floatingPanelHeight: 280,
        floatingPanelFontName: "Bangers-Regular",
        floatingPanelFontSize: 24,
        pronunciationEnabled: true,
        chineseMeaningPronunciationEnabled: false,
        exampleSentencePronunciationEnabled: false,
        exampleSentenceTranslationPronunciationEnabled: false,
        randomPronunciationEnabled: false,
        pronunciationOrder: .chineseThenEnglish,
        pronunciationLanguageInterval: 0.5,
        pronunciationProvider: .local,
        pronunciationAccent: .uk,
        pronunciationRate: 1.0,
        appAudioVolume: 1.0,
        newWordsPerDay: 20,
        reviewCountPerDay: 50,
        reminderEnabled: false,
        reminderTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(),
        typingPracticeShowMeaning: true,
        typingFollowLetterSoundEnabled: false,
        typingDictationMode: false,
        typingInputStyle: .perLetter,
        autoShowAnswerAfterErrors: 3,
        launchAtLogin: false,
        shortcutConfig: .default,
        translateDoubleCopyEnabled: false,
        translateDoubleCopyInterval: 0.5,
        translateClipboardOCREnabled: false,
        translateLanguageReversed: false,
        translateFontSize: 14
    )
}

extension LLAppSettings {
    init(from decoder: Decoder) throws {
        let fallback = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        displayLanguage = container.decodeOrDefault(LLDisplayLanguage.self, forKey: .displayLanguage, default: fallback.displayLanguage)
        lastSelectedSidebarModule = container.decodeOrDefault(SidebarModule.self, forKey: .lastSelectedSidebarModule, default: fallback.lastSelectedSidebarModule)
        currentLanguage = container.decodeOrDefault(LLLearningLanguage.self, forKey: .currentLanguage, default: fallback.currentLanguage)
        currentListId = container.decodeOrDefault(String?.self, forKey: .currentListId, default: fallback.currentListId)
        statusBarShowPhonetic = container.decodeOrDefault(Bool.self, forKey: .statusBarShowPhonetic, default: fallback.statusBarShowPhonetic)
        statusBarMaxLength = container.decodeOrDefault(Int.self, forKey: .statusBarMaxLength, default: fallback.statusBarMaxLength)
        statusBarShowContent = container.decodeOrDefault(Bool.self, forKey: .statusBarShowContent, default: fallback.statusBarShowContent)
        statusBarContentWidth = container.decodeOrDefault(Int.self, forKey: .statusBarContentWidth, default: fallback.statusBarContentWidth)
        showFeedbackButtons = container.decodeOrDefault(Bool.self, forKey: .showFeedbackButtons, default: fallback.showFeedbackButtons)
        statusBarShowWord = container.decodeOrDefault(Bool.self, forKey: .statusBarShowWord, default: fallback.statusBarShowWord)
        statusBarShowPhoneticSymbol = container.decodeOrDefault(Bool.self, forKey: .statusBarShowPhoneticSymbol, default: fallback.statusBarShowPhoneticSymbol)
        statusBarShowMeaning = container.decodeOrDefault(Bool.self, forKey: .statusBarShowMeaning, default: fallback.statusBarShowMeaning)
        statusBarAutoScroll = container.decodeOrDefault(Bool.self, forKey: .statusBarAutoScroll, default: fallback.statusBarAutoScroll)
        statusBarPlaybackInterval = container.decodeOrDefault(Int.self, forKey: .statusBarPlaybackInterval, default: fallback.statusBarPlaybackInterval)
        floatingPanelAlpha = container.decodeOrDefault(Double.self, forKey: .floatingPanelAlpha, default: fallback.floatingPanelAlpha)
        floatingPanelWidth = container.decodeOrDefault(CGFloat.self, forKey: .floatingPanelWidth, default: fallback.floatingPanelWidth)
        floatingPanelHeight = container.decodeOrDefault(CGFloat.self, forKey: .floatingPanelHeight, default: fallback.floatingPanelHeight)
        floatingPanelFontName = container.decodeOrDefault(String.self, forKey: .floatingPanelFontName, default: fallback.floatingPanelFontName)
        floatingPanelFontSize = container.decodeOrDefault(CGFloat.self, forKey: .floatingPanelFontSize, default: fallback.floatingPanelFontSize)
        pronunciationEnabled = container.decodeOrDefault(Bool.self, forKey: .pronunciationEnabled, default: fallback.pronunciationEnabled)
        chineseMeaningPronunciationEnabled = container.decodeOrDefault(Bool.self, forKey: .chineseMeaningPronunciationEnabled, default: fallback.chineseMeaningPronunciationEnabled)
        exampleSentencePronunciationEnabled = container.decodeOrDefault(Bool.self, forKey: .exampleSentencePronunciationEnabled, default: fallback.exampleSentencePronunciationEnabled)
        exampleSentenceTranslationPronunciationEnabled = container.decodeOrDefault(Bool.self, forKey: .exampleSentenceTranslationPronunciationEnabled, default: fallback.exampleSentenceTranslationPronunciationEnabled)
        randomPronunciationEnabled = container.decodeOrDefault(Bool.self, forKey: .randomPronunciationEnabled, default: fallback.randomPronunciationEnabled)
        pronunciationOrder = container.decodeOrDefault(LLPronunciationOrder.self, forKey: .pronunciationOrder, default: fallback.pronunciationOrder)
        pronunciationLanguageInterval = container.decodeOrDefault(Double.self, forKey: .pronunciationLanguageInterval, default: fallback.pronunciationLanguageInterval)
        pronunciationProvider = container.decodeOrDefault(LLPronunciationProvider.self, forKey: .pronunciationProvider, default: fallback.pronunciationProvider)
        pronunciationAccent = container.decodeOrDefault(LLPronunciationAccent.self, forKey: .pronunciationAccent, default: fallback.pronunciationAccent)
        pronunciationRate = container.decodeOrDefault(Float.self, forKey: .pronunciationRate, default: fallback.pronunciationRate)
        appAudioVolume = container.decodeOrDefault(Float.self, forKey: .appAudioVolume, default: fallback.appAudioVolume)
        newWordsPerDay = container.decodeOrDefault(Int.self, forKey: .newWordsPerDay, default: fallback.newWordsPerDay)
        reviewCountPerDay = container.decodeOrDefault(Int.self, forKey: .reviewCountPerDay, default: fallback.reviewCountPerDay)
        reminderEnabled = container.decodeOrDefault(Bool.self, forKey: .reminderEnabled, default: fallback.reminderEnabled)
        reminderTime = container.decodeOrDefault(Date.self, forKey: .reminderTime, default: fallback.reminderTime)
        typingPracticeShowMeaning = container.decodeOrDefault(Bool.self, forKey: .typingPracticeShowMeaning, default: fallback.typingPracticeShowMeaning)
        typingFollowLetterSoundEnabled = container.decodeOrDefault(Bool.self, forKey: .typingFollowLetterSoundEnabled, default: fallback.typingFollowLetterSoundEnabled)
        typingDictationMode = container.decodeOrDefault(Bool.self, forKey: .typingDictationMode, default: fallback.typingDictationMode)
        typingInputStyle = container.decodeOrDefault(LLTypingInputStyle.self, forKey: .typingInputStyle, default: fallback.typingInputStyle)
        autoShowAnswerAfterErrors = container.decodeOrDefault(Int.self, forKey: .autoShowAnswerAfterErrors, default: fallback.autoShowAnswerAfterErrors)
        launchAtLogin = container.decodeOrDefault(Bool.self, forKey: .launchAtLogin, default: fallback.launchAtLogin)
        shortcutConfig = container.decodeOrDefault(LLShortcutConfig.self, forKey: .shortcutConfig, default: fallback.shortcutConfig)
        translateDoubleCopyEnabled = container.decodeOrDefault(Bool.self, forKey: .translateDoubleCopyEnabled, default: fallback.translateDoubleCopyEnabled)
        translateDoubleCopyInterval = container.decodeOrDefault(Double.self, forKey: .translateDoubleCopyInterval, default: fallback.translateDoubleCopyInterval)
        translateClipboardOCREnabled = container.decodeOrDefault(Bool.self, forKey: .translateClipboardOCREnabled, default: fallback.translateClipboardOCREnabled)
        translateLanguageReversed = container.decodeOrDefault(Bool.self, forKey: .translateLanguageReversed, default: fallback.translateLanguageReversed)
        translateFontSize = container.decodeOrDefault(CGFloat.self, forKey: .translateFontSize, default: fallback.translateFontSize)
    }
}

private extension KeyedDecodingContainer {
    func decodeOrDefault<T: Decodable>(_ type: T.Type, forKey key: Key, default defaultValue: T) -> T {
        (try? decodeIfPresent(type, forKey: key)) ?? defaultValue
    }
}
