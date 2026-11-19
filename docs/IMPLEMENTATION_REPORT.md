# Keyboard implementation report

## Scope and CI evidence

The keyboard implements uniform-scale unified/split layout, mirrored halves with duplicated column 3, opaque popup plates, period punctuation, 123 swipe-up caps/presets, hold trackpad, machine-owned caps lock, and persisted DEVTOOLS tuning. See [Design](DESIGN.md) for behaviour and parameter metadata and [Decisions](DECISIONS.md) for rationale. Letter orders use assumed model constants without user testing; they are not validated ergonomic recommendations.

**Current change CI:** [Run 44616449530](https://github.com/SkrOYC/ios-keyboard/actions/runs/44616449530) passed phone, phone-dark, and tablet. Phone-contrast failed at the pre-feature keyboard-selection wait for `key-q` or the native globe, the same predicate that failed in [master's tablet control](https://github.com/SkrOYC/ios-keyboard/actions/runs/44599682230) on the same runner image. This does not establish that the phone-contrast failure is a baseline issue.

**Next run: PENDING — record the four build-job results and run URL after this documentation push.**

The [material baseline run](https://github.com/SkrOYC/ios-keyboard/actions/runs/44016204422) establishes the preceding native-glass baseline, not verification of the split/gesture changes. The workflow retains four independent required jobs: phone light, phone dark, phone Increase Contrast (Debug), and tablet dark (Release). Each runs source gates, compilation, 33 Foundation tests, 8 UIKit tests, and one full Settings-to-typing UI probe: 42 tests per job. The phone-light job also archives the device app and validates the unsigned IPA. No tag or release is part of this change.

## Local verification

Local simulator commands used a command-local `XCODE_VERSION=26.6` override and a local Xcode installation alias; the repository pin remains 26.4.1. No CI checks were disabled or replaced by local results.

| Check | Result | Evidence under ignored build/ |
| --- | --- | --- |
| `direnv exec . check` | 9 Python tests passed; source configuration, shell/workflow gates, independent geometry fixture, and spec parity passed | `stage3-check.log` |
| Debug host + extension build | `BUILD SUCCEEDED` | `stage2-build.log` |
| Debug logic + UIKit suites | 33 Core + 7 UIKit, zero failures; `TEST SUCCEEDED` | `stage2-tests-final.log`, `stage2-tests-final.xcresult` |
| Minimum-scale picker regression and UIKit suite | 8 UIKit tests, zero failures; `TEST SUCCEEDED`; Done remains in bounds and hit-testable across split scales and resize | `stage4-picker-tests-final.log`, `stage4-picker-tests-final.xcresult` |
| `direnv exec . env XCODE_VERSION=26.6 IOS_PROBE_APPEARANCE=light IOS_PROBE_CONTRAST=disabled ios-test` | 1 UI + 33 Core + 7 UIKit, zero failures; `TEST EXECUTE SUCCEEDED` | `stage3-phone.log`, `SmokeTests.xcresult` |
| `direnv exec . env XCODE_VERSION=26.6 ios-ipad-test` | Release/dark iPad, split layout; 1 UI + 33 Core + 7 UIKit, zero failures; `TEST EXECUTE SUCCEEDED` | `stage3-tablet.log`, `TabletTests.xcresult` |

The full UI probe retains the exact `Hi \n` gesture sequence, symbols, all presets, picker dismissal, gap taps, orientation changes, and repeated deletion. Added probes verify comma and farther question-mark selection, release-at-origin cancellation, caps on/off and all capital labels, capital insertion, swipe-up presets with Done preserving text and order, stationary trackpad hold, horizontal cursor movement followed by insertion, and a pasted `👩‍💻` ZWJ grapheme crossed without splitting. Landscape checks require left primary column-3 keys and right-half keys on the expected sides, an inert centre gap, and matching insertion from both copies of column 3. Tablet runs the same checks in split layout.

Core tests cover tuning validation/storage, forced/width-selected layouts, uniform scale, mirror symmetry, duplicated slots, inset alignment, height/overlap clamps, popup rows/clamping/cancel slop, caps state, independent contacts, and grapheme-to-UTF-16 movement including emoji/ZWJ/flags. UIKit tests cover one accessible element per slot, caps and editing actions, touch passthrough after unified/split resize, opaque popup selection outlines, and tuning controls. The independent Python fixture checks split placements as well as reference geometry. Strict parity includes presets, symbols, popup punctuation, tuning's shared swipe/hold defaults, and delete repeat.

## Visual and workflow evidence

Local full-screen captures of phone portrait unified, phone landscape split, and the period plate were reviewed: `build/stage2-portrait-unified.png`, `build/stage2-landscape-split.png`, and `build/stage2-period-popup.png`. The full phone and tablet runs exported all six popup frames each, at 4/6/8 seconds for portrait and landscape, using unchanged `HEX_POPUP_PORTRAIT` and `HEX_POPUP_LANDSCAPE` markers. Reviewed samples show the opaque plate and split halves, including the dark iPad popup.

- `build/SmokeTests-popup-{portrait,landscape}-{4,6,8}s.png`
- `build/TabletTests-popup-{portrait,landscape}-{4,6,8}s.png`
- `build/screenshots/SmokeTests/` and `build/screenshots/TabletTests/` contain exported attachments, including emoji cursor evidence.
- CI artifact names remain `lifecycle-evidence`, `lifecycle-evidence-phone-dark`, `lifecycle-evidence-phone-contrast`, and `lifecycle-evidence-tablet`; the package artifact is `KeyboardHost-ipa`.

Video-derived landscape frames retain the recording's orientation; full-screen XCTest attachments provide upright landscape views. All keyboard images are native simulator captures; no third-party artwork or replacement renderings are used. Simulator memory samples do not establish physical peak footprint or typing latency.

Keys use native Liquid Glass; the popup is deliberately opaque. Press feedback uses system tint, a visible SDR lift with an optional HDR contribution in dark appearance, darkening in light appearance, and compression respecting Reduce Motion. The system owns Clear/Tinted treatment. **HDR cannot be verified from CI screenshots.** The Tinted glass probe was not added because the simulator cannot set it through simctl; a reliable Settings automation path was not established. This does not claim that the system lacks a Tinted setting.

## Resolved probe issues

Settings can retain its navigation location and an already-installed extension; the probe returns to the settings root and identifies the installed keyboard by bundle identifier. A near-diagonal landscape presets gesture selected space instead of the upward popup; a clearly upward path with inward travel selects the presets cell. These fixes add no retries or weaker text assertions. The emoji fixture uses the paste menu and handles the system paste-permission alert, without changing the shipping host or keyboard.

The existing [CI recovery notes](CI_RECOVERY.md) document simulator readiness, switcher coordinates, movie-clock validation, and failure evidence collection. Strict source, text, capture, archive, and IPA checks remain enabled. The extension requests no Full Access, App Group, or network access and does not log typed characters.

## Device-only checks

The following remain unverified on physical hardware:

- swipe and hold feel at the new scales
- delete swipe near the outer edge of a split half
- two-thumb overlap
- trackpad sensitivity
- HDR highlight and its fallback
- whether the system hands a third-party keyboard a floating or split frame on iPad
- preset persistence after the extension is terminated

Reduce Transparency, Reduce Motion appearance, VoiceOver interaction, signing/provisioning, and physical-device performance also require device review. Defaults and cursor logic tests do not establish extension-termination persistence or every host application's context behaviour. Native simulator split frames do not establish how iPad's system floating/split keyboard controls frame a third-party extension.
