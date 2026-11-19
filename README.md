# Hex keyboard

A SwiftUI host app and a UIKit keyboard extension for iOS and iPadOS 26. The extension replaces QWERTY with a flat-top honeycomb containing 26 letters, a symbols key, and a period key. It requests no Full Access and uses no network or App Group.

The keyboard supports width-selected split layout, opaque popup grids, caps lock, cursor movement, and persisted runtime tuning. See the [design](docs/DESIGN.md) and [implementation report](docs/IMPLEMENTATION_REPORT.md) for behaviour, verification evidence, and device validation boundaries.

## Type with gestures

The keyboard uses the following controls:

- Tap a letter to insert it. Taps in visible gaps insert nothing.
- Swipe up on a letter to insert its uppercase form.
- Swipe right for a space and down for a newline.
- Swipe left to delete. Continue leftward to repeat deletion.
- Tap **123** for numbers and symbols, then **abc** for letters.
- Hold the period key, slide to **,**, **?**, **!**, or **'**, then release. A globe entry appears when keyboard switching is required.
- Swipe up on **123** and release for caps lock; move inward to the presets cell to choose **Familiar**, **Thumb-split**, or **Keep e·a**. The extension stores the selected preset in its own defaults. Done preserves text and order.
- Hold **123**, then drag horizontally to move the cursor by graphemes without splitting emoji. A stationary hold does nothing.
- Caps lock capitalizes letter labels and taps, leaves symbols unchanged, and resets when the keyboard disappears.

Each key has an accessibility element and custom editing actions. The period key also exposes punctuation and conditional keyboard switching. The host includes a test field, a gesture legend, and installation instructions.

## Layout and logic

The [design](docs/DESIGN.md) specifies current behaviour. The [Hex 7×4 prototype](docs/spec/hex7x4.html) is authoritative only for shared values enforced by the parity check. The letter orders come from a model with assumed constants and no user testing; they are not validated ergonomic rankings. Keep e·a is `wqzueaxyoijgtcvfrhmdnsbkpl`. `Keyboard/Core` contains Foundation-only, Double-based geometry, labels, gesture state, popup choices, layout policy, and preference storage. `HexKeyboardView` owns independent touches and accessible keys. `HexGlassRendererView` renders native materials and the UIKit labels without intercepting input. `KeyboardViewController` applies actions through the text document proxy.

Keys use the 1320×883 design aspect with one uniform scale, clamped to a tunable 320-point height budget. Auto layout splits at 600 points of available width after safe insets. Mirrored halves duplicate column 3 with identical slot behaviour, leaving an inert transparent gap. Split scale uses the shorter screen side capped at 430 points, multiplied by 0.75 on phone or 1.0 on tablet. A DEVTOOLS tuning strip sits outside the key area. Read the [decision register](docs/DECISIONS.md) for the geometry, interaction, accessibility, and verification choices.

Keys use native iOS 26 Liquid Glass over clear backgrounds. SwiftUI's [`glassEffect(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)) follows each rounded hex footprint inside a shared glass container. Separate silhouettes preserve visible gaps. Pressed keys gain a brightness lift in dark appearance (HDR when available, with a visible SDR fallback), darkening in light appearance, system tint accents, and slight compression; custom motion respects Reduce Motion. Popup choices use an opaque adaptive rectangular plate with a stem; selection adds tint, outline, and scaling. Covered base letters are hidden. Preset buttons and Done use native glass configurations.

Local light-phone and dark-tablet probes cover both orientations, split input, popups, caps lock, presets, and emoji-safe cursor movement. The CI matrix also covers dark phone and Increase Contrast. Tinted glass and physical HDR appearance are not verified; see the implementation report for device-only checks.

## Development environment

