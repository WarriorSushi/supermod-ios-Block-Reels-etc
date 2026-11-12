# Instagram feed jumping — 12 November 2026

The user reported flashing, blank frames, and posts jumping while scrolling Instagram on the unlocked iPhone 15 Plus. Device Hub showed the signed-in feed and a blank feed frame before the update. Remote swipe control later failed with `noWindowsAvailable`, so physical scrolling acceptance remains with the user.

## Confirmed layout defect

`instagram.css` conditionally replaced the virtual feed's inline bottom padding with `64px !important` whenever a rendered child was a hidden article or follow-suggestions row. Instagram owns that padding to represent posts outside its rendered window. Inserting/removing a filtered row switched the override on/off, changing document height and clamping the scroll offset. The previous pagination test explicitly required the override and did not test scroll stability.

Removed only this spacer override. Existing content filters, suggested-row pagination targets, and comment exceptions remain. The pagination fixture now scrolls its observed tail into view and asserts that the site's spacer remains intact.

## Verification

- Added `testFilteredRowsDoNotReplaceVirtualFeedSpacersOrClampScroll`: scroll to 3,000 points in a virtual feed, repeatedly insert/remove a filtered ad, and require the scroll offset and the site's 8,000-point spacer to remain unchanged.
- The regression failed against the original CSS, including failure to retain the scroll position after removing the recycled row: `Evidence/Instagram-scroll-2026-11-12/Red.xcresult`.
- All 39 model, StoreKit, and WebKit tests passed after the change, with zero failures/skips: `Green.xcresult` in the same directory.
- Development-signed device build succeeded. Bundled `instagram.css` matched source exactly.
- Installed on the test iPhone 15 Plus, preserving its app data, and relaunched successfully (PID 6723). Device Hub showed the signed-in Instagram feed after the update. Build/install/launch/process evidence is in the same evidence directory.

This proves the spacer-induced scroll clamp is corrected. It does not establish that every live feed flash or network-loading gap is resolved; repeated physical scrolling confirmation is pending. No production release was made.

## Follow-up: user still observed flashing/jumping

The user confirmed that the first update did not resolve the live symptom. Do not treat that build as accepted.

A temporary, explicitly launched DEBUG recorder sampled only geometry (scroll offset, document height, anonymous row IDs, row heights and filter state). `phone-before.json` contains 1,200 samples across approximately 132 seconds. It captured initial posts becoming hidden after rendering: a 652-point ad became zero height; two suggested posts of roughly 449 and 690 points became one-point targets. No user scrolling occurred in that recording (`scrollY` remained zero), so this is initial-layout evidence, not a captured reproduction of the user's scroll gesture. The temporary recorder source is preserved as `DiagnosticWebSession.swift` in Evidence and has been removed from the shipping source; `WebSession.swift` again matches the pre-investigation version.

The Instagram mutation observer deferred filtering with a 16 ms timer. Added a visible-window WebKit test that inserts mobile suggested-post markup and checks visibility at the next animation frame. It failed against that timer (one visible frame in eight insertions), then passed after moving the coalesced work to `queueMicrotask`, within the before-rendering mutation checkpoint. This avoids painting a newly inserted filtered post at full height before collapsing it. The initial version of the test lacked a visible host window and stalled; `Paint-red.xcresult` was interrupted. The meaningful red/green evidence is `Paint-red-visible.xcresult` and `Paint-green.xcresult`.

All 40 model/StoreKit/WebKit tests passed with zero skips/failures. The final development-signed device build succeeded; bundled engine matched source; the update was installed and launched on the physical iPhone. `final-device-build.log`, `final-device-install.json`, and `final-device-launch.json` record this second update. Device Hub showed the signed-in Instagram feed. The updated simulator accepted repeated native swipes and loaded additional posts; frame samples are in `simulator-after.json`. Physical user acceptance of the second update remains pending.

The simulator capture contains 2,353 frame samples, scroll offsets from 0 to 1,042 points, and 14 distinct rendered posts. No sampled post transitioned from visibly rendered to filtered/hidden. This supports the insertion-flash fix within that run, without proving all feed-loading or virtualization behavior is resolved.

The user subsequently answered the earlier diagnostic prompt with “Done—scrolled and saw the issue.” A fresh download (`phone-latest-reply.json`) still contains the same 1,200 samples, all at scroll offset zero; the bounded recording therefore did not capture that gesture. Because this reply targets the diagnostic prompt sent before the second update, confirmation was requested about whether the symptom persists after the latest restart. Do not interpret this delayed reply as acceptance or as a verified failure of the second update without that clarification.
