# Reference onboarding and no-charge iPhone testing

Goal: implement the user's supplied Socialite video as the behavioral and visual reference, repair missing device plans, and provide temporary payment-free app access.
Architecture: SwiftUI native screens and a full-resolution 390×844 sample renderer, scaled uniformly into a proportional phone; StoreKit 2 verified entitlements remain separate from Debug-only tester access.
Spec: user request and `<LOCAL_HOME>/Downloads/ScreenRecording_11-11-2026 01-51-50_1.MP4` (230.94 seconds). Source rollback: `Evidence/Onboarding-rebuild-2026-11-11/source-before.tgz`.
Execution authorized directly by “Go ahead” and “Make it right. Fix it.” No additional design gate. Work remains in this workspace without Git.

## Reference map
- 04–17s: dimensional rotating phone, large open stage, short two-line headline, fixed black CTA.
- 18–20s: choice rows, circular Back, narrow progress track.
- 21–28s: Instagram comparison, selected capsule slides, first primary action changes Original to filtered in place; second advances.
- 29–40s: automatically playing connection/messaging demonstration. No user interaction needed to see it.
- 41–46s: YouTube comparison, same two-stage primary action.
- 47–51s: service icons enter successively.
- 52–55s: plain centered personal-question interlude, distinct from device demonstration.
- 56–58s: discovery rows with service icons.
- 59–67s: 4.8 hours default, 1–8+ range, fixed red average marker and label; changing numeric value.
- 68–73s: centered age wheel.
- 74–82s: reasons and attempts rows.
- 83–88s: warning text enters line by line.
- 89–100s: life in weeks: entire grid, lived region, asleep region, scrolling region; red squares expand into a red percentage screen.
- 101–106s: clock, large minutes, tilted red years badge.
- 107–112s: automatically rotating illustrated time equivalents with page dots.
- 113–118s: individual versus a crowd, explanation underneath.
- 119–123s: quote cards; do not substitute false Supermod endorsements.
- 124–130s: brand/hope interlude.
- 131–139s: comparison table rows enter in sequence.
- 140–151s: chart/endorsements; retain visual explanation but no unsupported efficacy numbers.
- 152–163s: review wall; do not invent Supermod reviews.
- 164–169s: four photo goal cards, selected-state indicator.
- 170–179s: hold from bottom circular button, black radial expansion, reversed text.
- 180–182s: completion reveal.
- 183–206s: account/referral; Supermod stores setup locally, so use honest local-save composition.
- 207–218s: illustrated benefit recap.
- 219–227s: small phone above subscription rows, purchase CTA pinned below.

## Work
- [ ] StoreKit: inspect App Store Connect, create matching app/products if absent, verify sandbox on physical iPhone; fix device local restore; add explicit Debug tester access (no fabricated entitlement); test purchase/restore/refund separately.
- [x] PhoneDemo: photographic avatars, distinct feed/ad/profile/inbox/conversation/keyboard content, accurate device proportions, real visible ad removal, enlarged compact sample sheet.
- [x] OnboardingFlow: first Continue demonstrates comparison; automatic connection tour; distinct artwork for every interlude; reference slider; lifetime grid and transitions; automatic equivalents; visual table/privacy/modifications/recap.
- [ ] Verification: model and StoreKit regressions; full Continue-only walkthrough, interrupted/back/resumed demonstrations, ad restoration, bypass persistence and release exclusion; screenshots on standard/small simulators, physical device install and no-charge purchase evidence.

## Review focus
- Back or backgrounding cancels pending demonstration navigation.
- Replaying must not change saved filter preferences.
- Tester access survives a development-app relaunch but never becomes an Apple entitlement or survives into Release.
- Ages and large hour estimates cannot produce negative/overlapping life-grid regions; all future estimates explicitly state assumptions.
- Phone content scales uniformly; large text and small devices keep the primary action reachable.

## Latest direction and outcome

The user's later instruction replaces literal Socialite parity with a distinct, evidence-based Supermod story. Five redundant steps are removed from the active journey while persisted identifiers remain compatible. See `docs/onboarding-evidence-and-rationale-2026-11-11.md`.

Local StoreKit purchase/restore/refund/grace, temporary access, replay isolation, Release access exclusion, and small-screen Reduce Motion checks passed. Build 2 is development-signed for the iPhone. See the latest handoff for exact runs and the corrected intermediate replay failure.

Apple app and both draft subscription products exist. Apple paid agreement/legal-entity setup, a sandbox tester, RevenueCat signup/project/key, and physical iPhone installation/purchase verification remain pending user access. No production charge, publication, contract acceptance, or credential creation occurred.