Use the pinned [devenv](https://devenv.sh/getting-started/) environment through [direnv](https://direnv.net/). Repository tools are declared in `devenv.nix`; `devenv.lock` pins their inputs. Xcode 26.4.1 supplies the Apple SDK on macOS.

Enable the environment and run the checks:

```sh
direnv allow
direnv exec . check
```

`project.yml` is the source of truth. XcodeGen generates the ignored Xcode project. Linux checks configuration, shell syntax, workflow syntax, IPA validation fixtures, geometry invariants, and parity with the prototype constants. Swift compilation and simulator tests require macOS.

## Build and verify

The [GitHub workflow](.github/workflows/build.yml) runs four required jobs on `macos-26`, each with a 45-minute timeout. Each generates the project, boots an SDK-matching simulator, compiles, enables the extension through Settings, and runs tests. The standard phone job also archives the device app and verifies the unsigned IPA.

The phone probes use Debug in light, dark, and light with Increase Contrast. The tablet probe builds Release in dark appearance. Each runs 33 Core tests, 8 UIKit tests, and one complete UI probe (42 tests). The UIKit suite checks accessible actions, duplicate accessibility suppression, tuning controls, touch passthrough after unified/split resizing, and picker bounds at minimum split scale. The UI probe uses coordinate taps and drags and requires the exact `Hi \n` sequence before layer, popup, caps lock, preset, picker cancellation, gap, rotation, split-copy, and repeat checks. A paste-based emoji check verifies trackpad insertion without splitting a ZWJ grapheme.

On macOS with the declared Xcode installation, run the stages with these commands:

```sh
direnv exec . ios-test
direnv exec . ios-project
direnv exec . ios-ipad-test
direnv exec . ios-build
```

`ios-ipad-test` requires `ios-project` and can run independently of the phone probe. `ios-build` archives and packages the device app. Validate a downloaded package with this command:

```sh
direnv exec . ipa-check build/KeyboardHost.ipa
```

The `KeyboardHost-ipa` artifact contains the verified package and checksum. Evidence artifacts contain logs, result bundles, full-screen screenshots, simulator recordings, popup frames, and appearance readbacks:

| Probe | Artifact |
| --- | --- |
| iPhone light | `lifecycle-evidence` |
| iPhone dark | `lifecycle-evidence-phone-dark` |
| iPhone Increase Contrast | `lifecycle-evidence-phone-contrast` |
| Tablet Release/dark | `lifecycle-evidence-tablet` |

Artifacts expire after seven days. Download each with `direnv exec . gh run download RUN_ID --name ARTIFACT_NAME --dir build/simulator-cache/CACHE_NAME`, replacing the uppercase placeholders with the run, artifact, and cache names. Original material-refresh evidence is cached under `build/simulator-cache/glass-complete`; named review images and source mappings are under `build/simulator-cache/review/glass-complete`. Keep these directories ignored. The [CI recovery notes](docs/CI_RECOVERY.md) explain frame timing and failure diagnostics.

## Enable the extension

After installing a signed package, enable the keyboard with these steps:

1. Open **Keyboard Host**.
2. Open **Settings > General > Keyboard > Keyboards > Add New Keyboard**.
3. Choose **Keyboard Host**.
4. Return to the host test field and use the system globe to select the extension.
5. Try the gesture legend and both orientations.

The CI package is unsigned. Signing, provisioning, and physical installation are separate from simulator verification. Device communication tools are included in the environment; `direnv exec . phone-check` probes pairing. Keep credentials and device identifiers outside this public repository.

## Diagnostics and scope

`Keyboard/DebugLog.swift` compiles only with `DEVTOOLS`, enabled for Debug and sideload Release. Its strip cycles tuning parameters, adjusts with −/+, resets tuning, and shows the latest action and memory footprint. Changes persist in extension-owned defaults and apply immediately. Diagnostics record action names rather than character values; there is no `DebugLog.enabled` switch. See [parameter defaults and ranges](docs/DESIGN.md#runtime-tuning). Simulator footprint snapshots do not establish device peak memory or typing latency.

Dedicated shift, space, return, and delete keys, correction, prediction, emoji input, and haptics are outside this keyboard's scope. Physical swipe thresholds, two-thumb overlap, landscape feel, and VoiceOver interaction need device validation. The [Implementation report](docs/IMPLEMENTATION_REPORT.md) distinguishes implemented behavior from verified behavior.

## License

MIT. See [LICENSE](LICENSE).
