# Supermod release candidate implementation plan

Goal: polish the existing SwiftUI + WKWebView app, prioritize the supplied onboarding reference, fix reproducible defects, and preserve real sessions.

Architecture: retain local preferences, StoreKit verification and per-service WebKit stores. Rework onboarding composition and motion in its existing views. No new backend, production transactions, submission, or replacement of the approved icon.

User authorization: the supplied release-candidate handoff plus “Go ahead, do it all” directs autonomous implementation and verification without another design approval.

- [x] Back up source and run current tests on separate iPhone 17e (17 passed).
- [x] Inspect full 230.94-second reference sequence, then extract short welcome/commit motion clips and timestamped motion frames.
- [x] Onboarding: enlarge device demonstrations, simplify stage/background, reduce heading scale, stabilize footer, center interludes, implement full-screen hold feedback, honor Reduce Motion and Dynamic Type, guard rapid navigation. Verify short/interrupted holds and resume/replay.
- [x] Web lifecycle: regression tests for stale async document callbacks and reset filter pauses for all services. Preserve independent stores, login, navigation and ordinary playback.
- [x] Inspect all interior screens and current release metadata. Fix concrete local defects and record external blockers with fresh sources.
- [x] Full tests, release build, light/dark/large-type layouts, live reversible service checks on preserved iPhone 18 Pro session.
- [x] Development build, fresh onboarding recording, screenshots and current handoff. The user subsequently reconnected the iPhone: current development install/launch and rendered plans screen were verified; complete VoiceOver/device acceptance remains explicit.

Review focus: fast repeated next/back taps; disappearing or backgrounded hold gestures; old page JS callbacks after navigation/clear; filter restoration after suspend; subscription revocation and test isolation.

Source baseline is Evidence/RC-2026-11-11/source-before.tgz because this directory has no Git repository. Compare changed sources against that archive for review.
