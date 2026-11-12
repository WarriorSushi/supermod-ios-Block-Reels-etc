import Foundation
import SwiftUI

enum Step: Int, CaseIterable, Codable {
    case welcome, intent, comparison, keep, surfaces, available, personalize, discovery, hours, age
    case reasons, tried, time, grid, estimate, possibilities, reassurance, difference, trust, goal
    case mods, commit, saved, recap, paywall, ready
    case attentionEvidence, facebookDemo, reelsBreak

    // Keep persisted raw values stable while removing redundant onboarding steps.
    static let journey: [Step] = [.welcome, .intent, .comparison, .surfaces, .available, .facebookDemo, .reelsBreak,
        .personalize, .hours, .age, .reasons, .grid, .possibilities, .reassurance,
        .difference, .attentionEvidence, .goal, .mods, .commit, .recap, .paywall, .ready]
    var journeyIndex: Int { Self.journey.firstIndex(of: self) ?? Self.journey.firstIndex(where: { $0.rawValue > rawValue }) ?? 0 }
}

struct Setup: Codable, Equatable {
    var step: Step = .welcome
    var intent: String?
    var intents: Set<String>?
    var selectedIntents: Set<String> {
        get { intents ?? intent.map { [$0] } ?? [] }
        set { intents = newValue; intent = newValue.sorted().first }
    }
    var discoveries: Set<String>?
    var selectedDiscoveries: Set<String> {
        get { discoveries ?? discovery.map { [$0] } ?? [] }
        set { discoveries = newValue; discovery = newValue.sorted().first }
    }
    var breakMinutes: Int?
    var discovery: String?
    var hours: Double?
    var minutesBack: Double?
    var age: Int?
    var reasons: Set<String> = []
    var attempts: Set<String> = []
    var goal: Goal? // Retained for older saved setups.
    var goals: Set<Goal>?
    var selectedGoals: Set<Goal> {
        get { goals ?? goal.map { [$0] } ?? [] }
        set { goals = newValue; goal = Goal.allCases.first { newValue.contains($0) } }
    }
    var confirmedMods = false
    var draftMods: ModSettings?

    var annualHours: Double? { hours.map { $0 * 365 } }
    var tenYearHours: Double? { annualHours.map { $0 * 10 } }

    mutating func move(_ offset: Int) {
        if !Step.journey.contains(step) {
            step = offset >= 0 ? (Step.journey.first { $0.rawValue > step.rawValue } ?? .ready)
                : (Step.journey.last { $0.rawValue < step.rawValue } ?? .welcome)
        } else {
            let next = min(max(0, step.journeyIndex + offset), Step.journey.count - 1)
            step = Step.journey[next]
        }
    }
}

enum Goal: String, CaseIterable, Codable, Identifiable {
    case rest, focus, people, movement
    var id: Self { self }
    var title: String {
        switch self {
        case .rest: "Sleep"
        case .focus: "Focus"
        case .people: "Friends"
        case .movement: "Move"
        }
    }
    var symbol: String {
        switch self {
        case .rest: "moon.stars"
        case .focus: "book"
        case .people: "person.2"
        case .movement: "figure.walk"
        }
    }
}

enum Mod: String, Codable, CaseIterable, Identifiable {
    case reels, explore, stories, suggestions, sponsored, feed
    var id: Self { self }
    static let onboardingCases: [Mod] = [.reels, .explore, .stories, .suggestions, .sponsored]
    var title: String {
        switch self {
        case .reels: "Reels"
        case .explore: "Explore"
        case .stories: "Stories"
        case .suggestions: "Suggested posts"
        case .sponsored: "Sponsored posts"
        case .feed: "Home feed"
        }
    }
    var detail: String {
        switch self {
        case .reels: "Hide shortcuts and block Reel pages."
        case .explore: "Hide Explore and block its page."
        case .stories: "Hide the story tray and Story pages."
        case .suggestions: "Hide recognized recommendation cards."
        case .sponsored: "Best effort for identifiable ads."
        case .feed: "Keep Home available without its post stream."
        }
    }
    var symbol: String {
        switch self {
        case .reels: "play.rectangle"
        case .explore: "safari"
        case .stories: "circle.dashed"
        case .suggestions: "sparkles"
        case .sponsored: "megaphone"
        case .feed: "rectangle.stack"
        }
    }
}

