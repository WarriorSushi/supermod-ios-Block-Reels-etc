# Supermod release candidate — 11 November 2026

The app was improved directly in the existing project. The approved icon remains intact. No production purchase, account configuration, website deployment, or App Store submission was performed. This is a locally verified candidate with external release dependencies, not a distribution approval.

## Changes

- Rebuilt the onboarding composition around the supplied SocialLite recording: larger device demonstrations, open backgrounds, smaller centered headings, anchored actions, directional spring transitions, animated selections and number feedback, an open age wheel, full-screen hold expansion, and a cleaner completion/paywall reveal. Supermod keeps its own cat and truthful copy.
- Prevented fast repeated Next taps from skipping a page. Verified termination/resume and Back behavior. Replaying setup no longer changes the user's live filter preferences.
- Made interrupted/short holds reset cleanly. VoiceOver has a no-hold activation and a separate single-tap confirmation. Removed a completion latch that could suppress a second accessibility activation after the navigation guard rejected the first.
- Fixed recovery choosing a newly blocked URL, asynchronous callbacks overwriting a terminated WebKit state, redundant suspension updates, and clearing-session races. Facebook and YouTube temporary filter pauses now reset on backgrounding. Their session-clear actions have independent confirmation and busy-state handling.
- Extended Instagram suggestion detection to a recognized plain “Suggested for you” header without hiding matching captions/authors. YouTube now observes late/reused accessibility labels; Shorts shelf handling is tested for restoration and preservation of ordinary video content.
- Corrected subscription access during billing grace and when verified revocation precedes removal of a stale current entitlement. Refresh timing is bounded. Product descriptions now cover all three services; IDs and prices are unchanged.
- Separated Restore, Terms, and Privacy links on the paywall. Added stable native menu identifiers for reliable UI verification. Embedded web inspection is enabled only for Debug simulator builds.

## Evidence and tests

All current evidence is under `Evidence/RC-2026-11-11/`.

- Original baseline: 17 tests passed before changes (`Baseline.xcresult`).
- Integrated suite: `Release-candidate.xcresult` passed **25 tests, zero failures, four opt-in tests skipped**, with local StoreKit purchase/restore/refund/grace/revocation, model and WebKit fixtures, full onboarding/sample/purchase/replay/clear-session UI flow, double tap, resume, and interrupted holds. Exact totals are in its JSON summary.
- `Instagram-draft.xcresult` passed the explicit unsent draft/clear check in the signed-in account’s self-thread; screenshots are `Final-Live-Instagram-unsent-draft.png` and `Final-Live-Instagram-draft-cleared.png`. The earlier broad walkthrough could not locate that thread; the focused query corrected the test locator.
- `Live-current.xcresult` passed its opt-in live walkthrough on the preserved iPhone 18 Pro session. It toggled the three services' controls on/off and restored the starting values, visited Instagram profile/messages, exercised Facebook scrolling/Messenger, submitted a YouTube NASA search, and opened a regular video. This test records observations; it is not proof every real-world ad or page variant was encountered.
- `Small-Motion-verified.xcresult` passed complete onboarding on iPhone SE (3rd generation), dark appearance, with Reduce Motion enabled. Largest Dynamic Type welcome/intent screenshots show scrollable content above reachable actions.
- `YouTube-live-hydrated.xcresult` passed the final focused live check after waiting for page interactivity. `youtube-nasa-dom-final.json` records three Shorts grids and one standalone Shorts card at zero height while 17 normal videos remain visible. `Final-YouTube-search-filtered.png` confirms the empty gap is gone. Earlier focused harness attempts tapped before the page was interactive; those failed bundles are diagnostic, not accepted checks.
- `Onboarding-final.xcresult` and the final video capture the current motion and local test prices. The recording does not perform a purchase.
- Earlier red bundles remain to document reproductions. In particular, `Navigation-red-run`, `Web-red-retry`, `Suggestions-red`, `Entitlement-stale-red`, and `Shorts-shelf-red` must not be mistaken for final acceptance. The earlier `Final-tests.xcresult` had an invalid StoreKit refund assumption, investigated and replaced by explicit verified-state assertions.

## Live service coverage and limits

