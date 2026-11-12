import SwiftUI
import StoreKit
import SafariServices

struct HomeView: View {
    let store: LocalStore
    let open: () -> Void
    let openFacebook: () -> Void
    let openYouTube: () -> Void
    let settings: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Brand()
                    Spacer()
                    CircleButton(symbol: "gearshape", label: "Settings", action: settings)
                }
                HomeTipsCarousel()
                HStack(spacing: 14) {
                    platformButton(.instagram, action: open)
                    platformButton(.facebook, action: openFacebook)
                    platformButton(.youtube, action: openYouTube)
                }
                .frame(maxWidth: 390)
                .padding(.top, 10)
                ScrollTimerCard(store: store).padding(.top, 12)
                FilterLockButton(store: store)
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .buttonStyle(.plain)
        .foregroundStyle(Palette.ink)
        .background(Palette.canvas.ignoresSafeArea())
    }

    private func platformButton(_ platform: SocialPlatform, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.selection(); action() }) {
            HomePlatformIcon(platform: platform)
                .aspectRatio(1, contentMode: .fit)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(platform.title)
        .accessibilityIdentifier("home.\(platform.rawValue)")
    }
}

private struct HomeTipsCarousel: View {
    @Environment(\.scenePhase) private var scene
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var cardHeight = 122.0
    @AppStorage("supermod.homeTipsPaused") private var paused = false
    @State private var selected = Tip.welcome

    private var canRotate: Bool { !reduceMotion && !voiceOver }
    private var autoRotate: Bool { canRotate && !paused && scene == .active }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selected) {
                ForEach(Tip.allCases) { tip in
                    tipCard(tip).tag(tip)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: cardHeight)
            .accessibilityIdentifier("home.tips")
            HStack(spacing: 0) {
                ForEach(Tip.allCases) { tip in
                    Button { Haptics.selection();
                        select(tip)
                    } label: {
                        Capsule()
                            .fill(tip == selected ? Palette.ink : Palette.line)
                            .frame(width: tip == selected ? 15 : 6, height: 6)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Tip \(tip.rawValue + 1) of \(Tip.allCases.count)")
                    .accessibilityAddTraits(tip == selected ? .isSelected : [])
                    .accessibilityIdentifier("home.tip.\(tip.rawValue)")
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                if canRotate {
                    Button { Haptics.selection();
                        paused.toggle()
                    } label: {
                        Image(systemName: paused ? "play.fill" : "pause.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.muted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(paused ? "Resume tips" : "Pause tips")
                    .accessibilityIdentifier("home.tips.rotation")
                }
            }
        }
        .task(id: Rotation(tip: selected, enabled: autoRotate)) {
            guard autoRotate else { return }
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            guard !Task.isCancelled else { return }
            let index = (selected.rawValue + 1) % Tip.allCases.count
            select(Tip.allCases[index])
        }
    }

    private func select(_ tip: Tip) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { selected = tip }
    }

    private func tipCard(_ tip: Tip) -> some View {
        GeometryReader { card in
            HStack(spacing: 2) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title).font(.subheadline.weight(.bold))
                    Text(tip.detail).font(.caption.weight(.medium))
                        .foregroundStyle(Color(hex: 0x643F39))
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(tip.art)
                    .resizable()
                    .scaledToFit()
                    .frame(width: card.size.width * (textSize.isAccessibilitySize ? 0.24 : 0.37),
                           height: min(card.size.height - 10, 135))
                    .accessibilityHidden(true)
            }
            .padding(.leading, 16).padding(.trailing, 4)
            .frame(maxHeight: .infinity)
            .foregroundStyle(Color(hex: 0x30201C))
            .background(LinearGradient(colors: [tip.tint, Color(hex: 0xFFF4E8)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.55)) }
        }
    }

    private struct Rotation: Equatable {
        let tip: Tip
        let enabled: Bool
    }

    private enum Tip: Int, CaseIterable, Identifiable {
        case welcome, timer, quiet
        var id: Self { self }

        var title: String {
            switch self {
            case .welcome: "Make room for what matters."
            case .timer: "Cat’s on the clock."
            case .quiet: "Paws for a bit."
            }
        }

        var detail: String {
            switch self {
            case .welcome: "Your feed, your control."
            case .timer: "Start a Scroll timer on Home. Your selected features hide when it ends."
            case .quiet: "Set Quiet Hours in Settings to pause opening feeds on your schedule."
            }
        }

        var art: String {
            switch self {
            case .welcome: "MascotHome"
            case .timer: "MascotTimer"
            case .quiet: "MascotRest"
            }
        }

        var tint: Color {
            switch self {
            case .welcome: Color(hex: 0xF6C4AF)
            case .timer: Color(hex: 0xF6CEDA)
            case .quiet: Color(hex: 0xE3D9F5)
            }
        }
    }
}

