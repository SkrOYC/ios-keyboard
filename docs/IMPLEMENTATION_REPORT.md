# Hex keyboard implementation report

The QWERTY interface is replaced by the hex keyboard. Milestones 0 through 5 have green CI evidence. Milestone 6 is implemented and passes the phone probe and 23 unit tests, but final validation is blocked. Work stopped after the final failures were initially classified as two infrastructure failures. A follow-up investigation found invalid frame offsets in the second failure; it is not a confirmed decoder outage. The source declares version 0.3.0, build 3; that version has no verified device IPA.

## Milestone evidence

The following table separates completed checks from the remaining gates.

| Milestone | Implemented scope | Verification | CI evidence |
| --- | --- | --- | --- |
| 0 | Untouched branch baseline | Green; duration 15 minutes 55 seconds. Prior successful runs measured 11 to 14 minutes. | [Baseline run](https://github.com/SkrOYC/ios-keyboard/actions/runs/43830067814) |
| 1 | Foundation geometry, orders, symbols, gesture state, popup model, unit target, independent fixture, and parity check | Green; 14 logic tests, lifecycle probe, archive, and IPA validation. | [Core run](https://github.com/SkrOYC/ios-keyboard/actions/runs/43832299522) |
| 2 | Shape-layer hex renderer, key labels, letter taps, clear backgrounds, and debug strip | Green; portrait inspected. Complete landscape capture was verified in milestone 3. | [Renderer run](https://github.com/SkrOYC/ios-keyboard/actions/runs/43839204507) |
| 3 | Independent touches, uppercase swipe, space, return, deletion, repeats, and final-position handling | Green; exact coordinate sequence produced `Hi \n`, 15 logic tests passed, both orientation images inspected, and IPA validated. | [Gesture run](https://github.com/SkrOYC/ios-keyboard/actions/runs/43846152514) |
| 4 | Symbols, period hold, conditional globe, and accessibility actions | Green; symbols, comma selection, cancellation, 17 Core tests, and 2 UIKit tests. Landscape popup inspected. Portrait popup image remains unverified. | [Layer and accessibility run](https://github.com/SkrOYC/ios-keyboard/actions/runs/43853915882) |
| 5 | Three presets, extension defaults, invalid-value fallback, and in-keyboard picker | Green; all preset selections, 20 unit tests, lifecycle probe, archive, and IPA validation. Portrait picker inspected; compact picker image remains unverified. | [Preset run, attempt 2](https://github.com/SkrOYC/ios-keyboard/actions/runs/43857290266/attempts/2) |
| 6 | Safe-area layout policy, tablet cap, landscape glyph sizing, host legend, gap/repeat probes, stronger guards, Release tablet stage, video frames, and 0.3.0/build 3 | Partial: phone probe and 23 unit tests passed in both attempts. Tablet Release, dark appearance, final archive/IPA, and complete transient-image review remain blocked. | [Final run, attempt 1](https://github.com/SkrOYC/ios-keyboard/actions/runs/43863882102/attempts/1), [attempt 2](https://github.com/SkrOYC/ios-keyboard/actions/runs/43863882102/attempts/2) |

## Blocking failures and resolved findings

The final run first lost all concrete Xcode simulator destinations before tablet Release compilation. Its retry passed the phone tests, then frame export failed after writing three PNGs. The next requested offset was 455.280 seconds in a 433.550-second movie. Although the log also contains a paravirtual scaler warning, that warning does not establish a decoder outage. No CI retry has been launched for the follow-up investigation. [CI recovery investigation](CI_RECOVERY.md) records the evidence, local remediation, and bounded recovery plan.

Earlier resolved failures are preserved in the evidence:

- [Initial renderer probe](https://github.com/SkrOYC/ios-keyboard/actions/runs/43835319624): a system keyboard introduction covered input-mode switching. The probe dismisses its Continue overlay. Custom key elements also explicitly enable accessibility.
- [Initial coordinate probe](https://github.com/SkrOYC/ios-keyboard/actions/runs/43842910308): the field remained empty. Readiness checks, intermediate captures, and diagnostics were added; the following run proved normal begin, move, and end delivery. The initial cause was not conclusively isolated.
- [Initial punctuation probe](https://github.com/SkrOYC/ios-keyboard/actions/runs/43850022243): the immediate comma assertion failed. Fixed screen coordinates and exact-value polling passed the following run. All 19 unit tests passed in the failed attempt.
- [Preset attempt 1](https://github.com/SkrOYC/ios-keyboard/actions/runs/43857290266/attempts/1): Xcode lost its simulator destination after compilation. The unchanged retry passed.

On-demand popup captures were late despite correct functional results. Video export avoids capturing during a synthetic hold, but its first clock anchor used process launch time. The actual recording creation time can be later. A local version-zero movie-header correction aligns requests to each recording's creation clock and validates its duration. It passes regression tests and puts all requests within both cached recordings. The Swift exporter also has a local duration guard, and the Xcode stages have a local simulator readiness refresh. These recovery changes are pending macOS CI validation. The native evidence tool is compiled before UI probes, and its failure does not suppress result-bundle attachment export. The original saved patch remains under `build/movie-clock-correction.patch`.

## Inspected visual evidence

Downloaded CI evidence is cached under the ignored `build/simulator-cache` directory. Images are copied from CI artifacts; no generated replacement images are used.

The inspected evidence includes complete phone portrait and landscape grids, the symbol layer, the portrait preset picker, the landscape punctuation popup, and the host gesture guide. The landscape app-only capture was cropped; full-screen captures corrected that issue. The debug strip shows action names after its label tracking was changed to weakly cover controller instances.

Portrait popup frames selected with the launch-time clock missed the active hold. Tablet/dark images and the compact picker have not been inspected. Those views must not be treated as visually verified.

## Validation boundaries

The Linux `check` command passes configuration, workflow, shell, verifier, fixture, and spec-parity checks. Existing configuration and IPA assertions remain intact. Added guards enforce Foundation-only Core imports, extension-safe APIs, release metadata, runner settings, and excluded network, haptic, and correction APIs. The IPA verifier additionally rejects test tooling, malformed versions, and network exceptions. `devenv.lock` is unchanged.

The final phone probe passed the required uppercase/tap/space/tap/delete/return sequence, symbol input, popup selection and cancellation, all presets, rotation, a dead-gap tap, and repeated deletion. Its 23 unit tests comprise 21 Core tests and 2 UIKit accessibility tests. The final archive and device IPA stages were skipped after the infrastructure failures. The last fully verified IPA belongs to the preset milestone, before the version bump.

The geometry fixture checks every centre and six-vertex polygon, canvas bounds, equal apothems, centre mirror symmetry, and neighbour distances. Distance and apothem invariants remove the intentional horizontal stretch before measurement.

## Real-device gaps and open questions

The following behavior remains untested on a physical device:

- Swipe distance, 420-millisecond hold delay, and 10-unit movement allowance during natural thumb motion.
- Overlapping two-thumb contacts, cancellation timing, and repeated deletion under real input sampling.
- Landscape comfort, tablet reach, floating or split-window layouts, and preset preference after extension termination.
- VoiceOver interaction, conditional globe handoff, and accessibility sizing preferences.
- Signing, provisioning, installation, and operation of the unsigned package on a device.

Open validation work is to verify the simulator readiness mitigation and corrected frame export, verify tablet Release/dark behavior, inspect portrait popup and compact picker images, and complete the 0.3.0/build 3 archive and IPA checks. Ergonomic tuning and comparative preset performance require real typing evidence.

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
- D47: Cache simulator evidence under ignored build/simulator-cache because inspection files must remain available without entering Git.
- D48: Preserve the prototype script and remove personal attribution from its prose because spec parity and anonymous public text are both required.
- D49: Use neutral commit metadata because the change history must not publish personal identifiers.
- D50: Defer publishing the movie-clock correction because its locally tested timing still needs macOS frame verification.

## Recovery decisions prepared locally

The recovery patch adds the following decisions without changing keyboard behavior:

- D51: Refresh CoreSimulator at each Xcode boundary because an earlier successful boot does not prove later destination discovery is ready.
- D52: Anchor frame requests to the movie creation clock because recorder startup can lag behind process launch.
- D53: Reject invalid frame offsets before decoding because clamping can produce unrelated visual evidence.
- D54: Treat a driver warning as diagnostic context because successful earlier decodes contradict a confirmed decoder outage.
- D55: Preserve strict test and visual gates because recovery must not turn missing evidence into a successful check.

- D56: Compile the evidence exporter before UI probes because Swift or SDK errors should fail before simulator interaction.
- D57: Export test attachments before propagating evidence failures because successful test results must remain inspectable.
