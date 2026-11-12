> Latest build-2 evidence and outstanding account/device work: [11 November onboarding/subscription handoff](onboarding-subscriptions-handoff-2026-11-11.md). The notes below are earlier milestones, not a claim that the latest iPhone build or Apple sandbox has been exercised.

# Verification and handoff

**Current RC:** [11 November 2026 handoff](rc-handoff-2026-11-11.md). The sections below are historical evidence; use the current handoff for this revision and its remaining release dependencies.

## Simulator

Xcode 27.2 (27B52) and the existing iPhone 18 Pro with iOS 27.0 were used. The app’s deployment target is iOS 17. No SDK or runtime downloads were needed.

```sh
xcodebuild -project Supermod.xcodeproj -scheme Supermod \
  -destination 'platform=iOS Simulator,id=77488B04-E954-4F72-ADF4-5C07BF5864F1' \
  -derivedDataPath .build -parallel-testing-enabled NO test

xcodebuild -project Supermod.xcodeproj -scheme Supermod -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/release-final build
```

- The focused simulator suite passed 8 tests with zero failures. It covered onboarding navigation and persistence, projections, preset transitions, focus lock expiry, usage accounting, URL policy, dynamic and reversible WebKit filters, clearing only the chosen WebKit store, and StoreKit purchase, restore, and refund.
- The automated walkthrough completed onboarding, interacted with the comparison and sample, held to confirm, purchased with local StoreKit, restored, relaunched, confirmed the saved Stories modification, and cleared the Instagram session. The plans displayed ₹999.00 monthly and ₹2,999.00 annually from the India test storefront. Both values are provisional.
- The live logged-out smoke check reached Instagram’s entry and sign-in forms inside the native shell. Focusing the username field showed the input accessory bar and left Home and Mods tappable. No credentials were entered. Fixture passes establish WebKit mechanics. Logged-in pages can use different markup.
- Inspected the rendered standard and dark welcome screens, principal onboarding and Home screens, and the largest Dynamic Type welcome layout. At accessibility text sizes the welcome headline comes before its artwork and the primary action stays anchored. VoiceOver and Reduce Motion still need a manual pass.
- The Release simulator build succeeded. Its bundle contains the privacy manifest, compiled icons, and bundled filtering rules. The local StoreKit configuration is in the project and test bundles. The privacy manifest declares local UserDefaults access and uptime for foreground usage accounting. [Apple’s required-reason categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

[Simulator walkthrough](../Evidence/Supermod-simulator-walkthrough.mp4) · [Screenshots](../Evidence/Screenshots) · [Xcode result summary](../Evidence/Test-summary.json)

## Next on a real account and device

1. Sign in through Instagram’s page and complete 2FA or a checkpoint if requested. Confirm expected cookies persist after terminating and reopening Supermod.
2. Open a conversation, compose and send a text DM, background and reopen the app, and check the keyboard and unsent draft. Check sign-out and the clear-session action.
3. Test every selector against the logged-in feed and a second language. Check DMs, profiles, following links, Stories, Explore, sponsored labels, suggestions, and unfiltered fallback. Confirm both shared-Reel and endless-feed links are blocked with Hide Reels enabled. Verify single-item isolation before allowing any shared Reel exception.
4. Check focus lock and the return-to-Instagram setting across process restarts. Confirm that scope is limited to Supermod.
5. Walk onboarding, the paywall, and Instagram chrome with VoiceOver, Reduce Motion, large Dynamic Type, and the software keyboard on a physical iPhone.

## Release blockers

- Approve production prices, App Store Connect products, and subscription metadata. The Xcode products are local test data.
- Supply public Supermod privacy, terms, and support details. The current screens explain local-build behavior and link to Apple’s standard license where appropriate.
- Review privacy disclosures and manifests for actual distribution, including the embedded third-party website and StoreKit.
- Review Instagram service authorization and applicable third-party terms, as well as App Store minimum functionality, branding, and copycat considerations.
- Validate logged-in routing, selectors, live text DMs, account challenges, accessibility, and physical-device performance. The simulator fixture establishes local filtering mechanics.

The approved mascot replaces the original icon and appears in the launch and onboarding assets. The source image is preserved byte for byte. The installed icon was inspected on the iPhone 18 Pro Home Screen in both appearances. [Light appearance](../Evidence/Screenshots/19-Supermod-installed-icon-light.png) · [Dark appearance](../Evidence/Screenshots/20-Supermod-installed-icon-dark.png)

A later signed-in check confirmed the mobile feed hides an entire card labeled “Ad.” The WebKit fixtures also cover “Sponsored,” late badges, ordinary captions, and authors named “Ad.” Nine unit tests passed. A signed-in simulator check opened the compact Supermod menu and verified the sponsored-post setting. A text message sent to the signed-in account reappeared in the conversation after rebuilding and relaunching Supermod.

The full-screen layout keeps WebKit in charge of keyboard sizing. After the change, normal simulator typing found the signed-in account in Instagram’s recipient search.

Facebook uses a separate persistent WebKit profile. On the iPhone 18 Pro simulator, Facebook initially served the sign-in page in Telugu. With the `en_US` request, the simulator showed Facebook's own English (US) sign-in form.

The focused model and WebKit suite passed 10 tests on the iPhone 17e simulator. The Facebook fixture covers dynamic ad labels, reversible feed changes, Reels and Stories routes, and typing into a Messenger-style composer with the filters enabled. It also checks that ordinary posts and messaging links remain available. The simulator with the live sign-in form was kept separate from these automated tests.

On the signed-in iPhone 18 Pro simulator, the mobile Stories tray, Reels tab, and in-feed Reels section disappeared with their filters enabled. Regular posts remained visible and the feed scrolled. The Messages tab opened Facebook's desktop web inbox inside Supermod. With all filters enabled, the live Messenger composer accepted a draft that was then cleared. Facebook showed a PIN prompt again on a later visit and previously warned that some encrypted chats could not load.

The expanded model and WebKit suite passed 11 tests. Sponsored posts were hidden in local test pages, but no sponsored label appeared across the live feed screens checked with that filter off.

The polished build puts Instagram and Facebook on the same Home screen. Signed-in simulator checks confirmed that Facebook's header hides on a downward scroll, returns mid-feed on a short reverse scroll, and opens Search from that position. The original cat and background are separate layers in the Icon Composer icon and in the in-app launch animation.

[Home](../Evidence/Screenshots/22-Supermod-polished-home.png) · [Launch animation frame](../Evidence/Screenshots/21-Supermod-layered-launch.png) · [Installed icon](../Evidence/Screenshots/23-Supermod-layered-icon-installed.png)

All transactions were local Xcode tests. Distribution and real-money acceptance are pending.

## Onboarding and YouTube update

- The iPhone 17e simulator passed all 17 tests. The walkthrough exercised Back and Skip, the comparison and estimator controls, a released hold and a completed hold, the sample preview, local StoreKit purchase and restore, relaunch, and clear-session. Model and WebKit tests also covered legacy settings, overnight quiet hours, the YouTube origin allowlist, route blocking, late Shorts content, and reversible filtering.
- On the iPhone 18 Pro simulator, the live YouTube tab and shelf disappeared with Hide Shorts on and returned with it off. A regular video played with filtering on. The search interface opened. End-to-end live search submission and Google account sign-in were not verified.
- The Release simulator build passed. A development-signed build installed and launched on the connected iPhone 15 Plus using the existing development profile. That establishes installation and launch. Physical-device accessibility, haptics, and full service browsing still need a manual pass.

[Onboarding screenshots](../Evidence/Onboarding-refresh) · [Xcode test summary](../Evidence/Onboarding-refresh/Test-summary.json) · [SocialLite feature coverage](reference-adaptation.md#sociallite-ios-feature-coverage)

### App Store handoff

- Configure App Store distribution signing and the App Store Connect record for `app.supermod.ios`. The Mac has development signing. No valid local distribution identity was found.
- Confirm the monthly and annual subscription IDs and prices, configure them in App Store Connect, and verify both purchases and restore in TestFlight. The current purchase evidence is from Xcode’s local storefront.
- Supply public support and privacy URLs and final subscription terms. Review the App Privacy answers against the embedded sites and StoreKit.
- Establish authorization for the embedded services, including public YouTube playback and filtering, before submission. Apple asks that use of a third-party service be specifically permitted. [App Review Guidelines §5.2.2 and §5.2.3](https://developer.apple.com/app-store/review/guidelines/#intellectual-property)
- Complete the physical-device accessibility and account-flow checks. Prepare reviewer access or instructions for the authenticated surfaces. Keep the offline sample available so reviewers can see onboarding and filtering without a social account.
- Verify a real sponsored post with the Facebook filter both off and on. The WebKit fixtures cover this case, but the live Facebook test did not encounter a sponsored post.

Suggested review description

> Supermod lets users choose which parts of social feeds to see. Its native onboarding includes an offline example that shows the available filters without a social account. Subscription access opens Instagram, Facebook, and public YouTube inside the app. Settings provides local-data removal and subscription restore. Quiet hours apply inside Supermod.

### Current physical-device follow-up — 11 November 2026

After reconnection, the RC installed and launched on the test iPhone 15 Plus (iOS 27.0.1). The current plans screen was captured and the process remained running across two checks. The device reported plans unavailable; no purchase or local-data reset occurred. This is an install/launch/render smoke pass, not complete device accessibility or live-service acceptance. See the [current handoff](rc-handoff-2026-11-11.md) and `Evidence/RC-2026-11-11/Screenshots/Physical-iPhone-current.png`.
