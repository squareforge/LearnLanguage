//
//  LLPronunciationManager.swift
//  LearnLanguage
//
//  语音发音管理器 - 支持多种发音提供者

import Foundation
import AVFoundation
import AppKit

private extension Float {
    var llClampedAudioVolume: Float { min(max(self, 0), 1) }
}

private struct LLChineseMeaningSpeechNormalizer {
    
    private static let partOfSpeechReplacements: [(tokens: [String], text: String)] = [
        (["adj.", "a."], "形容词，"),
        (["adv."], "副词，"),
        (["n."], "名词，"),
        (["v."], "动词，"),
        (["vt."], "及物动词，"),
        (["vi."], "不及物动词，"),
        (["prep."], "介词，"),
        (["pron."], "代词，"),
        (["conj."], "连词，"),
        (["interj.", "int."], "感叹词，"),
        (["aux."], "助动词，"),
        (["num."], "数词，"),
        (["art."], "冠词，"),
        (["abbr."], "缩写，"),
        (["pl."], "复数，"),
        (["sing."], "单数，"),
        (["phr."], "短语，"),
        (["idiom."], "习语，")
    ]
    
    static func normalize(_ meaning: String) -> String {
        var text = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        text = replacePartOfSpeech(in: text)
        
        let punctuationReplacements: [(String, String)] = [
            ("\n", "，"),
            ("\r", "，"),
            (";", "，"),
            ("；", "，"),
            (",", "，"),
            ("/", "，"),
            ("、", "，")
        ]
        for (source, target) in punctuationReplacements {
            text = text.replacingOccurrences(of: source, with: target)
        }
        
        text = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "，\\s*，+",
            with: "，",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "\\s*，\\s*",
            with: "，",
            options: .regularExpression
        )
        
        return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "，")))
    }
    
    private static func replacePartOfSpeech(in text: String) -> String {
        var result = text
        for replacement in partOfSpeechReplacements {
            for token in replacement.tokens {
                result = replaceToken(token, with: replacement.text, in: result)
            }
        }
        return result
    }
    
    private static func replaceToken(_ token: String, with replacement: String, in text: String) -> String {
        let escapedToken = NSRegularExpression.escapedPattern(for: token)
        let pattern = "(?i)(^|[\\s\\n\\r,，;；/\\(\\[（【])\(escapedToken)(?=$|[^A-Za-z0-9])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)
        guard !matches.isEmpty else { return text }
        
        var result = text
        for match in matches.reversed() {
            guard
                let fullRange = Range(match.range(at: 0), in: result),
                let prefixRange = Range(match.range(at: 1), in: result)
            else { continue }
            
            let prefix = String(result[prefixRange])
            result.replaceSubrange(fullRange, with: prefix + replacement)
        }
        return result
    }
}

private struct LLEnglishExampleSpeechNormalizer {
    
    static func normalize(_ sentence: String) -> String {
        var text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\u{00a0}", with: " ")
        text = text.replacingOccurrences(
            of: #"(?i)^(?:OK|BrE|NAmE)(?=[A-Z])"#,
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\s*\((?:=|especially|also|British English|North American English|formal|informal|old-fashioned|slang)[^)]+\)"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"\s*\(=[^)]+\)"#,
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(of: "/", with: " or ")
        text = text.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\s+([,.!?;:])"#,
            with: "$1",
            options: .regularExpression
        )
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 发音提供者协议

/// 发音提供者协议，所有发音实现都需要遵循此协议
protocol LLPronunciationProviderProtocol {
    /// 播放单词发音
    /// - Parameters:
    ///   - word: 要发音的单词
    ///   - accent: 口音类型（美式/英式）
    ///   - rate: 语速倍率（1.0 为标准速度）
    ///   - completion: 完成回调
    func speak(word: String, accent: LLPronunciationAccent, rate: Float, completion: ((Bool, Error?) -> Void)?)
    
    /// 停止当前发音
    func stop()
    
    /// 是否正在发音
    var isSpeaking: Bool { get }
}

// MARK: - 本地 TTS 发音提供者

