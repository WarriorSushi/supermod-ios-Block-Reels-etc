# Stable Instagram suggested-post and sponsored-post filtering

## Problem and change

The user confirmed scrolling was stable with suggested-post filtering disabled. The previous implementation changed rendered recommendations to one-pixel rows and ads to `display:none`. Removing a spacer override and moving DOM scans before paint corrected two defects but left this conflict with Instagram's virtualized layout.

The current implementation filters recognized timeline entries **before Instagram renders them**. Live inspection identified `data.xdt_api__v1__feed__timeline__connection`, with `XDTFeedItem` nodes for ordinary `media`, recommended `explore_story.media`, `suggested_users`, and `ad`. A document-start page-world script wraps JSON parsing only for payloads containing that exact connection key. It handles both nested Relay-prefetched initial data and later GraphQL pages. It preserves unknown node types, unrelated payloads, server cursors, and pagination flags. Ad and recommendation settings work independently. No extra network requests or credentials are introduced.

The isolated-world DOM engine remains a fallback for unrecognized markup. It masks residual recommendation/ad content at its natural height, shows a neutral hidden-post label, and pauses residual media. It never collapses those rows or overrides feed spacers. Open comment dialogs and focused editors retain their existing exceptions. The live verification below did not encounter any fallback cards.

Changing either feed filter refreshes the home timeline once so Instagram rebuilds it with the new selection. Other routes and open comment drafts are not reloaded; a pending refresh can apply on return to Home. Route blocking and other services retain their existing behavior.

## Verification

Evidence: `Evidence/Instagram-stable-feed-2026-11-12/`.

- `Red.xcresult`: both new regressions failed on the preceding implementation—timeline data retained unwanted entries, and late suggested/sponsored labels moved the visible feed.
- `Targeted-green.xcresult`: both passed after the architectural change.
- `Regression.xcresult`: all **43** model, StoreKit, and WebKit tests passed, zero failures/skips. Coverage includes nested bootstrap data, independent settings, unrelated payloads, retained cursors for an all-filtered page, normal JSON parse errors, late labels above the viewport, restoration on node reuse, before-paint filtering, pagination, comment visibility, and safe home refresh versus an open unsent draft.
- Signed-in simulator: seven subsequent feed pages delivered only ordinary media entries to the renderer. Scrolled down beyond 8,000 points and back to the top. `live-scroll-trace.json` contains 12,000 frame samples and 25 distinct DOM row identities; maximum scroll offset was 8,248, first/last offset zero. No recorded row collapsed from normal height to zero/one pixel, and no fallback-masked rows were present. `live-scroll-summary.json` and `Live-feed-after-scroll.jpg` retain the summary and final view.
- Development-signed iPhone build succeeded. Bundled feed script, DOM engine, and CSS were byte-compared with source. Installed over the existing app on the test iPhone 15 Plus and launched successfully; Device Hub showed the signed-in Instagram feed. Build, installation, launch, and process evidence are saved here.
- The phone's saved custom settings already enabled both suggestions and sponsored filtering before installation; those settings and the signed-in data were preserved.

This is evidence for the observed current Instagram format and tested interactions. Unknown future feed formats use the geometry-preserving fallback. Repeated physical scroll gestures are not remotely verified by Device Hub's screen-only observation; do not describe the user's device acceptance as completed without their report. No App Store release or production deployment was performed.
