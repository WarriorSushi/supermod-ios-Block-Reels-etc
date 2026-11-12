import XCTest
import StoreKitTest

final class WalkthroughTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testRunningTimerKeepsStoriesChoiceVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--ui-test-home"]
        app.launch()
        XCTAssertTrue(app.buttons["timer.open"].waitForExistence(timeout: 10))
        app.buttons["timer.open"].tap()
        app.buttons["timer.start"].tap()
        app.buttons["timer.open"].tap()
        XCTAssertTrue(app.buttons["timer.feature.stories"].waitForExistence(timeout: 5))
        app.buttons["timer.feature.stories"].tap()
        app.buttons["timer.save"].tap()
        XCTAssertTrue(app.buttons["timer.open"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timer.open"].label.contains("Stories"))
        app.buttons["timer.open"].tap()
        XCTAssertTrue(app.buttons["timer.feature.stories"].isSelected)
        capture("Running-timer-with-Stories", app)
    }

    func testHomeScrollTimerAndFilterLock() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--ui-test-home"]
        app.launch()
        XCTAssertTrue(app.buttons["timer.open"].waitForExistence(timeout: 10))
        capture("Home-scroll-timer", app)
        app.buttons["timer.open"].tap()
        XCTAssertTrue(app.buttons["timer.feature.reels"].waitForExistence(timeout: 5))
        app.buttons["timer.feature.reels"].tap()
        XCTAssertFalse(app.buttons["timer.start"].isEnabled)
        app.buttons["timer.feature.stories"].tap()
        app.buttons["timer.feature.explore"].tap()
        app.buttons["5 min"].tap()
        let decrement = app.buttons["timer.minutes-Decrement"]
        for _ in 0..<4 { decrement.tap() }
        XCTAssertEqual(app.buttons["timer.start"].label, "Start 1-minute timer")
        capture("Scroll-timer-choices", app)
        app.buttons["timer.start"].tap()
        XCTAssertTrue(app.buttons["timer.open"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timer.open"].label.contains("running"))
        capture("Scroll-timer-running", app)
        // A persisted deadline must survive leaving and reopening the app.
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.buttons["timer.open"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["timer.open"].label.contains("running"))
        app.buttons["timer.open"].tap()
        XCTAssertTrue(app.buttons["timer.end"].waitForExistence(timeout: 5))
        app.buttons["timer.end"].tap()
        XCTAssertTrue(app.buttons["timer.start"].waitForExistence(timeout: 5))
        app.buttons["timer.start"].tap()
        // Locking ends the running timer and prevents a new one.
        app.buttons["filters.lock"].tap()
        XCTAssertTrue(app.buttons["filters.lock.start"].waitForExistence(timeout: 5))
        capture("Filter-lock-explanation", app)
        app.buttons["filters.lock.start"].tap()
        XCTAssertTrue(app.staticTexts["Your filters are locked"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["timer.open"].tap()
        XCTAssertTrue(app.staticTexts["Your filters are locked"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["timer.start"].exists)
    }

    func testScrollTimerExpiresWhileAwayFromHome() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--ui-test-home"]
        app.launch()
        XCTAssertTrue(app.buttons["timer.open"].waitForExistence(timeout: 10))
        app.buttons["timer.open"].tap()
        app.buttons["5 min"].tap()
        for _ in 0..<4 { app.buttons["timer.minutes-Decrement"].tap() }
        app.buttons["timer.start"].tap()
        app.buttons["timer.open"].tap()
        XCTAssertTrue(app.buttons["timer.end"].waitForExistence(timeout: 5))
        // Real wall-clock expiry, with the timer sheet open rather than Home.
        XCTAssertTrue(app.buttons["timer.start"].waitForExistence(timeout: 65))
        XCTAssertFalse(app.buttons["timer.end"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["timer.open"].label.contains("Time’s up"))
        capture("Scroll-timer-expired", app)
    }

    func testRapidNextDoesNotSkipAndSetupResumes() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset"]
        app.launch()
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        tap("Keep in touch",in: app)
        next.tap()
        XCTAssertTrue(app.buttons["Original"].exists)
        next.doubleTap()
        XCTAssertTrue(app.buttons["Supermod"].isSelected, "First Continue must demonstrate the change in place")
        XCTAssertTrue(app.buttons["Original"].exists, "Double tap must not skip the comparison")
        capture("Comparison-after-Continue",app)
        next.tap()
        XCTAssertTrue(app.staticTexts["More than one switch."].exists)
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.staticTexts["More than one switch."].waitForExistence(timeout: 10))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Original"].exists)
    }

    func testFreshOnboardingPurchaseAndSample() throws {
        let config = try XCTUnwrap(Bundle(for: WalkthroughTests.self).url(forResource: "Supermod",withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: config)
        session.resetToDefaultState(); session.clearTransactions(); session.disableDialogs = true
        session.storefront = "IND"; session.locale = Locale(identifier: "en_IN")
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset"]
        app.launchEnvironment["SUPERMOD_LOCAL_STOREKIT"] = "1"
        app.launch()
        walkthroughToPlans(app)
        let next = app.buttons["onboarding.next"]
        let monthly = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Monthly,")).firstMatch
        let annual = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Annual,")).firstMatch
        XCTAssertTrue(monthly.waitForExistence(timeout: 10))
        XCTAssertTrue(annual.label.contains("75%"),
                      "The ₹2,999 annual plan should display 75% savings against twelve ₹999 payments")
        monthly.tap()
        XCTAssertTrue(monthly.isSelected)
        XCTAssertTrue(next.label.hasSuffix("/ month"))
        annual.tap()
        XCTAssertTrue(annual.isSelected)
        XCTAssertTrue(next.label.hasSuffix("/ year"))
        app.buttons["Explore sample preview"].tap()
        XCTAssertTrue(app.navigationBars["Supermod preview"].waitForExistence(timeout: 8))
        app.buttons["Chat"].tap(); capture("Sample-keyboard",app)
        app.buttons["Profile"].tap(); capture("Sample-profile",app)
        app.buttons["Try modifications"].tap()
        XCTAssertTrue(app.navigationBars["Sample modifications"].exists)
        flip(toggle("Hide Stories",in: app))
        app.navigationBars["Sample modifications"].buttons["Done"].tap()
        app.navigationBars["Supermod preview"].buttons["Done"].tap()
        expectation(for: NSPredicate(format: "label BEGINSWITH %@","Subscribe"),evaluatedWith: next)
        waitForExpectations(timeout: 15)
        next.tap()
        XCTAssertTrue(app.buttons["Open Instagram"].waitForExistence(timeout: 18))
        capture("Ready-after-test-purchase",app)
        app.buttons["Go to Home"].tap()
        XCTAssertTrue(app.buttons["home.instagram"].waitForExistence(timeout: 8))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        let restore = app.buttons["Restore purchases"]
        for _ in 0..<5 where !restore.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(restore.isHittable)
        restore.tap()
        let status = app.descendants(matching: .any).matching(identifier: "settings.subscriptionStatus").firstMatch
        XCTAssertEqual(status.value as? String,"Active")
        app.buttons["Done"].tap()
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.buttons["home.instagram"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["home.facebook"].exists)
        XCTAssertTrue(app.buttons["home.youtube"].exists)
        capture("Home-launcher", app)
        app.buttons["Settings"].tap()
        app.buttons["Open sample preview"].tap()
        XCTAssertTrue(app.navigationBars["Supermod preview"].waitForExistence(timeout: 8))
        app.navigationBars["Supermod preview"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["home.instagram"].waitForExistence(timeout: 8))
    }

    func testContinueWithoutPayingOpensAppAndSurvivesRelaunch() throws {
        let config = try XCTUnwrap(Bundle(for: WalkthroughTests.self).url(forResource: "Supermod",withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: config)
        session.clearTransactions()
        defer { session.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset"]
        app.launch()
        walkthroughToPlans(app)
        app.buttons["onboarding.testAccess"].tap()
        XCTAssertTrue(app.buttons["Go to Home"].waitForExistence(timeout: 6))
        app.buttons["Go to Home"].tap()
        XCTAssertTrue(app.buttons["home.instagram"].waitForExistence(timeout: 8))
        XCTAssertTrue(session.allTransactions().isEmpty,"Bypass must not call StoreKit purchase")
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.buttons["home.instagram"].waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()
        let status = app.descendants(matching: .any).matching(identifier: "settings.subscriptionStatus").firstMatch
        XCTAssertEqual(status.value as? String,"Testing · no purchase")
        capture("Tester-access-status",app)
        app.buttons["Done"].tap()
        func savedStoriesValue() -> String? {
            app.buttons["Settings"].tap()
            app.buttons["Instagram controls"].tap()
            let stories = toggle("Hide Stories", in: app)
            XCTAssertTrue(stories.waitForExistence(timeout: 8))
            let value = stories.value as? String
            app.navigationBars["Modifications"].buttons["Done"].tap()
            return value
        }
        let hadStoriesHidden = savedStoriesValue()
        XCTAssertNotNil(hadStoriesHidden)
        app.buttons["Settings"].tap(); app.buttons["Replay onboarding"].tap()
        walkthroughToPlans(app, replay: true)
        XCTAssertEqual(savedStoriesValue(), hadStoriesHidden,
                       "Replaying and changing a draft must preserve saved modifications")
    }

    private func walkthroughToPlans(_ app: XCUIApplication, replay: Bool = false) {
        let next = app.buttons["onboarding.next"]
        func ready() {
            let enabled = NSPredicate(format: "enabled == true")
            expectation(for: enabled, evaluatedWith: next)
            waitForExpectations(timeout: 8)
        }
        func advance() { ready(); next.tap() }
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        capture("01-Welcome",app,delay: 6.2)
        advance(); tap("Keep in touch",in: app); tap("Stay focused",in: app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Keep in touch")).firstMatch.isSelected)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stay focused")).firstMatch.isSelected)
        advance()
        capture("02-Original",app)
        advance(); XCTAssertTrue(app.buttons["Supermod"].isSelected)
        capture("03-Filtered",app); advance()
        XCTAssertTrue(app.staticTexts["More than one switch."].exists)
        capture("07-Ad-visible",app)
        let ad = app.switches["demo.visible.sponsored"]
        XCTAssertTrue(ad.exists)
        XCTAssertEqual(ad.value as? String,"0")
        flip(ad); XCTAssertEqual(ad.value as? String,"1")
        capture("08-Ad-lift",app,delay: 0.55)
        capture("08-Ad-hidden",app,delay: 2.7)
        ready(); flip(ad); XCTAssertEqual(ad.value as? String,"0")
        advance(); XCTAssertEqual(ad.value as? String,"1","Continue must remove the ad before leaving")
        for _ in 0..<3 {
            if app.buttons["YouTube"].exists { break }
            advance()
        }
        XCTAssertTrue(app.buttons["YouTube"].exists)
        advance(); XCTAssertTrue(app.buttons["Supermod"].isSelected)
        capture("09-YouTube-filtered",app); advance()
        XCTAssertTrue(app.buttons["Facebook"].exists)
        advance(); XCTAssertTrue(app.buttons["Supermod"].isSelected)
        capture("09-Facebook-filtered",app); advance()
        XCTAssertTrue(app.segmentedControls["onboarding.break.duration"].exists)
        capture("09-Timed-break",app,delay: 4.5); advance()
        capture("10-Research-attention",app,delay: 4)
        advance()
        XCTAssertTrue(app.sliders.firstMatch.exists)
        XCTAssertTrue(app.staticTexts["4.8 hours"].exists)
        XCTAssertTrue(app.staticTexts["Average usage"].exists)
        capture("10-Average-slider",app); advance()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "33")
        advance(); advance()
        capture("11-Life-weeks",app,delay: 4)
        capture("12-Life-percentage",app,delay: 6.5)
        advance()
        let reduction = app.sliders["Daily scrolling reduction"]
        XCTAssertTrue(reduction.waitForExistence(timeout: 5))
        reduction.adjust(toNormalizedSliderPosition: 1)
        XCTAssertTrue(app.staticTexts["730 hours a year"].waitForExistence(timeout: 5))
        capture("14-Time-back",app)
        advance(); capture("15-Wellbeing-research",app,delay: 3)
        advance(); capture("16-Sleep-research",app,delay: 1.6)
        advance(); capture("17-Focus-research",app,delay: 2.7)
        advance(); tap("Sleep",in: app); tap("Friends",in: app)
        XCTAssertTrue(app.buttons["Sleep"].isSelected)
        XCTAssertTrue(app.buttons["Friends"].isSelected)
        app.buttons["Sleep"].tap()
        XCTAssertFalse(app.buttons["Sleep"].isSelected)
        XCTAssertTrue(app.buttons["Friends"].isSelected)
        app.buttons["Sleep"].tap()
        if !replay {
            app.terminate(); app.launchArguments.removeAll { $0 == "--ui-test-reset" }; app.launch()
            XCTAssertTrue(app.buttons["Sleep"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["Sleep"].isSelected)
            XCTAssertTrue(app.buttons["Friends"].isSelected)
        }
        capture("18-Goal",app)
        advance(); XCTAssertTrue(app.staticTexts["Choose what to hide."].exists)
        if !replay {
            capture("19-Filters-off",app)
            for name in ["Reels", "Explore", "Stories", "Suggested posts", "Sponsored posts"] {
                XCTAssertEqual(toggle("Hide \(name)",in: app).value as? String, "0", "New setup must start with every filter off")
            }
        }
        if replay {
            let stories = toggle("Hide Stories",in: app)
            for _ in 0..<4 {
                if stories.isHittable && stories.frame.maxY < next.frame.minY { break }
                app.scrollViews.firstMatch.swipeUp()
            }
            let before = stories.value as? String
            flip(stories)
            XCTAssertNotEqual(stories.value as? String,before)
        }
        for _ in 0..<7 {
            if !app.staticTexts["Choose what to hide."].exists { break }
            ready(); advance()
        }
        capture("19-Modifications-complete",app)
        let hold = app.buttons["Hold to commit"]
        XCTAssertTrue(hold.exists)
        hold.press(forDuration: 0.3); XCTAssertTrue(hold.exists)
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(hold.waitForExistence(timeout: 5))
        hold.press(forDuration: 2.0)
        XCTAssertTrue(app.staticTexts["How it works."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your other apps stay as they are."].exists)
        capture("20-Inside-Supermod",app,delay: 3.4)
        advance()
        if replay {
            XCTAssertTrue(app.buttons["home.instagram"].waitForExistence(timeout: 8))
            return
        }
        XCTAssertTrue(app.staticTexts["Make your feeds yours."].waitForExistence(timeout: 8))
        capture("20-Plans",app)
    }

    func testCompactScreenWithReducedMotion() throws {
        let config = try XCTUnwrap(Bundle(for: WalkthroughTests.self).url(forResource: "Supermod",withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: config)
        session.resetToDefaultState(); session.clearTransactions(); session.disableDialogs = true
        session.storefront = "IND"; session.locale = Locale(identifier: "en_IN")
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--ui-test-reduce-motion"]
        app.launch()
        walkthroughToPlans(app)
        XCTAssertTrue(app.buttons["onboarding.testAccess"].isHittable)
        app.buttons["onboarding.testAccess"].tap()
        app.buttons["Go to Home"].tap()
        XCTAssertTrue(app.buttons["home.instagram"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.facebook"].isHittable)
        XCTAssertTrue(app.buttons["home.youtube"].isHittable)
        capture("Compact-home-launcher", app)
        XCTAssertFalse(app.buttons["home.tips.rotation"].exists)
        let secondTip = app.buttons["home.tip.1"]
        XCTAssertTrue(secondTip.isHittable)
        secondTip.tap()
        XCTAssertTrue(secondTip.isSelected)
        XCTAssertTrue(app.staticTexts["Cat’s on the clock."].waitForExistence(timeout: 5))
        capture("Compact-home-timer-tip", app)
        // First presentation and warm reopening must both provide working controls.
        for platform in ["facebook", "youtube", "facebook", "youtube"] {
            app.buttons["home.\(platform)"].tap()
            let menu = app.buttons["\(platform).supermodControls"]
            XCTAssertTrue(menu.waitForExistence(timeout: 12))
            menu.tap()
            app.buttons["social.menu.modifications"].tap()
            let title = platform == "facebook" ? "Facebook modifications" : "YouTube modifications"
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 6))
            app.buttons["Done"].tap()
            menu.tap()
            app.buttons["social.menu.home"].tap()
            XCTAssertTrue(app.buttons["home.\(platform)"].waitForExistence(timeout: 6))
        }
    }

    func testOnboardingMotionCapture() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SUPERMOD_RECORD_ONBOARDING"] == "1")
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-reset"]; app.launch()
        walkthroughToPlans(app)
    }

    func testLiveInstagramDraft() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SUPERMOD_LIVE_DRAFT"] == "1")
        let app = XCUIApplication()
        app.activate()
        if app.buttons["home.instagram"].waitForExistence(timeout: 2) { app.buttons["home.instagram"].tap() }
        let messages = app.webViews.links["Messages"]
        XCTAssertTrue(messages.waitForExistence(timeout: 15))
        messages.tap()
        Thread.sleep(forTimeInterval: 2)
        let candidates = app.webViews.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "UltraStupid"))
            .allElementsBoundByIndex.filter { $0.isHittable && [.button, .link, .staticText].contains($0.elementType) }
        let labels = XCTAttachment(string: candidates.map { "\($0.elementType.rawValue): \($0.label)" }.joined(separator: "\n"))
        labels.name = "Draft-thread-candidates"; labels.lifetime = .keepAlways; add(labels)
        let thread = try XCTUnwrap(candidates.last)
        thread.tap()
        Thread.sleep(forTimeInterval: 2)
        let composer = app.webViews.textViews.firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 8))
        composer.tap()
        let draft = "Supermod unsent keyboard check"
        composer.typeText(draft)
        capture("Live-Instagram-unsent-draft", app)
        composer.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: draft.count))
        XCTAssertFalse((composer.value as? String ?? "").contains(draft))
        capture("Live-Instagram-draft-cleared", app)
    }

    func testLiveYouTubeInspection() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SUPERMOD_WEB_INSPECT"] == "1")
        let app = XCUIApplication()
        app.activate()
        for platform in ["instagram", "facebook", "youtube"] {
            let menu = app.buttons["\(platform).supermodControls"]
            if menu.waitForExistence(timeout: 1) {
                menu.tap()
                app.buttons["social.menu.home"].tap()
                break
            }
        }
        if app.buttons["home.youtube"].waitForExistence(timeout: 2) {
            app.buttons["home.youtube"].tap()
        }
        let search = app.webViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Search")).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        // The shell can render before the live page attaches its click handlers.
        Thread.sleep(forTimeInterval: 3)
        search.press(forDuration: 0.15)
        let field = app.webViews.descendants(matching: .any).matching(NSPredicate(
            format: "elementType == %d OR elementType == %d",
            XCUIElement.ElementType.textField.rawValue, XCUIElement.ElementType.searchField.rawValue)).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText("NASA\n")
        capture("Live-inspection-NASA", app, delay: 3)
        Thread.sleep(forTimeInterval: 45)
    }

    func testLiveReadOnlyServices() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SUPERMOD_LIVE_SMOKE"] == "1")
        let app = XCUIApplication()
        app.activate()
        var notes: [String] = []
        func record(_ text: String) { notes.append(text) }
        func visible(_ label: String) -> XCUIElement? {
            app.webViews.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label))
                .allElementsBoundByIndex.first(where: { $0.isHittable })
        }
        func home(_ platform: String) {
            let menu = app.buttons["\(platform).supermodControls"]
            XCTAssertTrue(menu.waitForExistence(timeout: 15))
            menu.tap()
            app.buttons["social.menu.home"].tap()
            XCTAssertTrue(app.buttons["home.instagram"].waitForExistence(timeout: 8))
        }
        func waitForPage() {
            _ = app.webViews.firstMatch.waitForExistence(timeout: 15)
            Thread.sleep(forTimeInterval: 2)
        }
        func compareFilters(_ platform: String, labels: [String]) {
            func openMods() {
                app.buttons["\(platform).supermodControls"].tap()
                app.buttons["social.menu.modifications"].tap()
            }
            openMods()
            let originals = labels.map { toggle($0, in: app).value as? String == "1" }
            for (index, label) in labels.enumerated() where !originals[index] { flip(toggle(label, in: app)) }
            app.buttons["Done"].tap()
            capture("Live-\(platform)-filters-on", app, delay: 1)
            openMods()
            for label in labels { flip(toggle(label, in: app)) }
            app.buttons["Done"].tap()
            capture("Live-\(platform)-filters-off", app, delay: 1)
            openMods()
            for (index, label) in labels.enumerated() where originals[index] { flip(toggle(label, in: app)) }
            app.buttons["Done"].tap()
            record("\(platform) controls exercised on/off and original values restored.")
        }
        if app.buttons["instagram.supermodControls"].exists { home("instagram") }
        if app.buttons["facebook.supermodControls"].exists { home("facebook") }
        if app.buttons["youtube.supermodControls"].exists { home("youtube") }
        XCTAssertTrue(app.buttons["home.instagram"].waitForExistence(timeout: 10))
        app.buttons["home.instagram"].tap()
        waitForPage()
        capture("Live-Instagram-feed", app)
        compareFilters("instagram", labels: ["Hide Reels", "Hide Explore", "Hide Stories", "Hide Suggested posts", "Hide Sponsored posts"])
        let profileLinks = app.webViews.links.matching(NSPredicate(format: "label ENDSWITH %@", "profile picture"))
        if let profile = profileLinks.allElementsBoundByIndex.filter({ $0.isHittable }).last {
            profile.tap()
            waitForPage()
            capture("Live-Instagram-profile", app)
            record("Instagram profile link opened; inspect screenshot for rendered profile.")
        } else { record("Instagram profile link unavailable in live accessibility tree.") }
        if let messages = visible("Messages") {
            messages.tap()
            waitForPage()
            capture("Live-Instagram-messages", app)
            record("Instagram Messages opened read-only. No message sent.")
            let selfThread = app.webViews.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "UltraStupid"))
                .allElementsBoundByIndex.first(where: { $0.isHittable })
            if let selfThread {
                selfThread.tap()
                waitForPage()
                let composer = app.webViews.textViews.firstMatch
                if composer.exists && composer.isHittable {
                    composer.tap()
                    let draft = "Supermod unsent keyboard check"
                    composer.typeText(draft)
                    capture("Live-Instagram-unsent-draft", app)
                    composer.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: draft.count))
                    XCTAssertFalse((composer.value as? String ?? "").contains(draft))
                    capture("Live-Instagram-draft-cleared", app)
                    record("Instagram self-thread draft typed and cleared. No Send action performed.")
                } else { record("Instagram thread opened; editable text-view composer unavailable.") }
            } else { record("Instagram self-thread unavailable; no draft created.") }
        } else { record("Instagram Messages link unavailable.") }
        home("instagram")
        app.buttons["home.facebook"].tap()
        waitForPage()
        capture("Live-Facebook-feed", app)
        compareFilters("facebook", labels: ["Hide Sponsored posts", "Hide Reels", "Hide Stories"])
        app.webViews.firstMatch.swipeUp()
        capture("Live-Facebook-scrolled", app)
        let web = app.webViews.firstMatch
        web.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            .press(forDuration: 0.05, thenDragTo: web.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)))
        capture("Live-Facebook-reverse-header", app)
        app.buttons["facebook.supermodControls"].tap()
        app.buttons["Messenger"].tap()
        waitForPage()
        capture("Live-Messenger", app)
        record("Messenger opened read-only; inspect screenshot for PIN/authentication blocker.")
        home("facebook")
        app.buttons["home.youtube"].tap()
        waitForPage()
        capture("Live-YouTube-filtered", app)
        compareFilters("youtube", labels: ["Hide Shorts"])
        if let search = visible("Search YouTube") ?? visible("Search") {
            search.tap()
            waitForPage()
            let field = app.webViews.searchFields.firstMatch.exists ? app.webViews.searchFields.firstMatch : app.webViews.textFields.firstMatch
            if field.exists && field.isHittable {
                field.tap()
                field.typeText("NASA\n")
                waitForPage()
                capture("Live-YouTube-search-results", app)
                record("YouTube search submitted NASA; inspect results screenshot.")
                let video = app.webViews.links.matching(NSPredicate(format: "label CONTAINS %@", "The New NASA Mission"))
                    .allElementsBoundByIndex.first(where: { $0.isHittable })
                if let video {
                    video.tap()
                    waitForPage()
                    if let play = visible("Play video") ?? visible("Play") { play.tap() }
                    capture("Live-YouTube-regular-video", app, delay: 5)
                    record("Regular NASA search result opened; inspect player screenshot for playback state.")
                } else { record("Known regular-video search result not available for playback check.") }
            } else { record("YouTube Search opened but no editable search field found.") }
        } else { record("YouTube Search unavailable in accessibility tree.") }
        home("youtube")
        let report = XCTAttachment(string: notes.joined(separator: "\n"))
        report.name = "Live-check-notes"
        report.lifetime = .keepAlways
        add(report)
    }

    private func capture(_ name: String, _ app: XCUIApplication, delay: TimeInterval = 0.35) {
        Thread.sleep(forTimeInterval: delay)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let control = button(label, in: app)
        XCTAssertTrue(control.exists, label)
        control.tap()
    }

    private func button(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    private func flip(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
    }

    private func toggle(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }
}
