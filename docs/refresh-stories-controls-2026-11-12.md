# Refresh, running timer choices and floating controls

## Changes

- Added a native pull-to-refresh control to supported Home feeds. It reloads the page while preserving the browsing screen rather than displaying the full loading overlay. It is disabled off Home and refuses refresh while a text field or dialog is open. Completion, failure, timeout and web-process termination end the spinner.
- The running Scroll timer sheet now keeps all feature choices visible, including Stories. Users can change choices without extending the original deadline. Removed choices become hidden immediately; selected choices hide at expiry. Empty selections and changes while filters are locked are rejected.
- The floating control is circular, with a 40-point visible button, a 52-point touch area and a 46-point countdown ring. It moves horizontally and vertically, snaps to the nearest edge and remembers its position. Its menu opens toward the screen interior. Accessibility actions also allow moving it without dragging; reduced motion and transparency preferences are respected.

“Hide Home feed” remains an optional way to use Instagram without its post stream while keeping messaging and profiles. No usage analytics were available to establish demand. This pass does not remove or move that setting.

## Verification

Evidence: `Evidence/Refresh-stories-controls-2026-11-12/`.

- Two regressions failed before implementation: absent native refresh control and missing Stories choice while a timer was running (`Red.xcresult`).
- Three targeted checks passed, then the final regression passed all 54 tests with zero failures or skips (`Regression.xcresult`). Coverage includes timer deadline preservation, Stories selection persistence, a real one-minute expiry, open-dialog refresh protection and existing suggested/sponsored feed stability and pagination checks.
- On the signed-in iPhone 18 Pro simulator, a native downward pull loaded a new document (`pull-gesture-check.json`). The circular button was dragged to the left edge, moved vertically and used to open its menu. Screenshots record the timer choices, button, menu and refreshed feed.
- Signed Debug device build succeeded. Installed and launched on the test iPhone 15 Plus; process 7441 confirmed running. Existing app data was retained. Physical-phone gesture acceptance was not observed; gesture verification was on Simulator.
- The scoped simulator inspection helper was stopped after verification. No temporary physical-device diagnostics were added.
