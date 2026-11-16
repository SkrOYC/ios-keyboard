# Hex keyboard decisions

These decisions define the implementation and its verification. Final tablet and transient-image validation remains blocked; see [Implementation report](IMPLEMENTATION_REPORT.md).

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
- D49: Use the host-wide Git identity because the content PII rule does not change author configuration.
- D50: Defer publishing the movie-clock correction because its locally tested timing still needs macOS frame verification.

## Recovery decisions prepared locally

The [recovery investigation](CI_RECOVERY.md) distinguishes local preparation from macOS validation.

- D51: Refresh CoreSimulator at each Xcode boundary because an earlier successful boot does not prove later destination discovery is ready.
- D52: Anchor frame requests to the movie creation clock because recorder startup can lag behind process launch.
- D53: Reject invalid frame offsets before decoding because clamping can produce unrelated visual evidence.
- D54: Treat a driver warning as diagnostic context because successful earlier decodes contradict a confirmed decoder outage.
- D55: Preserve strict test and visual gates because recovery must not turn missing evidence into a successful check.

- D56: Compile the evidence exporter before UI probes because Swift or SDK errors should fail before simulator interaction.
- D57: Export test attachments before propagating evidence failures because successful test results must remain inspectable.
