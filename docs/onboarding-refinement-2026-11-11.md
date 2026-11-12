# Latest onboarding refinement — 11 November 2026

This document supersedes the visual details in the earlier onboarding/RC handoffs. It does not supersede their external release blockers. No production purchase or App Store release was made.

## Requested work retained

- Consistent cream, gentle blush/peach and black palette, with black enamel primary buttons and paywall controls. The approved icon and mascot remain unchanged.
- The same transparent mascot is used by LaunchScreen and the first SwiftUI launch overlay. Actual iPhone launch-cache behavior still needs observation after reconnecting.
- Welcome uses a locally bundled, muted luxury reel of a woman in an ornate hotel. Phone entrance, framing shapes and floating label animate independently; the mascot stays clear of the profile button. Reduce Motion uses a still, and playback pauses while inactive.
- Original → Supermod is demonstrated on the first Continue, before leaving the screen. Enlarged bottom navigation and a red Reels spotlight make the change visible. The connection scene automatically shows feed, inbox, keyboard and profile.
- The switches scene keeps a stable friend post, a separate labeled ad with “UP TO 30% OFF,” and a separate suggestion. The switches mean “Turn off”; enabling them removes only their matching content. Continue demonstrates ad removal automatically.
- Attention scene uses animated dots with one headline and one subtitle. Removed redundant trust/marketing screens; preserved persisted step identifiers.
- Life weeks fill sequentially with haptic ticks. The red finale starts at the scrolling band, bubbles as one connected mass and covers the complete viewport. Reduce Motion skips the movement.
- Hold to commit takes 1.7 seconds. Black grows continuously from the button during the hold; early release retreats. Completion keeps the full black state through the transition. Haptic intensity increases in stages.
- Interactive daily minutes show arithmetic time regained over a year, explicitly an illustration rather than a promised outcome.
- Three simple research scenes explain wellbeing, sleep and attention, with source sheets and study limits. No claimed lifespan extension or guaranteed Supermod health effect.
- Pre-purchase explanation explicitly says the websites run inside Supermod; the original Instagram/YouTube apps are unchanged.
- Native mascot paywall uses soft colors, localized full prices and mathematically derived annual savings. No invented discount deadline, testimonial or free trial. The RevenueCat dashboard draft is separate and has not been published by this refinement.
- Larger sample preview, compact caption and reachable controls remain in place.
- Debug “Continue without paying” remains available and persists after relaunch without creating a transaction. Release ignores that development flag.

## Research

BMC Medicine (2025), DOI https://doi.org/10.1186/s12916-025-03944-z, Table 2: https://link.springer.com/article/10.1186/s12916-025-03944-z/tables/2.

111 students; reducing smartphone time to no more than two hours daily for three weeks. WHO-5 values are multiplied by four for the displayed 0–100 scale: intervention 56.60 → 64.44; usual-use 57.84 → 58.32. Insomnia Severity Index 8.84 → 7.23 versus 9.31 → 9.82; lower is better. These are group means, not personalized forecasts. Only 24 intervention participants strictly adhered; follow-up phone use rose again. Details are available in the source sheet.

PNAS Nexus (2025), DOI https://doi.org/10.1093/pnasnexus/pgaf017. The attention scene describes two weeks blocking all mobile internet, explicitly distinct from Supermod's selected filters. 119 of 467 participants met the stated compliance threshold. It does not claim Supermod reproduces these results.

## Welcome media provenance

User selected use of their Reel Factory collection. Source: `<LOCAL_HOME>/coding/reels factory/filthyrich.space/Project files/Source clips/Intro Vibes - CLIPS (149).mp4`. Derived excerpt starts at 0.3 seconds, lasts 7.5 seconds, 540×960 H.264, silent, approximately 1.3 MB. Original is untouched. Bundled at `Supermod/Resources/welcome-luxury.mp4`; still at `WelcomeReelPoster.imageset`. This records source provenance, not independent rights clearance.

## Verification and handoff

- `Liquid-Welcome-QA.xcresult`: full fresh onboarding, local StoreKit purchase, restore, sample keyboard/profile/modifications, relaunch — passed.
- `Liquid-Compact-QA.xcresult`: complete compact-screen Reduce Motion flow — passed.
- `Liquid-Free-Access-QA.xcresult`: no-payment entry, zero transactions, relaunch and replay isolation — passed.
- Visual inspection caught and corrected a cropped reel overlay, and a timeline-driven liquid shape that stalled before its final fill. The latter now uses SwiftUI's animatable presentation values; final motion verification is recorded below when complete.
- Previous `Final-Research-Hold.xcresult` and `Final-Research-Compact.xcresult` cover the research/hold changes; `Research-Final-QA.xcresult` includes ten passing model tests.
- Latest screenshots: `Evidence/Onboarding-refinement/Screenshots/` and `Compact/`. Earlier evidence directories include superseded visuals.

The iPhone was disconnected at the user's request. Build/install and physical haptics are separate checks. The earlier working version was installed and launched before departure; subsequent changes need installing when the phone returns. Local StoreKit success does not prove Apple's sandbox transactions or RevenueCat purchase ingestion. Apple account/tax/address completion and real sandbox purchase/restore remain external follow-up items.

### Final acceptance

`Final-Onboarding-Acceptance.xcresult` passed the complete onboarding/purchase/restore/sample/relaunch test after the liquid-clock and joined-surface fixes. `Final-Compact-Acceptance.xcresult` passed the final compact Reduce Motion flow. `Final-iPhone-Ready.log` reports a successful development-signed device build; `codesign --verify --deep --strict` passed. Ready app: `.build/rc-device/Build/Products/Debug-iphoneos/Supermod.app`.

Frame-by-frame review confirms: the liquid expands continuously from the scrolling band with joined, rounded crests, reaches all safe-area corners before the percentage appears, and has no internal holes. Hold capture confirms progressive growth while held, retreat on the intentionally interrupted hold, and a fully black completed state through transition. Welcome capture confirms the muted reel plays and loops in the correctly framed phone. Haptic strength must still be judged on the physical phone.

`Liquid-Final-QA.xcresult` is an intermediate failed run caused by a temporary simulator preference seed interfering with the reset fixture. That seed was removed; the subsequent `Liquid-Final-Clean-QA.xcresult` and final acceptance runs passed. No live-account simulator or phone data was changed by these clean-fixture checks.

Preview files: `Evidence/Onboarding-refinement/Motion-preview.mp4` (26-second highlights), `Welcome-reel.mp4`, and `Full-onboarding.mp4` (automated walkthrough, including intentional hold cancellation and local StoreKit tests). Final screenshots are in `Screenshots/` and `Compact/`. The temporary source archive contains app/project/tests/docs only; private Apple keys are excluded.
