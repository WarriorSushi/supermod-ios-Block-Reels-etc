import SwiftUI
import SafariServices
import WebKit

struct SocialScreen: View {
    let session: WebSession
    let locked: Bool
    let home: () -> Void
    var mods: (() -> Void)? = nil
    var messages: (() -> Void)? = nil
    var grayscale = false
    var timerStore: LocalStore? = nil
    @State private var showingTimer = false
    let browserVisibility: (Bool) -> Void
    @State private var browserURL: BrowserDestination?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scene

    var body: some View {
        VStack(spacing: 0) {
            if showsNotice {
                notice
                    .padding(.trailing, showsSignInNotice ? 48 : 0)
                    .frame(minHeight: showsSignInNotice ? 48 : nil)
                    .background(Palette.selection)
            }
            ZStack {
                PlatformWebView(view: session.webView)
                    .id(ObjectIdentifier(session.webView))
                    .saturation(grayscale && session.status.countsUsage ? 0 : 1)
                    .accessibilityHidden(hasOverlay)
                    .allowsHitTesting(!hasOverlay)
                if hasOverlay { overlay }
                if !hasOverlay, let info = session.feedStatus {
                    VStack { Spacer(); feedNotice(info).padding(.horizontal, 18).padding(.bottom, 72) }
                }
            }
            // WebKit adjusts its viewport for text input. Resizing the host as well
            // makes Instagram dismiss the recipient field as its accessory bar opens.
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .overlay {
            GeometryReader { geometry in
                SocialMenuButton(size: geometry.size, pinnedToNotice: showsSignInNotice,
                                 solidAtRest: hasOverlay || showsSignInNotice,
                                 identifier: "\(session.platformName.lowercased()).supermodControls",
                                 home: home, mods: mods, messages: messages,
                                 timer: timerStore?.preferences.shortVideoBreak,
                                 timerControls: timerStore == nil ? nil : { showingTimer = true })
            }
        }
        .sheet(isPresented: $showingTimer) {
            if let timerStore { ScrollTimerSheet(store: timerStore) }
        }
        .task(id: scene == .active) {
            guard scene == .active, session.platformName == "Instagram" else { return }
            while !Task.isCancelled {
                await session.refreshFeedStatus()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
        .onAppear { session.webView.setAllMediaPlaybackSuspended(false, completionHandler: nil) }
        .onDisappear { session.webView.setAllMediaPlaybackSuspended(true, completionHandler: nil) }
        .background(chromeColor.ignoresSafeArea())
        .foregroundStyle(Palette.ink)
        .onChange(of: browserURL?.url) { browserVisibility(browserURL != nil) }
        .sheet(item: $browserURL) { destination in ExternalBrowser(url: destination.url) }
    }

    private func feedNotice(_ info: FeedStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if info.state == .loading { ProgressView().controlSize(.small) }
                Text(feedTitle(info.state)).font(.subheadline.weight(.semibold))
            }
            if info.state == .hidden {
                Text("Your Home feed filter is on.").font(.caption).foregroundStyle(Palette.muted)
                if let mods { Button("Edit filters", action: mods).frame(minHeight: 44).disabled(locked) }
            } else {
                if info.filtered {
                    Text(session.feedFilterExplanation).font(.caption).foregroundStyle(Palette.muted)
                }
                if info.state == .stalled {
                    Button("Try loading more") { Haptics.selection(); session.retryFeed() }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("feed.retry")
                } else if info.state == .end {
                    Text("No more posts in this feed right now.").font(.caption).foregroundStyle(Palette.muted)
                    Button("Refresh feed") { Haptics.selection(); session.retryFeed() }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("feed.refresh")
                }
            }
        }
        .font(.subheadline.weight(.medium))
        .frame(maxWidth: 360, alignment: .leading)
        .padding(16)
        .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feed.status")
    }

    private func feedTitle(_ state: FeedState) -> String {
        switch state {
        case .loading: "Loading more posts…"
        case .stalled: "More posts haven’t loaded"
        case .end: "You’ve reached the end"
        case .hidden: "Home feed is hidden"
        }
    }

    private var showsSignInNotice: Bool {
        session.status == .authentication || session.status == .challenge
    }

    private var showsNotice: Bool {
        showsSignInNotice || session.status == .uncertain || session.suspended
    }

    private var chromeColor: Color {
        if showsNotice { return Palette.selection }
        if hasOverlay { return Palette.canvas }
        if let scheme = session.facebookChromeScheme {
            return scheme == .light ? .white : .black
        }

        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let page = session.pageBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard page.getRed(&red, green: &green, blue: &blue, alpha: &alpha), alpha > 0.98 else {
            return Color(uiColor: .systemBackground)
        }
        let brightness = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        let readable = colorScheme == .dark ? brightness < 0.5 : brightness >= 0.5
        return Color(uiColor: readable ? page : .systemBackground)
    }

    private var hasOverlay: Bool {
        switch session.status {
        case .offline, .error, .terminated, .blocked, .external, .idle, .loading: true
        default: false
        }
    }

    private var notice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(noticeCopy).font(.footnote).foregroundStyle(Palette.ink)
            if session.status == .authentication,
               session.webView.url?.path.split(separator: "/").isEmpty == true {
                Button("Sign in to \(session.platformName)", action: { Haptics.selection(); session.signIn() })
                    .font(.footnote.weight(.bold)).frame(minHeight: 44)
            } else if session.status == .uncertain && !locked && !session.suspended {
                Button("Pause filters for this session") { Haptics.selection(); session.setSuspended(true) }
                    .font(.footnote.weight(.bold)).frame(minHeight: 44)
            } else if session.suspended {
                Button("Resume filters") { Haptics.selection(); session.setSuspended(false) }
                    .font(.footnote.weight(.bold)).frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 17)
        .padding(.vertical, 9)
    }

