import SwiftUI
import StoreKit
import WebKit

@main
struct SupermodApp: App {
    init() { SubscriptionAnalytics.configure() }
    var body: some Scene {
        WindowGroup { SupermodRoot() }
    }
}

struct SupermodRoot: View {
    @State private var store: LocalStore
    @State private var session: WebSession
    @State private var facebookSession: WebSession?
    @State private var youtubeSession: WebSession?
    @State private var purchases = EntitlementStore()
    @State private var sheet: Sheet?
    @State private var nextSheet: Sheet?
    @State private var social = false
    @State private var browserPresented = false
    @State private var replay = false
    @State private var restoredLaunch = false
    @State private var usageStart: Date?
    @State private var usageUptime: TimeInterval?
    @State private var locked = false
    @State private var destination: SocialDestination?
    @State private var showsLaunch = true
    @State private var showsQuietHoursNotice = false
    @Environment(\.scenePhase) private var scene
    @Environment(\.supermodReduceMotion) private var reduceMotion

    private enum Sheet: String, Identifiable {
        case settings, mods, sample, plans
        var id: Self { self }
    }

    private enum SocialDestination: Identifiable {
        case facebook(WebSession), youtube(WebSession)
        var id: String {
            switch self { case .facebook: "facebook"; case .youtube: "youtube" }
        }
    }

    init() {
        let store = LocalStore()
        _store = State(initialValue: store)
        _session = State(initialValue: WebSession(profile: store.preferences.profile))
    }

