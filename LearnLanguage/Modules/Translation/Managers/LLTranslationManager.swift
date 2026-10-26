//
//  LLTranslationManager.swift
//  LearnLanguage
//
//  翻译管理器 - 封装系统 Translation API（需要 macOS 15.0+）
//

import Foundation

final class LLTranslationManager {

    static let shared = LLTranslationManager()

    private init() {}

    // MARK: - Types

    struct TranslationResult {
        let originalText: String
        let translatedText: String
        let phonetics: String?
    }

    enum TranslationError: Error, LocalizedError {
        case emptyInput
        case unsupportedSystem
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .emptyInput:          return "请输入要翻译的内容"
            case .unsupportedSystem:   return "翻译功能需要 macOS 15.0 或更高版本"
            case .failed(let msg):     return "翻译失败：\(msg)"
            }
        }
    }

    enum Direction {
        case enToZh   // 英文 → 中文
        case zhToEn   // 中文 → 英文
        case jaToEn   // 日文 → 英文
        case enToJa   // 英文 → 日文
        case koToEn   // 韩文 → 英文
        case enToKo   // 英文 → 韩文

        var sourceIdentifier: String {
            switch self {
            case .enToZh, .enToJa, .enToKo: return "en"
            case .zhToEn: return "zh"
            case .jaToEn: return "ja"
            case .koToEn: return "ko"
            }
        }

        var targetIdentifier: String {
            switch self {
            case .enToZh: return "zh"
            case .zhToEn, .jaToEn, .koToEn: return "en"
            case .enToJa: return "ja"
            case .enToKo: return "ko"
            }
        }
        
        var speechLanguageCode: String {
            switch sourceIdentifier {
            case "zh": return "zh-CN"
            case "ja": return "ja-JP"
            case "ko": return "ko-KR"
            default:   return "en-US"
            }
        }
        
        static func preferred(for language: LLLearningLanguage, reversed: Bool) -> Direction {
            guard reversed else { return language.translationDirection }
            
            switch language {
            case .english:  return .zhToEn
            case .japanese: return .enToJa
            case .korean:   return .enToKo
            }
        }
    }

    func cancel(_ id: UUID?) {
        guard let id, #available(macOS 15.0, *) else { return }
        LLTranslationTaskBridge.shared.cancel(id)
    }

    // MARK: - Public

    /// 翻译文字
    /// - Parameters:
    ///   - text: 原文
    ///   - direction: 翻译方向，默认英文 -> 中文
    ///   - completion: 主线程回调
    @discardableResult
    func translate(
        _ text: String,
        direction: Direction = .enToZh,
        completion: @escaping (Result<TranslationResult, Error>) -> Void
    ) -> UUID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(TranslationError.emptyInput))
            return nil
        }

        guard #available(macOS 15.0, *) else {
            completion(.failure(TranslationError.unsupportedSystem))
            return nil
        }

        // 英文原文时才获取音标（离线，基于系统词典）
        let phonetics: String? = direction.sourceIdentifier == "en" ? LLWordService.getPhonetics(for: trimmed) : nil

        let source = Locale.Language(identifier: direction.sourceIdentifier)
        let target = Locale.Language(identifier: direction.targetIdentifier)

        return LLTranslationTaskBridge.shared.performTranslation(trimmed, source: source, target: target) { result in
            switch result {
            case .success(let translated):
                let r = TranslationResult(originalText: trimmed, translatedText: translated, phonetics: phonetics)
                completion(.success(r))
            case .failure(let error):
                completion(.failure(TranslationError.failed(error.localizedDescription)))
            }
        }
    }
}
