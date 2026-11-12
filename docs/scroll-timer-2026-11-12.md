# Home scroll timer — 12 November 2026

Replaced the ambiguous “A short Reels break” control with a Home Scroll timer. Choose one or more features, choose 1–60 minutes, then Start. Supported choices are Reels & Shorts (all three services), Stories (Instagram/Facebook), Explore and Home feed (Instagram). Availability is stated beside each choice. Onboarding now points explicitly to Home to start the real timer.

The Home card shows remaining time. A small circular countdown drains around the floating controls while browsing; opening those controls shows the numeric countdown and a direct Scroll timer entry. The timer sheet offers End now & hide. Expiry persists the selected features as hidden; a new timer can temporarily allow them again. Wall-clock deadlines survive backgrounding and relaunch. Legacy Reels-only saved timers still decode.

“Focus lock” is now “Lock my filters,” accessible on Home and Instagram controls. Its sheet explains the duration, that it prevents filter changes and new timers, and that it does not lock the phone. Starting a lock ends any running timer and hides its selected features. The lock is respected by all three in-app services.

## Verification

- 46 model/StoreKit/WebKit regression tests passed. This includes the suggested/sponsored feed stability tests from the preceding fix.
- The expanded WebKit expiry test passed for Instagram Reels, Stories and Explore; Facebook Reels and Stories; YouTube Shorts. It verifies an open route becomes blocked and recovery returns to the service entry point.
- Two UI tests passed: Home selection, disabled empty selection, custom duration, starting, relaunch persistence, ending early, restarting, locking; and a real one-minute deadline with the timer sheet open.
- The initial UI run failed because the test used the wrong Stepper accessibility identifier. Updated the test locator; both UI flows then passed.
- Visually reviewed Home, choices and lock explanation screenshots; automated tests captured active and expired states. Checked the small ring draining over the signed-in Instagram feed in the iPhone 18 Pro simulator; it disappeared automatically at expiry.
- Final simulator build passed after copy/accessibility refinements; signed device build passed including the singular “1 minute” copy fix.
- Installed on the test iPhone 15 Plus (<DEVICE_ID>), launched successfully, and confirmed running process 7277. Existing phone data was retained. No timed session or filter lock was started on the physical phone during installation.

Evidence: `Evidence/Scroll-timer-2026-11-12/`. Physical-phone timer gesture/expiry acceptance remains unobserved; the end-to-end countdown checks were on Simulator.
