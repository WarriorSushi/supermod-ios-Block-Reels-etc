# Build Supermod for iOS — approved product and implementation brief

You are implementing Supermod in Codex on my Mac. Act as a senior iOS engineer and product designer. Build a real native app, not a website, presentation, or disposable mockup. UI/UX is the highest priority, alongside a trustworthy, functional core.

## 1. Execution agreement and settled decisions

I am unavailable during this work. Xcode is installed. Use the iPhone Simulator; do not wait for a connected iPhone, Apple ID authentication, Instagram credentials, or further design approval. Make reasonable reversible decisions and document them. Complete useful independent work when something is blocked. Do not claim that missing live-account tests passed.

This brief authorizes local implementation and simulator testing, not purchases, production deployments, App Store submissions, account creation, or changes to unrelated projects.

Settled requirements:
- Name: Supermod. Domain: supermod.app.
- Main promise: “Keep social. Lose the distractions.”
- iOS first. Android will be a separate project later.
- Instagram is the only functional integration in this release. Design the adapter boundary for other social platforms, but do not add fake working integrations.
- Instagram is used INSIDE Supermod. No changes to the installed Instagram app; no general-purpose website-modification product or browser extension.
- Native SwiftUI + WKWebView. No PhoneGap, Cordova, React Native, Flutter, or custom backend.
- Ask users to choose their modifications before opening Instagram. Do not silently activate a preset without showing the choices.
- Offer optional stricter settings inside Supermod, not device-wide enforcement.
- Rich, longer onboarding inspired by the supplied SocialLite recording, not a generic three-slide walkthrough.
- Follow the system theme with explicit light/dark overrides.
- Prioritize login, browsing, filtering, and text DMs. Media messaging, posting tools, calls, and notifications are not launch promises.
- One social account initially; design session identity/storage so multiple accounts can be added later.
- Only simple local statistics: foreground time inside Supermod's Instagram experience and current modifications.
- Subscription presentation follows the recording: monthly and annual options after onboarding. No invented trial.
- The icon must be original, premium, memorable, and softly dimensional. NO Dots or OpenAI visual reference.

One answer was ambiguous: the owner selected “D” for shared Reels, but the question only had A–C. Use this REVERSIBLE PROVISIONAL BEHAVIOR: allow one intentionally opened, specifically shared Reel while preventing entry into the endless Reels feed, only when this can be implemented reliably. Otherwise show an honest blocked-state explanation. Do not silently enable unrestricted Reels, and do not report this provisional choice as confirmed.

## 2. Reference and what was actually observed

Primary reference: `screen-recording-of-onboarding-sociallite.MP4`, approximately 3 minutes 51 seconds. If available in this workspace, inspect it. The companion reference images are private design-study material, not production assets. If the video is absent, use the observations below and continue; do not ask me to resend it or assume a ChatGPT sandbox path exists on this Mac.

Observed sequence, with approximate timestamps:
- 00:05–00:17: animated tilted phone, colorful sculptural background accents, short centered headline, black pill CTA.
- 00:18–00:20: single-choice cards and a thin top progress indicator.
- 00:21–00:29: Instagram before/after demonstration with a segmented control and a large phone mockup.
- 00:30–00:41: demonstration of keeping messaging and intentional content while removing distracting browsing.
- 00:42–00:53: YouTube demonstration and other-platform icons. Adapt these to Instagram capabilities; do not advertise unimplemented platforms.
- 00:54–01:23: short personal questions, selection rows, scrolling-hours slider, age wheel, reasons for keeping social media, previous attempts to cut back.
- 01:24–01:47: dramatic transition, animated time-in-weeks grid, large numerical estimate.
- 01:48–02:05: illustrated comparisons and reassurance.
- 02:06–02:46: benefits, comparison table, charts, testimonials and social-proof screens.
- 02:47–03:04: four goal-image cards, hold-to-commit interaction, celebratory finish.
- 03:05–03:28: app-account signup, optional referral, family upsell.
- 03:29–03:51: benefit recap and subscription selection. The captured Indian prices are ₹999/month and ₹2,999/year.

