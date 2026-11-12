import XCTest
import WebKit
@testable import Supermod

@MainActor
final class WebKitTests: XCTestCase {
    func testInstagramFiltersTimelineDataBeforeRenderingAndPreservesCursors() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: configuration.userContentController, hidden: [.suggestions, .sponsored])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        let load = WebFixtureLoad(); view.navigationDelegate = load
        view.loadHTMLString("<main></main>", baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        let result = try await view.evaluateJavaScript("""
            (() => {
              const edges = [
                {node:{__typename:'XDTFeedItem',media:{id:'followed'},ad:null,explore_story:null},cursor:'a'},
                {node:{__typename:'XDTFeedItem',media:null,ad:{ad_id:'ad'},explore_story:null},cursor:'b'},
                {node:{__typename:'XDTFeedItem',media:null,ad:null,explore_story:{media:{id:'suggested'}}},cursor:'c'},
                {node:{__typename:'XDTFeedItem',suggested_users:{users:[]}},cursor:'d'},
                {node:{__typename:'UnknownFeedItem',media:{id:'unknown'}},cursor:'e'}
              ];
              const page_info = {has_next_page:true,end_cursor:'server-next',has_previous_page:false,start_cursor:null};
              const payload = {data:{xdt_api__v1__feed__timeline__connection:{edges,page_info}},extensions:{is_final:true}};
              const direct = JSON.parse(JSON.stringify(payload));
              const bootstrap = JSON.parse(JSON.stringify({require:[['RelayPrefetchedStreamCache','next',[],[{__bbox:{result:payload}}]]]}));
              const connection = direct.data.xdt_api__v1__feed__timeline__connection;
              const initial = bootstrap.require[0][3][0].__bbox.result.data.xdt_api__v1__feed__timeline__connection;
              const unrelated = JSON.parse(JSON.stringify({data:{profile:{edges}}}));
              const both = connection.edges.length === 2 && connection.edges[0].node.media.id === 'followed' &&
                connection.edges[1].node.media.id === 'unknown' && initial.edges.length === 2 &&
                JSON.stringify(connection.page_info) === JSON.stringify(page_info) &&
                unrelated.data.profile.edges.length === 5 && direct.extensions.is_final;
              supermodConfigureFeed(['sponsored']);
              const onlyAds = JSON.parse(JSON.stringify(payload)).data.xdt_api__v1__feed__timeline__connection.edges;
              supermodConfigureFeed(['suggestions']);
              const onlySuggestions = JSON.parse(JSON.stringify(payload)).data.xdt_api__v1__feed__timeline__connection.edges;
              const emptyPage = JSON.parse(JSON.stringify({data:{xdt_api__v1__feed__timeline__connection:{edges:[edges[2]],page_info}}}));
              supermodConfigureFeed([]);
              const restored = JSON.parse(JSON.stringify(payload)).data.xdt_api__v1__feed__timeline__connection.edges;
              let invalidThrows = false;
              try { JSON.parse('{'); } catch { invalidThrows = true; }
              return both && onlyAds.length === 4 && onlySuggestions.length === 3 &&
                onlySuggestions.some(e => e.node.ad) && restored.length === 5 && invalidThrows &&
                emptyPage.data.xdt_api__v1__feed__timeline__connection.edges.length === 0 &&
                emptyPage.data.xdt_api__v1__feed__timeline__connection.page_info.end_cursor === 'server-next';
            })()
            """) as? Bool
        XCTAssertEqual(result, true)
    }

    func testSparseFeedResumesItsOwnPaginationWithoutMovingPosts() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: configuration.userContentController, hidden: [.suggestions, .sponsored])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        let load = WebFixtureLoad(); view.navigationDelegate = load
        view.loadHTMLString("<meta name='viewport' content='width=device-width'><main><article style='height:220px'>Followed post</article><svg aria-label='Loading...'></svg></main>", baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        let result = try await view.evaluateJavaScript("""
            (() => {
              if (!globalThis.supermodFeedStatus) return false;
              let now = Date.now(); Date.now = () => now;
              const spinner = document.querySelector('svg');
              let calls = 0;
              const props = {items:['one'], hasNextPage:true, isFetching:false, onNextPage:()=>{calls++}};
              const type = {displayName:'t [from PolarisGenericVirtualFeed.react]'};
              spinner.__reactFiber$test = {type,memoizedProps:props};
              const before = document.querySelector('article').getBoundingClientRect().top;
              const initial = supermodFeedStatus();
              now += 2000;
              const loading = supermodFeedStatus();
              supermodFeedStatus(); supermodFeedStatus();
              const single = calls === 1 && loading.state === 'loading';
              now += 16000;
              const stalled = supermodFeedStatus();
              const retry = supermodLoadMoreFeed();
              props.isFetching = true;
              const duplicate = supermodLoadMoreFeed();
              props.isFetching = false; props.hasNextPage = false;
              const ended = supermodFeedStatus();
              history.pushState({},'', '/direct/inbox/');
              const inbox = supermodFeedStatus();
              return single && initial.state === 'loading' && stalled.state === 'stalled' && retry && !duplicate &&
                calls === 2 && ended.state === 'end' && inbox === null &&
                document.querySelector('article').getBoundingClientRect().top === before;
            })()
            """) as? Bool
        XCTAssertEqual(result, true)
    }

    func testEmptyFilteredPageIsNotReportedAsEndAndRecoveryIsBounded() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: configuration.userContentController, hidden: [.suggestions, .sponsored])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        let load = WebFixtureLoad(); view.navigationDelegate = load
        view.loadHTMLString("<meta name='viewport' content='width=device-width'><main><svg aria-label='Loading...'></svg></main>", baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        let result = try await view.evaluateJavaScript("""
            (() => {
              if (!globalThis.supermodFeedStatus) return false;
              let now = Date.now(); Date.now = () => now;
              let calls = 0;
              const props = {items:[],hasNextPage:true,isFetching:false,onNextPage:()=>{calls++}};
              document.querySelector('svg').__reactFiber$test = {type:{displayName:'t [from PolarisGenericVirtualFeed.react]'},memoizedProps:props};
              const page = next => JSON.parse(JSON.stringify({data:{xdt_api__v1__feed__timeline__connection:{edges:[{node:{__typename:'XDTFeedItem',explore_story:{media:{id:'suggestion'}}}}],page_info:{has_next_page:next,end_cursor:'next'}}}}));
              supermodFeedStatus();
              for(let i=0;i<6;i++) { page(true); now += 2000; supermodFeedStatus(); }
              now += 16000;
              const stopped = supermodFeedStatus();
              const bounded = calls === 3 && stopped.state === 'stalled' && stopped.filtered;
              page(false);
              const end = supermodFeedStatus();
              supermodConfigureFeed(['feed']);
              const hidden = supermodFeedStatus();
              supermodConfigureFeed(['suggestions']);
              document.querySelector('main').innerHTML = '<input type="password" autocomplete="current-password">';
              const login = supermodFeedStatus();
              return bounded && end.state === 'end' && hidden.state === 'hidden' && login === null;
            })()
            """) as? Bool
        XCTAssertEqual(result, true)
    }

    func testNativeFeedStatusRetryProtectsDraftsAndOtherRoutes() async throws {
        let session = WebSession(profile: UUID())
        session.update(hidden: [.suggestions, .sponsored], locked: false)
        session.webView.frame = CGRect(x: 0, y: 0, width: 390, height: 750)
        let load = WebFixtureLoad(); session.webView.navigationDelegate = load
        let navigation = session.webView.loadHTMLString("<meta name='viewport' content='width=device-width'><main><article style='height:100px'>Post</article><svg aria-label='Loading...'></svg><textarea></textarea></main>", baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        session.webView(session.webView, didStartProvisionalNavigation: navigation)
        session.webView(session.webView, didFinish: navigation)
        _ = try await session.webView.evaluateJavaScript("""
            window.now = Date.now(); Date.now = () => now; window.calls = 0;
            const props = {items:['post'],hasNextPage:true,isFetching:false,onNextPage:()=>{calls++}};
            document.querySelector('svg').__reactFiber$fixture = {type:{displayName:'t [from PolarisGenericVirtualFeed.react]'},memoizedProps:props};
            """)
        await session.refreshFeedStatus()
        XCTAssertEqual(session.feedStatus?.state, .loading)
        _ = try await session.webView.evaluateJavaScript("now += 16000")
        await session.refreshFeedStatus()
        XCTAssertEqual(session.feedStatus?.state, .stalled)
        session.retryFeed()
        try await require(session.webView, "calls === 1")
        _ = try await session.webView.evaluateJavaScript("now += 16000; document.querySelector('textarea').outerHTML = '<section role=dialog>Unsent draft</section>'")
        session.retryFeed()
        await session.refreshFeedStatus()
        XCTAssertNil(session.feedStatus)
        let calls = try await session.webView.evaluateJavaScript("calls") as? Int
        XCTAssertEqual(calls, 1)
        _ = try await session.webView.evaluateJavaScript("document.querySelector('[role=dialog]').remove();history.pushState({},'', '/direct/inbox/')")
        await session.refreshFeedStatus()
        XCTAssertNil(session.feedStatus)
        session.retryFeed()
        let afterRoute = try await session.webView.evaluateJavaScript("calls") as? Int
        XCTAssertEqual(afterRoute, 1)
    }

    func testPullToRefreshReloadsHomeAndProtectsOpenDrafts() async throws {
        for protectsDraft in [false, true] {
            let session = WebSession(profile: UUID())
            session.webView.frame = CGRect(x: 0, y: 0, width: 390, height: 750)
            let load = WebFixtureLoad(); session.webView.navigationDelegate = load
            let html = "<main><article>Post</article>" + (protectsDraft ? "<section role='dialog'><textarea>Unsent draft</textarea></section>" : "") + "</main>"
            let nav = session.webView.loadHTMLString(html, baseURL: URL(string: "https://www.instagram.com/"))
            await fulfillment(of: [load.loaded], timeout: 8)
            session.webView(session.webView, didStartProvisionalNavigation: nav)
            session.webView(session.webView, didFinish: nav)
            let refresh = try XCTUnwrap(session.webView.scrollView.refreshControl)
            XCTAssertTrue(session.webView.scrollView.alwaysBounceVertical)
            let next = CancelledWebRequest(); next.received.isInverted = protectsDraft
            session.webView.navigationDelegate = next
            refresh.beginRefreshing()
            refresh.sendActions(for: .valueChanged)
            await fulfillment(of: [next.received], timeout: protectsDraft ? 0.4 : 4)
            if protectsDraft {
                XCTAssertFalse(refresh.isRefreshing)
            } else {
                XCTAssertEqual(next.url?.host, "www.instagram.com")
                XCTAssertNotEqual(session.status, .loading, "Pull refresh must retain the current page rather than flash a full-screen loader")
                session.webViewWebContentProcessDidTerminate(session.webView)
                XCTAssertFalse(refresh.isRefreshing)
            }
            session.webView.stopLoading()
        }
    }

    func testLateSuggestedAndSponsoredLabelsDoNotMoveTheVisibleFeed() async throws {
        for label in ["Suggested for you", "Sponsored"] {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            FilterScripts.install(on: configuration.userContentController, hidden: [.suggestions, .sponsored])
            let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
            let load = WebFixtureLoad(); view.navigationDelegate = load
            view.loadHTMLString("""
                <meta name="viewport" content="width=device-width">
                <style>body{margin:0} article{height:600px}</style>
                <main><article id="late"><div><div><a href="/author/">Author</a><span id="badge">Following</span></div><p>Content</p></div></article>
                <article id="anchor">Followed post</article><article>Next post</article><article>Last post</article></main>
                """, baseURL: URL(string: "https://www.instagram.com/"))
            await fulfillment(of: [load.loaded], timeout: 8)
            _ = try await view.evaluateJavaScript("scrollTo(0,650); window.anchorTop = document.getElementById('anchor').getBoundingClientRect().top")
            _ = try await view.callAsyncJavaScript("document.getElementById('badge').textContent = label", arguments: ["label": label], in: nil, contentWorld: .page)
            try await require(view, "document.getElementById('late').classList.contains('supermod-hidden')")
            try await require(view, "getComputedStyle(document.getElementById('late')).visibility === 'hidden' && document.getElementById('late').getBoundingClientRect().height === 600 && scrollY === 650 && document.getElementById('anchor').getBoundingClientRect().top === window.anchorTop")
            _ = try await view.evaluateJavaScript("document.getElementById('badge').textContent = 'Following'")
            try await require(view, "getComputedStyle(document.getElementById('late')).visibility === 'visible' && scrollY === 650 && document.getElementById('anchor').getBoundingClientRect().top === window.anchorTop")
        }
    }

    func testChangingTimelineFiltersReloadsHomeButProtectsAnOpenDraft() async throws {
        for protectsDraft in [false, true] {
            let session = WebSession(adapter: InstagramAdapter(), dataStore: .nonPersistent())
            let load = WebFixtureLoad(); session.webView.navigationDelegate = load
            let html = protectsDraft
                ? "<main><article>Post</article><section role='dialog'><textarea id='draft'>Unsent comment</textarea></section></main>"
                : "<main><article>Post</article></main>"
            let nav = session.webView.loadHTMLString(html, baseURL: URL(string: "https://www.instagram.com/"))
            await fulfillment(of: [load.loaded], timeout: 8)
            session.webView(session.webView, didStartProvisionalNavigation: nav)
            (session as WKNavigationDelegate).webView?(session.webView, didCommit: nav)
            let next = CancelledWebRequest()
            next.received.isInverted = protectsDraft
            session.webView.navigationDelegate = next
            session.update(hidden: [.suggestions, .sponsored], locked: false)
            await fulfillment(of: [next.received], timeout: protectsDraft ? 0.6 : 4)
            if protectsDraft {
                try await require(session.webView, "document.getElementById('draft').value === 'Unsent comment'")
                XCTAssertNil(next.url)
            } else {
                XCTAssertEqual(next.url?.absoluteString, "https://www.instagram.com/")
            }
        }
    }

    func testAppPromptsStayHiddenAcrossRoutesAndFilterChanges() async throws {
        for (engine, host) in [(FilterScripts.Engine.instagram, "www.instagram.com"), (.facebook, "m.facebook.com"), (.youtube, "m.youtube.com")] {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .nonPersistent()
            FilterScripts.install(on: config.userContentController, hidden: [], engine: engine)
            let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 402, height: 750), configuration: config)
            let load = WebFixtureLoad(); view.navigationDelegate = load
            view.loadHTMLString("""
              <meta name="apple-itunes-app" content="app-id=123">
              <main><article id="post"><p>Use the app to install something</p><button>Install</button></article>
              <form id="login"><input type="password"><button>Log in</button></form></main>
              <nav id="navigation"><a href="/">Home</a><a href="/direct/">Messages</a></nav>
              <div id="promo" style="position:fixed;bottom:50px;width:100%;height:48px">
                <button>Use the app</button><button aria-label="Close">×</button>
              </div>
              """, baseURL: URL(string: "https://\(host)/"))
            await fulfillment(of: [load.loaded], timeout: 8)
            try await require(view, "getComputedStyle(document.getElementById('promo')).display === 'none'")
            try await require(view, "!document.querySelector('meta[name=apple-itunes-app]')")
            try await require(view, "['post','login','navigation'].every(id => document.getElementById(id).getClientRects().length > 0)")
            _ = try await view.evaluateJavaScript("""
                document.getElementById('promo').remove();
                history.pushState({}, '', '/profile/');
                document.body.insertAdjacentHTML('beforeend', '<aside id="late" style="position:fixed;bottom:0"><a href="https://apps.apple.com/app/id123">Install</a><button>Not now</button></aside>');
                """)
            try await require(view, "getComputedStyle(document.getElementById('late')).display === 'none'")
            _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
            try await require(view, "getComputedStyle(document.getElementById('late')).display === 'none'")
            _ = try await view.evaluateJavaScript("document.getElementById('late').innerHTML = '<button>Continue reading</button>'")
            try await require(view, "document.getElementById('late').getClientRects().length > 0")
            _ = try await view.evaluateJavaScript("""
                document.body.insertAdjacentHTML('beforeend', '<aside id="localized"><a href="https://apps.apple.com/app/id123">ऐप खोलें</a></aside>');
                """)
            try await require(view, "document.getElementById('localized').getClientRects().length > 0")
            _ = try await view.evaluateJavaScript("document.getElementById('localized').style.position = 'fixed'")
            try await require(view, "getComputedStyle(document.getElementById('localized')).display === 'none'")
        }
    }

    func testCommittedPageBecomesUsableBeforeSlowSubresourcesFinish() async throws {
        let session = WebSession(adapter: InstagramAdapter(), dataStore: .nonPersistent())
        let load = WebFixtureLoad(); session.webView.navigationDelegate = load
        let nav = session.webView.loadHTMLString("<main><article>Ready post</article></main>", baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        session.webView(session.webView, didStartProvisionalNavigation: nav)
        (session as WKNavigationDelegate).webView?(session.webView, didCommit: nav)
        try await requireStatus(session, .browsing)
    }

    func testPostUpdatesDoNotWalkUnchangedFeedText() async throws {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: config.userContentController, hidden: [.suggestions])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 402, height: 750), configuration: config)
        let load = WebFixtureLoad(); view.navigationDelegate = load
        let posts = (0..<200).map { "<article><header>Author</header><p id='caption\($0)'>Ordinary caption</p></article>" }.joined()
        view.loadHTMLString("<main>\(posts)</main>", baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        let walks = try await view.callAsyncJavaScript("""
            await new Promise(resolve => setTimeout(resolve, 100));
            const original = document.createTreeWalker;
            let count = 0;
            document.createTreeWalker = function(...args) { count++; return original.apply(this, args); };
            for (let i = 0; i < 12; i++) {
              document.getElementById('caption0').textContent = 'Updated ' + i;
              await new Promise(resolve => setTimeout(resolve, 40));
            }
            document.createTreeWalker = original;
            return count;
            """, arguments: [:], in: nil, contentWorld: FilterScripts.world) as? Int
        XCTAssertEqual(walks, 0, "Post mutations must not traverse every caption in the feed")
    }

    func testInstagramAllowsInlineVideoPlayback() {
        let session = WebSession(adapter: InstagramAdapter(), dataStore: .nonPersistent())
        XCTAssertTrue(session.webView.configuration.allowsInlineMediaPlayback)
    }

    func testFacebookUsesDarkChromeForReelsOpenedFromVideoLinks() async throws {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: config.userContentController, hidden: [], engine: .facebook)
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 402, height: 750), configuration: config)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <div data-mcomponent="MScreen" data-light-status-bar="true">
              <h2>Videos</h2>
              <div data-mcomponent="MContainer" data-type="vscroller">Ordinary video page</div>
            </div>
            """, baseURL: URL(string: "https://www.facebook.com/example/videos/123/"))
        await fulfillment(of: [load.loaded], timeout: 8)

        func chrome() async throws -> String? {
            try await view.callAsyncJavaScript("return supermodChrome()", arguments: [:],
                                               in: nil, contentWorld: FilterScripts.world) as? String
        }
        let initial = try await chrome()
        XCTAssertEqual(initial, "light")

        _ = try await view.evaluateJavaScript("""
            document.body.insertAdjacentHTML('beforeend', `
              <div id="viewer" data-mcomponent="MScreen">
                <h2>Reels</h2>
                <div class="vscroller-snap" data-mcomponent="MContainer" data-type="vscroller">
                  <video playsinline></video>
                </div>
              </div>
            `)
            """)
        let opened = try await chrome()
        XCTAssertEqual(opened, "dark")

        _ = try await view.evaluateJavaScript("document.getElementById('viewer').remove()")
        let closed = try await chrome()
        XCTAssertEqual(closed, "light")
    }

    func testTimerExpiryBlocksOpenSelectedFeaturesAcrossServices() async throws {
        let examples: [(any PlatformAdapter, String, Mod)] = [
            (InstagramAdapter(), "https://www.instagram.com/reel/example/", .reels),
            (FacebookAdapter(), "https://m.facebook.com/reel/example/", .reels),
            (YouTubeAdapter(), "https://m.youtube.com/shorts/example", .reels),
            (InstagramAdapter(), "https://www.instagram.com/stories/example/", .stories),
            (FacebookAdapter(), "https://m.facebook.com/stories/example/", .stories),
            (InstagramAdapter(), "https://www.instagram.com/explore/", .explore)
        ]
        for (adapter, url, mod) in examples {
            let now = Date(timeIntervalSince1970: 1000)
            var preferences = Preferences()
            var timer = ShortVideoBreak(minutes: 5); timer.selection = [mod]; timer.start(at: now)
            preferences.shortVideoBreak = timer
            let session = WebSession(adapter: adapter, dataStore: .nonPersistent())
            session.update(hidden: preferences.filtered([mod], at: now), locked: false)
            let load = WebFixtureLoad(); session.webView.navigationDelegate = load
            let navigation = session.webView.loadHTMLString("<html><body>A short video</body></html>", baseURL: URL(string: url))
            await fulfillment(of: [load.loaded], timeout: 8)
            session.webView(session.webView, didStartProvisionalNavigation: navigation)
            session.webView(session.webView, didFinish: navigation)
            XCTAssertNotEqual(session.status, .blocked(mod))
            session.update(hidden: preferences.filtered([], at: now.addingTimeInterval(300)), locked: false)
            try await requireStatus(session, .blocked(mod))
            let request = CancelledWebRequest(); session.webView.navigationDelegate = request
            session.recover()
            await fulfillment(of: [request.received], timeout: 8)
            XCTAssertEqual(request.url, adapter.entry)
            session.webView.stopLoading()
        }
    }

    func testRecoveryAfterResumingFiltersDoesNotReloadBlockedPage() async throws {
        let session = WebSession(adapter: YouTubeAdapter(), dataStore: .nonPersistent())
        session.update(hidden: [.reels], locked: false)
        session.setSuspended(true)
        let load = WebFixtureLoad()
        session.webView.navigationDelegate = load
        let navigation = session.webView.loadHTMLString("<ytm-app>Short</ytm-app>",
                                                        baseURL: URL(string: "https://m.youtube.com/shorts/example"))
        await fulfillment(of: [load.loaded], timeout: 8)
        session.webView(session.webView, didStartProvisionalNavigation: navigation)
        session.webView(session.webView, didFinish: navigation)
        session.setSuspended(false)
        try await requireStatus(session, .blocked(.reels))

        let request = CancelledWebRequest()
        session.webView.navigationDelegate = request
        session.recover()
        await fulfillment(of: [request.received], timeout: 8)
        XCTAssertEqual(request.url, URL(string: "https://m.youtube.com/"))
        session.webView.stopLoading()
    }

    func testFilterChangesPreserveTerminatedState() async throws {
        let session = WebSession(adapter: YouTubeAdapter(), dataStore: .nonPersistent())
        let load = WebFixtureLoad()
        session.webView.navigationDelegate = load
        session.webView.loadHTMLString("<ytm-app>Short</ytm-app>",
                                       baseURL: URL(string: "https://m.youtube.com/shorts/example"))
        await fulfillment(of: [load.loaded], timeout: 8)
        session.webViewWebContentProcessDidTerminate(session.webView)
        session.update(hidden: [.reels], locked: false)
        // The filter callback and route message both run before this queued evaluation returns.
        _ = try await session.webView.evaluateJavaScript("true")
        XCTAssertEqual(session.status, .terminated)
    }

    func testYouTubeShortsFiltersReactToChangedLabelsAndText() async throws {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: config.userContentController, hidden: [.reels], engine: .youtube)
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 402, height: 750), configuration: config)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <ytm-app>
              <ytm-pivot-bar-item-renderer id="pivot"><button aria-label="Home"></button></ytm-pivot-bar-item-renderer>
              <ytm-rich-section-renderer id="section"><yt-shelf-header-view-model>Videos</yt-shelf-header-view-model></ytm-rich-section-renderer>
            </ytm-app>
            """, baseURL: URL(string: "https://m.youtube.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        try await require(view, "['pivot','section'].every(id => !document.getElementById(id).classList.contains('supermod-hidden'))")
        _ = try await view.evaluateJavaScript("""
            document.querySelector('#pivot button').setAttribute('aria-label', 'Shorts');
            document.querySelector('yt-shelf-header-view-model').firstChild.data = 'Shorts';
            """)
        try await require(view, "['pivot','section'].every(id => document.getElementById(id).classList.contains('supermod-hidden'))")
        _ = try await view.evaluateJavaScript("""
            document.querySelector('#pivot button').setAttribute('aria-label', 'Home');
            document.querySelector('yt-shelf-header-view-model').firstChild.data = 'Videos';
            """)
        try await require(view, "['pivot','section'].every(id => !document.getElementById(id).classList.contains('supermod-hidden'))")
    }

    func testFacebookMobileFeedHidesRowsAndPreservesNeighboringTabs() async throws {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: config.userContentController, hidden: [.reels, .stories, .sponsored], engine: .facebook)
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 402, height: 750), configuration: config)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <style>
              body { margin: 0; }
              [role=tablist], [role=tab] { display: flex; flex-direction: column; }
              [role=tab] { width: 25%; height: 48px; }
              [role=tab] + [role=tab] { margin-top: -48px; }
            </style>
            <div data-mcomponent="MContainer" data-type="vscroller">
              <div id="facebook-header" data-mcomponent="MContainer" style="height:43px">
                <span role="button">Search</span><span role="button">Menu</span>
              </div>
              <div role="tablist" data-mcomponent="MContainer">
                <div role="tab" id="home" aria-label="Home"></div>
                <div role="tab" id="messenger" aria-label="Messages" style="margin-left:25%"></div>
                <div role="tab" id="video" aria-label="Reels, 15 new items" style="margin-left:50%"></div>
                <div role="tab" id="notifications" aria-label="Notifications" style="margin-left:75%"></div>
              </div>
              <div data-mcomponent="MContainer" data-type="container">
                <div aria-label="Post a status update">Post</div>
              </div>
              <div id="storyRow" data-mcomponent="MContainer" data-type="container">
                <div role="button"><div role="button" aria-label="Create story">Create story</div></div>
              </div>
              <div id="reelRow" data-tracking-duration-id="fixture">
                <div><h2 data-mcomponent="TextArea"><span>Reels</span></h2></div>
              </div>
              <div id="paidRow" data-tracking-duration-id="paid"><a href="/ads/about/">Sponsored</a></div>
              <div id="post" data-tracking-duration-id="ordinary">Post mentioning sponsored Reels <button id="ordinary-button">Open app</button></div>
              <div style="height:1600px"></div>
            </div>
            <div data-mcomponent="MScreen">
              <div id="promo" data-mcomponent="MContainer" data-type="container" style="position:fixed;bottom:0;width:100%;height:67px">
                <div data-mcomponent="MContainer" role="button"><span>Open app</span></div>
              </div>
            </div>
            """, baseURL: URL(string: "https://www.facebook.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        try await require(view, "['video','storyRow','reelRow','paidRow'].every(id => !document.getElementById(id).getClientRects().length)")
        try await require(view, "['home','messenger','post'].every(id => document.getElementById(id).getClientRects().length)")
        try await require(view, """
            (() => {
              const [home, messages, notifications] = ['home','messenger','notifications'].map(id => document.getElementById(id).getBoundingClientRect());
              return home.y === messages.y && messages.y === notifications.y &&
                Math.abs(home.right - messages.left) < 1 && Math.abs(messages.right - notifications.left) < 1 &&
                Math.abs(notifications.right - innerWidth) < 1;
            })()
            """)
        try await require(view, "!document.getElementById('promo').getClientRects().length && document.getElementById('ordinary-button').getClientRects().length > 0")
        _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, "['video','storyRow','reelRow','paidRow'].every(id => document.getElementById(id).getClientRects().length)")
        try await require(view, "Math.abs(document.getElementById('notifications').getBoundingClientRect().left - innerWidth * 0.75) < 1 && !document.getElementById('promo').getClientRects().length")
        _ = try await view.callAsyncJavaScript("""
            scrollTo(0, 420);
            await new Promise(resolve => setTimeout(resolve, 120));
            """, arguments: [:], in: nil, contentWorld: .page)
        try await require(view, "scrollY === 420 && document.getElementById('facebook-header').getBoundingClientRect().bottom < 0")
        _ = try await view.evaluateJavaScript("scrollTo(0, 400)")
        try await require(view, """
            scrollY === 400 && Math.abs(document.getElementById('facebook-header').getBoundingClientRect().top) < 1 &&
            Math.abs(document.querySelector('[role=tablist]').getBoundingClientRect().top - 43) < 1
            """)
        _ = try await view.evaluateJavaScript("scrollTo(0, 440)")
        try await require(view, "scrollY === 440 && document.getElementById('facebook-header').getBoundingClientRect().bottom < 0")
        _ = try await view.evaluateJavaScript("history.pushState({}, '', '/search/')")
        try await require(view, "!document.getElementById('promo').getClientRects().length")
        _ = try await view.evaluateJavaScript("history.pushState({}, '', '/messages/')")
        try await require(view, "!document.getElementById('promo').getClientRects().length")
    }

    func testFacebookFiltersRestoreFeedAndLeaveMessengerComposerAlone() async throws {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: config.userContentController, hidden: [.reels, .stories, .sponsored], engine: .facebook)
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: config)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <nav><a id="reels" href="/reel/">Reels</a><a id="inbox" href="/messages/">Messenger</a>
            <a id="lookalike" href="https://facebook.com.example.test/reels/">External</a></nav>
            <main>
              <section id="stories" aria-label="Stories"><a href="/stories/123">A story</a></section>
              <section id="reels-rail" aria-label="Reels"><a href="/reel/123">A reel</a></section>
              <div role="feed">
                <div data-pagelet="FeedUnit_1" id="ad"><div role="article"><a href="/ads/about/?id=12">Sponsored</a></div></div>
                <article id="organic"><header><a href="/ad/">Ad</a></header><p>Sponsored</p>
                  <a id="shared-reel" href="/reel/123">Shared reel</a></article>
              </div>
              <div role="dialog"><div id="chat" contenteditable="true"></div></div>
            </main>
            """, baseURL: URL(string: "https://www.facebook.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        try await require(view, "['reels','stories','reels-rail','ad'].every(id => document.getElementById(id).getClientRects().length === 0)")
        try await require(view, "['inbox','lookalike','organic','shared-reel'].every(id => document.getElementById(id).getClientRects().length > 0)")
        _ = try await view.evaluateJavaScript("""
            document.querySelector('[role=feed]').insertAdjacentHTML('beforeend',
              '<article id="late"><header><span aria-label="Ad"></span></header>Advert</article>');
            """)
        try await require(view, "document.getElementById('late').getClientRects().length === 0")
        _ = try await view.evaluateJavaScript("""
            document.getElementById('late').querySelector('span').setAttribute('aria-label', 'Public');
            """)
        try await require(view, "document.getElementById('late').getClientRects().length > 0")
        _ = try await view.evaluateJavaScript("""
            history.pushState({}, '', '/messages/e2ee/t/123');
            document.getElementById('chat').focus();
            document.execCommand('insertText', false, 'Unsent draft');
            """)
        try await require(view, "!document.querySelector('.supermod-hidden') && document.activeElement.id === 'chat' && document.activeElement.textContent === 'Unsent draft'")
        _ = try await view.evaluateJavaScript("history.pushState({}, '', '/stories/123')")
        try await require(view, "document.documentElement.hasAttribute('data-supermod-blocked')")
        _ = try await view.evaluateJavaScript("history.replaceState({}, '', '/login.php?next=/stories/123')")
        try await require(view, "!document.documentElement.hasAttribute('data-supermod-blocked')")
        _ = try await view.evaluateJavaScript("history.replaceState({}, '', '/')")
        try await require(view, "document.getElementById('ad').getClientRects().length === 0")
        _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, "!document.querySelector('.supermod-hidden')")
    }

    func testDynamicFilteringAndSameDocumentRoutes() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: configuration.userContentController,
                              hidden: [.reels, .explore, .suggestions, .sponsored, .stories])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <meta name="viewport" content="width=device-width">
            <nav><a id="reels" href="/reels/">Reels</a><a id="dm" href="/direct/inbox/">Inbox</a>
            <a id="lookalike" href="https://instagram.com.example.test/reels/">Other</a></nav>
            <main>
            <section id="stories" data-pagelet="Stories">Stories</section>
            <article id="ordinary"><header>Nia</header>Here are some sponsored Reels I saw.</article>
            <article id="ad"><header><span aria-label="Sponsored"></span></header>Example advertisement.</article>
            <article id="suggested" data-testid="suggested-post">Recommendation.</article>
            </main>
            """, baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        try await require(view, "['reels','stories','ad','suggested'].every(id => document.getElementById(id).classList.contains('supermod-hidden'))")
        try await require(view, "['ordinary','dm','lookalike'].every(id => !document.getElementById(id).classList.contains('supermod-hidden'))")

        _ = try await view.evaluateJavaScript("""
            document.querySelector('main').insertAdjacentHTML('beforeend',
              '<article id="dynamic"><header><span aria-label="Sponsored"></span></header>Ad</article>');
            """)
        try await require(view, "document.getElementById('dynamic').classList.contains('supermod-hidden')")

        _ = try await view.evaluateJavaScript("document.querySelector('#dynamic header span').remove()")
        try await require(view, "!document.getElementById('dynamic').classList.contains('supermod-hidden')")

        _ = try await view.evaluateJavaScript("history.pushState({}, '', '/direct/inbox/')")
        try await require(view, "!document.getElementById('ad').classList.contains('supermod-hidden')")
        _ = try await view.evaluateJavaScript("history.replaceState({}, '', '/reel/shared-id/')")
        try await require(view, "document.documentElement.hasAttribute('data-supermod-blocked')")
        _ = try await view.evaluateJavaScript("""
            history.replaceState({}, '', '/accounts/login/');
            document.querySelector('main').insertAdjacentHTML('beforeend', '<form id="login"><input type="password"></form>');
            """)
        try await require(view, "!document.documentElement.hasAttribute('data-supermod-active') && !document.documentElement.hasAttribute('data-supermod-blocked') && document.getElementById('login').offsetHeight > 0")

        _ = try await view.evaluateJavaScript("history.replaceState({}, '', '/')")
        try await require(view, "document.getElementById('ad').classList.contains('supermod-hidden')")
        _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, "document.querySelectorAll('.supermod-hidden').length === 0")
    }

    func testMobileAdBadgesHideOnlyTheirFeedArticles() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: configuration.userContentController, hidden: [.sponsored])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <main>
              <article id="paid"><div><div><img alt=""><div><span>Shop</span><div><span>Ad</span></div></div></div><video></video></div></article>
              <article id="late"><div><div><a href="/shop/">Shop</a><span id="badge"></span></div><video></video></div></article>
              <article id="ordinary"><div><div><a href="/ad/"><span>Ad</span></a></div><p><span>Sponsored</span></p></div></article>
              <article id="plain-author"><div><div><img alt=""><div><span>Ad</span><span>Following</span></div></div><p>Post</p></div></article>
            </main>
            """, baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        try await require(view, "getComputedStyle(document.getElementById('paid')).visibility === 'hidden'")
        try await require(view, "getComputedStyle(document.getElementById('ordinary')).visibility === 'visible'")
        try await require(view, "getComputedStyle(document.getElementById('plain-author')).visibility === 'visible'")
        _ = try await view.evaluateJavaScript("document.getElementById('badge').append('Sponsored')")
        try await require(view, "getComputedStyle(document.getElementById('late')).visibility === 'hidden'")
        _ = try await view.evaluateJavaScript("document.getElementById('badge').firstChild.data = 'Following'")
        try await require(view, "getComputedStyle(document.getElementById('late')).visibility === 'visible'")
        _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, "getComputedStyle(document.getElementById('paid')).visibility === 'visible'")
    }

    func testMobileSuggestionBadgesHideOnlySuggestedFeedArticles() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: configuration.userContentController, hidden: [.suggestions])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <main>
              <article id="suggested"><div><div><img alt=""><div><span>Nia</span><div><span>Suggested for you</span></div></div></div><video></video></div></article>
              <article id="late"><div><div><a href="/nia/">Nia</a><span id="badge"></span></div><video></video></div></article>
              <article id="caption"><div><div><a href="/nia/">Nia</a><span>Following</span></div><p><span>Suggested for you</span></p></div></article>
              <article id="linked-author"><div><div><a href="/suggested/"><span>Suggested for you</span></a><span>Following</span></div><p>Post</p></div></article>
              <article id="plain-author"><div><div><img alt=""><div><span>Suggested for you</span><span>Following</span></div></div><p>Post</p></div></article>
              <article id="ad"><div><div><a href="/shop/">Shop</a><span>Sponsored</span></div><video></video></div></article>
              <input id="message" type="text">
            </main>
            """, baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        try await require(view, "getComputedStyle(document.getElementById('suggested')).visibility === 'hidden'")
        try await require(view, "['caption','linked-author','plain-author','ad'].every(id => getComputedStyle(document.getElementById(id)).display !== 'none')")
        _ = try await view.evaluateJavaScript("document.getElementById('badge').append('Suggested for you')")
        try await require(view, "getComputedStyle(document.getElementById('late')).visibility === 'hidden'")
        _ = try await view.evaluateJavaScript("document.getElementById('badge').firstChild.data = 'Following'")
        try await require(view, "getComputedStyle(document.getElementById('late')).visibility === 'visible'")
        _ = try await view.evaluateJavaScript("""
            history.pushState({}, '', '/direct/inbox/');
            document.getElementById('message').focus();
            document.getElementById('message').value = 'Suggested for you';
            """)
        try await require(view, "getComputedStyle(document.getElementById('suggested')).visibility === 'visible' && document.activeElement.value === 'Suggested for you'")
        _ = try await view.evaluateJavaScript("history.replaceState({}, '', '/')")
        try await require(view, "getComputedStyle(document.getElementById('suggested')).visibility === 'hidden'")
        _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, "getComputedStyle(document.getElementById('suggested')).visibility === 'visible'")
    }

    func testFollowSuggestionsRowHidesAfterHydrationAndRestoresOffHome() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: configuration.userContentController, hidden: [.suggestions])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <main>
              <article id="post"><p>Suggestions for you</p><button>Comment</button></article>
              <div id="carousel" style="height: 310px">
                <div><h2>Suggestions for you</h2><a href="/people/">See all</a></div>
                <div id="accounts"><div role="button">Follow</div><div role="button">Loading</div></div>
              </div>
              <section id="friends"><h2>Friends</h2><button>Follow</button><button>Follow</button></section>
            </main>
            """, baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        try await require(view, "getComputedStyle(document.getElementById('carousel')).visibility === 'visible'")
        _ = try await view.evaluateJavaScript("document.querySelector('#accounts div:last-child').firstChild.data = 'Follow'")
        try await require(view, """
            document.getElementById('carousel').getBoundingClientRect().height === 310 &&
            getComputedStyle(document.getElementById('carousel')).visibility === 'hidden' &&
            ['post','friends'].every(id => getComputedStyle(document.getElementById(id)).visibility === 'visible')
            """)
        _ = try await view.evaluateJavaScript("history.pushState({}, '', '/profile/')")
        try await require(view, "document.getElementById('carousel').getBoundingClientRect().height === 310")
        _ = try await view.evaluateJavaScript("history.replaceState({}, '', '/')")
        try await require(view, "getComputedStyle(document.getElementById('carousel')).visibility === 'hidden'")
        _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, "document.getElementById('carousel').getBoundingClientRect().height === 310")
    }

    func testFilteredRowsDoNotReplaceVirtualFeedSpacersOrClampScroll() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: configuration.userContentController, hidden: [.suggestions, .sponsored])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <meta name="viewport" content="width=device-width">
            <main><div id="feed" style="display: flex; flex-direction: column; padding-top: 1000px; padding-bottom: 8000px">
              <article style="height: 1000px; flex-shrink: 0">Followed account</article>
            </div></main>
            """, baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        _ = try await view.evaluateJavaScript("scrollTo(0, 3000)")
        try await require(view, "scrollY === 3000")
        for _ in 0..<3 {
            _ = try await view.evaluateJavaScript("""
                document.getElementById('feed').insertAdjacentHTML('beforeend',
                  '<article id="recycled" data-testid="sponsored-post" style="height: 500px">Ad</article>');
                """)
            try await require(view, "document.getElementById('recycled').classList.contains('supermod-hidden')")
            try await require(view, "getComputedStyle(document.getElementById('feed')).paddingBottom === '8000px' && scrollY === 3000")
            _ = try await view.evaluateJavaScript("document.getElementById('recycled').remove()")
            try await require(view, "scrollY === 3000")
        }
    }

    func testInsertedInstagramPostsAreFilteredBeforeTheNextPaint() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: configuration.userContentController, hidden: [.suggestions, .sponsored])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        let window = UIWindow(frame: view.bounds)
        let host = UIViewController()
        window.rootViewController = host
        host.view.addSubview(view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("<main></main>", baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        let visibleFrames = try await view.callAsyncJavaScript("""
            let flashes = 0;
            const frame = () => new Promise((resolve, reject) => {
              const timeout = setTimeout(() => reject(new Error('No animation frame')), 3000);
              requestAnimationFrame(() => { clearTimeout(timeout); resolve(); });
            });
            for (let i = 0; i < 8; i++) {
              await frame();
              const post = document.createElement('article');
              post.innerHTML = '<div><div><img alt=""><div><span>Author</span><div><span>Suggested for you</span></div></div></div><div style="height:600px">Suggested content</div></div>';
              document.querySelector('main').append(post);
              await frame();
              if (getComputedStyle(post).visibility !== 'hidden') flashes++;
              post.remove();
            }
            return flashes;
            """, arguments: [:], in: nil, contentWorld: .page) as? Int
        XCTAssertEqual(visibleFrames, 0, "Filtered posts must not appear for a frame before collapsing")
    }

    func testSuggestedTailKeepsPaginationAndCommentFeedbackWorking() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: configuration.userContentController, hidden: [.suggestions, .sponsored])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <meta name="viewport" content="width=device-width">
            <main><div id="feed" style="display: flex; flex-direction: column; padding-top: 0px; padding-bottom: 8000px; position: relative;">
              <article id="ordinary" style="height: 1400px">Followed account</article>
              <article id="ad" data-testid="sponsored-post" style="height: 500px">Ad</article>
              <article id="suggestion" data-testid="suggested-post" style="height: 900px">
                Suggested for you
                <section id="comments" role="dialog" hidden>
                  <form onsubmit="event.preventDefault(); document.getElementById('confirmation').textContent = 'Comment posted'">
                    <textarea aria-label="Comment"></textarea><button type="submit">Post</button>
                  </form>
                  <p id="confirmation" role="status"></p>
                </section>
              </article>
            </div></main>
            <script>
              const tail = document.getElementById('suggestion');
              const loader = new IntersectionObserver(entries => {
                if (!entries.some(entry => entry.isIntersecting && entry.intersectionRect.height > 0)) return;
                loader.disconnect();
                document.getElementById('feed').insertAdjacentHTML('beforeend',
                  '<article id="next" style="height: 400px">More from a followed account</article>');
              });
              loader.observe(tail);
            </script>
            """, baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        try await require(view, "document.getElementById('suggestion').classList.contains('supermod-hidden')")
        try await require(view, "getComputedStyle(document.getElementById('feed')).paddingBottom === '8000px'")
        _ = try await view.evaluateJavaScript("scrollTo(0, document.getElementById('suggestion').getBoundingClientRect().top + scrollY - innerHeight / 2)")
        try await require(view, "document.getElementById('next')?.getBoundingClientRect().height > 0")
        _ = try await view.evaluateJavaScript("""
            document.getElementById('comments').hidden = false;
            document.querySelector('#comments textarea').value = 'Local fixture comment';
            document.querySelector('#comments button').click();
            """)
        try await require(view, """
            document.getElementById('confirmation').textContent === 'Comment posted' &&
            document.getElementById('confirmation').getBoundingClientRect().height > 0 &&
            getComputedStyle(document.getElementById('confirmation')).visibility === 'visible'
            """)
        _ = try await view.evaluateJavaScript("document.getElementById('comments').hidden = true")
        try await require(view, "document.getElementById('suggestion').getBoundingClientRect().height === 900")
        _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, "getComputedStyle(document.getElementById('feed')).paddingBottom === '8000px'")
        _ = try await view.callAsyncJavaScript("return supermodApply(['sponsored'])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, """
            getComputedStyle(document.getElementById('ad')).visibility === 'hidden' &&
            getComputedStyle(document.getElementById('suggestion')).visibility === 'visible' &&
            getComputedStyle(document.getElementById('feed')).paddingBottom === '8000px'
            """)
    }

    func testClearSessionRemovesOnlyItsWebsiteData() async throws {
        let profile = UUID()
        let session = WebSession(profile: profile)
        let owned = WKWebsiteDataStore(forIdentifier: profile)
        let other = WKWebsiteDataStore.nonPersistent()
        let cookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: "fixture.example.test", .path: "/", .name: "sample",
            .value: "synthetic", .expires: Date().addingTimeInterval(3600)
        ]))
        await owned.httpCookieStore.setCookie(cookie)
        await other.httpCookieStore.setCookie(cookie)
        let originalView = session.webView
        let before = await owned.httpCookieStore.allCookies()
        XCTAssertEqual(before.count, 1)
        await session.clear()
        let cleared = await owned.httpCookieStore.allCookies()
        let unaffected = await other.httpCookieStore.allCookies()
        XCTAssertTrue(cleared.isEmpty)
        XCTAssertEqual(unaffected.count, 1)
        XCTAssertFalse(session.webView === originalView)
        XCTAssertEqual(session.status, .idle)
    }

    func testMobileShortcutsAndStoriesTrayHideAndRestore() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: configuration.userContentController, hidden: [.reels, .explore, .stories])
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <div>
              <div><span><a id="home" role="link" href="/"><svg aria-label="Home"></svg></a></span></div>
              <div id="explore-slot" style="min-width:48px"><span><a id="explore" role="link" href="/explore/"><svg aria-label="Explore"></svg></a></span></div>
              <div id="reels-slot" style="min-width:48px"><span><a id="reels" role="link" href="/reels/"><svg aria-label="Reels"></svg></a></span></div>
              <div><span><a id="inbox" role="link" href="/direct/inbox/"><svg aria-label="Messages"></svg></a></span></div>
            </div>
            <main>
              <article id="post"><span>Your story</span><a id="attribution" role="link" href="/reels/example/">Original audio</a></article>
              <div id="other-rail" style="overflow-x:auto"><div><div role="button"><span>Suggested account</span></div></div></div>
              <input id="message" type="text">
            </main>
            """, baseURL: URL(string: "https://www.instagram.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        _ = try await view.evaluateJavaScript("""
            const scroller = document.createElement('div');
            scroller.id = 'stories-tray';
            scroller.style.overflowX = 'auto';
            scroller.innerHTML = '<div><div role="button"><span><span>Your story</span></span></div><div role="button">A story</div></div>';
            const slot = document.createElement('div');
            slot.id = 'stories-slot';
            slot.style.minHeight = '124px';
            slot.append(scroller);
            document.querySelector('main').prepend(slot);
            """)
        try await require(view, "['explore-slot','reels-slot','stories-slot'].every(id => document.getElementById(id).getClientRects().length === 0)")
        try await require(view, "['home','inbox','post','attribution','other-rail'].every(id => getComputedStyle(document.getElementById(id)).display !== 'none')")

        _ = try await view.evaluateJavaScript("""
            history.pushState({}, '', '/direct/inbox/');
            document.getElementById('message').focus();
            document.getElementById('message').value = 'Unsent draft';
            """)
        _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, "document.activeElement.id === 'message' && document.activeElement.value === 'Unsent draft'")
        try await require(view, "['explore-slot','reels-slot','stories-slot'].every(id => document.getElementById(id).getClientRects().length !== 0)")
    }

    func testYouTubeShortsHideAndRestoreWithoutRemovingSearchOrVideos() async throws {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: config.userContentController, hidden: [.reels], engine: .youtube)
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 402, height: 750), configuration: config)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <ytm-app>
              <ytm-pivot-bar-item-renderer id="shortcut"><button aria-label="Shorts">Shorts</button></ytm-pivot-bar-item-renderer>
              <ytm-reel-shelf-renderer id="shelf"><a href="/shorts/example">Short</a></ytm-reel-shelf-renderer>
              <ytm-rich-section-renderer id="rich-shelf"><yt-shelf-header-view-model>Shorts</yt-shelf-header-view-model></ytm-rich-section-renderer>
              <input id="search" type="search">
              <a id="video" href="/watch?v=example">Video</a>
              <a id="outside" href="https://youtube.com.invalid/shorts/example">Other site</a>
            </ytm-app>
            """, baseURL: URL(string: "https://m.youtube.com/"))
        await fulfillment(of: [load.loaded], timeout: 8)
        try await require(view, "['shortcut','shelf','rich-shelf'].every(id => document.getElementById(id).getClientRects().length === 0)")
        try await require(view, "['search','video','outside'].every(id => document.getElementById(id).getClientRects().length > 0)")
        _ = try await view.evaluateJavaScript("""
            const tile = document.createElement('ytm-shorts-lockup-view-model');
            tile.id = 'late-tile';
            tile.textContent = 'Late tile';
            document.querySelector('ytm-app').append(tile);
            history.pushState({}, '', '/shorts/example');
            """)
        try await require(view, "document.getElementById('late-tile').getClientRects().length === 0 && document.documentElement.hasAttribute('data-supermod-blocked')")
        _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, "['shortcut','shelf','rich-shelf','late-tile'].every(id => document.getElementById(id).getClientRects().length > 0) && !document.documentElement.hasAttribute('data-supermod-blocked')")
    }

    func testYouTubeCustomTitledShortsShelvesCollapseWithoutHidingRegularVideos() async throws {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: config.userContentController, hidden: [.reels], engine: .youtube)
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 402, height: 750), configuration: config)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <style>body { margin: 0; } ytm-shelf-renderer, grid-shelf-view-model { display: block; min-height: 260px; }</style>
            <ytm-app>
              <input type="search" id="search">
              <grid-shelf-view-model id="shorts-only">
                <yt-shelf-header-view-model>Latest from NASA</yt-shelf-header-view-model>
                <ytm-shorts-lockup-view-model><a href="/shorts/space">Space</a></ytm-shorts-lockup-view-model>
              </grid-shelf-view-model>
              <ytm-video-with-context-renderer id="regular"><a href="/watch?v=space">NASA mission</a></ytm-video-with-context-renderer>
              <grid-shelf-view-model id="mixed">
                <yt-shelf-header-view-model>More from NASA</yt-shelf-header-view-model>
                <ytm-shorts-lockup-view-model id="mixed-short"><a href="/shorts/moon">Moon</a></ytm-shorts-lockup-view-model>
                <a id="mixed-video" href="https://www.youtube.com/watch?v=launch">Full launch</a>
              </grid-shelf-view-model>
              <ytm-shelf-renderer id="ordinary"><yt-shelf-header-view-model>Latest videos</yt-shelf-header-view-model><a href="/watch?v=planet">Planet</a></ytm-shelf-renderer>
            </ytm-app>
            """, baseURL: URL(string: "https://m.youtube.com/results?search_query=NASA"))
        await fulfillment(of: [load.loaded], timeout: 8)
        try await require(view, "!document.getElementById('shorts-only').getClientRects().length && !document.getElementById('mixed-short').getClientRects().length")
        try await require(view, "['search','regular','mixed','mixed-video','ordinary'].every(id => document.getElementById(id).getClientRects().length > 0)")
        try await require(view, "document.getElementById('regular').getBoundingClientRect().top < 50")
        _ = try await view.evaluateJavaScript("""
            document.getElementById('shorts-only').insertAdjacentHTML('beforeend', '<a id="new-video" href="/watch?v=new">New full video</a>');
            """)
        try await require(view, "document.getElementById('shorts-only').getClientRects().length > 0 && document.getElementById('new-video').getClientRects().length > 0")
        _ = try await view.evaluateJavaScript("document.getElementById('new-video').remove()")
        try await require(view, "!document.getElementById('shorts-only').getClientRects().length")
        _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, "['shorts-only','mixed-short','regular','mixed-video'].every(id => document.getElementById(id).getClientRects().length > 0)")
    }

    func testYouTubeStandaloneShortsCardsCollapseWithoutHidingRegularVideos() async throws {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        FilterScripts.install(on: config.userContentController, hidden: [.reels], engine: .youtube)
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 402, height: 750), configuration: config)
        let load = WebFixtureLoad()
        view.navigationDelegate = load
        view.loadHTMLString("""
            <style>ytm-video-with-context-renderer { display: block; min-height: 55px; }</style>
            <ytm-app><lazy-list>
              <ytm-video-with-context-renderer id="short-card"><ytm-media-item class="big-shorts-singleton">
                <a id="thumbnail" class="media-item-thumbnail-container" href="/shorts/launch">Thumbnail</a>
                <div><a href="/@NASA">NASA avatar</a><a href="/shorts/launch">Launch</a><button>Action menu</button></div>
              </ytm-media-item></ytm-video-with-context-renderer>
              <ytm-video-with-context-renderer id="regular-card"><ytm-media-item>
                <a class="media-item-thumbnail-container" href="/watch?v=launch">Full video</a>
                <p>Also watch <a href="/shorts/launch">our Short</a></p>
              </ytm-media-item></ytm-video-with-context-renderer>
              <ytm-video-with-context-renderer id="reused-card"><ytm-media-item class="big-shorts-singleton">
                <a class="media-item-thumbnail-container" href="https://m.youtube.com/watch?v=regular">Regular video in a reused card</a>
              </ytm-media-item></ytm-video-with-context-renderer>
              <ytm-video-with-context-renderer id="external-card"><ytm-media-item class="big-shorts-singleton">
                <a class="media-item-thumbnail-container" href="https://youtube.com.example.test/shorts/external">External link</a>
              </ytm-media-item></ytm-video-with-context-renderer>
            </lazy-list></ytm-app>
            """, baseURL: URL(string: "https://m.youtube.com/results?search_query=NASA"))
        await fulfillment(of: [load.loaded], timeout: 8)
        try await require(view, "!document.getElementById('short-card').getClientRects().length")
        try await require(view, "['regular-card','reused-card','external-card'].every(id => document.getElementById(id).getClientRects().length > 0)")
        _ = try await view.evaluateJavaScript("document.getElementById('thumbnail').setAttribute('href', '/watch?v=full')")
        try await require(view, "document.getElementById('short-card').getClientRects().length > 0")
        _ = try await view.evaluateJavaScript("document.getElementById('thumbnail').setAttribute('href', '/shorts/launch')")
        try await require(view, "!document.getElementById('short-card').getClientRects().length")
        _ = try await view.callAsyncJavaScript("return supermodApply([])", arguments: [:], in: nil, contentWorld: FilterScripts.world)
        try await require(view, "document.getElementById('short-card').getClientRects().length > 0 && document.getElementById('thumbnail').getClientRects().length > 0")
    }

    private func require(_ view: WKWebView, _ expression: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<32 {
            if try await view.evaluateJavaScript(expression) as? Bool == true { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("DOM predicate remained false: \(expression)", file: file, line: line)
    }

    private func requireStatus(_ session: WebSession, _ status: WebStatus, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<32 {
            if session.status == status { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Expected \(status), received \(session.status)", file: file, line: line)
    }
}

@MainActor
private final class CancelledWebRequest: NSObject, WKNavigationDelegate {
    let received = XCTestExpectation(description: "Recovery request received")
    private(set) var url: URL?
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        url = navigationAction.request.url
        decisionHandler(.cancel)
        received.fulfill()
    }
}

private final class WebFixtureLoad: NSObject, WKNavigationDelegate {
    let loaded = XCTestExpectation(description: "Fixture finished loading")
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded.fulfill() }
}