    var body: some View {
        Group {
            if replay || !store.preferences.completedSetup {
                OnboardingFlow(store: store, purchases: purchases, replaying: replay,
                               finish: finishSetup, preview: { sheet = .sample })
                    .id(replay)
            } else if social && purchases.canAccess {
                SocialScreen(session: session, locked: locked, home: { social = false }, mods: { sheet = .mods },
                             grayscale: store.preferences.grayscale == true, timerStore: store,
                             browserVisibility: { browserPresented = $0 })
            } else {
                HomeView(store: store, open: openInstagram, openFacebook: openFacebook, openYouTube: openYouTube,
                         settings: { sheet = .settings })
            }
        }
        .tint(Palette.ink)
        .preferredColorScheme(store.preferences.theme.scheme)
        .fullScreenCover(item: $destination) { destination in
            switch destination {
            case .facebook(let session): FacebookScreen(store: store, session: session)
            case .youtube(let session): YouTubeScreen(store: store, session: session)
            }
        }
        .accessibilityHidden(showsLaunch && !reduceMotion)
        .overlay {
            if showsLaunch && !reduceMotion {
                BrandLaunchView()
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .alert("Quiet hours are active", isPresented: $showsQuietHoursNotice) {
            Button("OK", role: .cancel) { Haptics.selection();}
        } message: {
            Text("You can change your schedule in Settings.")
        }
        .sheet(item: $sheet, onDismiss: presentNextSheet) { sheet in
            switch sheet {
            case .settings:
                SettingsView(store: store, purchases: purchases, replay: { self.sheet = nil; replay = true },
                             plans: { replaceSheet(with: .plans) }, instagramControls: { replaceSheet(with: .mods) },
                             preview: { replaceSheet(with: .sample) }, clear: clearSession, reset: reset)
            case .mods:
                ModsSheet(store: store, web: session)
            case .sample:
                SampleView(initialMods: store.preferences.mods)
            case .plans:
                PlansSheet(purchases: purchases, sample: { replaceSheet(with: .sample) })
            }
        }
        .task(id: store.preferences.shortVideoBreak?.endsAt) {
            guard let end = store.preferences.shortVideoBreak?.endsAt else { return }
            do { try await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow))) } catch { return }
            store.preferences.finishScrollTimer()
            applyMods()
        }
        .task { await purchases.listen() }
        .task { await purchases.refresh() }
        .task {
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(560)) }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { showsLaunch = false }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                updateLock()
                applyMods()
                accountUsage()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            switch destination {
            case .facebook: youtubeSession = nil
            case .youtube: facebookSession = nil
            case nil: facebookSession = nil; youtubeSession = nil
            }
        }
        .onChange(of: purchases.checked, initial: true) { restoreLaunch() }
        .onChange(of: purchases.canAccess) { _, entitled in
            if !entitled { social = false; destination = nil }
            restoreLaunch()
        }
        .onChange(of: store.preferences.mods, initial: true) { applyMods() }
        .onChange(of: store.preferences.shortVideoBreak) { applyMods() }
        .onChange(of: store.preferences.lock, initial: true) { updateLock() }
        .onChange(of: scene, initial: true) {
            accountUsage()
            if let timer = store.preferences.shortVideoBreak, timer.endsAt != nil, !timer.isActive(at: Date()) {
                store.preferences.finishScrollTimer()
            }
            applyMods()
            updateLock()
            if scene == .active { Task { await purchases.refresh() } }
            else if scene == .background { session.setSuspended(false) }
        }
        .onChange(of: social) {
            if !social { browserPresented = false }
            accountUsage()
        }
        .onChange(of: browserPresented) { accountUsage() }
        .onChange(of: sheet) { accountUsage() }
        .onChange(of: session.status) {
            accountUsage()
            if case .blocked(let mod) = session.status, let timer = store.preferences.shortVideoBreak,
               timer.features.contains(mod), timer.finishedAt != nil, !timer.isActive(at: Date()) { session.recover() }
        }
        .onChange(of: session.detectedConnection) {
            if session.detectedConnection { store.preferences.connectedInstagram = true }
        }
    }

    private func openFacebook() {
        guard purchases.canAccess else { sheet = .plans; return }
        guard canOpenDuringRoutine else { return }
        if store.preferences.facebookProfile == nil {
            store.preferences.facebookProfile = UUID()
        }
        if facebookSession == nil, let profile = store.preferences.facebookProfile {
            facebookSession = WebSession(adapter: FacebookAdapter(), dataStore: .init(forIdentifier: profile))
        }
        if let facebookSession { destination = .facebook(facebookSession) }
    }

    private func openYouTube() {
        guard purchases.canAccess else { sheet = .plans; return }
        guard canOpenDuringRoutine else { return }
        if store.preferences.youtubeProfile == nil {
            store.preferences.youtubeProfile = UUID()
        }
        if youtubeSession == nil, let profile = store.preferences.youtubeProfile {
            youtubeSession = WebSession(adapter: YouTubeAdapter(), dataStore: .init(forIdentifier: profile))
        }
        if let youtubeSession { destination = .youtube(youtubeSession) }
    }

    private func finishSetup(_ open: Bool) {
        if replay { replay = false; return }
        guard purchases.canAccess, store.preferences.setup.confirmedMods else { return }
        store.preferences.completedSetup = true
        if open { openInstagram() }
    }

    private func replaceSheet(with destination: Sheet) {
        nextSheet = destination
        sheet = nil
    }

    private func presentNextSheet() {
        guard let destination = nextSheet else { return }
        nextSheet = nil
        sheet = destination
    }

    private func openInstagram() {
        guard purchases.canAccess else { sheet = .plans; return }
        guard canOpenDuringRoutine else { return }
        store.preferences.hasOpenedInstagram = true
        social = true
        session.open()
    }

    private var canOpenDuringRoutine: Bool {
        guard store.preferences.quietHours?.contains(Date()) == true else { return true }
        showsQuietHoursNotice = true
        return false
    }

    private func restoreLaunch() {
        guard purchases.checked, !restoredLaunch else { return }
        restoredLaunch = true
        guard store.preferences.completedSetup, purchases.canAccess,
              store.preferences.quietHours?.contains(Date()) != true else { return }
        switch store.preferences.preferredLaunch {
        case .home: break
        case .instagram:
            if store.preferences.hasOpenedInstagram || store.preferences.launchDestination == .instagram { openInstagram() }
        case .facebook: openFacebook()
        case .youtube: openYouTube()
        }
    }

    private func applyMods() {
        session.update(hidden: store.preferences.filtered(store.preferences.mods.hidden), locked: locked)
    }

    private func updateLock() {
        let isLocked = store.preferences.lock?.isActive(at: Date()) ?? false
        if locked != isLocked {
            locked = isLocked
            applyMods()
        }
        if !isLocked && store.preferences.lock != nil { store.preferences.lock = nil }
    }

    private func accountUsage() {
        let now = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        if let start = usageStart, let lastUptime = usageUptime {
            let elapsed = max(0, min(now.timeIntervalSince(start), uptime - lastUptime))
            if elapsed > 0 { store.preferences.usage.add(from: start, to: start.addingTimeInterval(elapsed)) }
        }
        let active = scene == .active && social && purchases.canAccess && sheet == nil && !browserPresented && session.status.countsUsage
        usageStart = active ? now : nil
        usageUptime = active ? uptime : nil
    }

    private func clearSession() async {
        social = false
        store.preferences.hasOpenedInstagram = false
        store.preferences.connectedInstagram = nil
        await session.clear()
    }

    private func reset() async {
        await clearSession()
        for profile in [store.preferences.facebookProfile, store.preferences.youtubeProfile].compactMap({ $0 }) {
            await WKWebsiteDataStore(forIdentifier: profile)
                .removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        }
        facebookSession = nil
        youtubeSession = nil
        purchases.setTesterAccess(false)
        store.reset()
        session = WebSession(profile: store.preferences.profile)
        applyMods()
        sheet = nil
    }
}

private struct PlansSheet: View {
    let purchases: EntitlementStore
    let sample: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var plan = Plan.annual

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 17) {
                    PaywallContent(purchases: purchases, selection: $plan)
                    PrimaryButton(title: buttonTitle, enabled: !purchases.busy && !purchases.loading) {
                        Task {
                            if purchases.product(plan) == nil { await purchases.loadProducts() }
                            else { await purchases.purchase(plan) }
                        }
                    }
                    if purchases.allowsTesterAccess {
                        Button("Continue without paying") { Haptics.selection(); purchases.setTesterAccess(true); dismiss() }
                            .frame(minHeight: 44)
                    }
                    Button("Explore sample preview", action: { Haptics.selection(); sample() }).frame(minHeight: 44)
                }.padding(24)
            }
            .background(PaywallPalette.canvas)
            .tint(PaywallPalette.accent)
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { Haptics.selection(); dismiss() } } }
            .onChange(of: purchases.canAccess) { if purchases.canAccess { dismiss() } }
        }
    }

    private var buttonTitle: String {
        if purchases.busy { return "Working with Apple…" }
        if purchases.loading { return "Loading plans…" }
        if let product = purchases.product(plan) { return "Subscribe · \(product.displayPrice) / \(plan.period)" }
        return "Retry loading plans"
    }
}