The recording ends at the paywall. It DOES NOT establish the logged-in dashboard, toolbar, mod settings, or real filtering reliability. Those are specified independently below.

Preserve the reference's pacing, phone-led demonstrations, generous whitespace, readable hierarchy, microinteractions, and consistent bottom action. Create original Supermod copy, graphics, and identity. Do not reproduce proprietary assets, celebrity endorsements, testimonials, review counts, user counts, or claimed results. Do not ship the recording, its screenshots, or the account information visible in it.

Omit unrelated family/child onboarding, referrals, and Supermod account signup: they contradict the approved single-user, local-only scope. Replace signup with a truthful “Saved on this device” step. A later Instagram login is separate and still necessary.

## 3. Visual system and icon

Use a restrained editorial interface inspired by the recording, with original Supermod details. Avoid generic SaaS dashboards, excessive cards, neon gradients on every page, heavy glass everywhere, tiny text, and emoji used as finished artwork.

Starting design tokens, centralized and adjustable:
- Light canvas #FAFAF8; primary text #121212; secondary text #696966; subtle surface #F1F1EE; hairline #DEDEDA.
- Dark canvas #101110; primary text #F5F5F0; secondary text #AEAEA8; surface #1C1E1B; hairline #353832.
- Restrained accent #B6E36B. Use it selectively for active details and the brand, not as a substitute for contrast.
- Black primary buttons in light mode; a high-contrast near-white treatment in dark mode.
- System SF typography. Approximately 30–34 pt bold hero titles, 24–28 pt semibold step headings, 16–17 pt body, 13–14 pt secondary labels; scale with Dynamic Type.
- 24 pt horizontal margins on typical iPhones; 8 pt spacing rhythm; 56 pt primary buttons; 44 pt minimum interaction targets; 16–20 pt card corners.
- A circular back control and thin progress track above onboarding content; bottom action anchored with safe-area-aware layout. Content scrolls when needed, but never hide the primary action behind the keyboard or home indicator.

Use purposeful 180–300 ms navigation transitions, brief selection feedback, and restrained haptics. Hero/illustration motion may be longer but must not delay a usable button. Support Reduce Motion, VoiceOver, increased text sizes, and adequate contrast. Respect the user’s theme in native UI; do not crudely invert Instagram with CSS.

Build reusable components: OnboardingScaffold, PrimaryButton, SelectionRow, SegmentedDemoControl, PhoneDemo, GoalCard, ProgressTrack, ModToggleRow, and SubscriptionOption. Avoid duplicating 25 almost-identical full-screen views.

Phone demonstrations should use original synthetic content in a convincing device frame, with smooth masking, consistent perspective, and a small “Preview” label. Animate actual sample interface changes rather than crossfading two unrelated stock images. They must work offline. Do not play the competitor’s video as our onboarding.

ICON: choose one strong original visual direction, then finish it. Aim for a bold sculptural mark suggesting an intentional opening or selective passage, using a distinctive asymmetric silhouette and simple negative space. Soft ivory/pearl against deep charcoal is a suitable starting point. No dotted avatar, OpenAI knot, SocialLite symbol, generic shield, padlock, sliders glyph, or app-name text. Do not turn this into an endless logo-variation exercise.

Produce editable vector/layer sources and valid app-icon assets. Use supported layered-icon tooling when practical with the installed SDK, plus a compatible flattened asset where required. Let the system mask the icon; do not bake in rounded outer corners. Check the silhouette at small sizes and in supported appearance variants. If image-generation tooling is available, use it for original artwork; otherwise make deliberate vector artwork rather than substituting a stock system symbol.

## 4. Onboarding: screen-by-screen implementation

Implement a resumable, data-driven flow of roughly 24–26 purposeful screens/states. It should feel as considered as the reference, without reproducing every marketing claim. Back navigation preserves answers. Progress accurately reflects the chosen path. Only a genuinely required selection disables Continue. Optional questions have a clear skip path. Do not force scrolling through testimonials or an arbitrary waiting period to unlock a button.

