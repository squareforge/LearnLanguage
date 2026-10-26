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
        LLMMKVManager.shared.set(false, forKey: "learning.practice_sounds")
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
        let nextCourseButton = descendants(surface).compactMap { $0 as? NSButton }.first { $0.title == "下一课" }!
        check(nextCourseButton.isHidden, "Next lesson is hidden while practicing")
        let meaning = descendants(surface).compactMap { $0 as? NSTextField }.first { $0.stringValue == "我" }!
        check(meaning.isHidden, "Course meanings start hidden even when vocabulary meanings are enabled")
        let display = descendants(surface).compactMap { $0 as? LLPracticeTextView }.first!
        let displayPoint = display.convert(NSPoint(x: display.bounds.midX, y: display.bounds.midY), to: surface.superview)
        check(surface.hitTest(displayPoint) === surface, "Clicking the displayed sentence targets the typing surface instead of a label editor")
        let replayButton = descendants(surface).compactMap { $0 as? NSButton }.first!
        let replayPoint = replayButton.convert(NSPoint(x: replayButton.bounds.midX, y: replayButton.bounds.midY), to: surface.superview)
        check(surface.hitTest(replayPoint) !== surface, "Practice controls remain clickable beside the typing surface")
        check(LLStatusBarManager.shared.getCurrentWord() == nil, "Course mode clears the old vocabulary action target")
        let beforeCompletion = LLTypingSoundManager.shared.completionCount
        send("x", to: panel)
        check(meaning.isHidden && LLTypingSoundManager.shared.completionCount == beforeCompletion, "Incorrect input cannot reveal the meaning or play success")
        send("i", keyCode: 34, to: panel)
        check(controller.session?.isItemComplete == true, "A key event delivered through NSWindow reaches the course session")
        let beforeReview = LLPronunciationManager.shared.spoken.count
        check(!meaning.isHidden && controller.session?.item?.text == "I", "Correct completion immediately displays the Chinese meaning without advancing")
        check(LLTypingSoundManager.shared.completionCount == beforeCompletion + 1, "Course completion plays success even when key and error sounds are disabled")
        send("i", isRepeat: true, to: panel)
        check(LLTypingSoundManager.shared.completionCount == beforeCompletion + 1, "Extra input after completion cannot repeat success audio")
        check(LLCourseRepository.shared.progress(for: course.id).completedCount(total: 2) == 0 && LLPronunciationManager.shared.spoken.count == beforeReview, "Meaning review neither saves progress nor starts next-item speech")
        send(" ", keyCode: 49, isRepeat: true, to: panel)
        check(controller.session?.item?.text == "I", "Holding Space cannot skip past meaning review")
        controller.hide()
        controller.show()
        pump()
        check(!meaning.isHidden && controller.session?.isMeaningRevealed == true, "Hiding and reopening preserves the meaning review stage")
        check(LLTypingSoundManager.shared.completionCount == beforeCompletion + 1, "Reopening does not repeat success audio")
        send(" ", keyCode: 49, to: panel)
        check(controller.session?.item?.text == "like the food" && meaning.isHidden, "One Space saves the item and hides the next meaning")
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
        LLSettingsStore.shared.settings.typingPracticeShowMeaning = false
        let beforeSentenceCompletion = LLTypingSoundManager.shared.completionCount
        for character in "foo" { send(String(character), to: panel) }
        check(meaning.isHidden && LLTypingSoundManager.shared.completionCount == beforeSentenceCompletion, "An unfinished final word cannot reveal the meaning or play success")
        send("d", to: panel)
        check(!meaning.isHidden && meaning.stringValue == "喜欢食物" && controller.session?.isFinished == false, "A complete sentence reveals its meaning even when vocabulary meanings are disabled")
        check(LLTypingSoundManager.shared.completionCount == beforeSentenceCompletion + 1, "The final letter plays exactly one sentence success sound")
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
        check(nextCourseButton.isHidden, "Vocabulary practice never offers a next lesson")
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

        // Finish the penultimate bundled lesson, then continue into a saved final lesson.
        let courses = try LLCourseRepository.shared.courses()
        let penultimate = courses[courses.count - 2]
        let last = courses.last!
        for course in [penultimate, last] {
            try LLCourseRepository.shared.save(LLCourseProgress(nextIndex: course.words.count - 1,
                completedIndices: Set(0..<(course.words.count - 1))), for: course.id)
        }
        controller.start(source: LLCoursePracticeSource(course: penultimate))
        pump()
        let restoredNextCourseButton = descendants(restoredPanel.initialFirstResponder!).compactMap { $0 as? NSButton }.first { $0.title == "下一课" }!
        check(restoredNextCourseButton.isHidden, "A lesson with a successor still hides next until its final answer is confirmed")
        func finishVisibleItem() {
            for token in controller.session!.tokens {
                for character in token { send(String(character), to: restoredPanel) }
                send(" ", keyCode: 49, to: restoredPanel)
            }
        }
        finishVisibleItem()
        check(controller.session?.isFinished == true && !restoredNextCourseButton.isHidden, "Finishing a bundled lesson reveals the next-lesson button")
        check(LLCourseRepository.shared.progress(for: penultimate.id).completedCount(total: penultimate.words.count) == penultimate.words.count, "Current lesson progress is saved before offering the next lesson")
        restoredNextCourseButton.performClick(nil)
        pump()
        check(controller.courseSession?.source.id == "course:\(last.id)" && controller.session?.item?.text == last.words.last?.en, "Next lesson follows repository order and resumes its saved progress")
        check(restoredPanel.isKeyWindow && !controller.session!.isFinished && restoredNextCourseButton.isHidden, "Next lesson reuses the focused practice panel and hides the button")
        check(LLStatusBarContentView.displayedWord == last.words.last?.en && LLPronunciationManager.shared.spoken.last == last.words.last?.en, "Next lesson updates menu content and pronunciation")
        check(LLMMKVManager.shared.string(forKey: "learning.last_source") == "course:\(last.id)", "Next lesson becomes the remembered learning source")
        finishVisibleItem()
        check(controller.session?.isFinished == true && restoredNextCourseButton.isHidden, "Finishing the final lesson does not offer a next lesson")
        controller.hide()
        main.close()
        print("Passed \(assertions) native practice UI checks.")
    }
}
