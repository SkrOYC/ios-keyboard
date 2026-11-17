# Hex keyboard

A SwiftUI host app and a UIKit keyboard extension for iOS and iPadOS 26. The extension replaces QWERTY with a flat-top honeycomb containing 26 letters, a symbols key, and a period key. It requests no Full Access and uses no network or App Group.

Version 0.3.0, build 3 passes iPhone light, dark, and Increase Contrast probes, the tablet Release probe, screenshot export, device archive, and unsigned IPA validation. See the [green verification run](https://github.com/SkrOYC/ios-keyboard/actions/runs/44016204422) and [implementation report](docs/IMPLEMENTATION_REPORT.md) for milestone evidence and device validation boundaries.

## Type with gestures

The keyboard uses the following controls:

- Tap a letter to insert it. Taps in visible gaps insert nothing.
- Swipe up on a letter to insert its uppercase form.
- Swipe right for a space and down for a newline.
- Swipe left to delete. Continue leftward to repeat deletion.
- Tap **123** for numbers and symbols, then **abc** for letters.
- Hold the period key, slide to **,**, **?**, **!**, or **'**, then release. A globe entry appears when keyboard switching is required.
- Hold **123** to choose **Familiar**, **Thumb-split**, or **Keep e·a**. The extension stores the selected preset in its own defaults.

Each key has an accessibility element and custom editing actions. The period key also exposes punctuation and conditional keyboard switching. The host includes a test field, a gesture legend, and installation instructions.

## Layout and logic

The authoritative prototype is [Hex 7×4](docs/spec/hex7x4.html). The Familiar letter arrangement draws inspiration from the legacy Typewise (WRIO) layout; the prototype defines this extension's geometry and gestures. `Keyboard/Core` contains Foundation-only, Double-based geometry, labels, gesture state, popup choices, layout policy, and preference storage. `HexKeyboardView` owns independent touches and accessible keys. `HexGlassRendererView` renders native materials and the UIKit labels without intercepting input. `KeyboardViewController` applies actions through the text document proxy.

Portrait keys use a 1320×883 design space, producing a key area about 261 points tall at 390 points wide. A separate debug strip shows action names and memory use. Compact layouts use a 180-point key area; tablet width is capped at 700 points and centred. Read the [decision register](docs/DECISIONS.md) for the geometry, interaction, accessibility, and verification choices.

All 28 keys and punctuation choices use native iOS 26 Liquid Glass over clear backgrounds. SwiftUI's [`glassEffect(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)) follows each rounded hex footprint inside a shared glass container. Separate silhouettes preserve the visible gaps. Pressed keys gain a blue tint and slight compression; custom motion is disabled under Reduce Motion. Covered base letters are hidden while punctuation is open. Preset buttons and Done use native glass configurations.

The material refresh focuses on iPhone portrait and landscape. Light, dark, and Increase Contrast layouts, popups, and pickers have been visually inspected in both orientations. The existing tablet layout remains a regression baseline; a dedicated tablet layout is deferred. Reduce Transparency, Reduce Motion, and physical-device performance still need review.

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

The phone probes use Debug in light, dark, and light with Increase Contrast. The tablet probe builds Release in dark appearance. Each passes 21 Core tests, 3 UIKit tests, and the complete UI probe. The UIKit suite checks accessible actions and that glass surfaces leave touches with the keyboard after resizing. The UI probe uses coordinate taps and drags and requires the exact `Hi \n` sequence before layer, popup, preset, picker cancellation, gap, rotation, and repeat checks.

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

`Keyboard/DebugLog.swift` displays the latest action and memory footprint and keeps a bounded cache log. It records action names rather than character values. Set `DebugLog.enabled` to `false` to remove the strip. Simulator footprint snapshots do not establish device peak memory or typing latency.

Dedicated shift, space, return, and delete keys, correction, prediction, emoji input, and haptics are outside this keyboard's scope. Physical swipe thresholds, two-thumb overlap, landscape feel, and VoiceOver interaction need device validation. The [Implementation report](docs/IMPLEMENTATION_REPORT.md) distinguishes implemented behavior from verified behavior.

## License

MIT. See [LICENSE](LICENSE).