private struct HomePlatformIcon: View {
    let platform: SocialPlatform

    var body: some View {
        GeometryReader { icon in
            let size = icon.size.width
            let shape = RoundedRectangle(cornerRadius: size * 0.24)
            shape
                .fill(LinearGradient(colors: glassColors, startPoint: .top, endPoint: .bottom))
                .overlay {
                    shape.fill(RadialGradient(
                        colors: [lightColor.opacity(0.82), lightColor.opacity(0)],
                        center: UnitPoint(x: 0.46, y: 0.36),
                        startRadius: 0, endRadius: size * 0.68))
                }
                .overlay {
                    // The dark inside edge and lighter outside edge give the glass depth.
                    shape.strokeBorder(edgeColor.opacity(0.50), lineWidth: size * 0.055)
                    shape.inset(by: size * 0.009).strokeBorder(
                        LinearGradient(colors: [edgeColor, lightColor, edgeColor],
                                       startPoint: .topTrailing, endPoint: .bottomLeading),
                        lineWidth: size * 0.022)
                    shape.inset(by: size * 0.038).strokeBorder(
                        LinearGradient(stops: [
                            .init(color: .white.opacity(0.96), location: 0),
                            .init(color: lightColor.opacity(0.45), location: 0.23),
                            .init(color: edgeColor.opacity(0.65), location: 0.52),
                            .init(color: lightColor, location: 0.82),
                            .init(color: .white.opacity(0.86), location: 1)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: size * 0.027)
                    shape.inset(by: size * 0.071).strokeBorder(
                        LinearGradient(colors: [edgeColor.opacity(0.55), .clear, .white.opacity(0.46)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: size * 0.014)
                }
                .overlay {
                    glassGlint(size: size)
                }
                .overlay {
                    glyph(size: size)
                        .foregroundStyle(.white)
                        .shadow(color: edgeColor.opacity(0.52), radius: size * 0.023, y: size * 0.016)
                }
                .clipShape(shape)
                .shadow(color: edgeColor.opacity(0.28), radius: size * 0.06, y: size * 0.04)
                .contentShape(shape)
        }
        .accessibilityHidden(true)
    }

    private var glassColors: [Color] {
        switch platform {
        case .instagram: [Color(hex: 0xD00976), Color(hex: 0xF64982), Color(hex: 0xFF8853), Color(hex: 0xFFC56B)]
        case .facebook: [Color(hex: 0x0747BF), Color(hex: 0x008FE2), Color(hex: 0x0063DF)]
        case .youtube: [Color(hex: 0xB0092D), Color(hex: 0xEB0B25), Color(hex: 0xF52A32), Color(hex: 0xB60424)]
        }
    }

    private var lightColor: Color {
        switch platform {
        case .instagram: Color(hex: 0xFF8DC0)
        case .facebook: Color(hex: 0x43D7FF)
        case .youtube: Color(hex: 0xFF5565)
        }
    }

    private var edgeColor: Color {
        switch platform {
        case .instagram: Color(hex: 0x9D1259)
        case .facebook: Color(hex: 0x043F9F)
        case .youtube: Color(hex: 0x870525)
        }
    }

    private func glassGlint(size: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.075, y: size * 0.30))
            path.addCurve(to: CGPoint(x: size * 0.27, y: size * 0.075),
                          control1: CGPoint(x: size * 0.075, y: size * 0.14),
                          control2: CGPoint(x: size * 0.15, y: size * 0.075))
            path.addLine(to: CGPoint(x: size * 0.66, y: size * 0.075))
        }
        .stroke(LinearGradient(colors: [.white.opacity(0.30), .white.opacity(0.94), .clear],
                               startPoint: .bottomLeading, endPoint: .topTrailing),
                style: StrokeStyle(lineWidth: size * 0.031, lineCap: .round))
    }

    @ViewBuilder private func glyph(size: CGFloat) -> some View {
        switch platform {
        case .instagram:
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: size * 0.14).strokeBorder(lineWidth: size * 0.045)
                Circle().strokeBorder(lineWidth: size * 0.042)
                    .frame(width: size * 0.23, height: size * 0.23)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Circle().fill().frame(width: size * 0.06, height: size * 0.06)
                    .padding(size * 0.09)
            }
            .frame(width: size * 0.57, height: size * 0.57)
        case .facebook:
            Text("f").font(.system(size: size * 0.76, weight: .heavy))
                .offset(y: size * 0.035)
        case .youtube:
            Image(systemName: "play.fill").font(.system(size: size * 0.44, weight: .semibold))
                .offset(x: size * 0.025)
        }
    }
}

