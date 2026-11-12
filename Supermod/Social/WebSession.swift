import SwiftUI
import WebKit

enum WebStatus: Equatable {
    case idle, loading, browsing, authentication, challenge, offline, error, terminated, blocked(Mod), external(URL?), uncertain

    var countsUsage: Bool { self == .browsing || self == .uncertain }
}

enum FeedState: String { case loading, stalled, end, hidden }

struct FeedStatus: Equatable {
    let state: FeedState
    let filtered: Bool
}

struct FilterScripts {
    enum Engine {
        case instagram, facebook, youtube

        var script: String {
            switch self {
            case .instagram: "engine"
            case .facebook: "facebook-engine"
            case .youtube: "youtube-engine"
            }
        }
    }

    static let world = WKContentWorld.world(name: "SupermodFiltering")

    static func resource(_ name: String, _ extensionName: String) -> String? {
        Bundle.main.url(forResource: name, withExtension: extensionName)
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    static func install(on controller: WKUserContentController, hidden: Set<Mod>, fixture: Bool = false,
                        engine platform: Engine = .instagram) {
        controller.removeAllUserScripts()
        let rules = platform == .instagram ? resource("instagram-rules", "json") : "{}"
        guard let engine = resource(platform.script, "js"), let rules,
              let experience = resource("web-experience", "js"),
              let css = resource("instagram", "css"), let observer = resource("route-observer", "js"),
              let cssJSON = try? JSONEncoder().encode(css), let hiddenJSON = try? JSONEncoder().encode(hidden.map(\.rawValue)),
              let cssString = String(data: cssJSON, encoding: .utf8),
              let hiddenString = String(data: hiddenJSON, encoding: .utf8) else { return }

        let bootstrap = "globalThis.supermodBootstrap = {hidden: \(hiddenString), rules: \(rules), css: \(cssString), fixture: \(fixture)};"
        if platform == .instagram, let feed = resource("instagram-feed", "js") {
            controller.addUserScript(WKUserScript(source: "globalThis.supermodFeedBootstrap = \(hiddenString);" + feed,
                                                  injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        controller.addUserScript(WKUserScript(source: observer, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.addUserScript(WKUserScript(source: bootstrap + experience + engine, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: world))
    }
}

@MainActor @Observable
final class WebSession: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private let adapter: any PlatformAdapter
    private let dataStore: WKWebsiteDataStore
    private(set) var webView: WKWebView!
    private var observation: NSKeyValueObservation?
    private var backgroundObservation: NSKeyValueObservation?
    private(set) var pageBackground: UIColor = .systemBackground
    private(set) var facebookChromeScheme: ColorScheme?
    private var hidden: Set<Mod> = []
    private var activeNavigation: WKNavigation?
    private var lastSafeURL: URL?
    private var blockedInDocument = false
    private var feedReloadPending = false
    private var clearing = false
    private var refreshing = false
    private var timeout: Task<Void, Never>?
    private(set) var suspended = false
    private(set) var detectedConnection = false
    private(set) var status: WebStatus = .idle
    private(set) var feedStatus: FeedStatus?
    var platformName: String { adapter.name }

    convenience init(profile: UUID) {
        self.init(adapter: InstagramAdapter(), dataStore: .init(forIdentifier: profile))
    }

    init(adapter: any PlatformAdapter, dataStore: WKWebsiteDataStore) {
        self.adapter = adapter
        self.dataStore = dataStore
        super.init()
        configureView()
    }

    private func configureView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        // Let the page keep its video and vertical swipe controls in the same view.
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController.add(WeakScriptHandler(self), contentWorld: FilterScripts.world, name: "supermod")
        FilterScripts.install(on: configuration.userContentController, hidden: effectiveHidden, engine: adapter.filterEngine)
        let view = WKWebView(frame: .zero, configuration: configuration)
        #if DEBUG && targetEnvironment(simulator)
        view.isInspectable = true
        #endif
        view.navigationDelegate = self
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = true
        let refresh = UIRefreshControl()
        refresh.accessibilityLabel = "Refresh feed"
        refresh.addTarget(self, action: #selector(pulledToRefresh(_:)), for: .valueChanged)
        view.scrollView.refreshControl = refresh
        view.scrollView.alwaysBounceVertical = true
        webView = view
        facebookChromeScheme = nil
        pageBackground = view.underPageBackgroundColor
        backgroundObservation = view.observe(\.underPageBackgroundColor, options: [.new]) { [weak self, weak view] _, _ in
            Task { @MainActor in
                guard let self, let view, view === self.webView else { return }
                self.pageBackground = view.underPageBackgroundColor
            }
        }
        observation = view.observe(\.url, options: [.new]) { [weak self, weak view] _, _ in
            Task { @MainActor in
                guard let self, let view, view === self.webView else { return }
                self.checkRoute()
            }
        }
    }

    private var canRefreshFeed: Bool {
        guard let url = webView.url else { return false }
        return !clearing && adapter.owns(url) && url.path == "/" && status.countsUsage
    }

    @objc private func pulledToRefresh(_ control: UIRefreshControl) {
        guard !refreshing, canRefreshFeed, let url = webView.url else {
            if !refreshing { control.endRefreshing() }
            return
        }
        refreshing = true
        let view = webView!
        Task { [weak self, weak view] in
            guard let self, let view else { control.endRefreshing(); return }
            let safe = try? await view.evaluateJavaScript("""
                !document.activeElement?.matches('input,textarea,[contenteditable="true"]') &&
                !document.querySelector('dialog[open],[role="dialog"]:not([hidden]):not([aria-hidden="true"])')
                """) as? Bool
            guard view === self.webView, view.url == url, self.canRefreshFeed, safe == true else {
                self.finishRefresh()
                return
            }
            self.feedStatus = nil
            self.activeNavigation = view.reload()
            if self.activeNavigation == nil { self.finishRefresh() }
            else { self.scheduleTimeout() }
        }
    }

    private func finishRefresh() {
        refreshing = false
        webView.scrollView.refreshControl?.endRefreshing()
    }

    private func updateRefreshAvailability() {
        webView.scrollView.refreshControl?.isEnabled = canRefreshFeed || refreshing
    }

    private var effectiveHidden: Set<Mod> { suspended ? [] : hidden }

    func update(hidden: Set<Mod>, locked: Bool) {
        let wasSuspended = suspended
        if locked { suspended = false }
        guard self.hidden != hidden || wasSuspended != suspended else { return }
        self.hidden = hidden
        apply()
    }

    func setSuspended(_ value: Bool) {
        guard suspended != value else { return }
        suspended = value
        apply()
        if case .blocked = status, value { recover() }
    }

    private func apply() {
        let view = webView!
        FilterScripts.install(on: view.configuration.userContentController, hidden: effectiveHidden, engine: adapter.filterEngine)
        let selection = effectiveHidden.map(\.rawValue)
        Task { [weak self, weak view] in
            guard let self, let view, view === self.webView else { return }
            if self.adapter.filterEngine == .instagram {
                let changed = try? await view.callAsyncJavaScript("return globalThis.supermodConfigureFeed?.(hidden) ?? false;",
                                                                  arguments: ["hidden": selection], in: nil, contentWorld: .page)
                self.feedReloadPending = self.feedReloadPending || changed as? Bool == true
            }
            _ = try? await view.callAsyncJavaScript("return globalThis.supermodApply?.(hidden) ?? false;",
                                                   arguments: ["hidden": selection], in: nil, contentWorld: FilterScripts.world)
            guard view === self.webView else { return }
            self.checkRoute()
        }
    }

    func open() {
        guard status == .idle, !clearing else { return }
        load(adapter.entry)
    }

    func recover() {
        guard !clearing else { return }
        // A page visited while filters were paused may no longer be a safe destination.
        let destination = lastSafeURL.flatMap {
            adapter.decision(for: $0, hidden: effectiveHidden) == .allow ? $0 : nil
        } ?? adapter.entry
        if status == .terminated {
            detachView()
            configureView()
        }
        if case .blocked = status {
            if !blockedInDocument, webView.url != nil {
                settle()
                return
            }
            if blockedInDocument, adapter.filterEngine != .youtube,
               let previous = webView.backForwardList.backItem, previous.url == destination {
                status = .loading
                blockedInDocument = false
                activeNavigation = webView.goBack()
                scheduleTimeout()
                return
            }
        }
        if case .external = status {
            settle()
            return
        }
        load(destination)
    }

    func refreshFeedStatus() async {
        guard adapter.filterEngine == .instagram, status == .browsing, !suspended,
              let url = webView.url, adapter.owns(url), url.path == "/" else {
            feedStatus = nil
            return
        }
        let view = webView!
        let result = try? await view.evaluateJavaScript("globalThis.supermodFeedStatus?.() ?? null")
        guard view === webView, webView.url == url, status == .browsing else { feedStatus = nil; return }
        let next: FeedStatus?
        if let value = result as? [String: Any], let raw = value["state"] as? String, let state = FeedState(rawValue: raw) {
            next = FeedStatus(state: state, filtered: value["filtered"] as? Bool == true)
        } else { next = nil }
        if feedStatus != next { feedStatus = next }
    }

    func retryFeed() {
        guard adapter.filterEngine == .instagram, status == .browsing,
              let url = webView.url, adapter.owns(url), url.path == "/" else { return }
        Task { [weak self] in
            guard let self else { return }
            let action = try? await self.webView.evaluateJavaScript("""
                (() => {
                  if (location.pathname !== '/' || document.querySelector('input:focus,textarea:focus,[contenteditable="true"]:focus,dialog[open],[role="dialog"]:not([hidden]):not([aria-hidden="true"])')) return 'protected';
                  return globalThis.supermodLoadMoreFeed?.() ? 'requested' : 'refresh';
                })()
                """) as? String
            guard self.webView.url == url, self.status == .browsing else { return }
            if action == "requested" { await self.refreshFeedStatus() }
            else if action == "refresh" { self.load(url) }
        }
    }

    var feedFilterExplanation: String {
        if effectiveHidden.contains(.suggestions) && effectiveHidden.contains(.sponsored) { return "Suggested posts and ads are hidden." }
        if effectiveHidden.contains(.suggestions) { return "Suggested posts are hidden." }
        if effectiveHidden.contains(.sponsored) { return "Ads are hidden." }
        return ""
    }

    func signIn() {
        load(adapter.signInURL)
    }

    func openFacebookMessages() {
        guard adapter.filterEngine == .facebook else { return }
        load(URL(string: "https://www.facebook.com/messages/")!)
    }

    private func detachView() {
        finishRefresh()
        observation?.invalidate()
        backgroundObservation?.invalidate()
        timeout?.cancel()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        activeNavigation = nil
    }

    func clear() async {
        guard !clearing else { return }
        clearing = true
        detachView()
        await dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        lastSafeURL = nil
        blockedInDocument = false
        suspended = false
        detectedConnection = false
        status = .idle
        configureView()
        clearing = false
    }

    private func load(_ url: URL) {
        guard !clearing else { return }
        finishRefresh()
        feedReloadPending = false
        feedStatus = nil
        status = .loading
        blockedInDocument = false
        activeNavigation = webView.load(URLRequest(url: url, timeoutInterval: 25))
        scheduleTimeout()
    }

    private func scheduleTimeout() {
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, let self, self.status == .loading || self.refreshing else { return }
            self.finishRefresh()
            self.webView.stopLoading()
            self.activeNavigation = nil
            self.status = .error
        }
    }

    private func checkRoute() {
        defer { updateRefreshAvailability() }
        guard !clearing, status != .terminated, let url = webView.url else { return }
        if url.path != "/" || suspended { feedStatus = nil }
        if feedReloadPending, adapter.filterEngine == .instagram, adapter.owns(url),
           url.path == "/" || url.path.isEmpty, status.countsUsage {
            // A setting change rebuilds the timeline once. Never reload a message
            // composer, open comment dialog, or another route to change feed filters.
            feedReloadPending = false
            let view = webView!
            view.callAsyncJavaScript("""
                return !document.activeElement?.matches('input,textarea,[contenteditable="true"]') &&
                  !document.querySelector('dialog[open],[role="dialog"]:not([hidden],[aria-hidden="true"])');
                """, arguments: [:], in: nil, in: .page) { [weak self, weak view] result in
                guard let self, let view, view === self.webView, view.url == url else { return }
                if case .success(let safe) = result, safe as? Bool == true { self.load(url) }
                else { self.feedReloadPending = true }
            }
            return
        }
        switch adapter.decision(for: url, hidden: effectiveHidden) {
        case .blocked(let mod):
            blockedInDocument = true
            status = .blocked(mod)
        case .authentication where status != .loading:
            if case .external = status { return }
            status = authStatus(url)
        case .allow where status == .authentication || status == .challenge:
            settle()
        case .allow where isBlockedByDisabledFilter:
            settle()
        case .allow where status == .browsing || status == .uncertain:
            lastSafeURL = url
            inspectPage(at: url)
        default:
            break
        }
    }

    private var isBlockedByDisabledFilter: Bool {
        if case .blocked(let mod) = status { return !effectiveHidden.contains(mod) }
        return false
    }

    private func authStatus(_ url: URL) -> WebStatus {
        let components = url.path.lowercased().split(separator: "/")
        return components.contains(where: ["challenge", "checkpoint", "two_factor"].contains) ? .challenge : .authentication
    }

    private func settle() {
        defer { updateRefreshAvailability() }
        guard let url = webView.url, adapter.owns(url) else { status = .error; return }
        switch adapter.decision(for: url, hidden: effectiveHidden) {
        case .authentication:
            status = authStatus(url)
        case .allow:
            lastSafeURL = url
            status = .browsing
            inspectPage(at: url)
        default:
            checkRoute()
        }
    }

    private func inspectPage(at url: URL) {
        let view = webView!
        view.evaluateJavaScript("""
                                ({ state: globalThis.supermodPageState?.() ?? 'uncertain',
                                   chrome: globalThis.supermodChrome?.() ?? null })
                                """,
                                in: nil, in: FilterScripts.world) { [weak self, weak view] result in
            guard let self, let view, !self.clearing, self.webView === view, view.url == url,
                  [.browsing, .uncertain, .authentication].contains(self.status) else { return }
            let page = try? result.get() as? [String: Any]
            if self.adapter.filterEngine == .facebook {
                switch page?["chrome"] as? String {
                case "light": self.facebookChromeScheme = .light
                case "dark": self.facebookChromeScheme = .dark
                default: self.facebookChromeScheme = nil
                }
            }
            switch page?["state"] as? String {
            case "login":
                self.status = .authentication
            case "connected":
                self.detectedConnection = true
                self.status = .browsing
            case "feed":
                self.status = .browsing
            default:
                self.status = self.effectiveHidden.isEmpty ? .browsing : .uncertain
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        guard !clearing, webView === self.webView, let url = action.request.url else { return (.cancel, preferences) }
        if action.targetFrame?.isMainFrame == false { return (.allow, preferences) }
        switch adapter.decision(for: url, hidden: effectiveHidden) {
        case .allow, .authentication:
            if action.targetFrame == nil {
                // Keep an explicitly tapped platform link inside the existing session.
                if action.navigationType == .linkActivated { load(url) }
                return (.cancel, preferences)
            }
            if adapter.filterEngine == .facebook,
               url.path.split(separator: "/").first?.lowercased() == "messages" {
                preferences.preferredContentMode = .desktop
            }
            return (.allow, preferences)
        case .blocked(let mod):
            blockedInDocument = false
            status = .blocked(mod)
        case .external:
            status = .external(url)
        case .unsupported:
            status = .external(nil)
        }
        return (.cancel, preferences)
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        guard !clearing, webView === self.webView else { return .cancel }
        guard response.isForMainFrame else { return .allow }
        if let url = response.response.url {
            switch adapter.decision(for: url, hidden: effectiveHidden) {
            case .allow, .authentication: break
            case .blocked(let mod): status = .blocked(mod); return .cancel
            case .external: status = .external(url); return .cancel
            case .unsupported: status = .external(nil); return .cancel
            }
        }
        if let http = response.response as? HTTPURLResponse, http.statusCode >= 400 {
            status = .error
            return .cancel
        }
        return response.canShowMIMEType ? .allow : .cancel
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard !clearing, webView === self.webView else { return }
        activeNavigation = navigation
        if !refreshing { status = .loading }
        scheduleTimeout()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard !clearing, webView === self.webView, navigation === activeNavigation, status == .loading || refreshing else { return }
        defer { finishRefresh(); updateRefreshAvailability() }
        // Present the committed document without waiting for slow subresources.
        // Layout recognition runs at didFinish, after the page has hydrated.
        guard let url = webView.url else { return }
        switch adapter.decision(for: url, hidden: effectiveHidden) {
        case .allow: lastSafeURL = url; status = .browsing
        case .authentication: status = authStatus(url)
        default: checkRoute()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView, navigation === activeNavigation else { return }
        activeNavigation = nil
        finishRefresh()
        timeout?.cancel()
        if [.loading, .browsing, .uncertain, .authentication].contains(status) { settle() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(webView, navigation: navigation, error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(webView, navigation: navigation, error: error)
    }

    private func fail(_ view: WKWebView, navigation: WKNavigation?, error: Error) {
        guard view === webView, navigation === activeNavigation, status == .loading || refreshing else { return }
        finishRefresh()
        let failure = error as NSError
        if failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled { return }
        timeout?.cancel()
        activeNavigation = nil
        status = [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost].contains(failure.code) ? .offline : .error
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !clearing, webView === self.webView else { return }
        timeout?.cancel()
        finishRefresh()
        status = .terminated
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !clearing, status != .terminated, message.name == "supermod", message.world == FilterScripts.world,
              message.webView === webView, message.frameInfo.isMainFrame,
              let origin = URL(string: "\(message.frameInfo.securityOrigin.protocol)://\(message.frameInfo.securityOrigin.host)"),
              [0, 443].contains(message.frameInfo.securityOrigin.port), adapter.owns(origin),
              let body = message.body as? String, body.utf8.count <= 32 else { return }
        if body == "haptic" { Haptics.selection(); return }
        if body == "route" { checkRoute(); return }
        if body == "facebook-messenger", adapter.filterEngine == .facebook {
            openFacebookMessages()
            return
        }
        if body == "page-state", let url = webView.url, adapter.decision(for: url, hidden: effectiveHidden) == .allow {
            inspectPage(at: url)
            return
        }
        guard body.hasPrefix("blocked:"), let mod = Mod(rawValue: String(body.dropFirst(8))),
              [.reels, .explore, .stories].contains(mod), effectiveHidden.contains(mod) else { return }
        blockedInDocument = false
        status = .blocked(mod)
    }
}

private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WebSession?
    init(_ target: WebSession) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

struct PlatformWebView: UIViewRepresentable {
    let view: WKWebView
    func makeUIView(context: Context) -> WKWebView { view }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
