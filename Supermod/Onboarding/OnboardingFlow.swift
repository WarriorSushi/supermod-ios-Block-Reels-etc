import SwiftUI

struct OnboardingFlow: View {
    let store: LocalStore
    let purchases: EntitlementStore
    var replaying = false
    let finish: (Bool) -> Void
    let preview: () -> Void
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @AccessibilityFocusState private var stepFocused: Bool
    @State private var replay = Setup()
    @State private var filtered = false
    @State private var panel: DemoPanel = .feed
    @State private var youtubeFiltered = false
    @State private var facebookFiltered = false
    @State private var demoBusy = false
    @State private var demonstratedMods: Set<Mod> = []
    @State private var tourComplete = false
    @State private var lifePhase = 0
    @State private var illustratedMods: Set<Mod> = []
    @State private var plan = Plan.annual
    @State private var possibility = Goal.rest
    @State private var commitExpanded = false
    @State private var commitProgress = 0.0
    @State private var showRestore = false
    @State private var movingForward = true
    @State private var lastNavigation: TimeInterval = 0

    private var setup: Setup {
        get { replaying ? replay : store.preferences.setup }
        nonmutating set {
            if replaying { replay = newValue }
            else { store.preferences.setup = newValue }
        }
    }

    private var draft: Binding<ModSettings> {
        Binding(get: { setup.draftMods ?? (replaying ? store.preferences.mods : .allVisible) }, set: { setup.draftMods = $0; setup.confirmedMods = false })
    }

    private var valid: Bool {
        switch setup.step {
        case .intent: !setup.selectedIntents.isEmpty
        case .goal: !setup.selectedGoals.isEmpty
        case .surfaces, .mods: !demoBusy
        case .paywall: !purchases.loading && !purchases.busy
        default: true
        }
    }

    var body: some View {
        OnboardingScaffold(step: setup.step, forward: movingForward, commitExpanded: commitExpanded, commitProgress: commitProgress, liquidFill: setup.step == .grid && lifePhase >= 4, back: back) { availableHeight in
            VStack(alignment: .leading, spacing: 22) {
                content
            }
            .environment(\.onboardingHeight, availableHeight)
            .environment(\.demoPhoneWidth, min(242, max(145, (availableHeight - (setup.step == .surfaces ? 270 : setup.step == .keep ? 230 : 170)) / (864.0 / 410))))
            .accessibilityElement(children: .contain)
            .accessibilityFocused($stepFocused)
        } footer: {
            footer
        }
        .task(id: setup.step) {
            stepFocused = true
            if !Step.journey.contains(setup.step) { move(1); return }
            if setup.step == .hours && setup.hours == nil { setup.hours = 4.8 }
            if setup.step == .age && setup.age == nil { setup.age = 18 }
            if setup.step == .keep {
                panel = .feed; tourComplete = false
                for nextPanel in [DemoPanel.messages, .keyboard, .profile] {
                    do { try await Task.sleep(for: .seconds(2.2)) } catch { return }
                    guard !Task.isCancelled else { return }
                    if !tourComplete, let currentIndex = DemoPanel.allCases.firstIndex(of: panel),
                       let nextIndex = DemoPanel.allCases.firstIndex(of: nextPanel), nextIndex > currentIndex {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { panel = nextPanel }
                    }
                }
                tourComplete = true
            }
            if setup.step == .grid {
                lifePhase = 0
                for phase in 1...4 {
                    do { try await Task.sleep(for: .seconds(reduceMotion ? 0.45 : 1.65)) } catch { return }
                    lifePhase = max(lifePhase, phase)
                }
            }
        }
        .task(id: setup.step == .grid && lifePhase == 4) {
            guard setup.step == .grid, lifePhase == 4 else { return }
            do { try await Task.sleep(for: .seconds(reduceMotion ? 0.2 : RedBlobFill.duration)) } catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { lifePhase = 5 }
        }
        .task(id: commitExpanded) {
            guard commitExpanded, setup.step == .commit else { return }
            do { try await Task.sleep(for: .seconds(reduceMotion ? 0.12 : 0.78)) } catch { return }
            if !replaying {
                store.preferences.mods = draft.wrappedValue
                store.preferences.shortVideoBreak = ShortVideoBreak(minutes: setup.breakMinutes ?? 10)
            }
            move(1)
        }
        .tint(PaywallPalette.button)
        .sensoryFeedback(.success, trigger: commitExpanded) { _, expanded in expanded }
        .onChange(of: setup.step) {
            stepFocused = true
        }
        .onChange(of: purchases.canAccess, initial: true) { _, entitled in
            if entitled && setup.step == .paywall { move(1) }
            if !entitled && purchases.checked && setup.step == .ready { move(-1) }
        }
        .onChange(of: purchases.checked) {
            if purchases.checked && !purchases.canAccess && setup.step == .ready && !replaying { move(-1) }
        }
        .alert("Restore purchases", isPresented: $showRestore) {
            Button("OK", role: .cancel) { Haptics.selection();}
        } message: {
            Text(purchases.canAccess ? "Your subscription is active. Complete setup to open your feeds." : purchases.message ?? "Checking your Apple Account…")
        }
    }