1. WELCOME. Original animated phone composition and Supermod mark. Headline: “Keep social. Lose the distractions.” Primary action: “Set up Supermod.” Secondary: “Restore purchase.” No fake account sign-in.
2. MAIN INTENT. Single-choice cards for keeping in touch, staying focused, or using Instagram for work. Store locally and use the answer to personalize later wording. Do not show unsupported family-management choices.
3. INSTAGRAM BEFORE/AFTER. Large interactive phone. “Instagram, with less pulling you away.” Segmented Original/Supermod control. The demo visibly removes the Reels entry point. Let the user try it, but do not require a fixed animation duration.
4. KEEP WHAT MATTERS. Demonstrate messages, profiles, and followed content. Show the shared-Reel concept as an illustration, not a guaranteed working claim.
5. MORE THAN ONE SWITCH. Demonstrate Explore, suggestions, Stories, and identifiable sponsored posts as separate choices. Label ad removal best-effort where appropriate.
6. WHAT STAYS. Compact animated summary of the intended useful features. No carousel of supposedly supported apps that do not work yet.
7. PERSONALIZATION TRANSITION. “Make it fit the way you use Instagram.” Keep this short and reuse the same scaffold.
8. DISCOVERY SOURCE, OPTIONAL. A simple optional selection matching the reference’s interaction. Store only locally; no attribution SDK or analytics event. Skipping cannot affect functionality or price.
9. DAILY SCROLLING ESTIMATE. Slider with a large live value, explicit “Your estimate” label, and accessible adjustments. Allow 0–16 hours/day; start with no asserted personal measurement. No “average user” marker without a source.
10. AGE, OPTIONAL. A local, optional age wheel resembling the reference interaction. Do not request birth date. Use it only to label a planning horizon, e.g. “age 33 to 43,” not to predict life expectancy. Skipping keeps the next screens usable.
11. WHY KEEP INSTAGRAM? Multiple-choice reasons: messaging, friends/family, work/study, interests, habit, or another reason. These personalize the recap; they are not uploaded.
12. WHAT HAVE YOU TRIED? Limits, deleting apps, grayscale/focus modes, another blocker, willpower, nothing yet. Preserve answers without judgmental copy.
13. TIME TRANSITION. “Small moments add up.” Invite the user to see an illustration; avoid diagnostic language or invented research.
14. TIME GRID. Use an efficient Canvas-style illustration of the next 10 years, not a mortality prediction. Animate a clearly labeled portion based on the user’s estimate. If age is supplied, use it only for the horizon labels. Provide a text summary for accessibility.
15. LARGE ESTIMATE. Annual hours = daily estimate × 365; ten-year hours = annual hours × 10. Any percentage must show its denominator. Label all figures as estimates assuming an unchanged habit, not measured use or guaranteed waste. Handle zero and skipped answers cleanly.
16. POSSIBILITIES CAROUSEL. Original calm artwork for reading, rest, movement, and relationships. Use transparent arithmetic only where useful; do not claim hours equal professional qualifications, space travel, or achievements.
17. REASSURANCE. “You don’t have to leave the people you care about.” Explain that controls change the in-Supermod experience, not the original app.
18. HOW THIS IS DIFFERENT. A small factual table: blanket blocking versus selecting features inside Supermod. Describe our intended functionality, not unsupported claims about named competitors.
19. TRUST. Replace borrowed quotes and review cards with concrete statements about local preferences, direct platform login, no Supermod account, and the limits of the product. Do not imply Meta cannot see activity on Instagram.
20. PERSONAL GOAL. Four original image cards: rest, work/study, people, movement. Add a clearly user-selected reduction goal if showing a potential annual time budget. Example formula: estimated daily hours × chosen reduction fraction × 365. Label this a goal, not an efficacy claim or actual saved time.
21. CHOOSE YOUR MODS. Show every supported toggle and an optional preset shortcut. Require an explicit confirmation of the visible settings before first Instagram use. An initial recommendation is allowed, but it must be visible and editable.
22. COMMIT INTERACTION. Premium hold-to-confirm control with subtle progress/haptics and the chosen goal. Include an equivalent normal button/VoiceOver action. No subscription purchase or permissions are triggered by the hold. Use original abstract celebratory artwork, not copied champagne imagery.
23. LOCAL SAVE. “Your setup is ready.” Persist the actual preferences. No fake processing delay or claim of AI-generated personalization. No app-account signup, referral code, or family upsell.
24. BENEFIT RECAP. Clearly show the selected modifications and what remains available. A sample before/after diagram is acceptable if labeled illustrative; no fabricated measured results.
25. PAYWALL. Monthly/annual selection, complete renewal amounts, real StoreKit product data, Restore Purchases, terms/privacy access, and a back action. See the purchase requirements below. Allow a clearly labeled sample preview without a real account; do not present that as unrestricted paid access.
26. READY / CONNECT. After verified entitlement, provide a short privacy explanation and an “Open Instagram” action. Login happens on Instagram’s own page inside the app. Resume this step on a later launch if no social login has happened.

