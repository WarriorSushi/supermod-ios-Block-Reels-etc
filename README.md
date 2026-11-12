# Supermod for iOS

Supermod is a native SwiftUI app for browsing Instagram, Facebook, and public YouTube videos with user-selected filters. It targets iOS 17 or later. The checked-in Xcode project uses the RevenueCat SDK through Swift Package Manager; account-specific SDK keys and signing credentials are intentionally absent. See [RESTORE.md](RESTORE.md) to rebuild and reconnect optional services.

## Archived source — 12 November 2026

The latest source includes stable suggested/sponsored post filtering, sparse-feed pagination recovery, pull-to-refresh, a Home Scroll timer with editable Stories/Reels/Explore/feed choices, filter locking, and a circular draggable control with a countdown ring. The final development regression passed 54 tests before archival. This is a development snapshot, not an approved public release.

[Restore instructions and exclusions](RESTORE.md). Historical documentation may link to raw Evidence files that are intentionally absent from this public repository.

## Earlier build — 11 November 2026

Build 2 includes the reconstructed phone previews, automatic demonstrations, bouncing liquid fill, matching transparent-mascot launch screen, a shorter 21-screen onboarding with sourced research, an explicit explanation that filtering happens inside Supermod, and a redesigned paywall. Debug builds include **Continue without paying**. Release builds ignore that testing-access flag.

- [Latest handoff and validation](docs/onboarding-subscriptions-handoff-2026-11-11.md)
- [Apple and RevenueCat account setup / remaining steps](docs/subscriptions-setup-2026-11-11.md)
- [Screen decisions and research sources](docs/onboarding-evidence-and-rationale-2026-11-11.md)
- [Onboarding preview](Evidence/Onboarding-rebuild-2026-11-11/Onboarding-preview.mp4)

## Run on a simulator

1. Open `Supermod.xcodeproj` in Xcode.
2. Select the **Supermod** scheme and an installed iPhone simulator, then press **Run**. The Debug scheme uses `Supermod.storekit`, a local StoreKit test configuration. Its monthly and annual prices are provisional. StoreKit supplies the displayed currency and amount.
3. Complete setup and confirm your modifications. Use **Explore sample preview** on the paywall to try a labeled offline sample. Use an Xcode test purchase or **Continue without paying** to reach the connection screen. The app opens Instagram’s website inside Supermod.

The project can be regenerated with `xcodegen generate` after changing `project.yml`. XcodeGen is optional for building the checked-in project.

## Architecture

- **App** owns local Codable settings, the current onboarding step, aggregate usage, and StoreKit entitlement state. StoreKit verifies transactions on-device and updates access on revocation and expiration. The local Debug scheme restores verified Xcode transactions directly on simulator or device. Production restore requests Apple account synchronization.
- **Onboarding** uses one scrollable scaffold with a fixed action area for 21 active screens (26 persisted identifiers remain compatible). Choices resume after relaunch. Replay starts a separate flow and returns to Home before subscription selection. Goal artwork is bundled, and preview content is fictional.
- **Social** owns one reusable WKWebView and one persistent data store keyed by a local UUID. Instagram handles sign-in. The compact Supermod control along the right edge opens Home and Modifications. On a cold launch with a previous connection, the app opens Instagram’s entry page with the same WebKit data store. A prior unsigned-in visit returns to Connect when automatic return is enabled.
- **Filtering** bundles versioned JSON, CSS, a page-world history signal, and an isolated-world engine. The native navigation delegate independently checks allowed origins and routes. The engine batches scoped DOM changes and avoids post text and message text. Ad and suggestion selectors use English accessibility labels and known structural markers. Unknown layouts can show a filter warning. A session pause is available outside a focus lock and clears on backgrounding.
- **Interior** exposes the modifications editor, focus lock, settings, separate site data and usage deletion, subscription management, and an offline sample. The focus lock uses the device clock, persists an end time, and clears after expiration or a backward change of more than five minutes relative to the recorded start. It controls only Supermod. Aggregate usage excludes login and recovery states, background time, onboarding, and the sample.

While **Hide Reels** is on, Supermod blocks both the Reels feed and shared Reel pages. This is the provisional fallback until single-item playback and the prevention of endless-next transitions can be validated. The native adapter leaves Instagram sign-in, challenge, and consent pages to the platform. WebKit reload recovery may lose unsent drafts after a process failure.

The approved mascot is the source for the layered Icon Composer app icon and launch artwork. iOS applies the Home Screen mask. The original upload is preserved in [Design](Design/Supermod-approved-icon-original.png).

The **Facebook** button on Home opens Facebook with an English locale request and a persistent WebKit store separate from Instagram. The Supermod menu opens Facebook’s filters for sponsored posts, Reels, and Stories. The mobile feed header hides as you scroll down and returns on a short reverse scroll. Facebook’s Messages tab opens the web inbox in the same session. Live simulator testing confirmed that the Stories tray and Reels tab and section hide, regular posts stay visible, and the Messenger composer accepts a draft. Sponsored posts still need a live comparison.

**YouTube** uses its own WebKit store and opens the public mobile website. Hide Shorts removes supported Shorts shelves and shortcuts and blocks Shorts routes inside Supermod. Settings offers a launch destination, a grayscale view for the embedded browsers, and an optional daily quiet-hours window that prevents opening a social site inside Supermod during that window.

## Verification

```sh
xcodebuild -project Supermod.xcodeproj -scheme Supermod \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  -derivedDataPath .build -parallel-testing-enabled NO test
```

The unit target exercises local state, URL policy, bundled scripts in a real WKWebView, and Xcode StoreKit products. The UI target uses local StoreKit test data and captures onboarding and interior screens. [Verification and handoff](docs/verification.md) records executed checks and launch blockers.

[Reference adaptation](docs/reference-adaptation.md)

## Current release candidate

See [the 11 November 2026 handoff](docs/rc-handoff-2026-11-11.md) for current fixes, verification, the fresh onboarding recording, and external release dependencies.