enum Preset: String, CaseIterable, Codable, Identifiable {
    case custom = "Custom"
    case balanced = "Balanced"
    case messages = "Messages-first"
    var id: Self { self }
    var detail: String {
        switch self {
        case .custom: "Your saved individual choices."
        case .balanced: "Hides Reels, Explore, and suggested posts."
        case .messages: "Hides all six surfaces. DMs and profiles stay available."
        }
    }
}

struct ModSettings: Codable, Equatable {
    var preset: Preset = .balanced
    private var custom: Set<Mod> = [.reels, .explore, .suggestions]

    static var allVisible: ModSettings {
        var settings = ModSettings()
        settings.preset = .custom
        settings.custom = []
        return settings
    }

    var hidden: Set<Mod> {
        switch preset {
        case .custom: custom
        case .balanced: [.reels, .explore, .suggestions]
        case .messages: Set(Mod.allCases)
        }
    }

    mutating func select(_ choice: Preset) { preset = choice }

    mutating func toggle(_ mod: Mod) {
        custom = hidden
        if custom.contains(mod) { custom.remove(mod) } else { custom.insert(mod) }
        preset = .custom
    }
}

struct FocusLock: Codable, Equatable {
    let start: Date
    let minutes: Int
    var end: Date { start.addingTimeInterval(Double(minutes) * 60) }
    func isActive(at date: Date) -> Bool {
        [15, 30, 60].contains(minutes) && date >= start.addingTimeInterval(-300) && date < end
    }
}

struct Usage: Codable, Equatable {
    private var days: [String: Double] = [:]
    var total: Double { days.values.reduce(0, +) }

    func seconds(on date: Date, calendar: Calendar = .current) -> Double {
        days[dayKey(date, calendar: calendar), default: 0]
    }

    mutating func add(from start: Date, to end: Date, calendar: Calendar = .current) {
        var cursor = start
        while cursor < end, let day = calendar.dateInterval(of: .day, for: cursor), day.end > cursor {
            let stop = min(end, day.end)
            days[dayKey(cursor, calendar: calendar), default: 0] += stop.timeIntervalSince(cursor)
            cursor = stop
        }
    }

    private func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

enum Theme: String, CaseIterable, Codable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: Self { self }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum LaunchDestination: String, Codable, CaseIterable, Identifiable {
    case home = "Supermod Home", instagram = "Instagram", facebook = "Facebook", youtube = "YouTube"
    var id: Self { self }
}

struct QuietHours: Codable, Equatable {
    var start = 22 * 60
    var end = 7 * 60

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard start != end else { return false }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return start < end ? (start..<end).contains(minute) : minute >= start || minute < end
    }
}

struct Preferences: Codable, Equatable {
    var setup = Setup()
    var mods = ModSettings()
    var theme = Theme.system
    var returnToInstagram = false
    var launchDestination: LaunchDestination?
    var grayscale: Bool?
    var quietHours: QuietHours?
    var profile = UUID()
    var hasOpenedInstagram = false
    var connectedInstagram: Bool?
    var facebookProfile: UUID?
    var facebookHidden: Set<Mod>?
    var youtubeProfile: UUID?
    var youtubeShowsShorts: Bool?
    var completedSetup = false
    var lock: FocusLock?
    var usage = Usage()
    var shortVideoBreak: ShortVideoBreak?

    func filtered(_ base: Set<Mod>, at date: Date = Date()) -> Set<Mod> {
        guard lock?.isActive(at: date) != true, let timer = shortVideoBreak, timer.endsAt != nil else { return base }
        var result = base
        if timer.isActive(at: date) { result.subtract(timer.features) }
        else { result.formUnion(timer.features) }
        return result
    }