final class LLLocalPronunciationProvider: NSObject, LLPronunciationProviderProtocol {
    
    private let synthesizer = AVSpeechSynthesizer()
    private var completion: ((Bool, Error?) -> Void)?
    private var currentUtterance: AVSpeechUtterance?
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(word: String, accent: LLPronunciationAccent, rate: Float, completion: ((Bool, Error?) -> Void)?) {
        stop()
        self.completion = completion
        
        let utterance = AVSpeechUtterance(string: word)
        
        // 设置语言和口音
        let languageCode = accent == .us ? "en-US" : "en-GB"
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        
        utterance.rate = min(max(AVSpeechUtteranceDefaultSpeechRate * rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        
        // 设置音量和音调
        let appAudioVolume = LLSettingsStore.shared.settings.appAudioVolume.llClampedAudioVolume
        utterance.volume = appAudioVolume
        utterance.pitchMultiplier = 1.0
        
        // 开始发音
        currentUtterance = utterance
        synthesizer.speak(utterance)
        
        LLLogger.debug("🔊 本地发音：\(word) [\(accent.displayName)]")
    }
    
    func stop() {
        let callback = completion
        completion = nil
        currentUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        callback?(false, nil)
    }
    
    var isSpeaking: Bool {
        return synthesizer.isSpeaking
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension LLLocalPronunciationProvider: AVSpeechSynthesizerDelegate {
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finish(utterance, success: true)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish(utterance, success: false)
    }

    private func finish(_ utterance: AVSpeechUtterance, success: Bool) {
        guard utterance === currentUtterance else { return }
        let callback = completion
        completion = nil
        currentUtterance = nil
        callback?(success, nil)
    }
}

// MARK: - 有道发音提供者

final class LLYoudaoPronunciationProvider: NSObject, LLPronunciationProviderProtocol, AVAudioPlayerDelegate {
    
    private var audioPlayer: AVAudioPlayer?
    private var dataTask: URLSessionDataTask?
    private var completion: ((Bool, Error?) -> Void)?
    private var playbackGeneration = 0
    
    func speak(word: String, accent: LLPronunciationAccent, rate: Float, completion: ((Bool, Error?) -> Void)?) {
        playbackGeneration += 1
        let generation = playbackGeneration
        dataTask?.cancel()
        dataTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        self.completion = completion
        
        // 先查缓存
        if let cachedData = LLAudioCacheManager.shared.cachedAudioData(word: word, provider: .youdao, accent: accent) {
            playAudioData(cachedData, rate: rate, generation: generation)
            return
        }
        
        // 有道词典音频 URL
        // 美式：https://dict.youdao.com/dictvoice?audio={word}&type=1
        // 英式：https://dict.youdao.com/dictvoice?audio={word}&type=2
        let type = accent == .us ? "1" : "2"
        let urlString = "https://dict.youdao.com/dictvoice?audio=\(word)&type=\(type)"
        
        LLLogger.info("🔊 有道发音 URL：\(urlString)")
        
        guard let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedString) else {
            completion?(false, NSError(domain: "LLPronunciation", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Invalid URL", comment: "Invalid URL error")]))
            return
        }
        
        LLLogger.debug("🔊 有道发音：\(word) [\(accent.displayName)] - \(urlString)")
        
        // 使用 URLSession.shared，它会自动处理系统代理
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            guard self.isCurrentPlayback(generation) else { return }
            
            if let error = error {
                if (error as NSError).code == NSURLErrorCancelled { return }
                DispatchQueue.main.async {
                    guard self.isCurrentPlayback(generation) else { return }
                    LLLogger.error("❌ 播放失败：\(error.localizedDescription)")
                    LLLogger.info("💡 提示：请检查网络连接或代理设置，也可以尝试使用本地发音")
                    self.completion?(false, error)
                    self.completion = nil
                }
                return
            }
            
            // 检查 HTTP 响应状态
            if let httpResponse = response as? HTTPURLResponse {
                LLLogger.debug("📡 HTTP 状态码：\(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    DispatchQueue.main.async {
                        guard self.isCurrentPlayback(generation) else { return }
                        let error = NSError(domain: "LLPronunciation", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: String(format: NSLocalizedString("Server Error", comment: "Server error message"), httpResponse.statusCode)])
                        LLLogger.error("❌ 播放失败：HTTP \(httpResponse.statusCode)")
                        self.completion?(false, error)
                        self.completion = nil
                    }
                    return
                }
            }
            
            guard let data = data, !data.isEmpty else {
                DispatchQueue.main.async {
                    guard self.isCurrentPlayback(generation) else { return }
                    let error = NSError(domain: "LLPronunciation", code: -2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("No Audio Data", comment: "No audio data error")])
                    LLLogger.error("❌ 播放失败：无音频数据")
                    self.completion?(false, error)
                    self.completion = nil
                }
                return
            }
            
            LLLogger.debug("📦 收到音频数据：\(data.count) 字节")
            
            // 保存到缓存
            LLAudioCacheManager.shared.saveAudioData(data, word: word, provider: .youdao, accent: accent)
            
            DispatchQueue.main.async {
                guard self.isCurrentPlayback(generation) else { return }
                self.playAudioData(data, rate: rate, generation: generation)
            }
        }
        dataTask = task
        task.resume()
    }
    
