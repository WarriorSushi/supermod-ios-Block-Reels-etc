# Simulator performance and interaction audit — 12 November 2026

## Implemented

- Added a shared, always-on app-promotion filter for Instagram, Facebook, and YouTube. It is separate from optional feed filters. It recognizes bounded fixed/sticky install/open-app overlays, including late insertion, SPA navigation, style changes, and App Store links with localized text. It removes smart-app-banner metadata. Ordinary post text, navigation, forms, editors, and videos are excluded from container removal. Reused promo containers are restored when they stop being promotions.
- Reproduced Instagram's **Use the app** bar and Facebook's **Open app** bar in signed-in simulator sessions; verified both hidden after implementation. Pausing optional feed filters does not disable promotion removal.
- Instagram's follow-suggestion detection now revisits the changed non-post row instead of walking every post caption on each mutation. It skips unchanged ancestor/descendant duplicates and drops disconnected references.
- Facebook and YouTube retain a lazily created WebSession across Home transitions. The presentation receives its session as an item, avoiding an empty first cover. Only opened services allocate sessions. Inactive retained sessions are released on a memory warning. Returning Home suspends media; returning to the service re-enables media playback controls.
- Replaced Facebook/YouTube's once-per-second filter polling with a cancellable task tied to the actual Reels-break deadline.
- The native loading overlay ends at document commit instead of waiting for all secondary resources. Layout recognition still runs after navigation finishes. Existing offline, blocked-route, challenge, and process-recovery states remain.
- Added centralized, coalesced native haptics to all SwiftUI button actions, including onboarding, plans, Home, toolbar buttons, floating menu, menu items, and accessibility move actions. Added feedback for remaining pickers/toggles and floating-button repositioning. Existing slider, switch, and successful-hold feedback remains. A trusted-control-click bridge adds haptics inside the social sites; scrolling, typing, disabled controls, and synthetic JavaScript clicks do not trigger it. Reduce Motion no longer suppresses the hold's tactile ticks.
- Made the DEBUG-only UI-test reset write a fresh preference snapshot. The compact simulator had a stale domain written outside the app container; removing the container value exposed that fallback and resumed an old onboarding step. No production reset behavior changed.

## Measured and observed

| Check | Before | After |
|---|---|---|
| Twelve caption mutations in a 200-post WebKit fixture | 10 full-feed text walks after mutation coalescing | 0 full-feed text walks |
| Instagram install prompt | Visible at the bottom of live feed | `display: none`; native navigation remains visible |
| Facebook install prompt | Existing narrow rule only covered one layout and selected routes | Hidden in live feed and regression-tested across routes/filter changes |
| Facebook return from Home | Screen created a fresh session | Same JavaScript page identity and scroll offset of 778 points retained |
| Facebook/YouTube idle timer polling | Every second | One cancellable task for a configured deadline |

This is a measured reduction in filtering work, not a claimed percentage improvement in network speed or FPS. A live Instagram next-feed request took approximately 2.65 seconds. The sites control their pagination and delivery. A tested early IntersectionObserver experiment did not reliably initiate the live request earlier and was removed; no interception of site pagination or media-visibility observers ships.

## Verification

Evidence directory: `Evidence/Performance-audit-2026-11-12/`.

- `Red.xcresult`: new banner and document-commit regressions failed against the old implementation, then passed with the fixes.
- `Performance-baseline.xcresult`: the old engine failed the no-full-feed-walk assertion with 10 walks. The revised engine passed with zero.
- `Walkthrough.xcresult`: all 3 normal-size walkthroughs passed: purchase/sample/restore, free testing access/replay/persistence, and rapid-navigation/resumption. Purchases used local StoreKit only. The tool's five-minute response timed out while Xcode continued; the finalized result bundle confirms all 3 passed.
- `Final-regression.xcresult`: 38 model/StoreKit/WebKit tests passed; compact UI exposed the stale test-preference domain described above. This intermediate result is retained rather than hidden.
- `Final-unit.xcresult`: all 38 model/StoreKit/WebKit tests passed against the final source, with zero failures or skipped tests.
- `Compact-final.xcresult`: the compact Reduce Motion walkthrough passed after the test-reset fix, including repeated Facebook/YouTube launches and their mod controls. Combined with the normal-size walkthroughs, all 4 UI tests passed. Exported compact onboarding and Home screenshots were inspected for layout issues.
- Release simulator build passed with no build warnings or errors; bundled JavaScript resources were verified against source. The final Debug build was installed and launched on the signed-in iPhone 18 Pro simulator (process 15428), preserving existing accounts. Instagram reported a complete document, four articles, and the app-promo container at `display: none`. `Final-Instagram.png` records the final running build.

## Boundaries

The simulator cannot establish the physical feel of haptics. After the simulator audit, the user requested physical installation. The final development-signed build was installed on the test iPhone 15 Plus and launched successfully; a subsequent device process query confirmed process 6332 remained running. Evidence: `device-build.log`, `device-install.json`, `device-launch.json`, and `device-processes.json`. No real-money purchase, deployment, or App Store release was performed. Physical haptic feel has not been assessed remotely. The app owns neither the social sites' network latency nor future markup changes; current recognized install prompts are suppressed persistently, but an absolute guarantee against every future platform redesign would be inaccurate. SwiftUI emitted an Environment<Bool> initialization warning during the normal-size UI tests; those walkthroughs passed. The audit does not establish a measured FPS or energy improvement.

WebKit media suspension uses Apple's supported [setAllMediaPlaybackSuspended API](https://developer.apple.com/documentation/webkit/wkwebview/setallmediaplaybacksuspended(_:completionhandler:)). Document presentation uses the [navigation commit callback](https://developer.apple.com/documentation/webkit/wknavigationdelegate/webview(_:didcommit:)).
