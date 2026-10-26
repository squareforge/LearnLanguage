import AppKit

@main
struct PracticeUITests {
    static var assertions = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        if !condition() { fatalError(message) }
    }
    static func pump(_ seconds: TimeInterval = 0.1) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    }
    static func send(_ text: String, keyCode: UInt16 = 0, isRepeat: Bool = false, to panel: NSWindow) {
        let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: isRepeat, keyCode: keyCode)!
        panel.sendEvent(key)
    }
    static func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: false) { _ in
            do { try runChecks(); exit(0) }
            catch { fatalError("Native practice UI checks failed: \(error)") }
        }
        app.run()
    }
    static func runChecks() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        LLSettingsStore.shared.currentListId = "vocabulary"
        LLSettingsStore.shared.settings.statusBarPlaybackInterval = 1
        LLSettingsStore.shared.settings.typingPracticeShowMeaning = true
        LLStatusBarManager.shared.setupStatusBar()
        LLPronunciationManager.shared.spoken.removeAll()
        let controller = LLPracticePanelController.shared
        let course = LLSentenceCourse(id: "ui-course", category: "test", title: "测试课程", words: [
            .init(en: "I", zh: "我", ipa: nil),
            .init(en: "like the food", zh: "喜欢食物", ipa: nil)
        ])
        let main = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 700, height: 500), styleMask: [.titled], backing: .buffered, defer: false)
        main.isReleasedWhenClosed = false
        main.makeKeyAndOrderFront(nil)
        main.orderOut(nil)
        app.setActivationPolicy(.accessory)
        controller.start(source: LLCoursePracticeSource(course: course))
        pump()
        let panel = app.windows.first { $0.title.contains("测试课程") }!
        check(controller.session?.item?.text == "I", "Starting a course selects its first item")
        check(panel.isVisible, "Course opens the shared practice panel")
        check(panel.isKeyWindow, "The practice panel becomes the key window after the main window hides")
        check(LLPronunciationManager.shared.spoken == ["I"], "Entering a course stops vocabulary and starts only its own audio")
        check(LLStatusBarContentView.displayedWord == "I", "The menu bar switches from vocabulary to the course item")
        check(!LLStatusBarContentView.allowsFeedback, "Course mode removes vocabulary-only feedback controls")
        let surface = panel.initialFirstResponder!
        let meaning = descendants(surface).compactMap { $0 as? NSTextField }.first { $0.stringValue == "我" }!
        check(meaning.isHidden, "Course meanings start hidden even when vocabulary meanings are enabled")
        let display = descendants(surface).compactMap { $0 as? LLPracticeTextView }.first!
        let displayPoint = display.convert(NSPoint(x: display.bounds.midX, y: display.bounds.midY), to: surface.superview)
        check(surface.hitTest(displayPoint) === surface, "Clicking the displayed sentence targets the typing surface instead of a label editor")
        let replayButton = descendants(surface).compactMap { $0 as? NSButton }.first!
        let replayPoint = replayButton.convert(NSPoint(x: replayButton.bounds.midX, y: replayButton.bounds.midY), to: surface.superview)
        check(surface.hitTest(replayPoint) !== surface, "Practice controls remain clickable beside the typing surface")
        check(LLStatusBarManager.shared.getCurrentWord() == nil, "Course mode clears the old vocabulary action target")
        send("i", keyCode: 34, to: panel)
        check(controller.session?.isItemComplete == true, "A key event delivered through NSWindow reaches the course session")
        let beforeReview = LLPronunciationManager.shared.spoken.count
        send(" ", keyCode: 49, to: panel)
        check(!meaning.isHidden && controller.session?.item?.text == "I", "First Space displays the Chinese meaning without advancing")
        check(LLCourseRepository.shared.progress(for: course.id).completedCount(total: 2) == 0 && LLPronunciationManager.shared.spoken.count == beforeReview, "Meaning review neither saves progress nor starts next-item speech")
        send(" ", keyCode: 49, isRepeat: true, to: panel)
        check(controller.session?.item?.text == "I", "Holding Space cannot skip past meaning review")
        controller.hide()
        controller.show()
        pump()
        check(!meaning.isHidden && controller.session?.isMeaningRevealed == true, "Hiding and reopening preserves the meaning review stage")
        send(" ", keyCode: 49, to: panel)
        check(controller.session?.item?.text == "like the food" && meaning.isHidden, "Second Space saves the item and hides the next meaning")
        check(LLStatusBarContentView.displayedWord == "like the food", "The menu bar advances with the course")
        send("l", to: panel)
        controller.hide()
        let speechCount = LLPronunciationManager.shared.spoken.count
        pump(1.2)
        check(LLPronunciationManager.shared.spoken.count == speechCount, "Hiding a course cannot resume the vocabulary timer's audio")
        LLStatusBarManager.shared.refreshStatusBar()
        check(LLStatusBarContentView.displayedWord == "like the food", "A menu refresh while hidden retains the selected course")
        LLStatusBarManager.shared.playCurrentWordPronunciation()
        check(LLPronunciationManager.shared.spoken.last == "like the food", "Global and menu replay target the course even while hidden")
        LLStatusBarManager.shared.recordFeedback(.know)
        pump()
        check(LLDailyLearningManager.shared.recordedFeedback == 0, "Vocabulary feedback shortcuts cannot write into the old word list during a course")
        check(controller.session?.typedCount == 1, "Reopening the course preserves in-progress input")
        check(panel.isKeyWindow, "Reopening restores the keyboard target")
        for character in "ike" { send(String(character), to: panel) }
        send(" ", keyCode: 49, to: panel)
        check(meaning.isHidden && controller.session?.wordIndex == 1, "Space between words advances the token without revealing the meaning")
        for character in "the" { send(String(character), to: panel) }
        send(" ", keyCode: 49, to: panel)
        for character in "food" { send(String(character), to: panel) }
        LLSettingsStore.shared.settings.typingPracticeShowMeaning = false
        send(" ", keyCode: 49, to: panel)
        check(!meaning.isHidden && meaning.stringValue == "喜欢食物" && controller.session?.isFinished == false, "A complete sentence reveals its meaning even when vocabulary meanings are disabled")
        send("\r", keyCode: 36, to: panel)
        check(controller.session?.isFinished == true, "Space and Return complete a sentence through actual window key events")
        check(LLCourseRepository.shared.progress(for: course.id).completedCount(total: 2) == 2, "Window input persists exactly the course's completed exercises")

        // Exercise the actual course-row button, including switching activation policy while it tracks.
        let home = LLLearningHomeViewController()
        main.contentViewController = home
        app.setActivationPolicy(.regular)
        main.makeKeyAndOrderFront(nil)
        pump()
        let table = descendants(home.view).compactMap { $0 as? NSTableView }.first!
        check(table.numberOfRows == 55, "The course tab shows the bundled lessons")
        let cell = table.view(atColumn: 0, row: 0, makeIfNecessary: true)!
        let button = descendants(cell).compactMap { $0 as? NSButton }.first!
        let firstCourse = try LLCourseRepository.shared.courses()[0]
        button.performClick(nil)
        pump(0.25)
        check(controller.courseSession?.source.id == "course:\(firstCourse.id)", "The real home-page start button switches the practice source")
        check(!main.isVisible && panel.isKeyWindow, "Starting from the home page hides it and focuses the practice panel")
        send("i", keyCode: 34, to: panel)
        check(controller.session?.isItemComplete == true, "The course started from its row accepts typing immediately")
        check(LLPronunciationManager.shared.spoken.last == "I", "The row's start action speaks the course rather than the menu vocabulary")

        NotificationCenter.default.post(name: .learnLanguageRefreshStatus, object: nil)
        pump()
        check(controller.courseSession?.source.id == "course:\(firstCourse.id)" && LLStatusBarContentView.displayedWord == "I", "Reloading menu settings preserves the course source")
        let beforeHiding = LLPronunciationManager.shared.spoken.count
        controller.show()
        controller.hide()
        pump()
        check(LLPronunciationManager.shared.spoken.count == beforeHiding && !panel.isVisible, "A pending focus callback cannot reopen or speak a hidden panel")
        let third = LLSentenceCourse(id: "ui-new-course", category: "", title: "切换课程", words: [.init(en: "New lesson", zh: "新课", ipa: nil)])
        controller.start(source: LLCoursePracticeSource(course: course))
        controller.start(source: LLCoursePracticeSource(course: third))
        let startCount = LLPronunciationManager.shared.spoken.count
        pump()
        check(Array(LLPronunciationManager.shared.spoken.dropFirst(startCount)) == ["New lesson"], "Rapid course switches cannot run a stale course's pending autoplay")
        LLStatusBarManager.shared.moveToNextWord()
        check(controller.session?.isFinished == true && LLDailyLearningManager.shared.recordedFeedback == 0, "The next-item shortcut skips within the course without writing vocabulary feedback")
        check(LLCourseRepository.shared.progress(for: third.id).completedCount(total: 1) == 0, "Skipping a course item leaves it uncompleted")

        // Explicitly selecting vocabulary switches the source back and releases course routing.
        let list = LLWordListStorage.shared.lists[0]
        controller.start(source: LLVocabularyPracticeSource(list: list))
        pump()
        check(controller.courseSession == nil && LLStatusBarContentView.displayedWord == "unrelated-vocabulary", "Switching back to words restores vocabulary mode")
        controller.hide()
        LLPronunciationManager.shared.stop()
        LLStatusBarManager.shared.refreshStatusBar()
        check(LLPronunciationManager.shared.spoken.last == "unrelated-vocabulary", "Word playback is restored after leaving course mode")
        controller.resetAfterDataChange()
        LLMMKVManager.shared.set("course:\(firstCourse.id)", forKey: "learning.last_source")
        let beforeRestore = LLPronunciationManager.shared.spoken.count
        controller.restoreSelectedCourseIfNeeded()
        check(controller.courseSession?.source.id == "course:\(firstCourse.id)" && !controller.isVisible, "Startup restores the selected course mode without opening its panel")
        LLStatusBarManager.shared.refreshStatusBar()
        check(LLPronunciationManager.shared.spoken.count == beforeRestore, "Restoring course mode cannot start old vocabulary speech")
        let restoredItem = controller.session?.item?.id
        LLStatusBarManager.shared.moveToNextWord()
        check(controller.session?.item?.id != restoredItem && !controller.isVisible, "Next-item works after startup before the practice window has been created")
        controller.resumeOrStart()
        pump()
        let restoredPanel = app.windows.first { $0.isVisible && $0.title.hasPrefix("学习练习") }!
        let restoredToken = controller.session!.currentToken
        for character in restoredToken { send(String(character), to: restoredPanel) }
        check(controller.session?.isWordComplete == true, "Opening a restored course connects its session to the keyboard input controller")
        controller.hide()
        main.close()
        print("Passed \(assertions) native practice UI checks.")
    }
}