    /// 播放音频数据
    private func playAudioData(_ data: Data, rate: Float, generation: Int) {
        guard isCurrentPlayback(generation) else { return }
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.enableRate = true
            audioPlayer?.rate = rate
            audioPlayer?.volume = LLSettingsStore.shared.settings.appAudioVolume.llClampedAudioVolume
            
            let success = audioPlayer?.play() ?? false
            if success {
                LLLogger.info("✅ 播放成功")
                return
            } else {
                LLLogger.error("❌ 播放失败：无法启动播放器")
            }
            completion?(success, success ? nil : NSError(domain: "LLPronunciation", code: -3, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Player Start Failed", comment: "Player startup failed error")]))
            completion = nil
        } catch {
            LLLogger.error("❌ 播放失败：\(error.localizedDescription)")
            completion?(false, error)
            completion = nil
        }
    }
    
    func stop() {
        playbackGeneration += 1
        dataTask?.cancel()
        dataTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        completion = nil
    }
    
    var isSpeaking: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === audioPlayer else { return }
        completion?(flag, nil)
        completion = nil
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard player === audioPlayer else { return }
        completion?(false, error)
        completion = nil
    }
    
    private func isCurrentPlayback(_ generation: Int) -> Bool {
        playbackGeneration == generation
    }
}

// MARK: - 发音管理器

final class LLPronunciationManager {
    
    static let shared = LLPronunciationManager()
    private static let maxOrderedPronunciationDelay: TimeInterval = 5.0
    private static let englishExampleSpeechRate: Float = 0.42
    private static let chineseExampleSpeechRate: Float = 0.45
    
    private enum PronunciationModeChoice: Equatable {
        case english
        case chinese
    }

    private enum PronunciationStep {
        case englishWord(String)
        case chineseMeaning(String)
        case englishExample(String)
        case chineseExample(String)
    }
    
    // 所有发音提供者
    private var providers: [LLPronunciationProvider: LLPronunciationProviderProtocol] = [:]
    
    // 当前使用的提供者
    private var currentProvider: LLPronunciationProviderProtocol?
    
    // 随机朗读对当前词只随机一次，直到切换到另一个词
    private var currentRandomChoice: (entryKey: String, choice: PronunciationModeChoice)?
    private var playbackGeneration = 0
    
    private init() {
        // 初始化所有提供者
        providers[.local] = LLLocalPronunciationProvider()
        providers[.youdao] = LLYoudaoPronunciationProvider()
        
        // 设置当前提供者
        updateCurrentProvider()
    }
    
    /// 更新当前提供者（根据设置）
    private func updateCurrentProvider() {
        let settings = LLSettingsStore.shared.settings
        currentProvider = providers[settings.pronunciationProvider]
    }
    