    private var footer: some View {
        VStack(spacing: 1) {
            if setup.step != .commit {
            PrimaryButton(title: buttonTitle, icon: setup.step == .commit ? "checkmark" : "arrow.right",
                          enabled: valid, action: next)
                .accessibilityIdentifier("onboarding.next")
            }
            switch setup.step {
            case .welcome:
                Button(replaying ? "Exit replay" : "Restore purchase") { Haptics.selection();
                    if replaying { finish(false) }
                    else {
                        Task {
                            await purchases.restore()
                            showRestore = true
                        }
                    }
                }
                .disabled(purchases.busy)
                .font(.footnote.weight(.semibold)).frame(minHeight: 44)
            case .discovery, .hours, .age, .reasons, .tried:
                Button("Skip") { Haptics.selection();
                    guard canNavigate else { return }
                    switch setup.step {
                    case .discovery: setup.discovery = nil
                    case .hours: setup.hours = nil
                    case .age: setup.age = nil
                    case .reasons: setup.reasons = []
                    case .tried: setup.attempts = []
                    default: break
                    }
                    move(1)
                }
                .font(.footnote.weight(.semibold)).frame(minHeight: 44)
            case .paywall:
                if purchases.allowsTesterAccess {
                    Button("Continue without paying") { Haptics.selection();
                        purchases.setTesterAccess(true)
                        navigate(to: .ready)
                    }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(PaywallPalette.accent).frame(minHeight: 44)
                    .accessibilityIdentifier("onboarding.testAccess")
                }
                Button("Explore sample preview", action: { Haptics.selection(); preview() })
                    .font(.footnote.weight(.semibold)).foregroundStyle(PaywallPalette.accent).frame(minHeight: 44)
            case .ready:
                if !replaying {
                    Button("Go to Home") { Haptics.selection(); finish(false) }
                        .font(.footnote.weight(.semibold)).frame(minHeight: 44)
                }
            default:
                EmptyView()
            }
        }
        .buttonStyle(.plain)
    }

    private var nextSurface: Mod? { [Mod.sponsored, .stories, .suggestions].first { !illustratedMods.contains($0) } }

    private var nextUndemonstrated: Mod? {
        Mod.onboardingCases.first { !demonstratedMods.contains($0) && !draft.wrappedValue.hidden.contains($0) }
    }

    private var buttonTitle: String {
        switch setup.step {
        case .welcome: "Get started"
        case .comparison: filtered ? "Continue" : "See with Supermod"
        case .available: youtubeFiltered ? "Continue" : "See with Supermod"
        case .facebookDemo: facebookFiltered ? "Continue" : "See with Supermod"
        case .surfaces: nextSurface.map { "See \($0 == .sponsored ? "ads" : $0.title.lowercased()) go" } ?? "Continue"
        case .time: "Show me"
        case .mods: nextUndemonstrated.map { "See \($0 == .sponsored ? "ads" : $0.title.lowercased()) go" } ?? "Continue"
        case .commit: "Lock in my picks"
        case .saved: "Review my setup"
        case .recap: replaying ? "Finish replay" : "Continue"
        case .paywall:
            if purchases.busy { "Working with Apple…" }
            else if purchases.loading { "Loading plans…" }
            else if let product = purchases.product(plan) { "Subscribe · \(product.displayPrice) / \(plan.period)" }
            else { "Retry loading plans" }
        case .ready: "Open Instagram"
        default: "Continue"
        }
    }

