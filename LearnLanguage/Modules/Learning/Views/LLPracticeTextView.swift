import AppKit
import SnapKit

private final class LLPracticeTextDocument: NSView {
    override var isFlipped: Bool { true }
}

/// Wrapping text keeps the same panel usable for a single word or a long sentence.
final class LLPracticeTextView: NSView {
    private var displayedSession: LLPracticeSession?
    private var renderedSize = NSSize.zero
    private let label = NSTextField(wrappingLabelWithString: "")
    private let scrollView = NSScrollView()
    private let document = LLPracticeTextDocument()
    private var currentWordEnd = 0
    private var lastInputPosition = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.alignment = .center
        label.isSelectable = false
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = document
        document.addSubview(label)
        addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        if renderedSize != bounds.size, let displayedSession { render(displayedSession) }
    }

    override func scrollWheel(with event: NSEvent) { scrollView.scrollWheel(with: event) }

    func render(_ session: LLPracticeSession) {
        displayedSession = session
        let resized = renderedSize != bounds.size
        renderedSize = bounds.size
        let settings = LLSettingsStore.shared.settings
        let length = session.item?.text.count ?? 0
        var size = max(14, min(settings.floatingPanelFontSize, length > 75 ? 20 : 30))
        let width = bounds.width > 0 ? bounds.width : 360
        let height = bounds.height > 0 ? bounds.height : 88
        var result = attributedText(session, size: size)
        while size > 14 && result.boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).height > height {
            size -= 1
            result = attributedText(session, size: size)
        }
        label.attributedStringValue = result
        label.preferredMaxLayoutWidth = width
        let textHeight = ceil(result.boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).height) + 6
        document.frame = NSRect(x: 0, y: 0, width: width, height: max(height, textHeight))
        label.frame = NSRect(x: 0, y: max(0, (height - textHeight) / 2), width: width, height: textHeight)
        let position = "\(session.item?.id ?? ""):\(session.wordIndex):\(session.typedCount):\(session.isItemComplete)"
        if resized || position != lastInputPosition {
            if session.isItemComplete || session.wordIndex == 0 {
                document.scroll(NSPoint.zero)
            } else {
                let prefix = result.attributedSubstring(from: NSRange(location: 0, length: min(currentWordEnd, result.length)))
                let endY = prefix.boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).height
                document.scrollToVisible(NSRect(x: 0, y: max(0, endY - size * 1.8), width: width, height: size * 1.8 + 4))
            }
            lastInputPosition = position
        }
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
                if isCurrent { currentWordEnd = result.length }
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
            if wordIndex == session.wordIndex { currentWordEnd = result.length }
        }
        return result
    }
}
