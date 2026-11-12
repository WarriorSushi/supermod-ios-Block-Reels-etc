import XCTest
@testable import Supermod

final class ModelTests: XCTestCase {
    func testIntentAndDiscoverySelectionsMigrateAndPersist() throws {
        var setup = Setup()
        setup.intent = "Keep in touch"; setup.discovery = "Friend"
        XCTAssertEqual(setup.selectedIntents, ["Keep in touch"])
        XCTAssertEqual(setup.selectedDiscoveries, ["Friend"])
        setup.selectedIntents = ["Keep in touch", "Stay focused"]
        setup.selectedDiscoveries = ["Friend", "Search"]
        let restored = try JSONDecoder().decode(Setup.self, from: JSONEncoder().encode(setup))
        XCTAssertEqual(restored.selectedIntents, setup.selectedIntents)
        XCTAssertEqual(restored.selectedDiscoveries, setup.selectedDiscoveries)
        setup.selectedIntents = []; setup.selectedDiscoveries = []
        XCTAssertNil(setup.intent); XCTAssertNil(setup.discovery)
    }

    func testShortVideoBreakPersistsAndExpiresAtDeadline() throws {
        let start = Date(timeIntervalSince1970: 1000)
        var prefs = Preferences()
        prefs.shortVideoBreak = ShortVideoBreak(minutes: 5)
        XCTAssertEqual(prefs.filtered([.reels, .stories], at: start), [.reels, .stories])
        prefs.shortVideoBreak?.start(at: start)
        XCTAssertEqual(prefs.filtered([.reels, .stories], at: start), [.stories])
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(prefs))
        XCTAssertEqual(restored.filtered([.stories], at: start.addingTimeInterval(299)), [.stories])
        XCTAssertEqual(restored.filtered([.stories], at: start.addingTimeInterval(300)), [.reels, .stories])
        prefs.lock = FocusLock(start: start, minutes: 15)
        XCTAssertEqual(prefs.filtered([.reels, .stories], at: start), [.reels, .stories])
        XCTAssertFalse(Mod.onboardingCases.contains(.feed), "Guided setup must retain friends' posts")
    }

    func testScrollTimerSelectionExpiryAndRestartKeepOtherFilters() throws {
        let now = Date(timeIntervalSince1970: 1000)
        var prefs = Preferences()
        prefs.mods = .allVisible
        prefs.facebookHidden = [.sponsored]
        prefs.youtubeShowsShorts = true
        var timer = ShortVideoBreak(minutes: 1)
        timer.selection = [.stories, .explore]
        prefs.startScrollTimer(timer, at: now)
        XCTAssertEqual(prefs.mods.hidden, [.stories, .explore])
        XCTAssertEqual(prefs.filtered(prefs.mods.hidden, at: now), [])
        XCTAssertEqual(prefs.facebookHidden, [.sponsored, .stories])
        XCTAssertEqual(prefs.youtubeShowsShorts, true)
        XCTAssertEqual(prefs.filtered(prefs.mods.hidden, at: now.addingTimeInterval(60)), [.stories, .explore])
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(prefs))
        XCTAssertEqual(restored.shortVideoBreak?.features, [.stories, .explore])
        XCTAssertEqual(restored.shortVideoBreak?.fractionRemaining(at: now.addingTimeInterval(30)), 0.5)
        prefs.finishScrollTimer(at: now.addingTimeInterval(60))
        XCTAssertNil(prefs.shortVideoBreak?.endsAt)
        XCTAssertNotNil(prefs.shortVideoBreak?.finishedAt)
        // Finished timers no longer override manual filter changes.
        prefs.mods.toggle(.stories)
        XCTAssertEqual(prefs.filtered(prefs.mods.hidden, at: now.addingTimeInterval(61)), [.explore])
        timer.selection = [.reels]
        prefs.startScrollTimer(timer, at: now.addingTimeInterval(70))
        XCTAssertEqual(prefs.filtered(prefs.mods.hidden, at: now.addingTimeInterval(70)), [.explore])
        XCTAssertEqual(prefs.youtubeShowsShorts, false)
        XCTAssertEqual(prefs.facebookHidden, [.sponsored, .stories, .reels])
    }

    func testChangingRunningTimerFeaturesPreservesDeadline() {
        let now = Date(timeIntervalSince1970: 1000)
        var prefs = Preferences()
        prefs.startScrollTimer(ShortVideoBreak(minutes: 5), at: now)
        let end = prefs.shortVideoBreak?.endsAt
        prefs.updateScrollTimerFeatures([.stories], at: now.addingTimeInterval(60))
        XCTAssertEqual(prefs.shortVideoBreak?.endsAt, end)
        XCTAssertEqual(prefs.shortVideoBreak?.features, [.stories])
        XCTAssertTrue(prefs.filtered(prefs.mods.hidden, at: now.addingTimeInterval(61)).contains(.reels))
        XCTAssertFalse(prefs.filtered(prefs.mods.hidden, at: now.addingTimeInterval(61)).contains(.stories))
        XCTAssertTrue(prefs.filtered(prefs.mods.hidden, at: now.addingTimeInterval(300)).contains(.stories))
        prefs.updateScrollTimerFeatures([], at: now.addingTimeInterval(62))
        XCTAssertEqual(prefs.shortVideoBreak?.features, [.stories])
        prefs.updateScrollTimerFeatures([.explore], at: now.addingTimeInterval(300))
        XCTAssertEqual(prefs.shortVideoBreak?.features, [.stories])
    }

    func testFilterLockEndsTimerAndRejectsNewTimers() {
        let now = Date(timeIntervalSince1970: 1000)
        var prefs = Preferences()
        prefs.mods = .allVisible
        var timer = ShortVideoBreak(minutes: 10)
        timer.selection = [.feed, .reels]
        prefs.startScrollTimer(timer, at: now)
        prefs.startFilterLock(minutes: 15, at: now.addingTimeInterval(10))
        XCTAssertNil(prefs.shortVideoBreak?.endsAt)
        XCTAssertEqual(prefs.filtered(prefs.mods.hidden, at: now.addingTimeInterval(11)), [.feed, .reels])
        prefs.startScrollTimer(timer, at: now.addingTimeInterval(12))
        XCTAssertNil(prefs.shortVideoBreak?.endsAt)
        XCTAssertEqual(prefs.facebookHidden, [.reels])
        XCTAssertEqual(prefs.youtubeShowsShorts, false)
        prefs.startScrollTimer(timer, at: now.addingTimeInterval(910))
        XCTAssertTrue(prefs.shortVideoBreak!.isActive(at: now.addingTimeInterval(910)))
    }

    func testLegacyTimerMigrationAndEmptySelection() throws {
        let timer = try JSONDecoder().decode(ShortVideoBreak.self, from: Data(#"{"minutes":5,"endsAt":300}"#.utf8))
        XCTAssertEqual(timer.features, [.reels])
        var prefs = Preferences()
        prefs.shortVideoBreak = timer
        prefs.finishScrollTimer(at: Date(timeIntervalSinceReferenceDate: 301))
        XCTAssertTrue(prefs.mods.hidden.contains(.reels))
        XCTAssertEqual(prefs.youtubeShowsShorts, false)
        var empty = ShortVideoBreak(minutes: 5)
        empty.selection = []
        prefs.startScrollTimer(empty)
        XCTAssertNil(prefs.shortVideoBreak?.endsAt)
        var clamped = ShortVideoBreak(minutes: 999)
        clamped.start(at: .distantPast)
        XCTAssertEqual(clamped.minutes, 60)
        XCTAssertEqual(clamped.fractionRemaining(at: .distantFuture), 0)
    }

    func testGoalSelectionsMigrateAndRoundTrip() throws {
        var old = Setup(); old.goal = .people
        XCTAssertEqual(old.selectedGoals, [.people])
        let legacy = try JSONDecoder().decode(Setup.self, from: JSONEncoder().encode(old))
        XCTAssertEqual(legacy.selectedGoals, [.people])
        var updated = legacy
        updated.selectedGoals = [.people, .rest, .focus]
        let restored = try JSONDecoder().decode(Setup.self, from: JSONEncoder().encode(updated))
        XCTAssertEqual(restored.selectedGoals, [.people, .rest, .focus])
        updated.selectedGoals = []
        XCTAssertNil(updated.goal)
        XCTAssertTrue(try JSONDecoder().decode(Setup.self, from: JSONEncoder().encode(updated)).selectedGoals.isEmpty)
    }

    func testAllVisibleDraftDoesNotChangeExistingSettings() {
        let saved = ModSettings()
        var draft = ModSettings.allVisible
        XCTAssertTrue(draft.hidden.isEmpty)
        draft.toggle(.stories)
        XCTAssertEqual(draft.hidden, [.stories])
        XCTAssertEqual(saved.hidden, [.reels, .explore, .suggestions])
        draft.toggle(.stories)
        XCTAssertTrue(draft.hidden.isEmpty)
    }

    func testLifetimeProjectionHandlesBoundaryAgesAndHours() {
        var setup = Setup()
        setup.age = 33; setup.hours = 4.8
        let p = LifeProjection(setup: setup)
        XCTAssertEqual(p.wakingPercent, 30, accuracy: 0.001)
        XCTAssertEqual(p.scrollingYears, 9.4, accuracy: 0.001)
        for age in [13, 79, 80, 100] {
            setup.age = age; setup.hours = 16
            let value = LifeProjection(setup: setup)
            XCTAssertGreaterThan(value.remainingYears, 0)
            XCTAssertLessThanOrEqual(value.livedFraction + value.asleepFraction + value.scrollingFraction, 1.00001)
        }
    }

    func testNavigationProjectionAndSkipRoundTrip() throws {
        var state = Setup()
        state.step = .age
        state.move(1)
        XCTAssertEqual(state.step, .reasons)
        state.move(-1)
        XCTAssertEqual(state.step, .age)
        XCTAssertNil(state.annualHours)
        state.hours = 0
        XCTAssertEqual(state.annualHours, 0)
        state.hours = 2.5
        XCTAssertEqual(state.annualHours, 912.5)
        XCTAssertEqual(state.tenYearHours, 9125)
        XCTAssertEqual(try JSONDecoder().decode(Setup.self, from: JSONEncoder().encode(state)), state)
    }

    func testOnboardingJourneySkipsRedundantScreensAndPreservesSavedValues() {
        var setup = Setup()
        var seen: [Step] = [.welcome]
        while setup.step != .ready { setup.move(1); seen.append(setup.step) }
        XCTAssertEqual(seen, Step.journey)
        for retired in [Step.discovery, .tried, .time, .estimate, .saved] {
            setup.step = retired; setup.move(1)
            XCTAssertTrue(Step.journey.contains(setup.step))
            XCTAssertGreaterThan(setup.step.rawValue, retired.rawValue)
        }
        setup.step = .ready; setup.move(1); XCTAssertEqual(setup.step, .ready)
        setup.step = .welcome; setup.move(-1); XCTAssertEqual(setup.step, .welcome)
    }

    func testCustomPresetAndStrictExpiry() {
        var mods = ModSettings()
        mods.toggle(.stories)
        let custom = mods.hidden
        mods.select(.messages)
        XCTAssertTrue(mods.hidden.contains(.feed))
        mods.select(.custom)
        XCTAssertEqual(mods.hidden, custom)
        let now = Date(timeIntervalSince1970: 1000)
        let lock = FocusLock(start: now, minutes: 15)
        XCTAssertTrue(lock.isActive(at: now.addingTimeInterval(899)))
        XCTAssertFalse(lock.isActive(at: now.addingTimeInterval(900)))
        XCTAssertFalse(lock.isActive(at: now.addingTimeInterval(-301)))
    }

    func testUsageSplitsAtMidnightAndIgnoresBackwardIntervals() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let midnight = Date(timeIntervalSince1970: 1_728_000_000)
        var usage = Usage()
        usage.add(from: midnight.addingTimeInterval(-10), to: midnight.addingTimeInterval(20), calendar: calendar)
        usage.add(from: midnight, to: midnight.addingTimeInterval(-5), calendar: calendar)
        XCTAssertEqual(usage.seconds(on: midnight, calendar: calendar), 20)
        XCTAssertEqual(usage.total, 30)
    }

    func testNavigationBoundaries() {
        let adapter = InstagramAdapter()
        let blocked: Set<Mod> = [.reels, .explore]
        func check(_ url: String) -> RouteDecision {
            adapter.decision(for: URL(string: url)!, hidden: blocked)
        }
        XCTAssertEqual(check("https://www.instagram.com/direct/t/example/"), .allow)
        XCTAssertEqual(check("https://www.instagram.com/reel/sample/"), .blocked(.reels))
        XCTAssertEqual(check("https://www.instagram.com/explore/"), .blocked(.explore))
        XCTAssertEqual(check("https://www.instagram.com/accounts/login/?next=/reels/"), .authentication)
        XCTAssertEqual(check("https://www.instagram.com.evil.test/reels/"), .external)
        XCTAssertEqual(check("http://instagram.com/"), .external)
        XCTAssertEqual(check("https://instagram.com:444/"), .external)
        XCTAssertEqual(check("instagram://reels"), .unsupported)
    }

    func testLegacyLaunchPreferenceSurvivesUpgrade() throws {
        var legacy = Preferences()
        legacy.returnToInstagram = false
        let encoded = try JSONEncoder().encode(legacy)
        var restored = try JSONDecoder().decode(Preferences.self, from: encoded)
        XCTAssertEqual(restored.preferredLaunch, .home)
        restored.launchDestination = .facebook
        XCTAssertEqual(restored.preferredLaunch, .facebook)
        XCTAssertEqual(restored.profile, legacy.profile)
    }

    func testQuietHoursAcrossMidnightAndAtEndpoints() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let midnight = Date(timeIntervalSince1970: 0)
        let quiet = QuietHours()
        for (minutes, expected) in [(-121, false), (-120, true), (0, true), (419, true), (420, false)] {
            XCTAssertEqual(quiet.contains(midnight.addingTimeInterval(Double(minutes * 60)), calendar: calendar), expected)
        }
        XCTAssertFalse(QuietHours(start: 0, end: 0).contains(midnight, calendar: calendar))
    }

    func testYouTubeAllowsRegularVideosAndRespectsShortsPreference() {
        let adapter = YouTubeAdapter()
        func check(_ url: String, hidden: Set<Mod> = [.reels]) -> RouteDecision {
            adapter.decision(for: URL(string: url)!, hidden: hidden)
        }
        XCTAssertEqual(check("https://m.youtube.com/shorts/example"), .blocked(.reels))
        XCTAssertEqual(check("https://m.youtube.com/shorts/example", hidden: []), .allow)
        XCTAssertEqual(check("https://www.youtube.com/watch?v=123"), .allow)
        XCTAssertEqual(check("https://m.youtube.com/results?search_query=shorts"), .allow)
        XCTAssertEqual(check("https://consent.youtube.com/"), .authentication)
        XCTAssertEqual(check("https://accounts.google.com/"), .external)
        XCTAssertEqual(check("https://m.youtube.com.invalid/shorts/example"), .external)
    }

    #if DEBUG
    func testFacebookPreviewOwnsOnlyApprovedHostsAndKeepsSignInInside() {
        let adapter = FacebookAdapter()
        func check(_ url: String) -> RouteDecision {
            adapter.decision(for: URL(string: url)!, hidden: [.reels, .stories, .sponsored])
        }
        XCTAssertTrue(adapter.owns(adapter.entry))
        XCTAssertEqual(check(adapter.signInURL.absoluteString), .authentication)
        XCTAssertEqual(check("https://m.facebook.com/checkpoint/"), .authentication)
        XCTAssertEqual(check("https://www.facebook.com/reel/example"), .blocked(.reels))
        XCTAssertEqual(check("https://m.facebook.com/reels/"), .blocked(.reels))
        XCTAssertEqual(check("https://m.facebook.com/stories/example"), .blocked(.stories))
        XCTAssertEqual(check("https://www.facebook.com/watch/?v=123"), .allow)
        XCTAssertEqual(check("https://www.facebook.com/messages/e2ee/t/123"), .allow)
        XCTAssertEqual(check("https://www.facebook.com/login.php?next=/stories/"), .authentication)
        XCTAssertEqual(check("https://www.facebook.com.evil.test/login"), .external)
        XCTAssertEqual(check("https://www.instagram.com/"), .external)
        XCTAssertEqual(check("https://www.facebook.com:444/login"), .external)
        XCTAssertEqual(adapter.decision(for: URL(string: "https://www.facebook.com/reel/example")!, hidden: []), .allow)
    }
    #endif
}
