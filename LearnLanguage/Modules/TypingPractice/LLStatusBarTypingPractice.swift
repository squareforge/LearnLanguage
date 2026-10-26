import AppKit

/// Compatibility entry point for the existing menu bar and keyboard shortcuts.
final class LLStatusBarTypingPractice {
    static let shared = LLStatusBarTypingPractice()
    private init() {}
    var isVisible: Bool { LLPracticePanelController.shared.isVisible }
    func show() { LLPracticePanelController.shared.resumeOrStart() }
    func hide() { LLPracticePanelController.shared.hide() }
    func toggleVisibility() { LLPracticePanelController.shared.toggleVisibility() }
    func syncWithStatusBarCurrentWord() { LLPracticePanelController.shared.syncVocabulary() }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
