//
//  LLSettingsTabViewController.swift
//  LearnLanguage
//

import AppKit
import SnapKit
import LaunchAtLogin

final class LLSettingsTabViewController: NSViewController {
    
    // MARK: - Constants
    
    private let availableFonts = [
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
    
    private let fontSizes: [CGFloat] = [24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64, 72]

    // MARK: - UI Components
    
    private lazy var scrollView: NSScrollView = {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        return scroll
    }()
    
    private lazy var contentView: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: NSLocalizedString("Learning Settings", comment: ""))
        label.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        label.textColor = NSColor(white: 0.11, alpha: 1.0)
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        return label
    }()
    
    // 学习目标卡片
    private var newWordsField: NSTextField!
    
    // 状态栏设置卡片
    private var statusBarDisplayPopup: NSPopUpButton!
    private var statusBarPhoneticCheck: NSButton!
    private var statusBarMaxLengthField: NSTextField!
    private var statusBarShowContentCheck: NSButton!
    private var statusBarContentWidthSlider: NSSlider!
    private var statusBarContentWidthLabel: NSTextField!
    private var showFeedbackButtonsCheck: NSButton!
    private var statusBarPlaybackIntervalPopup: NSPopUpButton!
    
    // 新增：状态栏显示内容细分控制
    private var statusBarShowWordCheck: NSButton!
    private var statusBarShowPhoneticSymbolCheck: NSButton!
    private var statusBarShowMeaningCheck: NSButton!
    private var statusBarAutoScrollCheck: NSButton!
    
    // 复习设置卡片
    private var reviewModePopup: NSPopUpButton!
    private var wrongWordRetryField: NSTextField!
    
    // 发音设置卡片
    private var pronunciationCheck: NSButton!
    private var chineseMeaningPronunciationCheck: NSButton!
    private var exampleSentencePronunciationCheck: NSButton!
    private var exampleSentenceTranslationPronunciationCheck: NSButton!
    private var randomPronunciationCheck: NSButton!
    private var pronunciationOrderSegment: NSSegmentedControl!
    private var pronunciationLanguageIntervalSlider: NSSlider!
    private var pronunciationLanguageIntervalLabel: NSTextField!
    private var pronunciationProviderPopup: NSPopUpButton!
    private var pronunciationAccentPopup: NSPopUpButton!
    private var pronunciationRatePopup: NSPopUpButton!
    private var appAudioVolumeSlider: NSSlider!
    private var appAudioVolumeLabel: NSTextField!
    
    // 浮窗设置卡片
    private var panelAlphaSlider: NSSlider!
    private var panelWidthField: NSTextField!
    private var panelHeightField: NSTextField!
    private var panelFontPopup: NSPopUpButton!
    private var panelFontSizePopup: NSPopUpButton!
    private var fontPreviewLabel: NSTextField!
    private var typingDictationModeCheck: NSButton!
    private var typingPracticeShowMeaningCheck: NSButton!
    private var typingFollowLetterSoundCheck: NSButton!
    private var typingInputStylePopup: NSPopUpButton!
    private var autoShowAnswerPopup: NSPopUpButton!
    
    // 快捷键设置卡片（动态创建，无需存储引用）

    // 翻译设置卡片
    private var translateDoubleCopyCheck: NSButton!
    private var translateDoubleCopyIntervalStepper: NSStepper!
    private var translateDoubleCopyIntervalLabel: NSTextField!
    private var translateClipboardOCRCheck: NSButton!
    private var translateLanguageDirectionSegment: NSSegmentedControl!
    private var translateFontSizeSlider: NSSlider!
    private var translateFontSizeLabel: NSTextField!

    // 其他设置卡片
    private var launchAtLoginCheck: NSButton!
    private var displayLanguagePopup: NSPopUpButton!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        
        // 添加标题
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(28)
            make.leading.equalToSuperview().offset(28)
        }
        
        // 设置滚动视图
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
            make.leading.equalToSuperview().offset(28)
            make.trailing.equalToSuperview().offset(-28)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        // 创建卡片
        let cardsStack = NSStackView()
        cardsStack.orientation = .vertical
        cardsStack.spacing = 20
        cardsStack.alignment = .leading
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // 1. 学习目标卡片
        let goalCard = createGoalCard()
        cardsStack.addArrangedSubview(goalCard)
        
        // 2. 状态栏设置卡片
        let statusBarCard = createStatusBarCard()
        cardsStack.addArrangedSubview(statusBarCard)
        
        // 3. 复习设置卡片
        let reviewCard = createReviewCard()
        cardsStack.addArrangedSubview(reviewCard)
        
        // 4. 发音设置卡片
        let pronunciationCard = createPronunciationCard()
        cardsStack.addArrangedSubview(pronunciationCard)
        
        // 5. 浮窗设置卡片
        let floatingPanelCard = createFloatingPanelCard()
        cardsStack.addArrangedSubview(floatingPanelCard)
        
        // 6. 快捷键设置卡片
        let shortcutCard = createShortcutCard()
        cardsStack.addArrangedSubview(shortcutCard)
        
        // 7. 翻译设置卡片
        let translationCard = createTranslationCard()
        cardsStack.addArrangedSubview(translationCard)
        
        // 8. 其他设置卡片
        let otherCard = createOtherCard()
        cardsStack.addArrangedSubview(otherCard)
        
        contentView.addSubview(cardsStack)
        scrollView.documentView = contentView
        
        contentView.snp.makeConstraints { make in
            make.width.equalTo(scrollView.contentView)
        }
        
        // 设置所有卡片宽度跟随父容器
        [goalCard, statusBarCard, reviewCard, pronunciationCard, floatingPanelCard, shortcutCard, translationCard, otherCard].forEach { card in
            card.snp.makeConstraints { make in
                make.width.equalTo(cardsStack)
            }
        }
        
        cardsStack.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
            make.width.equalTo(contentView)
        }
    }
    
    // MARK: - Create Cards
    
    private func createGoalCard() -> LLSettingsCardView {
        let card = LLSettingsCardView(title: NSLocalizedString("Learning Settings", comment: ""), icon: "🎯")
        
        newWordsField = createNumberField(value: "20")
        
        card.addFormItem(label: NSLocalizedString("Daily New Words", comment: ""), control: newWordsField)
        
        return card
    }
    
    private func createStatusBarCard() -> LLSettingsCardView {
        let card = LLSettingsCardView(title: NSLocalizedString("Status Bar Settings", comment: ""), icon: "🔔")
        
        statusBarDisplayPopup = NSPopUpButton()
        statusBarDisplayPopup.target = self
        statusBarDisplayPopup.action = #selector(saveSettings)
        statusBarDisplayPopup.addItems(withTitles: [
            NSLocalizedString("Status Bar Word Only", comment: ""),
            NSLocalizedString("Status Bar Word Phonetic", comment: ""),
            NSLocalizedString("Status Bar Word Meaning", comment: "")
        ])
        
        statusBarPhoneticCheck = NSButton(checkboxWithTitle: NSLocalizedString("Show Phonetic", comment: ""), target: self, action: #selector(saveSettings))
        
        statusBarMaxLengthField = createNumberField(value: "20")
        
        // 新增：状态栏是否显示内容
        statusBarShowContentCheck = NSButton(checkboxWithTitle: NSLocalizedString("Show Content", comment: ""), target: self, action: #selector(saveSettings))
        
        // 新增：状态栏显示内容细分控制
        statusBarShowWordCheck = NSButton(checkboxWithTitle: NSLocalizedString("Show Word", comment: ""), target: self, action: #selector(saveSettings))
        statusBarShowPhoneticSymbolCheck = NSButton(checkboxWithTitle: NSLocalizedString("Show Phonetic", comment: ""), target: self, action: #selector(saveSettings))
        statusBarShowMeaningCheck = NSButton(checkboxWithTitle: NSLocalizedString("Show Meaning", comment: ""), target: self, action: #selector(saveSettings))
        statusBarAutoScrollCheck = NSButton(checkboxWithTitle: NSLocalizedString("Auto Scroll", comment: ""), target: self, action: #selector(saveSettings))
        
        // 创建显示内容选项的水平布局
        let displayOptionsStack = NSStackView(views: [
            statusBarShowWordCheck,
            statusBarShowPhoneticSymbolCheck,
            statusBarShowMeaningCheck
        ])
        displayOptionsStack.orientation = .horizontal
        displayOptionsStack.spacing = 16
        displayOptionsStack.distribution = .fillEqually
        
        // 新增：状态栏内容宽度滑块
        statusBarContentWidthSlider = NSSlider(value: 150, minValue: 135, maxValue: 300, target: self, action: #selector(onStatusBarWidthChanged))
        statusBarContentWidthSlider.isContinuous = true
        
        statusBarContentWidthLabel = NSTextField(labelWithString: "150")
        statusBarContentWidthLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        statusBarContentWidthLabel.textColor = NSColor(white: 0.4, alpha: 1.0)
        statusBarContentWidthLabel.alignment = .right
        statusBarContentWidthLabel.snp.makeConstraints { make in
            make.width.equalTo(40)
        }
        
        let widthSliderStack = NSStackView(views: [statusBarContentWidthSlider, statusBarContentWidthLabel])
        widthSliderStack.orientation = .horizontal
        widthSliderStack.spacing = 8
        widthSliderStack.distribution = .fill
        statusBarContentWidthSlider.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(200)
        }
        
        // 新增：是否显示反馈按钮
        showFeedbackButtonsCheck = NSButton(checkboxWithTitle: NSLocalizedString("Show Feedback Buttons", comment: ""), target: self, action: #selector(saveSettings))
        
        card.addFormItem(label: NSLocalizedString("Show Content", comment: ""), control: displayOptionsStack)
        card.addFormItem(label: NSLocalizedString("Auto Scroll", comment: ""), control: statusBarAutoScrollCheck)
        card.addFormItem(label: NSLocalizedString("Status Bar Width", comment: ""), control: widthSliderStack)
        card.addFormItem(label: NSLocalizedString("Show Feedback Buttons", comment: ""), control: showFeedbackButtonsCheck)
        
        return card
    }
    
    private func createReviewCard() -> LLSettingsCardView {
        let card = LLSettingsCardView(title: NSLocalizedString("Review Settings", comment: ""), icon: "🔄")
        
        reviewModePopup = NSPopUpButton()
        reviewModePopup.target = self
        reviewModePopup.action = #selector(saveSettings)
        reviewModePopup.addItems(withTitles: [
            NSLocalizedString("Review Mode Simple", comment: ""),
            NSLocalizedString("Review Mode Ebbinghaus", comment: "")
        ])
        
        wrongWordRetryField = createNumberField(value: "3")
        
        card.addFormItem(label: NSLocalizedString("Review Interval Rule", comment: ""), control: reviewModePopup)
        card.addFormItem(label: NSLocalizedString("Wrong Word Retry", comment: ""), control: wrongWordRetryField)
        
        return card
    }
    
    private func createPronunciationCard() -> LLSettingsCardView {
        let card = LLSettingsCardView(title: NSLocalizedString("Pronunciation Settings", comment: ""), icon: "🔊")
        
        pronunciationCheck = NSButton(checkboxWithTitle: NSLocalizedString("English Pronunciation", comment: ""), target: self, action: #selector(onPronunciationModeChanged(_:)))
        chineseMeaningPronunciationCheck = NSButton(checkboxWithTitle: NSLocalizedString("Chinese Meaning Pronunciation", comment: ""), target: self, action: #selector(onPronunciationModeChanged(_:)))
        exampleSentencePronunciationCheck = NSButton(checkboxWithTitle: "英文例句", target: self, action: #selector(onPronunciationModeChanged(_:)))
        exampleSentenceTranslationPronunciationCheck = NSButton(checkboxWithTitle: "例句中文", target: self, action: #selector(onPronunciationModeChanged(_:)))
        randomPronunciationCheck = NSButton(checkboxWithTitle: NSLocalizedString("Random Pronunciation", comment: ""), target: self, action: #selector(onPronunciationModeChanged(_:)))
        
        pronunciationOrderSegment = NSSegmentedControl(labels: LLPronunciationOrder.allDisplayNames, trackingMode: .selectOne, target: self, action: #selector(saveSettings))

        pronunciationLanguageIntervalSlider = NSSlider(value: 0.5, minValue: 0, maxValue: 5, target: self, action: #selector(onPronunciationLanguageIntervalChanged))
        pronunciationLanguageIntervalSlider.isContinuous = true

        pronunciationLanguageIntervalLabel = NSTextField(labelWithString: "0.5s")
        pronunciationLanguageIntervalLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        pronunciationLanguageIntervalLabel.textColor = NSColor(white: 0.4, alpha: 1.0)
        pronunciationLanguageIntervalLabel.alignment = .right

        let languageIntervalStack = NSStackView(views: [pronunciationLanguageIntervalSlider, pronunciationLanguageIntervalLabel])
        languageIntervalStack.orientation = .horizontal
        languageIntervalStack.spacing = 8
        languageIntervalStack.alignment = .centerY
        languageIntervalStack.distribution = .fill
        pronunciationLanguageIntervalLabel.snp.makeConstraints { make in
            make.width.equalTo(44)
        }
        pronunciationLanguageIntervalSlider.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(200)
        }
        
        pronunciationProviderPopup = NSPopUpButton()
        pronunciationProviderPopup.target = self
        pronunciationProviderPopup.action = #selector(saveSettings)
        for provider in LLPronunciationProvider.allCases {
            pronunciationProviderPopup.addItem(withTitle: provider.displayName)
        }
        
        pronunciationAccentPopup = NSPopUpButton()
        pronunciationAccentPopup.target = self
        pronunciationAccentPopup.action = #selector(saveSettings)
        for accent in LLPronunciationAccent.allCases {
            pronunciationAccentPopup.addItem(withTitle: "\(accent.flag) \(accent.displayName)")
        }
        
        pronunciationRatePopup = NSPopUpButton()
        pronunciationRatePopup.target = self
        pronunciationRatePopup.action = #selector(saveSettings)
        pronunciationRatePopup.addItems(withTitles: LLSpeechRate.allDisplayNames)
        
        // 播放间隔设置（从状态栏设置移至此处）
        statusBarPlaybackIntervalPopup = NSPopUpButton()
        statusBarPlaybackIntervalPopup.target = self
        statusBarPlaybackIntervalPopup.action = #selector(saveSettings)
        statusBarPlaybackIntervalPopup.addItems(withTitles: LLPlaybackInterval.allDisplayNames)
        
        appAudioVolumeSlider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: self, action: #selector(onAppAudioVolumeChanged))
        appAudioVolumeSlider.isContinuous = true
        
        appAudioVolumeLabel = NSTextField(labelWithString: "100%")
        appAudioVolumeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        appAudioVolumeLabel.textColor = NSColor(white: 0.4, alpha: 1.0)
        appAudioVolumeLabel.alignment = .right
        appAudioVolumeLabel.snp.makeConstraints { make in
            make.width.equalTo(44)
        }
        
        let volumeStack = NSStackView(views: [appAudioVolumeSlider, appAudioVolumeLabel])
        volumeStack.orientation = .horizontal
        volumeStack.spacing = 8
        volumeStack.distribution = .fill
        appAudioVolumeSlider.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(200)
        }

        let pronunciationModeStack = NSStackView(views: [
            pronunciationCheck,
            chineseMeaningPronunciationCheck,
            exampleSentencePronunciationCheck,
            exampleSentenceTranslationPronunciationCheck,
            randomPronunciationCheck
        ])
        pronunciationModeStack.orientation = .horizontal
        pronunciationModeStack.spacing = 14
        pronunciationModeStack.alignment = .centerY
        card.addFormItem(label: NSLocalizedString("Pronunciation Mode", comment: ""), control: pronunciationModeStack)
        card.addFormItem(label: NSLocalizedString("Pronunciation Order", comment: ""), control: pronunciationOrderSegment)
        card.addFormItem(label: NSLocalizedString("Pronunciation Language Interval", comment: ""), control: languageIntervalStack)
        card.addNote(NSLocalizedString("Pronunciation Privacy Note", comment: ""))
        card.addFormRow(items: [
            (label: NSLocalizedString("Pronunciation Provider", comment: ""), control: pronunciationProviderPopup),
            (label: NSLocalizedString("Pronunciation Accent", comment: ""), control: pronunciationAccentPopup)
        ])
        card.addFormItem(label: NSLocalizedString("Speech Rate", comment: ""), control: pronunciationRatePopup)
        card.addFormItem(label: NSLocalizedString("Playback Interval", comment: ""), control: statusBarPlaybackIntervalPopup)
        card.addFormItem(label: NSLocalizedString("Playback Volume", comment: ""), control: volumeStack)
        
        return card
    }
    
    private func createFloatingPanelCard() -> LLSettingsCardView {
        let card = LLSettingsCardView(title: NSLocalizedString("Floating Panel Settings", comment: ""), icon: "🪟")
        
        panelAlphaSlider = NSSlider(value: 0.55, minValue: 0.2, maxValue: 1, target: self, action: #selector(saveSettings))
        panelAlphaSlider.isContinuous = true
        
        panelWidthField = createNumberField(value: "400")
        panelHeightField = createNumberField(value: "200")
        
        // 字体选择
        panelFontPopup = NSPopUpButton()
        panelFontPopup.target = self
        panelFontPopup.action = #selector(onFontSettingChanged)
        for fontName in LLAvailableFonts {
            panelFontPopup.addItem(withTitle: fontName)
            if let font = NSFont(name: fontName, size: 13) {
                panelFontPopup.lastItem?.attributedTitle = NSAttributedString(
                    string: fontName,
                    attributes: [.font: font]
                )
            }
        }
        
        // 字号选择
        panelFontSizePopup = NSPopUpButton()
        panelFontSizePopup.target = self
        panelFontSizePopup.action = #selector(onFontSettingChanged)
        for size in LLAvailableFontSizes {
            panelFontSizePopup.addItem(withTitle: "\(Int(size)) pt")
        }
        
        // 字体预览
        fontPreviewLabel = NSTextField(labelWithString: "ABCDEFG abcdefg")
        fontPreviewLabel.alignment = .center
        fontPreviewLabel.textColor = .labelColor
        fontPreviewLabel.drawsBackground = true
        fontPreviewLabel.backgroundColor = NSColor(white: 0.0, alpha: 0.05)
        fontPreviewLabel.wantsLayer = true
        fontPreviewLabel.layer?.cornerRadius = 6
        fontPreviewLabel.isBezeled = false
        
        typingDictationModeCheck = NSButton(checkboxWithTitle: NSLocalizedString("Dictation Mode", comment: ""), target: self, action: #selector(saveSettings))
        typingPracticeShowMeaningCheck = NSButton(checkboxWithTitle: NSLocalizedString("Show Meaning", comment: ""), target: self, action: #selector(saveSettings))
        typingFollowLetterSoundCheck = NSButton(checkboxWithTitle: "跟播字母发音", target: self, action: #selector(saveSettings))
        
        let typingStack = NSStackView(views: [typingDictationModeCheck, typingPracticeShowMeaningCheck, typingFollowLetterSoundCheck])
        typingStack.orientation = .horizontal
        typingStack.spacing = 16
        
        typingInputStylePopup = NSPopUpButton()
        typingInputStylePopup.target = self
        typingInputStylePopup.action = #selector(saveSettings)
        for style in LLTypingInputStyle.allCases {
            typingInputStylePopup.addItem(withTitle: style.displayName)
        }
        
        autoShowAnswerPopup = NSPopUpButton()
        autoShowAnswerPopup.target = self
        autoShowAnswerPopup.action = #selector(saveSettings)
        autoShowAnswerPopup.addItems(withTitles: LLAutoShowAnswerOption.allDisplayNames)
        
        card.addFormItem(label: NSLocalizedString("Panel Alpha", comment: ""), control: panelAlphaSlider)
        card.addFormRow(items: [
            (label: NSLocalizedString("Panel Width", comment: ""), control: panelWidthField),
            (label: NSLocalizedString("Panel Height", comment: ""), control: panelHeightField)
        ])
        card.addFormRow(items: [
            (label: NSLocalizedString("Font", comment: ""), control: panelFontPopup),
            (label: NSLocalizedString("Font Size", comment: ""), control: panelFontSizePopup)
        ])
        card.addFormItem(label: NSLocalizedString("Font Preview", comment: ""), control: fontPreviewLabel)
        card.addFormItem(label: NSLocalizedString("Typing Practice", comment: ""), control: typingStack)
        card.addFormItem(label: NSLocalizedString("Input Style", comment: ""), control: typingInputStylePopup)
        card.addFormItem(label: NSLocalizedString("Auto Show Answer", comment: ""), control: autoShowAnswerPopup)
        
        return card
    }
    
    private func createShortcutCard() -> LLSettingsCardView {
        let card = LLSettingsCardView(title: NSLocalizedString("Keyboard Shortcuts", comment: ""), icon: "⌨️")
        
        let config = LLSettingsStore.shared.settings.shortcutConfig
        
        let actions: [(label: String, keyPath: WritableKeyPath<LLShortcutConfig, LLKeyCombo>, id: String)] = [
            (NSLocalizedString("Shortcut Show Main Window", comment: ""),  \.showMainWindow,    "showMainWindow"),
            (NSLocalizedString("Shortcut Next Word", comment: ""),         \.nextWord,          "nextWord"),
            (NSLocalizedString("Shortcut Mark Know", comment: ""),         \.markKnow,          "markKnow"),
            (NSLocalizedString("Shortcut Mark Unclear", comment: ""),      \.markUnclear,       "markUnclear"),
            (NSLocalizedString("Shortcut Mark Unknown", comment: ""),      \.markUnknown,       "markUnknown"),
            (NSLocalizedString("Shortcut Play Pronunciation", comment: ""),\.playPronunciation, "playPronunciation"),
            (NSLocalizedString("Shortcut Toggle Typing", comment: ""),     \.toggleTypingMode,  "toggleTypingMode"),
        ]
        
        for action in actions {
            let recorder = LLShortcutRecorderView(frame: NSRect(x: 0, y: 0, width: 160, height: 28))
            recorder.keyCombo = config[keyPath: action.keyPath]
            let keyPath = action.keyPath
            recorder.onChanged = { newCombo in
                var s = LLSettingsStore.shared.settings
                s.shortcutConfig[keyPath: keyPath] = newCombo
                LLSettingsStore.shared.settings = s
                LLKeyboardShortcutManager.shared.registerAll()
            }
            card.addFormItemInline(label: action.label, control: recorder)
        }
        
        return card
    }
    
    private func createTranslationCard() -> LLSettingsCardView {
        let card = LLSettingsCardView(title: NSLocalizedString("Translation Settings", comment: ""), icon: "🌐")

        // 两次 ⌘+C 翻译开关
        translateDoubleCopyCheck = NSButton(checkboxWithTitle: NSLocalizedString("Double Copy Translate", comment: ""), target: self, action: #selector(saveSettings))

        // 时间间隔：步进器 + 数值标签
        translateDoubleCopyIntervalStepper = NSStepper()
        translateDoubleCopyIntervalStepper.minValue = 0.1
        translateDoubleCopyIntervalStepper.maxValue = 2.0
        translateDoubleCopyIntervalStepper.increment = 0.05
        translateDoubleCopyIntervalStepper.valueWraps = false
        translateDoubleCopyIntervalStepper.target = self
        translateDoubleCopyIntervalStepper.action = #selector(onDoubleCopyIntervalChanged)

        translateDoubleCopyIntervalLabel = NSTextField(labelWithString: "0.50s")
        translateDoubleCopyIntervalLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        translateDoubleCopyIntervalLabel.textColor = NSColor(white: 0.4, alpha: 1.0)
        translateDoubleCopyIntervalLabel.alignment = .right
        translateDoubleCopyIntervalLabel.snp.makeConstraints { make in
            make.width.equalTo(44)
        }

        let intervalStack = NSStackView(views: [translateDoubleCopyIntervalLabel, translateDoubleCopyIntervalStepper])
        intervalStack.orientation = .horizontal
        intervalStack.spacing = 6
        intervalStack.alignment = .centerY

        // 剪贴板截图 OCR 翻译
        translateClipboardOCRCheck = NSButton(checkboxWithTitle: NSLocalizedString("Clipboard OCR Translate", comment: ""), target: self, action: #selector(saveSettings))

        // 翻译方向
        translateLanguageDirectionSegment = NSSegmentedControl(labels: ["EN → 中文", "中文 → EN"], trackingMode: .selectOne, target: self, action: #selector(saveSettings))
        translateLanguageDirectionSegment.selectedSegment = 0

        // 翻译结果字体大小
        translateFontSizeSlider = NSSlider(value: 14, minValue: 10, maxValue: 30, target: self, action: #selector(onTranslateFontSizeChanged))
        translateFontSizeSlider.isContinuous = true

        translateFontSizeLabel = NSTextField(labelWithString: "14 pt")
        translateFontSizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        translateFontSizeLabel.textColor = NSColor(white: 0.4, alpha: 1.0)
        translateFontSizeLabel.alignment = .right
        translateFontSizeLabel.snp.makeConstraints { make in
            make.width.equalTo(40)
        }

        let fontSizeStack = NSStackView(views: [translateFontSizeSlider, translateFontSizeLabel])
        fontSizeStack.orientation = .horizontal
        fontSizeStack.spacing = 8
        fontSizeStack.distribution = .fill
        translateFontSizeSlider.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(200)
        }

        card.addFormItem(label: NSLocalizedString("Double Copy Translate", comment: ""), control: translateDoubleCopyCheck)
        card.addNote(NSLocalizedString("Double Copy Privacy Note", comment: ""))
        card.addFormItem(label: NSLocalizedString("Double Copy Interval", comment: ""), control: intervalStack)
        card.addFormItem(label: NSLocalizedString("Clipboard OCR Translate", comment: ""), control: translateClipboardOCRCheck)
        card.addNote(NSLocalizedString("Clipboard OCR Privacy Note", comment: ""))
        card.addFormItem(label: NSLocalizedString("Translate Direction", comment: ""), control: translateLanguageDirectionSegment)
        card.addFormItem(label: NSLocalizedString("Translate Font Size", comment: ""), control: fontSizeStack)

        return card
    }

    @objc private func onDoubleCopyIntervalChanged() {
        let val = translateDoubleCopyIntervalStepper.doubleValue
        translateDoubleCopyIntervalLabel.stringValue = String(format: "%.2fs", val)
        saveSettings()
    }

    @objc private func onTranslateFontSizeChanged() {
        let val = Int(translateFontSizeSlider.doubleValue)
        translateFontSizeLabel.stringValue = "\(val) pt"
        saveSettings()
    }
    
    @objc private func onAppAudioVolumeChanged() {
        let value = Int(appAudioVolumeSlider.doubleValue.rounded())
        appAudioVolumeLabel.stringValue = "\(value)%"
        saveSettings()
    }

    @objc private func onPronunciationLanguageIntervalChanged() {
        let value = (pronunciationLanguageIntervalSlider.doubleValue * 10).rounded() / 10
        pronunciationLanguageIntervalSlider.doubleValue = value
        pronunciationLanguageIntervalLabel.stringValue = String(format: "%.1fs", value)
        saveSettings()
    }
    
    private func updatePronunciationOrderSegmentState() {
        let hasBothOrderedModes = pronunciationCheck.state == .on
            && chineseMeaningPronunciationCheck.state == .on
            && randomPronunciationCheck.state != .on
        pronunciationOrderSegment.isEnabled = hasBothOrderedModes
        pronunciationLanguageIntervalSlider.isEnabled = hasBothOrderedModes
        pronunciationLanguageIntervalLabel.textColor = hasBothOrderedModes ? NSColor(white: 0.4, alpha: 1.0) : NSColor.disabledControlTextColor
    }

    private func createOtherCard() -> LLSettingsCardView {
        let card = LLSettingsCardView(title: NSLocalizedString("Other Settings", comment: ""), icon: "⚙️")
        
        launchAtLoginCheck = NSButton(checkboxWithTitle: NSLocalizedString("Launch at Login", comment: ""), target: self, action: #selector(toggleLaunchAtLogin))
        
        displayLanguagePopup = NSPopUpButton()
        displayLanguagePopup.target = self
        displayLanguagePopup.action = #selector(saveSettings)
        for language in LLDisplayLanguage.allCases {
            displayLanguagePopup.addItem(withTitle: language.displayName)
        }
        
        card.addFormItem(label: NSLocalizedString("Launch at Login", comment: ""), control: launchAtLoginCheck)
        card.addNote(NSLocalizedString("Launch at Login Privacy Note", comment: ""))
        card.addFormItem(label: NSLocalizedString("Display Language", comment: ""), control: displayLanguagePopup)
        
        return card
    }
    
    // MARK: - Helper Methods
    
    private func createNumberField(value: String) -> NSTextField {
        let field = NSTextField(string: value)
        field.font = NSFont.systemFont(ofSize: 14)
        field.placeholderString = NSLocalizedString("Number Field Placeholder", comment: "")
        field.target = self
        field.action = #selector(saveSettings)
        return field
    }

    
    // MARK: - Load & Save Settings
    
    private func loadSettings() {
        let s = LLSettingsStore.shared.settings
        
        // 显示语言
        if let index = LLDisplayLanguage.allCases.firstIndex(of: s.displayLanguage) {
            displayLanguagePopup.selectItem(at: index)
        }
        
        // 学习目标
        newWordsField.stringValue = "\(s.newWordsPerDay)"
        
        // 状态栏设置
        statusBarDisplayPopup.selectItem(at: s.statusBarShowPhonetic ? 1 : 0)
        statusBarPhoneticCheck.state = s.statusBarShowPhonetic ? .on : .off
        statusBarMaxLengthField.stringValue = "\(s.statusBarMaxLength)"
        statusBarShowContentCheck.state = s.statusBarShowContent ? .on : .off
        statusBarContentWidthSlider.integerValue = s.statusBarContentWidth
        statusBarContentWidthLabel.stringValue = "\(s.statusBarContentWidth)"
        showFeedbackButtonsCheck.state = s.showFeedbackButtons ? .on : .off
        
        // 新增：状态栏显示内容细分控制
        statusBarShowWordCheck.state = s.statusBarShowWord ? .on : .off
        statusBarShowPhoneticSymbolCheck.state = s.statusBarShowPhoneticSymbol ? .on : .off
        statusBarShowMeaningCheck.state = s.statusBarShowMeaning ? .on : .off
        statusBarAutoScrollCheck.state = s.statusBarAutoScroll ? .on : .off
        
        // 新增：播放间隔设置
        let playbackOption = LLPlaybackInterval.from(seconds: s.statusBarPlaybackInterval)
        if let index = LLPlaybackInterval.allCases.firstIndex(of: playbackOption) {
            statusBarPlaybackIntervalPopup.selectItem(at: index)
        }
        
        // 复习设置
        reviewModePopup.selectItem(at: 1)
        wrongWordRetryField.stringValue = "3"
        
        // 发音设置
        pronunciationCheck.state = s.pronunciationEnabled ? .on : .off
        chineseMeaningPronunciationCheck.state = s.chineseMeaningPronunciationEnabled ? .on : .off
        exampleSentencePronunciationCheck.state = s.exampleSentencePronunciationEnabled ? .on : .off
        exampleSentenceTranslationPronunciationCheck.state = s.exampleSentenceTranslationPronunciationEnabled ? .on : .off
        randomPronunciationCheck.state = s.randomPronunciationEnabled ? .on : .off
        if let index = LLPronunciationOrder.allCases.firstIndex(of: s.pronunciationOrder) {
            pronunciationOrderSegment.selectedSegment = index
        }
        let pronunciationLanguageInterval = min(max(s.pronunciationLanguageInterval, 0), 5)
        pronunciationLanguageIntervalSlider.doubleValue = pronunciationLanguageInterval
        pronunciationLanguageIntervalLabel.stringValue = String(format: "%.1fs", pronunciationLanguageInterval)
        updatePronunciationOrderSegmentState()
        if let index = LLPronunciationProvider.allCases.firstIndex(of: s.pronunciationProvider) {
            pronunciationProviderPopup.selectItem(at: index)
        }
        if let index = LLPronunciationAccent.allCases.firstIndex(of: s.pronunciationAccent) {
            pronunciationAccentPopup.selectItem(at: index)
        }
        let speechRate = LLSpeechRate.from(rate: s.pronunciationRate)
        if let index = LLSpeechRate.allCases.firstIndex(of: speechRate) {
            pronunciationRatePopup.selectItem(at: index)
        }
        appAudioVolumeSlider.doubleValue = Double(s.appAudioVolume * 100)
        appAudioVolumeLabel.stringValue = "\(Int((s.appAudioVolume * 100).rounded()))%"
        
        // 其他设置
        panelAlphaSlider.doubleValue = s.floatingPanelAlpha
        panelWidthField.stringValue = "\(Int(s.floatingPanelWidth))"
        panelHeightField.stringValue = "\(Int(s.floatingPanelHeight))"
        if let index = LLAvailableFonts.firstIndex(of: s.floatingPanelFontName) {
            panelFontPopup.selectItem(at: index)
        }
        if let index = LLAvailableFontSizes.firstIndex(of: s.floatingPanelFontSize) {
            panelFontSizePopup.selectItem(at: index)
        }
        typingDictationModeCheck.state = s.typingDictationMode ? .on : .off
        typingPracticeShowMeaningCheck.state = s.typingPracticeShowMeaning ? .on : .off
        typingFollowLetterSoundCheck.state = s.typingFollowLetterSoundEnabled ? .on : .off
        if let index = LLTypingInputStyle.allCases.firstIndex(of: s.typingInputStyle) {
            typingInputStylePopup.selectItem(at: index)
        }
        // 自动显示答案：使用枚举来映射
        let autoShowOption = LLAutoShowAnswerOption.from(errorCount: s.autoShowAnswerAfterErrors)
        if let index = LLAutoShowAnswerOption.allCases.firstIndex(of: autoShowOption) {
            autoShowAnswerPopup.selectItem(at: index)
        }
        
        launchAtLoginCheck.state = LaunchAtLogin.isEnabled ? .on : .off
        
        // 翻译设置
        translateDoubleCopyCheck.state = s.translateDoubleCopyEnabled ? .on : .off
        translateDoubleCopyIntervalStepper.doubleValue = s.translateDoubleCopyInterval
        translateDoubleCopyIntervalLabel.stringValue = String(format: "%.2fs", s.translateDoubleCopyInterval)
        translateClipboardOCRCheck.state = s.translateClipboardOCREnabled ? .on : .off
        translateLanguageDirectionSegment.selectedSegment = s.translateLanguageReversed ? 1 : 0
        translateFontSizeSlider.doubleValue = s.translateFontSize
        translateFontSizeLabel.stringValue = "\(Int(s.translateFontSize)) pt"
        
        // 初始化字体预览
        updateFontPreview()
    }

    private func updateFontPreview() {
        let fontIndex = panelFontPopup.indexOfSelectedItem
        let fontSizeIndex = panelFontSizePopup.indexOfSelectedItem
        let fontName = (fontIndex >= 0 && fontIndex < LLAvailableFonts.count) ? LLAvailableFonts[fontIndex] : ""
        let fontSize = (fontSizeIndex >= 0 && fontSizeIndex < LLAvailableFontSizes.count) ? LLAvailableFontSizes[fontSizeIndex] : 48
        let previewSize = min(fontSize, 36)
        if let font = NSFont(name: fontName, size: previewSize) {
            fontPreviewLabel.font = font
        } else {
            fontPreviewLabel.font = NSFont.systemFont(ofSize: previewSize)
        }
        fontPreviewLabel.stringValue = "ABCDEFG abcdefg"
    }

    @objc private func onFontSettingChanged() {
        updateFontPreview()
        saveSettings()
    }
    
    @objc private func onPronunciationModeChanged(_ sender: NSButton) {
        if sender === randomPronunciationCheck, sender.state == .on {
            pronunciationCheck.state = .off
            chineseMeaningPronunciationCheck.state = .off
            exampleSentencePronunciationCheck.state = .off
            exampleSentenceTranslationPronunciationCheck.state = .off
        } else if sender === exampleSentenceTranslationPronunciationCheck, sender.state == .on {
            exampleSentencePronunciationCheck.state = .on
            randomPronunciationCheck.state = .off
        } else if sender === exampleSentencePronunciationCheck, sender.state == .off {
            exampleSentenceTranslationPronunciationCheck.state = .off
        } else if sender.state == .on {
            randomPronunciationCheck.state = .off
        }
        saveSettings()
    }

    @objc private func saveSettings() {
        var s = LLSettingsStore.shared.settings
        
        // 显示语言
        let languageIndex = displayLanguagePopup.indexOfSelectedItem
        if languageIndex >= 0 && languageIndex < LLDisplayLanguage.allCases.count {
            let newLanguage = LLDisplayLanguage.allCases[languageIndex]
            if newLanguage != s.displayLanguage {
                s.displayLanguage = newLanguage
                LLLocalizationManager.shared.setLanguage(newLanguage)
                // 弹提示重启
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("Language Changed Title", comment: "")
                    alert.informativeText = NSLocalizedString("Language Changed Desc", comment: "")
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: NSLocalizedString("Restart Later", comment: ""))
                    alert.addButton(withTitle: NSLocalizedString("Quit Now", comment: ""))
                    if alert.runModal() == .alertSecondButtonReturn {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
        
        // 学习目标
        s.newWordsPerDay = min(max(Int(newWordsField.stringValue) ?? 20, LLAppSettings.dailyWordRange.lowerBound), LLAppSettings.dailyWordRange.upperBound)
        newWordsField.stringValue = String(s.newWordsPerDay)
        
        // 状态栏设置
        s.statusBarShowPhonetic = statusBarPhoneticCheck.state == .on
        s.statusBarMaxLength = Int(statusBarMaxLengthField.stringValue) ?? 20
        s.statusBarShowContent = statusBarShowContentCheck.state == .on
        s.statusBarContentWidth = statusBarContentWidthSlider.integerValue
        s.showFeedbackButtons = showFeedbackButtonsCheck.state == .on
        
        // 新增：状态栏显示内容细分控制
        s.statusBarShowWord = statusBarShowWordCheck.state == .on
        s.statusBarShowPhoneticSymbol = statusBarShowPhoneticSymbolCheck.state == .on
        s.statusBarShowMeaning = statusBarShowMeaningCheck.state == .on
        s.statusBarAutoScroll = statusBarAutoScrollCheck.state == .on
        
        // 新增：播放间隔设置
        let playbackIndex = statusBarPlaybackIntervalPopup.indexOfSelectedItem
        if playbackIndex >= 0 && playbackIndex < LLPlaybackInterval.allCases.count {
            s.statusBarPlaybackInterval = LLPlaybackInterval.allCases[playbackIndex].rawValue
        }
        
        // 发音设置
        if randomPronunciationCheck.state == .on {
            pronunciationCheck.state = .off
            chineseMeaningPronunciationCheck.state = .off
            exampleSentencePronunciationCheck.state = .off
            exampleSentenceTranslationPronunciationCheck.state = .off
        } else if pronunciationCheck.state == .on || chineseMeaningPronunciationCheck.state == .on {
            randomPronunciationCheck.state = .off
        } else if exampleSentencePronunciationCheck.state == .on || exampleSentenceTranslationPronunciationCheck.state == .on {
            randomPronunciationCheck.state = .off
        }
        if exampleSentencePronunciationCheck.state == .off {
            exampleSentenceTranslationPronunciationCheck.state = .off
        }
        s.pronunciationEnabled = pronunciationCheck.state == .on
        s.chineseMeaningPronunciationEnabled = chineseMeaningPronunciationCheck.state == .on
        s.exampleSentencePronunciationEnabled = exampleSentencePronunciationCheck.state == .on
        s.exampleSentenceTranslationPronunciationEnabled = exampleSentenceTranslationPronunciationCheck.state == .on
        s.randomPronunciationEnabled = randomPronunciationCheck.state == .on
        updatePronunciationOrderSegmentState()
        let pronunciationOrderIndex = pronunciationOrderSegment.selectedSegment
        if pronunciationOrderIndex >= 0 && pronunciationOrderIndex < LLPronunciationOrder.allCases.count {
            s.pronunciationOrder = LLPronunciationOrder.allCases[pronunciationOrderIndex]
        }
        s.pronunciationLanguageInterval = min(max(pronunciationLanguageIntervalSlider.doubleValue, 0), 5)
        let providerIndex = pronunciationProviderPopup.indexOfSelectedItem
        if providerIndex >= 0 && providerIndex < LLPronunciationProvider.allCases.count {
            s.pronunciationProvider = LLPronunciationProvider.allCases[providerIndex]
        }
        let accentIndex = pronunciationAccentPopup.indexOfSelectedItem
        if accentIndex >= 0 && accentIndex < LLPronunciationAccent.allCases.count {
            s.pronunciationAccent = LLPronunciationAccent.allCases[accentIndex]
        }
        let rateIndex = pronunciationRatePopup.indexOfSelectedItem
        if rateIndex >= 0 && rateIndex < LLSpeechRate.allCases.count {
            s.pronunciationRate = LLSpeechRate.allCases[rateIndex].rawValue
        }
        s.appAudioVolume = Float(appAudioVolumeSlider.doubleValue / 100.0)
        
        // 其他设置
        s.floatingPanelAlpha = panelAlphaSlider.doubleValue
        s.floatingPanelWidth = CGFloat(Int(panelWidthField.stringValue) ?? 400)
        s.floatingPanelHeight = CGFloat(Int(panelHeightField.stringValue) ?? 200)
        let fontIndex = panelFontPopup.indexOfSelectedItem
        if fontIndex >= 0 && fontIndex < LLAvailableFonts.count {
            s.floatingPanelFontName = LLAvailableFonts[fontIndex]
        }
        let fontSizeIndex = panelFontSizePopup.indexOfSelectedItem
        if fontSizeIndex >= 0 && fontSizeIndex < LLAvailableFontSizes.count {
            s.floatingPanelFontSize = LLAvailableFontSizes[fontSizeIndex]
        }
        s.typingDictationMode = typingDictationModeCheck.state == .on
        s.typingPracticeShowMeaning = typingPracticeShowMeaningCheck.state == .on
        s.typingFollowLetterSoundEnabled = typingFollowLetterSoundCheck.state == .on
        
        // 打字练习输入框样式
        let inputStyleIndex = typingInputStylePopup.indexOfSelectedItem
        if inputStyleIndex >= 0 && inputStyleIndex < LLTypingInputStyle.allCases.count {
            s.typingInputStyle = LLTypingInputStyle.allCases[inputStyleIndex]
        }
        
        // 自动显示答案
        let autoShowIndex = autoShowAnswerPopup.indexOfSelectedItem
        if autoShowIndex >= 0 && autoShowIndex < LLAutoShowAnswerOption.allCases.count {
            s.autoShowAnswerAfterErrors = LLAutoShowAnswerOption.allCases[autoShowIndex].rawValue
        }
        
        // 翻译设置
        s.translateDoubleCopyEnabled = translateDoubleCopyCheck.state == .on
        s.translateDoubleCopyInterval = translateDoubleCopyIntervalStepper.doubleValue
        s.translateClipboardOCREnabled = translateClipboardOCRCheck.state == .on
        s.translateLanguageReversed = translateLanguageDirectionSegment.selectedSegment == 1
        s.translateFontSize = CGFloat(Int(translateFontSizeSlider.doubleValue))
        
        LLSettingsStore.shared.settings = s
        NotificationCenter.default.post(name: .learnLanguageRefreshStatus, object: nil)
        
        // 发送通知更新浮窗（浮窗相关设置变化）
        NotificationCenter.default.post(name: .floatingPanelSettingsChanged, object: nil)
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.isEnabled = launchAtLoginCheck.state == .on
        var s = LLSettingsStore.shared.settings
        s.launchAtLogin = LaunchAtLogin.isEnabled
        LLSettingsStore.shared.settings = s
        LLLogger.info("开机自启动已\(LaunchAtLogin.isEnabled ? "开启" : "关闭")")
    }
    
    @objc private func onStatusBarWidthChanged() {
        let width = statusBarContentWidthSlider.integerValue
        statusBarContentWidthLabel.stringValue = "\(width)"
        saveSettings()
    }
}
