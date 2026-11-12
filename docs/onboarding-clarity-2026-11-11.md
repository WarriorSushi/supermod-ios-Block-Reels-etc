# Six-screen clarity revision — 11 November 2026

Implements feedback on the six supplied phone screenshots. This supersedes the earlier research-chart and goal/filter-screen descriptions.

| Screen | Current message and interaction |
| --- | --- |
| Time back | “Get time back.” A large dial shows minutes less per day. The slider changes a rounded annual-hours total. The daily assumption stays visible. Removed the unlabeled bar chart and extra explanatory text. |
| Well-being | “Less phone time. Better days.” A large face changes from neutral to smiling. One sentence identifies this as a study result; the three-week period stays visible. |
| Sleep | “Less phone time. Better sleep.” A large moon settles into a dark circle as stars appear. Removed the confusing sleep-score numbers from the main screen. |
| Focus | “Less noise. More focus.” Distraction icons move away, blurred words become clear, and a frame draws around “One thing.” The main screen says the study used two weeks with phone internet off. |
| Goals | “More time for what?” Four larger photo cards: Sleep, Focus, Friends, Move. Any combination can be selected; tapping a selected card removes it. At least one is required to continue. Selection survives relaunch. |
| Filters | “Choose what to hide.” New onboarding starts with all six switches off, meaning everything is visible. Each switch turns on hiding for its named feature. The phone is larger; preset picker and explanatory paragraphs are removed. Main labels are Reels, Explore, Stories, For you, Ads, Feed. Accessibility labels retain the precise feature names. |

The last action is now “Save my picks.” The commitment screen lists all selected goals. Existing saved filters are preserved; replay edits its draft rather than changing the installed configuration. The all-off starting point applies to fresh onboarding without an existing draft.

## Research and accessibility

“See the study” opens the existing source sheet. Exact group means, scales, sample sizes, compliance limitations, source links and the distinction from Supermod remain there. Faces, moon and focus imagery are illustrations, not graphs or promised outcomes. No new clinical or lifespan claim was added. Main copy uses short words and sentences.

The visuals animate once on arrival. Reduce Motion shows the final state immediately. Content remains scrollable with fixed navigation actions; large text uses a vertical filter layout. Goal cards announce selected state; the time dial has a spoken value; filter toggles retain native accessibility semantics.

## State compatibility

`Setup.goals` is an optional set. Old `goal` values are read as a one-item selection when the set is absent. An explicitly empty set does not resurrect the legacy selection. Writes keep a deterministic legacy goal for compatibility. `ModSettings.allVisible` is a separate onboarding draft; global defaults and saved settings are not reset.

## Verification

- `Clear-Screens-QA.xcresult`: 12 model tests plus the full onboarding/local purchase/restore/sample/relaunch UI test passed. Includes legacy-goal decoding, multi-goal persistence, all-off filter defaults and independent toggles.
- `Clear-Compact-QA.xcresult`: small-screen Reduce Motion flow passed.
- `Clear-Free-Entry-QA.xcresult`: no-payment entry, zero transactions, persistence and replay isolation passed.
- Final copy/label cleanup and screenshots: see final acceptance addendum below.

No real charges. No change to Apple account configuration or the published app. The iPhone build is prepared separately from installation and physical haptic review.

### Final acceptance

`Clear-Final-QA.xcresult` passed the final full purchase/restore walkthrough, including multi-selection and the all-off default assertions. `Clear-Final-Compact-QA.xcresult` passed on iPhone SE 3 with Reduce Motion. Final screenshots were reviewed after the larger label/short-copy cleanup; “For you” fits without breaking words. The focus screenshot is taken after its blur-to-clear transition finishes. `19-Filters-off.png` records the untouched filter defaults; `19-Modifications.png` records independent Reels and Ads selections.

`Clear-Final-iPhone.log` reports a successful signed device build, and strict code-signature verification passed. Ready app: `.build/rc-device/Build/Products/Debug-iphoneos/Supermod.app`. Not installed during this revision.

Current review media: `Evidence/Onboarding-clarity/Six-screen-preview.mp4` (18 seconds), `Screenshots/`, `Compact/`. Earlier evidence directories are historical. The preview preserves the actual animation speed; the deliberate relaunch test is omitted from the highlights.