The completed flow is replayable from Settings without erasing session data or repeatedly forcing a paid user through the paywall. No unnecessary app permission prompts during onboarding.

## 5. Main app experience

The interior was not visible in the reference; implement this original, coherent design:
- Home: one excellent Instagram entry card, a compact summary of active modifications, a clearly labeled local usage summary, and a Settings button. No empty grid of unsupported apps.
- Return to the most recent in-app Instagram session where safe. Provide an option to launch Home instead. Do not recreate the WKWebView on every SwiftUI state change.
- In-app social screen: slim native chrome with Home/back, platform identity, and a Mods button. A bottom sheet exposes controls without losing the session or scroll position. Do not place a floating button over messaging controls.
- Mods: Custom, Balanced, and Messages-first presets plus individual controls. Explain what changing a preset changes; retain a reversible custom configuration.
- Settings: theme, launch preference, replay onboarding, local usage/reset, subscription/restore/manage, privacy/terms/help, clear Instagram session, and reset all local data with appropriate confirmation.
- State design: first use, logged out, loading, offline, login challenge, content blocked, filter uncertain, WebKit process recovery, purchase unavailable, and successful setup. No blank panels or endless spinners.
- Keep demo mode separate and visibly labeled. Synthetic messages and accounts must never appear to be real user data.

Optional stricter mode locks the selected modifications inside Supermod for a chosen 15, 30, or 60 minutes. Show the end time and persist it across app restarts. Do not advertise tamper-proof protection, prevent access to privacy/deletion controls, or imply this stops use of the original Instagram app. Handle clock changes reasonably and document limitations.

## 6. Native architecture and filtering engine

Use SwiftUI, Swift, WebKit, StoreKit 2, local Codable/UserDefaults storage, and bundled JavaScript/CSS. Target iOS 17+ unless the installed toolchain imposes a justified constraint. Use the installed stable SDK and available simulator runtime; do not block on unnecessary upgrades. Avoid third-party dependencies unless they solve a concrete problem more simply than native APIs.

Suggested boundaries:
- App / DesignSystem
- Features / Onboarding / Home / Mods / Settings / Paywall
- Social / PlatformAdapter / InstagramAdapter / WebSession / NavigationPolicy
- Filtering / bundled engine.js, instagram.css, versioned rule data
- Persistence / Preferences / UsageStore
- Purchases / EntitlementStore
- Tests / unit / WebKit fixtures / UI
- Resources / original artwork / app icon / StoreKit configuration

Prefer small explicit types and feature-focused files, not a single enormous view or speculative enterprise architecture.

Web session:
- Use WKWebView with persistent WKWebsiteDataStore. Introduce a local session/profile identifier now; expose only one account. Use supported isolated data-store APIs when available and document the fallback.
- Send platform requests directly to the platform. No proxy server, private Instagram API, cookie export service, or scraping backend.
- Never collect passwords, mirror cookies into app preferences, log DMs, extract existing Safari/Keychain sessions, or automate someone’s account login.
- Let Instagram handle passwords, verification, and challenges. Do not bypass CAPTCHA, certificate validation, authentication restrictions, or anti-bot protections.
- Handle new windows and external destinations deliberately. Do not hand off to the installed social app unexpectedly. Unsupported navigation needs a clear native explanation/action, not a crash.
- Keep authentication, checkpoint, consent, and recovery routes free from disruptive filtering. Do not recreate or restyle the login form.