    /// 播放单词发音（使用当前设置）
    /// - Parameters:
    ///   - word: 要发音的单词
    ///   - completion: 完成回调
    func speak(word: String, completion: ((Bool, Error?) -> Void)? = nil) {
        let settings = LLSettingsStore.shared.settings
        
        // 检查是否启用发音
        guard settings.pronunciationEnabled else {
            LLLogger.warn("⚠️ 发音功能已禁用")
            completion?(false, NSError(domain: "LLPronunciation", code: -100, userInfo: [NSLocalizedDescriptionKey: "发音功能已禁用"]))
            return
        }
        
        beginPlayback()
        speakEnglishWord(word, accent: settings.pronunciationAccent, rate: settings.pronunciationRate, completion: completion)
    }
    
    /// 播放单词发音（指定口音）
    /// - Parameters:
    ///   - word: 要发音的单词
    ///   - accent: 口音类型
    ///   - completion: 完成回调
    func speak(word: String, accent: LLPronunciationAccent, completion: ((Bool, Error?) -> Void)? = nil) {
        let settings = LLSettingsStore.shared.settings
        
        guard settings.pronunciationEnabled else {
            LLLogger.warn("⚠️ 发音功能已禁用")
            completion?(false, NSError(domain: "LLPronunciation", code: -100, userInfo: [NSLocalizedDescriptionKey: "发音功能已禁用"]))
            return
        }
        
        beginPlayback()
        speakEnglishWord(word, accent: accent, rate: settings.pronunciationRate, completion: completion)
    }
    
    /// 播放单词发音（完全自定义）
    /// - Parameters:
    ///   - word: 要发音的单词
    ///   - provider: 发音提供者
    ///   - accent: 口音类型
    ///   - rate: 语速
    ///   - completion: 完成回调
    func speak(word: String, provider: LLPronunciationProvider, accent: LLPronunciationAccent, rate: Float, completion: ((Bool, Error?) -> Void)? = nil) {
        beginPlayback()
        providers[provider]?.speak(word: word, accent: accent, rate: rate, completion: completion)
    }
    
    /// 手动播放英文单词发音，不受英文/中文/随机朗读开关影响
    func speakEnglishManually(word: String, completion: ((Bool, Error?) -> Void)? = nil) {
        let text = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            completion?(false, NSError(domain: "LLPronunciation", code: -103, userInfo: [NSLocalizedDescriptionKey: "单词为空"]))
            return
        }
        
