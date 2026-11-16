# Hex keyboard implementation report

All milestones are implemented and have green CI evidence. The QWERTY interface is replaced by the specified 7×4 hex keyboard, including the preset picker stretch goal. Version 0.3.0, build 3 passes phone Debug/light and tablet Release/dark tests, screenshot export, device archive, and unsigned IPA validation. The [final implementation run](https://github.com/SkrOYC/ios-keyboard/actions/runs/43966486861) covers the current application code. No CI blocker remains.

## Milestone evidence

| Milestone | Delivered scope | Verification and CI evidence |
| --- | --- | --- |
| 0 | Untouched branch baseline | [Green baseline](https://github.com/SkrOYC/ios-keyboard/actions/runs/43830067814); duration 15 minutes 55 seconds. Prior successful runs measured 11 to 14 minutes. |
| 1 | Foundation-only geometry, letter orders, symbols, touch state machine, popup model, unit target, independent fixture, and spec parity check | [Green Core milestone](https://github.com/SkrOYC/ios-keyboard/actions/runs/43832299522); 14 logic tests, lifecycle probe, archive, and IPA verification. |
| 2 | Shape-layer renderer, labels, letter taps, clear backgrounds, and working debug strip | [Green renderer milestone](https://github.com/SkrOYC/ios-keyboard/actions/runs/43839204507); portrait reviewed. Complete portrait and landscape evidence is also covered by the final run. |
| 3 | Independent touches, uppercase swipe, space, newline, deletion, repeat travel, and release-position handling | [Green gesture milestone](https://github.com/SkrOYC/ios-keyboard/actions/runs/43846152514); the required coordinate sequence produced exactly `Hi \n`, both orientations were reviewed, and IPA verification passed. |
| 4 | Symbol layer, period popup, conditional globe, and key accessibility actions | [Green layer milestone](https://github.com/SkrOYC/ios-keyboard/actions/runs/43853915882); comma selection and cancellation, 17 Core tests, and 2 UIKit tests. Final popup frames were reviewed in both orientations and appearances. |
| 5 | Familiar, Thumb-split, Keep e·a, extension-owned defaults, invalid-value fallback, and in-keyboard picker | [Green preset milestone](https://github.com/SkrOYC/ios-keyboard/actions/runs/43857290266/attempts/2); all preset selections, 20 unit tests, lifecycle probe, archive, and IPA verification. Both picker orientations were reviewed in final evidence. |
| 6 | Safe-area sizing, centred tablet width cap, landscape glyph sizing, host gesture legend, gap/repeat checks, compact picker cancellation, dark popup contrast, documentation, and 0.3.0/build 3 | [Green final implementation](https://github.com/SkrOYC/ios-keyboard/actions/runs/43966486861); both simulator jobs, all 23 unit tests per configuration, complete UI probes, native frame export, archive, and IPA verification. |

## Validation

Each simulator passed 21 Foundation Core tests, 2 UIKit accessibility tests, and the full Settings-to-typing UI probe. The probe requires swipe up on h, tap i, swipe right, tap q, swipe left, and swipe down to produce exactly `Hi \n`. It then verifies a dead-gap tap, symbol digits, punctuation selection and cancellation, all presets, portrait and landscape input, picker dismissal without text or order changes, and repeated deletion. Unit tests cover overlapping contacts, a popup alongside another contact, all popup choices, conditional globe actions, hold cancellation, defaults persistence, and responsive layout.

The independent geometry fixture compares every key centre and polygon against Core. Its generator checks canvas bounds, equal apothems, mirror symmetry, and neighbour distances before horizontal stretching. The Linux check also compares Swift presets, symbols, popup characters, swipe distance, hold delay, and repeat distance with the prototype. All nine Python tests, workflow checks, shell checks, configuration checks, and fixture checks pass.

The unsigned IPA passes arm64, host/extension structure, matching version, iOS minimum, signing-state, extension-safety, and prohibited-content checks. The downloaded 0.3.0/build 3 package also passes `ipa-check`; its checksum matches the artifact checksum. Existing configuration and IPA assertions remain intact and have been extended. `devenv.lock` is unchanged. No tag or release was created.

## Inspected screenshots and Liquid Glass

The final implementation evidence contains full-screen phone portrait and landscape screenshots, symbols, both picker orientations, and active punctuation popups. The tablet probe provides the same states in dark appearance, including the fifth globe entry. Both orientations of the corrected dark popup were inspected: the opaque adaptive backing prevents underlying letters from showing through its labels. The phone popup remains visually consistent in light appearance.

Original CI artifacts are cached under ignored `build/simulator-cache/popup-contrast`. Named review copies are kept under `build/simulator-cache/review`; earlier evidence remains available for comparison. All saved keyboard images come from CI simulators. Video-derived landscape frames retain the recording's orientation; full-screen XCTest attachments provide upright landscape views. No external reference screenshots or generated replacement images are included.

Clear view backgrounds and the original adaptive Glass key fills preserve the system keyboard backdrop. Individual hexes and preset buttons draw custom fills. Native `UIGlassEffect` refraction and interaction are not implemented on those controls.

## Resolved failures

The [recovery notes](CI_RECOVERY.md) retain the recording measurements and recovery details. The missing simulator destination was consistent with a CoreSimulator readiness race; its internal cause was not proven. Readiness refreshes and separate simulator jobs passed the final runs.

The first video clock used recorder launch time, which can precede the movie's creation clock. One failed request was 455.280 seconds into a 433.550-second movie. The corrected parser uses the movie header and validates every offset; the native exporter independently validates asset duration. Both orientations now decode to visibly active popups. A driver warning in the earlier failure is not treated as proof of a decoder outage.

The [first recovery run](https://github.com/SkrOYC/ios-keyboard/actions/runs/43950697188) passed the phone probe and tablet Release compilation, then failed to discover the tablet's hex keys. The [menu-selection probe](https://github.com/SkrOYC/ios-keyboard/actions/runs/43959142526) also failed before key discovery while both unit suites passed. Fixed-coordinate globe cycling passed the [complete recovery run](https://github.com/SkrOYC/ios-keyboard/actions/runs/43962591187). A native preview alone did not establish an extension crash. Failure-only launch-log and crash-report collection is available; the final successful runs did not exercise that failure path.

Earlier resolved issues included the system keyboard introduction covering switching, accessibility elements missing their explicit enabled flag, premature text assertions across processes, cropped app-only landscape screenshots, and stale debug-label instances. Strict text, image, archive, and IPA gates remain enabled.

## Device checks and open questions

No physical-device typing or installation is verified. The remaining checks are:

- Swipe thresholds and the 420-millisecond hold under natural typing speed.
- Two-thumb overlap, palm contact, and simultaneous UIKit touch delivery; the independent state machine is unit tested.
- Landscape reach, flattened key shape, popup target size, and the 700-point tablet width cap.
- VoiceOver navigation and custom-action usability, including keyboard handoff through the globe.
- Preset persistence across extension termination on a device.
- Reduce Transparency, Increase Contrast, Reduce Motion, and larger accessibility text settings.
- Signing, provisioning, and installation of the unsigned package.

There are no remaining implementation blockers. These checks concern device behavior and accessibility preferences beyond the simulator evidence. Dedicated shift, space, return, and delete keys, correction, prediction, emoji input, and haptics remain outside scope.

## Decision register

The complete register is also maintained in [Decisions](DECISIONS.md).

- D01: Use filled hexagons and their round strokes for hit-testing because visible gaps must insert nothing.
- D02: Track every touch independently because two thumbs need separate gesture state, popup state, and hold timers.
- D03: Snapshot the input layer and letter order at touch-down because another touch must not change the starting character.
- D04: Keep layer toggling shared because both thumbs use one displayed keyboard layer.
- D05: Process the final release position before inferring a hold because a movement callback can be absent.
- D06: Cancel holds after 10 design units of movement because small finger jitter needs tolerance.
- D07: Keep holds at 420 milliseconds because elapsed time is independent of display width.
- D08: Scale spatial thresholds with width because the 70-unit gesture distance belongs to the reference design space.
- D09: Repeat deletion from the first firing position because the prototype measures further leftward travel from that point.
- D10: Cancel contacts on resize, picker opening, and keyboard handoff because their coordinates or input destination become stale.
- D11: Cancel contacts when switch-key availability changes because an open popup must not retain a stale globe entry.
- D12: Use full-precision Double geometry because rendering and tests need the same formula results.
- D13: Measure neighbour distances before horizontal stretching because the reference formulas stretch only x coordinates.
- D14: Use proportional 14-unit canvas margins because responsive footprints must remain continuous with the reference layout.
- D15: Use portrait key height width × 883 / 1320, about 261 points at 390 points wide, because this preserves the reference scale.
- D16: Place the 22-point debug strip outside the key area because diagnostics must not compress the reference geometry.
- D17: Use a 180-point compact key area and a 320-point height cap because the host needs editing space.
- D18: Cap tablet key width at 700 points and centre it because full-width tablet keys become difficult to reach.
- D19: Use the available phone width because landscape typing needs horizontal space.
- D20: Preserve transparent backgrounds and the original Glass fills because the system supplies the Liquid Glass platter.
- D21: Use the system typeface and bound glyph size by key height because flattened landscape hexes need legible labels.
- D22: Use neutral preset names and the three specified orders because selectable layouts must remain covered by spec parity checks.
- D23: Store only the raw preset key in the extension defaults because an App Group is prohibited.
- D24: Fall back to Familiar for missing or invalid preferences because input must remain usable after malformed stored data.
- D25: Keep the symbol layer unchanged during preset selection because the preference controls letters only.
- D26: Replace keys temporarily with an in-keyboard picker because preset selection must not overlap active letter input.
- D27: Use a horizontal picker row in compact height and 44-point controls because both orientations need usable tap targets.
- D28: Expose one keyboard-key accessibility element per key because drawn shapes need explicit accessible identities.
- D29: Keep the mode and period identifiers stable and name symbol keys by their displayed characters because automation must locate both layers.
- D30: Provide delete, space, return, capitalization, punctuation, and conditional switching actions because VoiceOver must not require directional swipes.
- D31: Expose order selection as a custom action because the picker must be reachable without a hold.
- D32: Keep diagnostics outside screen reader navigation because typing controls need a focused navigation order.
- D33: Track debug labels weakly across controller instances because the visible strip must receive action updates.
- D34: Log action names without character values because diagnostics must not retain typed content.
- D35: Put the host test field before setup instructions because typed text must remain visible with the keyboard open.
- D36: Test UIKit accessibility separately from Foundation logic because rendering must not introduce UIKit into Core.
- D37: Use an independent Python geometry fixture because shared implementation code would hide formula drift.
- D38: Dismiss the observed system keyboard introduction in UI probes because its Continue overlay blocks input-mode switching.
- D39: Wait for hittable keys and landscape bounds because keyboard hosting passes through transient layouts.
- D40: Use fixed screen coordinates for taps and drags because accessibility-frame queries can change during a held gesture.
- D41: Wait for exact proxy text changes because the extension and host exchange input across processes.
- D42: Capture the full screen because app-only landscape screenshots were cropped.
- D43: Export transient frames from simulator video because build-log and live still-capture timing missed active holds.
- D44: Use Xcode AVFoundation APIs for frame export because they require no extra package or lock change.
- D45: Probe phone Debug in light appearance and tablet Release in dark appearance because both configurations and Glass fill variants need evidence.
- D46: Remove detailed touch traces because the shipped keyboard needs only bounded action and memory diagnostics.
- D47: Cache original evidence and named review copies under ignored build/simulator-cache because screenshots must remain easy to inspect without entering Git.
- D48: Preserve the prototype script and remove personal attribution from its prose because spec parity and anonymous public text are both required.
- D49: Use the host-wide Git identity because the content PII rule does not change author configuration.
- D50: Require native decoding and visual review for clock changes because valid offset arithmetic alone cannot prove popup content.
- D51: Refresh CoreSimulator at each Xcode boundary because an earlier successful boot does not prove later destination discovery is ready.
- D52: Anchor frame requests to the movie creation clock because recorder startup can lag behind process launch.
- D53: Reject invalid frame offsets before decoding because clamping can produce unrelated visual evidence.
- D54: Treat a driver warning as diagnostic context because successful earlier decodes contradict a confirmed decoder outage.
- D55: Preserve strict test and visual gates because recovery must not turn missing evidence into a successful check.
- D56: Compile the evidence exporter before UI probes because Swift or SDK errors should fail before simulator interaction.
- D57: Export test attachments before propagating evidence failures because successful test results must remain inspectable.
- D58: Isolate phone and tablet in required matrix jobs because each probe needs its own simulator and 45-minute budget.
- D59: Cycle the system globe with fixed coordinates because native iPad accessibility hit points can be invalid.
- D60: Collect extension launch logs and crash reports on UI failure because a native keyboard preview cannot identify the cause.
- D61: Check Done in the landscape picker because dismissing preferences must preserve text and letter order.
- D62: Back popup hexes with an opaque adaptive color because underlying letters showed through the dark translucent fills.
- D63: Treat reverse-engineering notes as background because the bundled HTML defines this keyboard's geometry and gestures.
- D64: Give each probe a distinct evidence artifact because parallel uploads require unique artifact names.