| Surface | Current observation | Remaining limit |
| --- | --- | --- |
| Instagram feed/profile | Ordinary feed and profile rendered; Stories/Reels/Explore controls exercised reversibly; recognized suggestion fix covered by WebKit regression | New markup/languages and real sponsored examples are not exhaustively validated |
| Instagram messaging | Signed-in inbox opened; focused `Instagram-draft.xcresult` passed unsent text entry and clearing; native menu remains available | Focused self-thread draft test typed text and cleared it; no Send action was performed |
| Facebook | Feed and ordinary posts rendered, Stories/Reels toggled, short reverse scroll/header captured | No genuine sponsored label encountered in this run; ad fixture passes are separate evidence |
| Messenger | Inbox navigation reached “Create a PIN to access your chats on any device” | PIN creation/authentication is an external dependency; typing was not verified in this run |
| YouTube | Shorts controls restored on/off; NASA search submitted; regular NASA video displayed playback content with filtering on | Google sign-in is not promised by the public-browser implementation; custom search shelves and standalone Shorts were confirmed collapsed in the final live DOM and screenshot; 17 regular video results remained visible |
| Recovery and isolation | Blocked-route recovery, termination state, separate stores, clearing and dynamic filter restoration tested with WKWebView fixtures | Lossy real-device network and long-session performance acceptance remain |
| Quiet hours/startup/grayscale | Existing model tests cover overnight schedule/usage/presets and launch preferences; no system-wide Screen Time blocking is claimed | Physical-device behavior and accessibility acceptance remain |

The signed-in simulator is reserved for reversible live checks. Clean setup, data-clearing, and local StoreKit tests run on separate simulators. Existing account credentials were not entered or exported. Live screenshot evidence contains account content and is for local review.

## Accessibility and device boundary

The full small-screen Reduce Motion flow passed. Large Dynamic Type welcome and selection content were inspected in dark appearance. VoiceOver was enabled and focus reached the heading and primary action; the simulator mirror did not reliably forward double-tap activation, so complete spoken order and assistive interaction acceptance is not claimed. `accessibility-checks.txt` records this boundary. Both light and dark current screenshots are retained.

The final Release simulator and development-signed iPhone builds succeeded with the existing development team (`Logs/release-final.log`, `Logs/device-final.log`). After the user reconnected the test iPhone 15 Plus (iOS 27.0.1), the current build installed and launched successfully. It resumed the existing plans screen; a 1290×2796 physical-device screenshot confirms the rendered UI, and two process checks confirmed the app remained running. Evidence: `device-install.json`, `device-launch.json`, `device-process-check.json`, `device-process-final.json`, and `Screenshots/Physical-iPhone-current.png`. No reset or purchase was performed. The device displayed “Plans are unavailable. Try again in a moment.” This confirms the unavailable-products state, not production billing readiness. Full physical-device browsing, haptics, VoiceOver, keyboard, and performance acceptance remain open.

## Release dependencies

See `rc-release-review-2026-11-11.md` for inspected sources and Apple documentation.

1. `supermod.app/privacy` currently describes an unrelated Amazon listing scanner; `/support` returns 404. An approved app-specific public policy, reachable support page and monitored contact are required.
2. App Store distribution signing, production product metadata/prices/agreements, and sandbox/TestFlight purchase/restore remain unverified. Local fixture prices are provisional.
3. Service authorization, actual embedded-site App Privacy disclosures, reviewer access, metadata/screenshots and age rating need completion.
4. Physical-device and complete assistive-technology acceptance remain pending. Messenger PIN/authentication and real Facebook sponsored-post comparison are unresolved live checks.

## Files to review

- Fresh recording: `Evidence/RC-2026-11-11/Supermod-onboarding-final.mp4`
- Current screenshots: `Evidence/RC-2026-11-11/Screenshots/`
- Full test results: `Evidence/RC-2026-11-11/Release-candidate.xcresult`
- Reference inspection: `Evidence/RC-2026-11-11/Reference/` (full timestamped sequence plus welcome/hold clips and close motion frames)
- Optional logo concepts: `Design/Supermod-logo-explorations.png`; source prompt: `Design/RC-logo-exploration-prompt.txt`. These are an exploration board, not replacements for the approved icon.
- Source rollback: `Evidence/RC-2026-11-11/source-before.tgz`. This workspace has no Git repository; the archive preserves the starting source, project, and docs.

Final source comparison is in `source-review.json`: all 15 archived icon/mascot resource files are unchanged. Final app products are `.build/rc-release/Build/Products/Release-iphonesimulator/Supermod.app` and `.build/rc-device/Build/Products/Debug-iphoneos/Supermod.app`.

The final preserved-session preferences were read back after UI restoration: Instagram Custom hides Explore/Suggestions/Sponsored only; Facebook hides Sponsored only; YouTube Hide Shorts is on. See `restored-filter-preferences.json`.