    // A second tap in the same gesture must not act on the incoming page.
    private var canNavigate: Bool {
        ProcessInfo.processInfo.systemUptime - lastNavigation >= 0.28
    }

    private func back() {
        guard canNavigate, !commitExpanded else { return }
        if setup.step == .ready && purchases.canAccess {
            navigate(to: .recap)
        } else { move(-1) }
    }

    private func move(_ offset: Int) {
        var draft = setup
        draft.move(offset)
        navigate(to: draft.step)
    }

    private func navigate(to step: Step) {
        guard step != setup.step else { return }
        demoBusy = false
        lastNavigation = ProcessInfo.processInfo.systemUptime
        movingForward = step.journeyIndex > setup.step.journeyIndex
        withAnimation(reduceMotion ? nil : .onboardingSpring) {
            setup.step = step
            commitExpanded = false
            commitProgress = 0
        }
    }

    private func next() {
        guard canNavigate, valid else { return }
        switch setup.step {
        case .comparison where !filtered:
            lastNavigation = ProcessInfo.processInfo.systemUptime
            withAnimation(reduceMotion ? nil : .onboardingSpring) { filtered = true }
        case .available where !youtubeFiltered:
            lastNavigation = ProcessInfo.processInfo.systemUptime
            withAnimation(reduceMotion ? nil : .onboardingSpring) { youtubeFiltered = true }
        case .keep where !tourComplete:
            // Continue itself demonstrates every screen, even if the user taps fast.
            lastNavigation = ProcessInfo.processInfo.systemUptime
            let panels = DemoPanel.allCases
            if let index = panels.firstIndex(of: panel), index + 1 < panels.count {
                withAnimation(reduceMotion ? nil : .onboardingSpring) { panel = panels[index + 1] }
                if panel == .profile { tourComplete = true }
            } else { tourComplete = true }
        case .surfaces where nextSurface != nil && !demoBusy:
            lastNavigation = ProcessInfo.processInfo.systemUptime
            if let mod = nextSurface { illustratedMods.insert(mod) }
        case .grid where lifePhase == 4:
            break // Let the liquid finish before revealing the result.
        case .grid where lifePhase < 4:
            lifePhase += 1
            lastNavigation = ProcessInfo.processInfo.systemUptime
        case .facebookDemo where !facebookFiltered:
            lastNavigation = ProcessInfo.processInfo.systemUptime
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.65)) { facebookFiltered = true }
        case .mods where nextUndemonstrated != nil && !demoBusy:
            if let mod = nextUndemonstrated {
                lastNavigation = ProcessInfo.processInfo.systemUptime
                demonstratedMods.insert(mod)
                draft.wrappedValue.toggle(mod)
            }
        case .mods:
            if replaying && (store.preferences.lock?.isActive(at: Date()) ?? false) {
                setup.draftMods = store.preferences.mods
            }
            setup.confirmedMods = true
            move(1)
        case .commit:
            guard setup.confirmedMods, !commitExpanded else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.58)) {
                commitProgress = 1
                commitExpanded = true
            }
        case .recap:
            if replaying { finish(false) }
            else if purchases.canAccess {
                navigate(to: .ready)
            } else { move(1) }
        case .paywall:
            Task {
                if purchases.product(plan) == nil { await purchases.loadProducts() }
                else { await purchases.purchase(plan) }
            }
        case .ready:
            if purchases.canAccess && setup.confirmedMods { finish(true) }
            else { back() }
        default:
            move(1)
        }
    }

    @ViewBuilder private var content: some View {
        switch setup.step {
        case .welcome:
            if textSize.isAccessibilitySize {
                welcomeHeading
                WelcomeArtwork()
            } else {
                WelcomeArtwork()
                welcomeHeading
            }
        case .intent:
            Heading(title: "What brings you here?", detail: "Pick all that fit.", centered: true)
            VStack(spacing: 9) {
                intent("Keep in touch", "Messages and the people I follow", "bubble.left.and.bubble.right")
                intent("Stay focused", "Fewer detours when I open the app", "scope")
                intent("Use it for work", "A more deliberate place to check in", "briefcase")
            }
        case .comparison:
            VStack(spacing: 18) {
                Heading(title: "Instagram, without\nthe Reels", centered: true)
                SegmentedDemoControl(filtered: $filtered)
                PhoneDemo(hidden: filtered ? [.reels] : [], width: 242, spotlightsReels: true)
                    .padding(.top, 7)
            }.frame(maxWidth: .infinity)
        case .keep:
            EmptyView() // Retained persisted ID; removed from the active journey.
        case .surfaces:
            SwitchTourScene(hidden: $illustratedMods, busy: $demoBusy)
        case .available:
            VStack(spacing: 18) {
                Heading(title: "YouTube, without\nthe Shorts", centered: true)
                SegmentedDemoControl(filtered: $youtubeFiltered, originalTitle: "YouTube")
                PhoneDemo(hidden: youtubeFiltered ? [.reels] : [], width: 242, youtube: true).padding(.top, 7)
            }.frame(maxWidth: .infinity)
        case .facebookDemo:
            VStack(spacing: 18) {
                Heading(title: "Facebook, without\nthe Reels", centered: true)
                SegmentedDemoControl(filtered: $facebookFiltered, originalTitle: "Facebook")
                PhoneDemo(hidden: facebookFiltered ? [.reels] : [], width: 242, showsAd: true, facebook: true)
            }.frame(maxWidth: .infinity)
        case .reelsBreak:
            BreakDemoScene(minutes: Binding(get: { setup.breakMinutes }, set: { setup.breakMinutes = $0 }))
        case .personalize:
            AttentionScene()
        case .discovery:
            Heading(title: "Where did you hear\nabout us?", centered: true)
            ForEach(["Instagram", "YouTube", "A friend", "X / Twitter", "Facebook", "Reddit", "Google / App Store search"], id: \.self) { option in
                SelectionRow(title: option, selected: setup.selectedDiscoveries.contains(option)) {
                    if setup.selectedDiscoveries.contains(option) { setup.selectedDiscoveries.remove(option) }
                    else { setup.selectedDiscoveries.insert(option) }
                }
            }
        case .hours:
            Heading(title: "How much time do you spend\nscrolling per day?", centered: true)
            EstimateSlider(hours: Binding(get: { setup.hours }, set: { setup.hours = $0 }))
        case .age:
            Heading(title: "How old are you?", detail: "We use this to map out your life in weeks.", centered: true)
            Picker("Age", selection: Binding(get: { setup.age }, set: { Haptics.selection(); setup.age = $0 })) {
                Text("Prefer not to say").tag(nil as Int?)
                ForEach(13...100, id: \.self) { age in Text("\(age)").tag(Optional(age)) }
            }
            .pickerStyle(.wheel)
            .frame(height: 260)
            .padding(.top, 100)
        case .reasons:
            Heading(title: "Why not just delete\nsocial media?", detail: "Choose any that fit.", centered: true)
            multi(["Messaging", "Friends and family", "Work or study", "Interests", "Habit", "Another reason"], keyPath: \.reasons)
        case .tried:
            Heading(title: "Tried anything to cut back?", detail: "Choose any that fit.", centered: true)
            multi(["Time limits", "Deleting apps", "Grayscale or Focus", "Another blocker", "Willpower", "Nothing yet"], keyPath: \.attempts)
        case .time:
            AnimatedWarning()
        case .grid:
            LifeWeeksView(setup: setup, phase: lifePhase)
        case .estimate:
            Heading(title: "Here’s how it adds up", centered: true)
            LifetimeEstimate(setup: setup)
        case .possibilities:
            TimeBackScene(dailyHours: setup.hours ?? 4.8, minutes: Binding(get: { setup.minutesBack }, set: { setup.minutesBack = $0 }))
        case .reassurance:
            WellbeingStudyScene()
        case .difference:
            SleepStudyScene()
        case .attentionEvidence:
            FocusStudyScene()
        case .trust:
            Heading(title: "Your setup stays here.", detail: "Your choices. Your device.", centered: true)
            LocalPrivacyIllustration()
        case .goal:
            Heading(title: "More time for what?", detail: "Pick as many as you like.", centered: true)
            GoalGrid(selection: Binding(get: { setup.selectedGoals }, set: { setup.selectedGoals = $0 }))
        case .mods:
            Heading(title: "Choose what to hide.", detail: "Turn on a switch. Watch it go.", centered: true)
            OnboardingModsPreview(mods: draft, animating: $demoBusy, locked: replaying && (store.preferences.lock?.isActive(at: Date()) ?? false))
        case .commit:
            CommitScene(goals: Goal.allCases.filter { setup.selectedGoals.contains($0) }.map(\.title).joined(separator: " · "),
                        expanded: commitExpanded, charge: $commitProgress, action: next)
        case .saved:
            SavedArtwork()
            Heading(title: "Your setup is ready.", detail: replaying ? "Your replay is complete. Your existing setup is unchanged." : "Saved on this device. You’ll sign in with Instagram when you open it.", centered: true, hero: true)
        case .recap:
            HowItWorksScene()
        case .paywall:
            PaywallContent(purchases: purchases, selection: $plan)
        case .ready:
            PhoneDemo(hidden: draft.wrappedValue.hidden, panel: .messages, width: 208).frame(maxWidth: .infinity)
            Heading(title: "Open Instagram.", detail: "You’ll sign in on Instagram’s own page inside Supermod.", hero: true)
            InfoLine(icon: "hand.raised", title: "Your Instagram session stays on this device",
                     detail: "Clear it at any time in Settings.")
        }
    }

    private var welcomeHeading: some View {
        Heading(title: "Same apps.\nFewer distractions.", centered: true, hero: true)
    }

    private var recapCopy: String {
        switch setup.intent {
        case "Keep in touch": "More room for the people you came to see."
        case "Use it for work": "Keep the parts you use for work within reach."
        default: "Here’s the setup you chose."
        }
    }

    private var estimate: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let annual = setup.annualHours, let decade = setup.tenYearHours {
                estimateValue(annual, label: "hours in one year")
                Divider()
                estimateValue(decade, label: "hours over 10 years")
                Text("Daily estimate × 365 days × years").font(.footnote).foregroundStyle(Palette.muted)
            } else {
                Text("No daily estimate entered. You can continue without one.").font(.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(21)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 21))
    }

    private func estimateValue(_ value: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value.formatted(.number.precision(.fractionLength(0...1))))
                .font(.system(.largeTitle).weight(.bold)).monospacedDigit()
            Text(label).font(.subheadline).foregroundStyle(Palette.muted)
        }.accessibilityElement(children: .combine)
    }

    private func intent(_ title: String, _ detail: String, _ symbol: String) -> some View {
        SelectionRow(title: title, detail: detail, symbol: symbol, selected: setup.selectedIntents.contains(title)) {
            if setup.selectedIntents.contains(title) { setup.selectedIntents.remove(title) }
            else { setup.selectedIntents.insert(title) }
        }
    }

    private func multi(_ options: [String], keyPath: WritableKeyPath<Setup, Set<String>>) -> some View {
        VStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                SelectionRow(title: option, selected: setup[keyPath: keyPath].contains(option)) {
                    if setup[keyPath: keyPath].contains(option) { setup[keyPath: keyPath].remove(option) }
                    else { setup[keyPath: keyPath].insert(option) }
                }
            }
        }
    }

    private func comparisonRow(_ title: String, _ detail: String, _ symbol: String) -> some View {
        InfoLine(icon: symbol, title: title, detail: detail)
            .padding(17).background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct GoalGrid: View {
    @Binding var selection: Set<Goal>
    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: size.isAccessibilitySize ? 1 : 2), spacing: 10) {
            ForEach(Goal.allCases) { goal in
                GoalCard(goal: goal, selected: selection.contains(goal)) { if selection.contains(goal) { selection.remove(goal) } else { selection.insert(goal) } }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
