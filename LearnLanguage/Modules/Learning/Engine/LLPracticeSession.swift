import Foundation

/// Both words and sentences use the same token input state machine.
final class LLPracticeSession {
    enum InputEvent { case ignored, correct, incorrect, itemCompleted }

    let source: LLPracticeSource
    private(set) var item: LLLearningItem?
    private(set) var tokens: [String] = []
    private(set) var wordIndex = 0
    private(set) var typedCount = 0
    private(set) var errorCount = 0
    private(set) var showHint: Bool
    private var defaultShowHint: Bool
    private var autoShowAnswerAfterErrors = 0
    private(set) var persistenceError: String?
    var errorMessage: String? { persistenceError ?? source.errorMessage }
    private(set) var usedHint = false
    private(set) var lastInputWasError = false
    private(set) var isAdvancing = false
    var reviewsMeaningBeforeAdvancing: Bool { source is LLCoursePracticeSource }
    var isMeaningRevealed: Bool { reviewsMeaningBeforeAdvancing && isItemComplete }

    init(source: LLPracticeSource, showHint: Bool) {
        self.source = source
        self.showHint = showHint
        defaultShowHint = showHint
        loadCurrentItem()
    }

    var currentToken: String { tokens.indices.contains(wordIndex) ? tokens[wordIndex] : "" }
    var isWordComplete: Bool { !currentToken.isEmpty && typedCount >= currentToken.count }
    var isItemComplete: Bool { !tokens.isEmpty && wordIndex == tokens.count - 1 && isWordComplete }
    var isFinished: Bool { item == nil }

    static func tokens(in text: String) -> [String] {
        text.replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    @discardableResult
    func input(_ character: Character) -> InputEvent {
        guard item != nil, !currentToken.isEmpty, !isWordComplete else { return .ignored }
        let normalized = character == "’" || character == "‘" ? Character("'") : character
        let target = Array(currentToken)[typedCount]
        if normalized.lowercased() == target.lowercased() {
            typedCount += 1
            lastInputWasError = false
            return isItemComplete ? .itemCompleted : .correct
        }
        errorCount += 1
        lastInputWasError = true
        typedCount = 0
        if autoShowAnswerAfterErrors > 0 && errorCount >= autoShowAnswerAfterErrors {
            showHint = true
            usedHint = true
        }
        return .incorrect
    }

    func backspace() {
        guard item != nil else { return }
        typedCount = max(0, typedCount - 1)
        lastInputWasError = false
    }

    /// Space/Return commits a completed token or saves the completed learning item.
    @discardableResult
    func confirm() -> Bool {
        guard isWordComplete else { return false }
        if isItemComplete {
            return finishCurrentItem(skipped: false)
        } else {
            wordIndex += 1
            typedCount = 0
            lastInputWasError = false
        }
        return true
    }

    func skip() { if item != nil { finishCurrentItem(skipped: true) } }

    func toggleHint() {
        showHint.toggle()
        if showHint { usedHint = true }
    }

    func applySettings(showHint: Bool, autoShowAnswerAfterErrors: Int) {
        if defaultShowHint != showHint {
            defaultShowHint = showHint
            self.showHint = showHint
        }
        self.autoShowAnswerAfterErrors = autoShowAnswerAfterErrors >= 999 ? 0 : max(0, autoShowAnswerAfterErrors)
    }

    func replay() {
        source.replay()
        loadCurrentItem()
    }

    func syncCurrentItem() {
        guard !isAdvancing, source.currentItem?.id != item?.id else { return }
        loadCurrentItem()
    }

    @discardableResult
    private func finishCurrentItem(skipped: Bool) -> Bool {
        guard let item else { return false }
        isAdvancing = true
        defer { isAdvancing = false }
        do {
            try source.advance(result: LLPracticeResult(itemID: item.id, errorCount: errorCount, usedHint: usedHint, skipped: skipped))
            loadCurrentItem()
            return true
        } catch {
            persistenceError = error.localizedDescription
            return false
        }
    }

    private func loadCurrentItem() {
        item = source.currentItem
        tokens = Self.tokens(in: item?.text ?? "")
        wordIndex = 0
        typedCount = 0
        errorCount = 0
        showHint = defaultShowHint
        usedHint = false
        lastInputWasError = false
        persistenceError = nil
    }
}
