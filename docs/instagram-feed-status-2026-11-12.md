# Sparse Instagram feed: stalled pagination and status feedback

## Observed cause

Device Hub showed one post followed by a spinner and blank space on the user's iPhone. Temporary native WKWebView diagnostics reproduced the stalled state on the actual phone for six samples over 18 seconds:

- `articles=1`, feed `items=1`, `hasNextPage=true`, `isFetching=false`.
- `scrollY=0`, document height 915, viewport height 839.
- Instagram's virtual-feed paginator was available, but it was not being invoked after filtering left the initial feed short.

This was not evidence that the feed had ended. Simulator inspection also showed that regular batches often contained 8–11 entries but only 2–3 ordinary posts after suggested/ad filtering.

## Change

The existing document-start data filter remains in place. It now retains only small pagination metadata (end flag and counts; no post content). At a short/empty end of the feed, the adapter recognizes the observed PolarisGenericVirtualFeed component and invokes its own `onNextPage` callback after allowing normal prefetch to run. It never constructs requests, changes cursors, scrolls the page, or collapses rendered posts.

Automatic recovery is bounded to three pages per empty stretch, is suppressed while a request is outstanding or Instagram reports fetching, and stops after 15 seconds. Unknown component formats are not invoked. Non-Home routes, sign-in, focused input and open dialogs are excluded. The native check runs every two seconds only while the Instagram screen is active.

When enough blank space is visible below the last post, a native card distinguishes:

- Loading more posts.
- More posts haven't loaded, with Try loading more.
- A confirmed end of this feed, with Refresh feed.
- Home feed deliberately hidden by the user's filter.

The card explains active suggested/ad filters and overlays existing blank space without resizing WebKit. Manual retry uses Instagram's paginator when available and otherwise refreshes Home, preserving open drafts by refusing either action while an editor/dialog is active.

## Verification

Evidence directory: `Evidence/Instagram-feed-status-2026-11-12/`.

- `phone-probe.log`: physical-device stalled state before the fix.
- `phone-after.log`: actual phone changed from one post / idle to fetching, then three posts. Document height grew to 2051; `scrollY` remained zero throughout. This confirms recovery of the reproduced stall, not a guarantee about all future Instagram formats.
- Two new behavior tests failed before implementation (`Red.xcresult`) and passed afterward: sparse-feed recovery preserves post geometry; filtered-empty pages are not treated as end, and recovery is bounded.
- 48 model, StoreKit and WebKit tests passed (`Regression.xcresult`), including previous feed-stability regressions.
- Added native status/retry test passes for open-dialog protection and navigation away from Home. Initial fixture failure was due to zero WebView geometry and focusing an unattached textarea; fixture now has a phone-sized frame and an actual open-dialog marker.
- All three new feed tests passed again against final source (`Final-feed-checks.xcresult`). 49 distinct tests passed across regression and added native checks.
- Reviewed the native stalled-feed card in a clearly labeled simulator fixture (`Stalled-feed-fixture.jpg`). Reloaded/reinstalled the simulator app to remove the fixture and debug parse observer.
- Signed device build succeeded, final app installed and launched on the test iPhone 15 Plus. Existing data/preferences retained. Temporary diagnostic logging and physical-device Web Inspector enablement removed; inspection remains simulator-only.

The automatic paginator is a guarded adaptation to the observed Instagram component. If its private structure changes, the app falls back to explicit status and user-triggered refresh instead of making unbounded guesses.