enum SocialPlatform: String, CaseIterable {
    case instagram, facebook, youtube

    var title: String { self == .youtube ? "YouTube" : rawValue.capitalized }

    var colors: [Color] {
        switch self {
        case .instagram: [Color(hex: 0xA73179), Color(hex: 0xD94C52), Color(hex: 0xFFAE6F)]
        case .facebook: [Color(hex: 0x3873DF), Color(hex: 0x183A9B)]
        case .youtube: [Color(hex: 0xE44448), Color(hex: 0xAD1733)]
        }
    }

    var emblem: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(LinearGradient(
                    colors: colors,
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            if self == .instagram {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(lineWidth: 1.8)
                    Circle().strokeBorder(lineWidth: 1.8).frame(width: 9, height: 9)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Circle().fill().frame(width: 3, height: 3).padding(4.5)
                }
                .frame(width: 23, height: 23)
            } else if self == .facebook {
                Text("f")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .offset(y: -1)
            } else {
                Image(systemName: "play.fill").font(.system(size: 16, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: 46, height: 46)
        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.24)) }
        .accessibilityHidden(true)
    }
}

struct UsageSummary: View {
    let usage: Usage
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time in Instagram today").font(.subheadline.weight(.semibold))
            Text(formattedUsage(usage.seconds(on: Date()))).font(.title.weight(.bold)).monospacedDigit()
            Text("Foreground time inside Supermod.").font(.footnote).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 21))
        .accessibilityElement(children: .combine)
    }

    private func formattedUsage(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0 min" }
        guard seconds >= 60 else { return "<1 min" }
        return Duration.seconds(Int(seconds)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

struct ModsSheet: View {
    @Bindable var store: LocalStore
    var web: WebSession?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let lock = store.preferences.lock.flatMap { $0.isActive(at: context.date) ? $0 : nil }
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let lock {
                            InfoLine(icon: "lock", title: "Your filters are locked",
                                     detail: "You can change your filters again at \(lock.end.formatted(date: .omitted, time: .shortened)).")
                        }
                        ScrollTimerCard(store: store)
                        if let timer = store.preferences.shortVideoBreak, timer.isActive(at: context.date) {
                            Text("The timer is temporarily showing \(timer.featureNames). Your saved filters below apply when it ends.")
                                .font(.subheadline).foregroundStyle(Palette.muted)
                        }
                        ModsEditor(mods: $store.preferences.mods, locked: lock != nil)
                        if let web, web.suspended {
                            Button("Resume filters") { Haptics.selection(); web.setSuspended(false) }
                                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        }
                        FilterLockButton(store: store) { web?.setSuspended(false) }
                    }.padding(24)
                }
                .background(Palette.canvas)
            }
            .navigationTitle("Modifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { Haptics.selection(); dismiss() } } }

        }
        .foregroundStyle(Palette.ink)
    }
}

