//
//  LLWordEntry.swift
//  LearnLanguage
//

import Foundation

/// 单条学习项（单词/短语）
struct LLWordEntry: Codable, Identifiable, Equatable {
    var id: String
    var wordListId: String
    var text: String           // 原文，如 "apple"
    var meaning: String        // 释义
    var phonetic: String?     // 音标，如 "/ˈæpl/"
    var language: LLLearningLanguage
    var examples: [LLWordExample]

    init(
        id: String = UUID().uuidString,
        wordListId: String,
        text: String,
        meaning: String,
        phonetic: String? = nil,
        language: LLLearningLanguage,
        examples: [LLWordExample] = []
    ) {
        self.id = id
        self.wordListId = wordListId
        self.text = text
        self.meaning = meaning
        self.phonetic = phonetic
        self.language = language
        self.examples = examples
    }
}

/// 单词例句（全局例句库按 wordText 匹配）
struct LLWordExample: Codable, Identifiable, Equatable {
    var id: String
    var wordText: String
    var sentenceEn: String
    var sentenceCn: String?
    var heat: Int
    var difficultyLevel: Int
}

extension LLWordEntry {
    static func invalidateExampleCache() { LLWordExampleCache.shared.clear() }
    func enrichedWithExamplesIfNeeded(limit: Int = 3) -> LLWordEntry {
        guard examples.isEmpty else { return self }

        let difficultyLevel: Int = {
            do {
                let reviewCount = try LLDatabaseManager.shared
                    .getLearningProgress(wordId: id, wordListId: wordListId)?
                    .reviewCount ?? 0
                return min(max(reviewCount + 1, 1), 4)
            } catch {
                LLLogger.warn("⚠️ 获取例句难度失败：\(text), \(error)")
                return 1
            }
        }()

        let loadedExamples = LLWordExampleCache.shared.examples(
            for: text,
            difficultyLevel: difficultyLevel,
            limit: limit
        )
        guard !loadedExamples.isEmpty else { return self }

        var entry = self
        entry.examples = loadedExamples
        return entry
    }
}

private final class LLWordExampleCache {
    static let shared = LLWordExampleCache()

    private var cache: [String: [LLWordExample]] = [:]

    private init() {}

    func clear() { cache.removeAll() }

    func examples(for wordText: String, difficultyLevel: Int, limit: Int) -> [LLWordExample] {
        let key = wordText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return [] }

        let cacheKey = "\(key)#\(difficultyLevel)"
        if let cached = cache[cacheKey] {
            return Array(cached.prefix(limit))
        }

        do {
            var examples = try LLDatabaseManager.shared.getExamples(
                forWordText: key,
                difficultyLevel: difficultyLevel,
                limit: limit
            ).map {
                LLWordExample(
                    id: "\($0.id ?? 0)",
                    wordText: $0.wordText,
                    sentenceEn: $0.sentenceEn,
                    sentenceCn: $0.sentenceCn,
                    heat: $0.heat,
                    difficultyLevel: $0.difficultyLevel
                )
            }

            // 生成内容缺失时，保留外部例句作为兜底，不影响正常学习。
            if examples.isEmpty {
                examples = try LLDatabaseManager.shared.getExamples(
                    forWordText: key,
                    difficultyLevel: 0,
                    limit: limit
                ).map {
                    LLWordExample(
                        id: "\($0.id ?? 0)",
                        wordText: $0.wordText,
                        sentenceEn: $0.sentenceEn,
                        sentenceCn: $0.sentenceCn,
                        heat: $0.heat,
                        difficultyLevel: $0.difficultyLevel
                    )
                }
            }

            cache[cacheKey] = examples
            return examples
        } catch {
            LLLogger.warn("⚠️ 按需加载例句失败：\(wordText), \(error)")
            cache[cacheKey] = []
            return []
        }
    }
}

/// 词库（兼容 qwerty-learner 等：name/trans/usphone/ukphone）
struct WordList: Codable, Identifiable {
    var id: String
    var name: String
    var category: String
    var language: LLLearningLanguage
    var entries: [LLWordEntry]
    var createdAt: Date
    var totalWords: Int? // 实际单词数量（用于列表页显示，避免加载所有单词）
    var isVocabularyNotebook: Bool = false

    init(id: String = UUID().uuidString, name: String, category: String = "未分类", language: LLLearningLanguage, entries: [LLWordEntry] = [], createdAt: Date = Date(), totalWords: Int? = nil, isVocabularyNotebook: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.language = language
        self.entries = entries
        self.createdAt = createdAt
        self.totalWords = totalWords
        self.isVocabularyNotebook = isVocabularyNotebook
    }

    var entryCount: Int { 
        // 优先使用 totalWords，如果没有则使用 entries.count
        totalWords ?? entries.count 
    }

    enum CodingKeys: String, CodingKey { case id, name, category, language, entries, createdAt, totalWords, isVocabularyNotebook }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "未分类"
        language = try c.decode(LLLearningLanguage.self, forKey: .language)
        entries = try c.decode([LLWordEntry].self, forKey: .entries)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        totalWords = try c.decodeIfPresent(Int.self, forKey: .totalWords)
        isVocabularyNotebook = try c.decodeIfPresent(Bool.self, forKey: .isVocabularyNotebook) ?? false
    }
}