Engine:
- Inject bundled filtering styles/scripts at document start. This reduces unwanted flashes but is not a guarantee that every element is hidden before rendering.
- Separate configuration from engine code. Apply changes without throwing away the session.
- Hide known UI surfaces reversibly using scoped classes/styles. Avoid deleting arbitrary parent containers or scanning every post’s text.
- Match parsed HTTPS hosts and paths, not broad substrings. Match `instagram.com` and approved subdomains correctly; do not accidentally trust lookalike suffixes.
- Use navigation policy for loads/redirects and a tested mechanism for single-page route changes. Understand the difference between isolated and page JavaScript worlds: patching history in an isolated world does not automatically intercept the page’s own router.
- Prefer an isolated content world for the filtering bridge. If a minimal page-world route observer is necessary, keep it unprivileged, narrowly scoped, and treat its messages as untrusted.
- Native message handlers accept only allowlisted, type-checked, size-bounded messages from approved origins/frames. Never expose arbitrary native execution or file access.
- Observe relevant added DOM subtrees; batch work, ignore our own mutations, disconnect cleanly, and avoid continuous whole-document scans or polling loops.
- Implement separate adapters/rules for hiding Reels entry points, Explore, Stories, suggested posts, identifiable sponsored posts, and the home feed. Preserve DMs, profiles, and allowed content where the current platform interface permits it.
- Ad and suggestion filters need strong container/context evidence. Do not remove ordinary messages or posts just because they mention “sponsored,” “suggested,” or “Reels.” Document initial language coverage.
- For a permitted shared Reel, constrain the exception to that exact intentional item/session and prevent endless-next navigation where verifiable. When reliability is insufficient, explain the limitation instead of showing a success badge.
- Unknown layout or failed rules must not blank Instagram or trap the user. Offer scoped filter suspension and a clear warning; do not silently claim successful filtering. Keep strict-mode behavior and the emergency recovery path explicit.
- Implement offline, load-error, and terminated-WebKit-process recovery without an automatic reload loop. Preserve settings; avoid silently discarding an in-progress message where preventable.

Rules ship in the app bundle. No remote executable-code loader, remote configuration service, or auto-updating selectors in this release. Record that platform changes may require an app update.

## 7. Privacy, statistics, and scope discipline

No Supermod account, cloud sync, Supabase, Firebase, analytics SDK, advertising SDK, attribution SDK, crash-upload service, server subscription validation, or push server. The app still needs internet for Instagram and Apple services. “No custom backend” does not mean offline, anonymous to Instagram, or zero distribution costs.

Store local preferences, onboarding progress, and aggregated usage only. Count foreground time only while the social experience is actually active; exclude onboarding, background time, and demo fixtures. Handle interruptions and date boundaries. Do not calculate “actual time saved” from an estimate or count every DOM mutation as a blocked item.

Offer clear deletion controls. Logging must exclude credentials, cookies, messages, private URLs, and personal account information. Prepare an accurate privacy manifest and required-reason API declarations based on actual APIs, not a fabricated compliance template.

Do not promise reliable background DM notifications, complete native-Instagram parity, media uploads, calling, or other unverified features. Android, extra social platforms, family controls, and system-wide Screen Time enforcement are explicitly out of scope.

## 8. Subscriptions without a custom server

Implement StoreKit 2 with locally verified transactions, entitlement updates, cancellation/pending/error states, restore, expiration/revocation handling, and a manage-subscription entry point.

Provide a LOCAL `.storekit` configuration so the simulator can exercise purchases without real payment or waiting for App Store Connect. Wire it into the appropriate debug/test scheme. Use monthly and annual products in one subscription group. For simulator reference pricing, seed the recorded ₹999/month and ₹2,999/year only as PROVISIONAL values; production prices are not approved. Display the actual localized StoreKit product values rather than hardcoded currency text. Document any local-test currency difference.

No invented introductory offer, countdown, discount, free trial, social proof, or renewal statement. Only display offers the user is eligible for and that StoreKit actually supplies. Annual savings may be shown only when calculated from comparable current product prices; make the annual billing total unambiguous.