struct SettingsView: View {
    @Bindable var store: LocalStore
    let purchases: EntitlementStore
    let replay: () -> Void
    let plans: () -> Void
    let instagramControls: () -> Void
    let preview: () -> Void
    let clear: () async -> Void
    let reset: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var policy: PolicyPage?
    @State private var action: Deletion?
    @State private var working = false
    @State private var manage = false

    private enum Deletion: String {
        case usage = "Reset local usage", instagram = "Clear Instagram session", all = "Reset all local data"
        var explanation: String {
            switch self {
            case .usage: "Delete the usage totals saved on this device."
            case .instagram: "Sign out of Instagram in Supermod and remove its local website data. Your Supermod choices stay saved."
            case .all: "Delete setup, modifications, usage, and all local social sessions. Apple manages subscriptions separately."
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Supermod") {
                    Button("Instagram controls", action: { Haptics.selection(); instagramControls() })
                    Button("Open sample preview", action: { Haptics.selection(); preview() })
                }
                Section("Appearance and launch") {
                    Picker("Theme", selection: $store.preferences.theme) {
                        ForEach(Theme.allCases) { theme in Text(theme.rawValue).tag(theme) }
                    }
                    Picker("Open on launch", selection: Binding(
                        get: { store.preferences.preferredLaunch },
                        set: { store.preferences.launchDestination = $0 }
                    )) {
                        ForEach(LaunchDestination.allCases) { destination in
                            Text(destination.rawValue).tag(destination)
                        }
                    }
                    Toggle("Grayscale while browsing", isOn: Binding(
                        get: { store.preferences.grayscale ?? false },
                        set: { store.preferences.grayscale = $0 }
                    ))
                    Button("Replay onboarding", action: { Haptics.selection(); replay() })
                }
                Section {
                    Toggle("Quiet hours", isOn: Binding(
                        get: { store.preferences.quietHours != nil },
                        set: { store.preferences.quietHours = $0 ? QuietHours() : nil }
                    ))
                    if let quietHours = store.preferences.quietHours {
                        DatePicker("Start", selection: quietTime(\.start), displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: quietTime(\.end), displayedComponents: .hourAndMinute)
                        if quietHours.start == quietHours.end {
                            Text("Choose different times to activate the schedule.").foregroundStyle(Palette.muted)
                        }
                    }
                } footer: {
                    Text("Prevents opening feeds in Supermod during the same hours each day. An open feed can finish its session.")
                }
                Section("Subscription") {
                    LabeledContent("Status", value: subscriptionStatus)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Subscription status")
                        .accessibilityValue(subscriptionStatus)
                        .accessibilityIdentifier("settings.subscriptionStatus")
                    Button("View plans", action: { Haptics.selection(); plans() })
                    if purchases.allowsTesterAccess {
                        Toggle("Temporary testing access", isOn: Binding(get: { purchases.testerAccess }, set: { Haptics.selection(); purchases.setTesterAccess($0) }))
                        Text("Open the app without a purchase. This switch exists only in development builds.").font(.footnote)
                    }
                    Button("Restore purchases") { Haptics.selection(); Task { await purchases.restore() } }.disabled(purchases.busy)
                    if purchases.entitled { Button("Manage subscription") { Haptics.selection(); manage = true } }
                    if let message = purchases.message { Text(message).font(.footnote).foregroundStyle(Palette.muted) }
                }
                Section("On this device") {
                    UsageSummary(usage: store.preferences.usage)
                        .listRowInsets(EdgeInsets())
                    Button("Reset local usage", role: .destructive) { Haptics.selection(); action = .usage }
                    Button("Clear Instagram session", role: .destructive) { Haptics.selection(); action = .instagram }
                    Button("Reset all local data", role: .destructive) { Haptics.selection(); action = .all }
                }
                Section("About") {
                    ForEach([PolicyPage.privacy, .terms, .help]) { page in
                        Button(page.rawValue) { Haptics.selection(); policy = page }
                    }
                    LabeledContent("Supermod", value: "1.0")
                }
            }
            .disabled(working)
            .tint(Palette.ink)
            .scrollContentBackground(.hidden)
            .background(Palette.canvas)
            .onChange(of: store.preferences.theme) { Haptics.selection() }
            .onChange(of: store.preferences.launchDestination) { Haptics.selection() }
            .onChange(of: store.preferences.grayscale) { Haptics.selection() }
            .onChange(of: store.preferences.quietHours) { Haptics.selection() }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { Haptics.selection(); dismiss() }.disabled(working) } }
            .sheet(item: $policy) { PolicySheet(page: $0) }
            .manageSubscriptionsSheet(isPresented: $manage)
            .confirmationDialog(action?.rawValue ?? "", isPresented: Binding(
                get: { action != nil }, set: { if !$0 { action = nil } }
            ), titleVisibility: .visible, presenting: action) { choice in
                Button(choice.rawValue, role: .destructive) { Haptics.selection();
                    Task { await delete(choice) }
                }
            } message: { choice in
                Text(choice.explanation)
            }
            .overlay { if working { ProgressView("Clearing…").padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)) } }
            .interactiveDismissDisabled(working)
        }
    }

    private func quietTime(_ field: WritableKeyPath<QuietHours, Int>) -> Binding<Date> {
        Binding {
            let minute = (store.preferences.quietHours ?? QuietHours())[keyPath: field]
            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            Haptics.selection()
            guard var schedule = store.preferences.quietHours else { return }
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            schedule[keyPath: field] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            store.preferences.quietHours = schedule
        }
    }

    private var subscriptionStatus: String {
        if !purchases.checked { return "Checking…" }
        if purchases.entitled { return "Active" }
        return purchases.testerAccess ? "Testing · no purchase" : "Inactive"
    }

    private func delete(_ choice: Deletion) async {
        working = true
        defer { working = false }
        switch choice {
        case .usage: store.preferences.usage = Usage()
        case .instagram: await clear()
        case .all: await reset()
        }
    }
}

