import AppKit
import SnapKit

/// Wrapping text keeps the same panel usable for a single word or a long sentence.
final class LLPracticeTextView: NSView {
    private var displayedSession: LLPracticeSession?
    private var renderedSize = NSSize.zero
    private let label = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.alignment = .center
        label.isSelectable = false
        label.maximumNumberOfLines = 5
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(label)
        label.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.top.greaterThanOrEqualToSuperview()
            $0.bottom.lessThanOrEqualToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        label.preferredMaxLayoutWidth = bounds.width
        if renderedSize != bounds.size, let displayedSession { render(displayedSession) }
    }

    func render(_ session: LLPracticeSession) {
        displayedSession = session
        renderedSize = bounds.size
        let settings = LLSettingsStore.shared.settings
        let length = session.item?.text.count ?? 0
        var size = max(14, min(settings.floatingPanelFontSize, length > 75 ? 20 : 30))
        let width = bounds.width > 0 ? bounds.width : 360
        let height = bounds.height > 0 ? bounds.height : 88
        var result = attributedText(session, size: size)
        while size > 12 && result.boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).height > height {
            size -= 1
            result = attributedText(session, size: size)
        }
        label.attributedStringValue = result
        label.toolTip = session.showHint ? session.item?.text : nil
        label.setAccessibilityLabel(session.showHint ? session.item?.text : "当前练习，答案已隐藏")
    }

    private func attributedText(_ session: LLPracticeSession, size: CGFloat) -> NSAttributedString {
        let settings = LLSettingsStore.shared.settings
        let font = LLAppearanceManager.appFont(name: settings.floatingPanelFontName, size: size, fallbackWeight: .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 6
        let result = NSMutableAttributedString(string: "")
        for (wordIndex, word) in session.tokens.enumerated() {
            if wordIndex > 0 { result.append(NSAttributedString(string: "  ", attributes: [.font: font])) }
            if settings.typingInputStyle == .wholeWord, !session.showHint, wordIndex >= session.wordIndex {
                let isCurrent = wordIndex == session.wordIndex
                let typed = isCurrent ? String(word.prefix(session.typedCount)) : ""
                let remaining = isCurrent ? max(0, word.count - session.typedCount) : word.count
                result.append(NSAttributedString(string: typed + (remaining > 0 ? "____" : ""), attributes: [
                    .font: font, .foregroundColor: session.lastInputWasError && isCurrent ? NSColor.systemRed : NSColor.labelColor,
                    .paragraphStyle: paragraph, .kern: 1
                ]))
                continue
            }
            for (charIndex, char) in word.enumerated() {
                let completed = wordIndex < session.wordIndex || (wordIndex == session.wordIndex && charIndex < session.typedCount)
                let current = wordIndex == session.wordIndex
                let visible = completed || session.showHint
                let color: NSColor = completed ? .labelColor : current ? .secondaryLabelColor : .tertiaryLabelColor
                var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph, .kern: 1]
                if current {
                    attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    attributes[.underlineColor] = session.lastInputWasError ? NSColor.systemRed : NSColor.controlAccentColor.withAlphaComponent(0.6)
                }
                result.append(NSAttributedString(string: visible ? String(char) : "_", attributes: attributes))
            }
        }
        return result
    }
}