    private var noticeCopy: String {
        if session.suspended { return "Filters paused for this \(session.platformName) session." }
        switch session.status {
        case .challenge: return "Complete \(session.platformName)’s security check below."
        case .authentication: return "You’re on \(session.platformName)’s own sign-in or account page."
        default: return locked
            ? "Supermod couldn’t recognize this layout. Your filters are locked and remain on."
            : "Supermod couldn’t recognize this layout. Some filters may be incomplete."
        }
    }

    @ViewBuilder private var overlay: some View {
        ScrollView {
            VStack(spacing: 19) {
                switch session.status {
                case .loading, .idle:
                    BrandMascot(size: 64)
                    ProgressView().accessibilityLabel("Connecting")
                    Heading(title: "Opening \(session.platformName)…", detail: "Connecting to \(session.platformName)’s website.", centered: true)
                case .offline:
                    state("You’re offline.", "Check your connection and try again.", "wifi.slash", "Try again")
                case .error:
                    state("\(session.platformName) couldn’t open.", "The page may be unavailable or taking too long.", "exclamationmark.circle", "Try again")
                case .terminated:
                    state("\(session.platformName) stopped responding.", "Reopen the page to continue. An unsent draft may be lost.", "arrow.clockwise", "Reopen page")
                case .blocked(let mod):
                    state("\(session.platformName == "YouTube" && mod == .reels ? "Shorts" : mod.title) hidden",
                          session.platformName == "YouTube"
                          ? "Turn off Hide Shorts in Modifications to open this video."
                          : mod == .reels
                          ? "Your Reels setting blocks this link. Shared Reels are blocked while Reels are hidden."
                          : "This page is hidden by your current modifications.", mod.symbol, "Go back")
                case .external(let url):
                    state("This link leaves \(session.platformName).", "You can return to your current page.", "arrow.up.right.square", "Go back")
                    if let url, url.scheme == "https", url.user == nil, url.password == nil {
                        Button("Open in browser") { Haptics.selection();
                            session.recover()
                            browserURL = BrowserDestination(url: url)
                        }.font(.headline).frame(minHeight: 44)
                    }
                default:
                    EmptyView()
                }
            }
            .padding(26)
            .frame(maxWidth: 460)
            .padding(.top, 64)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.canvas)
    }

    private func state(_ title: String, _ detail: String, _ icon: String, _ button: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.title)
                .frame(width: 65, height: 65).background(Palette.selection, in: Circle())
                .accessibilityHidden(true)
            Heading(title: title, detail: detail, centered: true)
            PrimaryButton(title: button, action: session.recover)
        }
    }
}