struct SampleView: View {
    let initialMods: ModSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var panel = DemoPanel.feed
    @State private var mods: ModSettings
    @State private var editing = false

    init(initialMods: ModSettings) {
        self.initialMods = initialMods
        _mods = State(initialValue: initialMods)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 8) {
                    Text("Sample accounts · changes stay in this preview")
                        .font(.caption).foregroundStyle(Palette.muted)
                    Picker("Sample screen", selection: $panel) {
                        ForEach(DemoPanel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    PhoneDemo(hidden: mods.hidden, panel: panel, width: min(310, max(140, (geometry.size.height - 142) / (864.0 / 410))), showsAd: true)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.23), value: mods.hidden)
                    Spacer(minLength: 0)
                    PrimaryButton(title: "Try modifications", icon: "slider.horizontal.3") { editing = true }
                }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 16).frame(maxWidth: 500).frame(maxWidth: .infinity)
            }
            .background(Palette.canvas)
            .onChange(of: panel) { Haptics.selection() }
            .navigationTitle("Supermod preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { Haptics.selection(); dismiss() } } }
            .sheet(isPresented: $editing) {
                NavigationStack {
                    ScrollView { ModsEditor(mods: $mods).padding(24) }
                        .background(Palette.canvas)
                        .navigationTitle("Sample modifications")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { Haptics.selection(); editing = false } } }
                }
            }
        }
        .foregroundStyle(Palette.ink)
    }
}


