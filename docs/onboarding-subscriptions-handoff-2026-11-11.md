# Supermod build 2 — onboarding and subscriptions

## Ready locally

Signed development app: `.build/device-ready/Build/Products/Debug-iphoneos/Supermod.app`.
Bundle `app.supermod.ios`; build `2`; team `<APPLE_TEAM_ID>`; application identifier verified as `<APPLE_TEAM_ID>.app.supermod.ios`; development entitlement `get-task-allow=true`.

The user reconnected the iPhone; the RevenueCat-enabled build was installed and launched successfully without resetting app data. Actual Apple sandbox purchases and physical visual acceptance remain unverified.

### Product changes

- Proportional phone hardware and detailed Instagram-style sample feed, photo avatars, inbox, conversation, keyboard, profiles and YouTube previews. Fictional sample content; photo source inventory in `Design/preview-photo-sources.json`.
- Continue performs Original → Supermod before leaving the comparison. Automatic connection tour shows all four panels. The sponsored coffee ad visibly disappears/restores; Continue demonstrates its removal.
- Larger sample screen and a pinned editing button, compact caption. Onboarding filter switches sit beside the live phone preview.
- Life grid culminates in 24 stretching/bouncing liquid drops that merge into a rising pool across the whole screen, then reveal the percentage. The fill completes before Continue can advance. Reduce Motion avoids bouncing, and the render loop stops after settling.
- Launch storyboard and first SwiftUI frame both use the existing transparent mascot, centered at 144 points on the same cream background. Removed the square asset reference from launch configuration. Build number advanced to 2; actual iPhone launch-cache behavior still needs observation after installation.
- 21 active onboarding screens, preserving all persisted enum IDs. Removed five repetitive screens, added two sourced research cards, made the time-equivalent illustration a hypothetical 30-minute daily reduction, and replaced the competitor table with an actual hide/keep feature table.
- Clear pre-purchase screen: use the social websites **inside Supermod**; installed Instagram, Facebook and YouTube apps stay unchanged. Repeated on paywall, including compact layout.
- Native subscription page with localized StoreKit prices, annual/monthly choices, renewal notice, Restore, Terms, Privacy, and offline preview. No fabricated trial, savings, review count or testimonial.
- Temporary development access remains separate from verified Apple entitlement. **Continue without paying** works without a transaction and survives relaunch. Settings can disable it; Release ignores the flag.
- RevenueCat 5.102.3 added in StoreKit 2 observer mode. Apple credentials show **Valid credentials** in RevenueCat; Apple and Test Store products share the saved entitlement/offering, and the public SDK key is included in the installed build. Physical-device SDK configuration, offerings and CustomerInfo network responses are verified. Apple still returned no StoreKit products; sandbox transactions remain blocked. No private key is embedded. Verified StoreKit continues to decide app access.

## Verification evidence

Folder: `Evidence/Onboarding-rebuild-2026-11-11/`.

| Evidence | Result |
|---|---|
| `Final-tests.xcresult` | 26 model/StoreKit/WebKit tests and rapid-navigation/resume UI check passed. Initial replay test failed because an offscreen switch tap reached the fixed footer; this was fixed, not suppressed. Four live/recording opt-in tests skipped. |
| `Acceptance2-tests.xcresult` | Both complete UI tests passed: no-purchase entry + persistence + draft replay isolation, and local StoreKit purchase + sample + restore + relaunch. |
| `Final-purchase.xcresult` | Final build-2 walkthrough, local purchase/restore/relaunch, sample keyboard/profile and sample modifications passed after the final layout/copy edits. |
| `Small2-tests.xcresult` | iPhone SE 3 full flow with a Debug Reduce Motion override and real local StoreKit product metadata passed. Verified price rows, terms, restore, no-payment entry and the unchanged-original-app notice are visible. This is software behavior testing, not physical accessibility acceptance. |
| `Release-guard2.xcresult` | Release-only entitlement guard passed: a preexisting development-access flag and a setter call cannot unlock access. `ENABLE_TESTABILITY=YES` enabled test imports; Release had no DEBUG condition. |
| `Logs/device-ready2.log` | Development-signed generic iPhone build succeeded; no device connection required. |

An earlier Release test invocation could not import a non-testable optimized module; rerun with test imports enabled passed. An intermediate Debug build caught the system Reduce Motion environment value being read-only; corrected with a Debug-only test override that leaves real Release accessibility behavior intact.

Final reviewed screenshots: `Final-proof/`, plus compact screenshots in `Small2-screenshots/`.
Videos: `Red-blob-animation.mp4` (focused fill), `Onboarding-preview.mp4` (simulator test walkthrough, including an intentional interrupted-hold check), and full source capture `Final-capture.mp4`.

## External work still pending

See `docs/subscriptions-setup-2026-11-11.md` for sanitized configuration, schemes and follow-up steps.

1. The user submitted the legal-entity address and personally accepted the Paid Apps Agreement. Apple shows **Pending User Info**, requesting banking and U.S. tax information. Products still returned empty immediately after acceptance.
2. An India sandbox tester was created by the user and verified in Apple. The user confirmed device sandbox sign-in.
3. RevenueCat configuration is saved and the SDK key is built into the app. Physical SDK network connectivity is verified. Actual sandbox purchase events remain unverified because Apple returned no products.
4. On the connected iPhone, verify launch and no-payment entry. Then use `Supermod Sandbox` for Apple product loading, purchase, restore and expiry. Never use a production checkout for this task.

No real charge, App Store submission or production release was performed. The user personally accepted the Paid Apps Agreement. The Apple purchase key was generated and uploaded only after explicit user approval; its private Drive backup was confirmed by metadata.