        beginPlayback()
        let settings = LLSettingsStore.shared.settings
        speakEnglishWord(
            text,
            accent: settings.pronunciationAccent,
            rate: settings.pronunciationRate,
            completion: completion
        )
    }
    
    /// 根据朗读模式播放学习项：英文、中文释义、例句，或随机二选一
    func speak(entry: LLWordEntry, completion: ((Bool, Error?) -> Void)? = nil) {
        let settings = LLSettingsStore.shared.settings
        let generation = beginPlayback()
        
        if settings.randomPronunciationEnabled {
            let choice = randomChoice(for: entry)
            switch choice {
            case .english:
                speakEnglishWord(
                    entry.text,
                    accent: settings.pronunciationAccent,
                    rate: settings.pronunciationRate,
                    completion: completion
                )
            case .chinese:
                speakChineseMeaning(entry.meaning, completion: completion)
            }
            return
        }

        let entryWithExamples = entry.enrichedWithExamplesIfNeeded()
        let steps = pronunciationSteps(for: entryWithExamples, settings: settings)
        guard !steps.isEmpty else {
            completion?(false, NSError(domain: "LLPronunciation", code: -101, userInfo: [NSLocalizedDescriptionKey: "朗读功能未启用"]))
            return
        }

        playSteps(steps, generation: generation, completion: completion)
    }
    
    /// 原生朗读中文释义
    func speakChineseMeaning(_ meaning: String, completion: ((Bool, Error?) -> Void)? = nil) {
        let text = LLChineseMeaningSpeechNormalizer.normalize(meaning)
        guard !text.isEmpty else {
            completion?(false, NSError(domain: "LLPronunciation", code: -102, userInfo: [NSLocalizedDescriptionKey: "中文释义为空"]))
            return
        }
        LLLogger.debug("🔊 中文释义朗读：\(text)")
        
        let didStart = LLSpeechService.shared.speak(text, language: "zh-CN") { success in
            completion?(success, nil)
        }
        if !didStart {
            completion?(false, nil)
        }
    }
    
    /// Whole phrases and sentences use system speech instead of word-audio endpoints.
    /// Manual replay remains available when automatic pronunciation is disabled.
    func speakSentence(_ sentence: String, rateMultiplier: Float = 1, completion: ((Bool, Error?) -> Void)? = nil) {
        let text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { completion?(false, nil); return }
        beginPlayback()
        let settings = LLSettingsStore.shared.settings
        let language = settings.pronunciationAccent == .uk ? "en-GB" : "en-US"
        let rate = min(max(AVSpeechUtteranceDefaultSpeechRate * settings.pronunciationRate * rateMultiplier, 0.1), 1)
        if !LLSpeechService.shared.speak(text, language: language, rate: rate, completion: { success in
            completion?(success, nil)
        }) {
            completion?(false, nil)
        }
    }

    /// 停止当前发音
    func stop() {
        playbackGeneration += 1
        providers.values.forEach { $0.stop() }
        LLSpeechService.shared.stop()
    }
    
    /// 是否正在发音
    var isSpeaking: Bool {
        return (currentProvider?.isSpeaking ?? false) || LLSpeechService.shared.isSpeaking
    }
    
    private func speakEnglishWord(_ word: String, accent: LLPronunciationAccent, rate: Float, completion: ((Bool, Error?) -> Void)? = nil) {
        updateCurrentProvider()
        currentProvider?.speak(
            word: word,
            accent: accent,
            rate: rate,
            completion: completion
        )
    }
    
    @discardableResult
    private func beginPlayback() -> Int {
        stop()
        return playbackGeneration
    }
    
    private func isCurrentPlayback(_ generation: Int) -> Bool {
        playbackGeneration == generation
    }
    
    private func speakEnglishWordAfterDelay(_ word: String, accent: LLPronunciationAccent, rate: Float, generation: Int, completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + orderedPronunciationDelay) { [weak self] in
            guard let self, self.isCurrentPlayback(generation) else {
                completion?(false, nil)
                return
            }
            self.speakEnglishWord(word, accent: accent, rate: rate, completion: completion)
        }
    }
    
    private func speakChineseMeaningAfterDelay(_ meaning: String, generation: Int, completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + orderedPronunciationDelay) { [weak self] in
            guard let self, self.isCurrentPlayback(generation) else {
                completion?(false, nil)
                return
            }
            self.speakChineseMeaning(meaning, completion: completion)
        }
    }

    private func speakEnglishExample(_ sentence: String, generation: Int, completion: ((Bool, Error?) -> Void)? = nil) {
        let text = LLEnglishExampleSpeechNormalizer.normalize(sentence)
        guard !text.isEmpty else {
            completion?(false, NSError(domain: "LLPronunciation", code: -104, userInfo: [NSLocalizedDescriptionKey: "英文例句为空"]))
            return
        }

        let didStart = LLSpeechService.shared.speak(text, language: "en-US", rate: Self.englishExampleSpeechRate) { success in
            completion?(success, nil)
        }
        if !didStart {
            completion?(false, nil)
        }
    }

    private func speakChineseExample(_ sentence: String, generation: Int, completion: ((Bool, Error?) -> Void)? = nil) {
        let text = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            completion?(false, NSError(domain: "LLPronunciation", code: -105, userInfo: [NSLocalizedDescriptionKey: "例句中文为空"]))
            return
        }

        let didStart = LLSpeechService.shared.speak(text, language: "zh-CN", rate: Self.chineseExampleSpeechRate) { success in
            completion?(success, nil)
        }
        if !didStart {
            completion?(false, nil)
        }
    }

    private func playSteps(_ steps: [PronunciationStep], generation: Int, completion: ((Bool, Error?) -> Void)? = nil) {
        playStep(0, steps: steps, generation: generation, completion: completion)
    }

    private func playStep(_ index: Int, steps: [PronunciationStep], generation: Int, completion: ((Bool, Error?) -> Void)? = nil) {
        guard isCurrentPlayback(generation) else {
            completion?(false, nil)
            return
        }

        guard index < steps.count else {
            completion?(true, nil)
            return
        }

        let finishStep: (Bool, Error?) -> Void = { [weak self] success, error in
            guard let self, self.isCurrentPlayback(generation) else {
                completion?(false, nil)
                return
            }
            guard success else {
                completion?(success, error)
                return
            }
            self.playNextStep(after: index, steps: steps, generation: generation, completion: completion)
        }

        switch steps[index] {
        case .englishWord(let word):
            let settings = LLSettingsStore.shared.settings
            speakEnglishWord(word, accent: settings.pronunciationAccent, rate: settings.pronunciationRate, completion: finishStep)
        case .chineseMeaning(let meaning):
            speakChineseMeaning(meaning, completion: finishStep)
        case .englishExample(let sentence):
            speakEnglishExample(sentence, generation: generation, completion: finishStep)
        case .chineseExample(let sentence):
            speakChineseExample(sentence, generation: generation, completion: finishStep)
        }
    }

    private func playNextStep(after index: Int, steps: [PronunciationStep], generation: Int, completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + orderedPronunciationDelay) { [weak self] in
            self?.playStep(index + 1, steps: steps, generation: generation, completion: completion)
        }
    }

    private func pronunciationSteps(for entry: LLWordEntry, settings: LLAppSettings) -> [PronunciationStep] {
        var steps: [PronunciationStep] = []
        let firstExample = entry.examples.first
        let hasExample = firstExample?.sentenceEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        switch settings.pronunciationOrder {
        case .chineseThenEnglish:
            if settings.chineseMeaningPronunciationEnabled {
                steps.append(.chineseMeaning(entry.meaning))
            }
            if settings.pronunciationEnabled {
                steps.append(.englishWord(entry.text))
            }
        case .englishThenChinese:
            if settings.pronunciationEnabled {
                steps.append(.englishWord(entry.text))
            }
            if settings.chineseMeaningPronunciationEnabled {
                steps.append(.chineseMeaning(entry.meaning))
            }
        }

        if settings.exampleSentencePronunciationEnabled, hasExample, let example = firstExample {
            steps.append(.englishExample(example.sentenceEn))
            if settings.exampleSentenceTranslationPronunciationEnabled,
               let sentenceCn = example.sentenceCn?.trimmingCharacters(in: .whitespacesAndNewlines),
               !sentenceCn.isEmpty {
                steps.append(.chineseExample(sentenceCn))
            }
        }

        return steps
    }

    private var orderedPronunciationDelay: TimeInterval {
        let value = LLSettingsStore.shared.settings.pronunciationLanguageInterval
        return min(max(value, 0), Self.maxOrderedPronunciationDelay)
    }
    
    private func randomChoice(for entry: LLWordEntry) -> PronunciationModeChoice {
        let entryKey = "\(entry.id)|\(entry.text)"
        if let cached = currentRandomChoice, cached.entryKey == entryKey {
            return cached.choice
        }
        
        let choice: PronunciationModeChoice = Bool.random() ? .english : .chinese
        currentRandomChoice = (entryKey: entryKey, choice: choice)
        LLLogger.debug("🎲 随机朗读选择：\(entry.text) -> \(choice == .english ? "英文" : "中文")")
        return choice
    }
    
    /// 获取可用的发音提供者列表
    func availableProviders() -> [LLPronunciationProvider] {
        return Array(providers.keys)
    }
    
    /// 测试发音提供者是否可用
    /// - Parameter provider: 发音提供者
    /// - Returns: 是否可用
    func testProvider(_ provider: LLPronunciationProvider, completion: @escaping (Bool) -> Void) {
        providers[provider]?.speak(word: "test", accent: .us, rate: 0.5) { success, error in
            if let error = error {
                LLLogger.error("❌ 测试 \(provider.displayName) 失败：\(error.localizedDescription)")
            }
            completion(success)
        }
    }
}