    mutating func startScrollTimer(_ draft: ShortVideoBreak, at date: Date = Date()) {
        guard lock?.isActive(at: date) != true, !draft.features.isEmpty else { return }
        // Commit the previous selection before replacing it, including legacy timers.
        finishScrollTimer(at: date)
        var timer = draft
        timer.start(at: date)
        hideTimerFeatures(timer.features)
        shortVideoBreak = timer
    }

    mutating func updateScrollTimerFeatures(_ selection: Set<Mod>, at date: Date = Date()) {
        let features = selection.intersection(ShortVideoBreak.choices)
        guard !features.isEmpty, lock?.isActive(at: date) != true,
              var timer = shortVideoBreak, timer.isActive(at: date) else { return }
        // Removed choices hide immediately; new choices use the same deadline.
        hideTimerFeatures(timer.features.union(features))
        timer.selection = features
        shortVideoBreak = timer
    }

    mutating func finishScrollTimer(at date: Date = Date()) {
        guard var timer = shortVideoBreak, timer.endsAt != nil else { return }
        hideTimerFeatures(timer.features)
        timer.endsAt = nil
        timer.finishedAt = date
        shortVideoBreak = timer
    }

    mutating func startFilterLock(minutes: Int, at date: Date = Date()) {
        finishScrollTimer(at: date)
        lock = FocusLock(start: date, minutes: minutes)
    }

    private mutating func hideTimerFeatures(_ features: Set<Mod>) {
        for mod in features where !mods.hidden.contains(mod) { mods.toggle(mod) }
        let facebook = features.intersection([.reels, .stories])
        if !facebook.isEmpty { facebookHidden = (facebookHidden ?? []).union(facebook) }
        if features.contains(.reels) { youtubeShowsShorts = false }
    }


    var preferredLaunch: LaunchDestination {
        launchDestination ?? (returnToInstagram ? .instagram : .home)
    }
}

@MainActor @Observable
final class LocalStore {
    private static let key = "supermod.preferences.v1"
    private let defaults: UserDefaults
    var preferences: Preferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences) {
                defaults.set(data, forKey: Self.key)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-reset") {
            // A simulator may also have an older domain written by `simctl defaults`.
            // Removing the app-container value exposes that fallback. Override it
            // with a fresh snapshot so a reset cannot resume a previous QA screen.
            preferences = Preferences()
            if ProcessInfo.processInfo.arguments.contains("--ui-test-home") { preferences.completedSetup = true }
            if let data = try? JSONEncoder().encode(preferences) {
                defaults.set(data, forKey: Self.key)
            }
            return
        }
        #endif
        preferences = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
    }

    func reset() { preferences = Preferences() }
}

/// A short break uses elapsed wall time, including time outside the app.
/// The deadline persists across relaunch and applies to all three in-app services.
struct ShortVideoBreak: Codable, Equatable {
    var minutes = 10
    var endsAt: Date?
    // Optional for compatibility with the original Reels-only saved timer.
    var selection: Set<Mod>?
    var finishedAt: Date?
    static let choices: [Mod] = [.reels, .stories, .explore, .feed]
    var features: Set<Mod> { (selection ?? [.reels]).intersection(Self.choices) }
    var featureNames: String { Self.choices.filter { features.contains($0) }.map { $0 == .reels ? "Reels & Shorts" : $0.title }.joined(separator: ", ") }
    func remaining(at date: Date) -> TimeInterval { max(0, endsAt?.timeIntervalSince(date) ?? 0) }
    func fractionRemaining(at date: Date) -> Double { min(1, remaining(at: date) / Double(max(1, minutes) * 60)) }
    func isActive(at date: Date) -> Bool { endsAt.map { date < $0 } ?? false }
    mutating func start(at date: Date = Date()) {
        minutes = min(60, max(1, minutes))
        finishedAt = nil
        endsAt = date.addingTimeInterval(Double(minutes * 60))
    }
}