private struct SocialMenuButton: View {
    let size: CGSize
    let pinnedToNotice: Bool
    let solidAtRest: Bool
    let identifier: String
    let home: () -> Void
    let mods: (() -> Void)?
    let messages: (() -> Void)?
    let timer: ShortVideoBreak?
    let timerControls: (() -> Void)?
    @AppStorage("socialMenuPosition") private var verticalPosition = 1.0 / 3.0
    @AppStorage("socialMenuOnLeft") private var onLeft = false
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var pendingAction: (() -> Void)?
    @GestureState private var dragOffset: CGSize = .zero

    private let touchSize: CGFloat = 52
    private var top: CGFloat { 30 }
    private var bottom: CGFloat { max(top, size.height - top) }
    private var travel: CGFloat { max(1, bottom - top) }
    private var center: CGFloat { top + travel * min(1, max(0, verticalPosition)) }
    private var edgeX: CGFloat { onLeft && !pinnedToNotice ? touchSize / 2 + 8 : max(touchSize / 2, size.width - touchSize / 2 - 8) }

    var body: some View {
        Button { Haptics.selection();
            expanded.toggle()
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(SocialMenuStyle(solid: solidAtRest || expanded || dragOffset != .zero))
        .overlay { if let timer { TimerMenuRing(timer: timer) } }
        .accessibilityLabel("Supermod controls")
        .accessibilityValue(expanded ? "Expanded" : (timer?.isActive(at: Date()) == true ? "Scroll timer running. Open to see time remaining." : ""))
        .accessibilityIdentifier(identifier)
        .accessibilityHint("Tap for controls. Drag to move to either edge.")
        .accessibilityActions {
            if !pinnedToNotice {
                Button("Move up") { Haptics.selection(); move(to: center - 56) }
                Button("Move down") { Haptics.selection(); move(to: center + 56) }
                Button(onLeft ? "Move to right edge" : "Move to left edge") { Haptics.selection(); onLeft.toggle() }
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                .updating($dragOffset) { value, offset, _ in
                    if !pinnedToNotice && !expanded { offset = value.translation }
                }
                .onEnded { value in
                    if !pinnedToNotice && !expanded {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                            onLeft = edgeX + value.translation.width < size.width / 2
                            move(to: center + value.translation.height)
                        }
                    }
                }
        )
        .popover(isPresented: $expanded, arrowEdge: onLeft && !pinnedToNotice ? .leading : .trailing) {
            VStack(spacing: 0) {
                if let timerControls {
                    if let timer, let end = timer.endsAt, timer.isActive(at: Date()) {
                        Text(end, style: .timer).font(.headline.monospacedDigit()).padding(8)
                            .accessibilityLabel("Scroll timer remaining")
                    }
                    menuItem("Scroll timer", symbol: "timer", action: timerControls)
                }
                if let mods { menuItem("Modifications", symbol: "slider.horizontal.3", action: mods) }
                if let messages { menuItem("Messenger", symbol: "message", action: messages) }
                menuItem("Home", symbol: "house", action: home)
            }
            .padding(6)
            .frame(idealWidth: 205)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(Palette.ink)
            .presentationCompactAdaptation(.popover)
            .onDisappear {
                let action = pendingAction
                pendingAction = nil
                action?()
            }
        }
        .position(x: min(max(touchSize / 2, edgeX + dragOffset.width), max(touchSize / 2, size.width - touchSize / 2)),
                  y: pinnedToNotice ? top : clamped(center + dragOffset.height))
    }

    private func menuItem(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.selection();
            pendingAction = action
            expanded = false
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("social.menu.\(title.lowercased())")
    }

    private func clamped(_ y: CGFloat) -> CGFloat {
        min(max(y, top), bottom)
    }

    private func move(to y: CGFloat) {
        Haptics.selection()
        verticalPosition = (clamped(y) - top) / travel
    }
}

private struct SocialMenuStyle: ButtonStyle {
    let solid: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        let opaque = solid || configuration.isPressed || reduceTransparency || contrast == .increased
        configuration.label
            .foregroundStyle(Palette.ink.opacity(opaque ? 1 : 0.85))
            .background(Palette.canvas.opacity(opaque ? 1 : 0.86), in: Circle())
            .overlay { Circle().strokeBorder(Palette.ink.opacity(opaque ? 0.18 : 0.12)) }
            .shadow(color: .black.opacity(opaque ? 0.14 : 0.08), radius: 5, y: 2)
            .frame(width: 52, height: 52)
            .contentShape(Circle())
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: opaque)
    }
}

private struct BrowserDestination: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct ExternalBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