A DEBUG sample-entitlement path may support UI work, but it must not masquerade as a real purchase or leak into Release. Test purchase/restore with actual StoreKit testing, not only a Boolean mock. If production products are unavailable, show a proper unavailable/retry state, not a fabricated checkout. Keep preview mode clearly labeled.

## 9. Simulator-first workflow and efficient verification

Inspect the workspace and existing instructions first. Preserve user work. Do not treat an earlier prototype ZIP as approved or production-ready. Work in a dedicated local branch where applicable; do not push or overwrite unrelated files.

1. Record a short implementation checklist and the assumptions above. Then implement; do not stop for a new questionnaire or approval loop.
2. Inspect Xcode/toolchain and available simulators using `xcodebuild` and `xcrun simctl`. Use one existing iPhone simulator. Avoid unnecessary runtime downloads or machine-wide changes.
3. Establish a compiling native shell and one minimal WebKit integration early, before polishing 25 screens around an impossible integration.
4. Build the design system, original icon/artwork, full onboarding, and local persistence. Use deterministic bundled fixtures for the demonstration content.
5. Implement the real Instagram WebKit path, filters, preferences, usage, and StoreKit flow. Share the same engine between live mode and test fixtures; never replace live Instagram with a fake clone.
6. Run a focused test suite and one primary simulator walkthrough. Capture screenshots and a short screen recording. Inspect actual rendered screens rather than only the source.
7. Fix concrete failures, rerun affected checks, and deliver the working simulator build with an honest handoff.

Focused checks:
- Unit tests: onboarding persistence/back/skip, preference transitions, projection arithmetic and skipped/zero values, strict-mode expiry, usage accounting, URL host/path decisions, and purchase-state mapping.
- WebKit fixtures: dynamic insertion, reversible hiding, preservation of ordinary posts/DMs/login UI, SPA navigation, and shared-Reel behavior or its explicit fallback. Fixtures passing do NOT establish live-platform reliability.
- One main UI journey: fresh launch → rich onboarding → mod selection → local StoreKit purchase/restore → sample social experience → toggle changes → relaunch persistence → clear-session behavior. Keep social-data deletion separate from preference reset.
- A short visual/accessibility pass in light and dark, plus a compact-screen or large-text configuration. Check clipping, bottom safe areas, keyboard interaction, VoiceOver names, and Reduce Motion.
- One logged-out network smoke check of the real Instagram route, when reachable. No owner credentials, no purchasing a competitor subscription, and no unsupported authentication workarounds.

Do not use screenshot–redesign–rebuild loops with no concrete defect. Do not repeatedly rerun unchanged passing suites. If the same external failure recurs, capture the exact blocker and move to independent work. Still perform the necessary build and security/functional checks; speed is not permission to fabricate verification.

If tool permissions or missing runtimes prevent simulator execution, provide exact commands/errors, finish everything else possible, and say that a simulator run is blocked. Never describe syntax parsing or fixture tests as a successful iPhone build.

## 10. Completion and tomorrow's handoff

Deliver:
- A complete, runnable Xcode project, source, bundled rules, original design assets, icon source, and local StoreKit configuration.
- README with build/run instructions and a clear architecture summary.
- A reference-adaptation note distinguishing observed onboarding from original interior design.
- Simulator screenshots of the principal screens and a walkthrough recording, with demo states labeled.
- Actual build/test commands and results, not “all tests pass” without execution evidence.
- A short manual checklist for tomorrow: real Instagram login/2FA, text DMs, live selectors and shared-Reel behavior, background/relaunch behavior, and physical-device polish.
- A release-blocker list: final pricing/product configuration, public privacy/terms/support details, privacy disclosures, third-party service authorization/terms review, App Store minimum-functionality/copycat concerns, and any unverified platform behavior. Do not invent company/contact details, live legal URLs, or approval guarantees.

Completion means a high-quality simulator-runnable app with the real WebKit integration implemented and a precise account of what was and was not validated. A polished onboarding video alone is not completion. Missing credentials do not justify leaving unrelated features unfinished.

Execute now within the authorized local scope. Keep one coherent design direction, prioritize excellent UI/UX and the functional core, and stop only for a genuine permission boundary or environment blocker—not optional design questions.
