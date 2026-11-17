# CI recovery and screenshot evidence

Recording recovery is verified by the [complete phone and tablet run](https://github.com/SkrOYC/ios-keyboard/actions/runs/43962591187) and the [popup-contrast run](https://github.com/SkrOYC/ios-keyboard/actions/runs/43966486861). The [native-material verification run](https://github.com/SkrOYC/ios-keyboard/actions/runs/44016204422) passes all four required probes, frame export, archive, and unsigned IPA validation. Portrait and landscape images were inspected in light, dark, and Increase Contrast iPhone evidence, with tablet Release regression coverage.

## Recording-clock defect

The original frame requests used the recorder process launch time. Movie creation can occur later, so this clock selected late UI states or offsets beyond the recording. The cached evidence establishes the following ranges; these are offsets within movies.

| Recording attempt | Movie duration | Original requested range | Files exported before failure | Corrected frame range |
| --- | --- | --- | --- | --- |
| 1 | 528.703 seconds | 453.278 to 509.355 seconds | Six | 411.711 to 467.788 seconds |
| 2 | 433.550 seconds | 412.962 to 459.280 seconds | Three portrait frames | 355.118 to 401.435 seconds |

In [attempt 2](https://github.com/SkrOYC/ios-keyboard/actions/runs/43863882102/attempts/2), landscape requests at 455.280, 457.280, and 459.280 seconds exceeded the movie duration. Three earlier PNGs had already decoded successfully. The accompanying paravirtual scaler warning therefore does not establish a decoder outage. Invalid offsets are a definite defect; the warning is retained as diagnostic context.

`capture-popup-evidence.py` reads creation time, time scale, and duration from the version-zero movie header observed in the pinned simulator recordings. It anchors popup markers to that clock and rejects negative, nonfinite, or out-of-range requests. It supports extended atom sizes and fails explicitly on unsupported or truncated headers. The format follows Apple's [movie header specification](https://developer.apple.com/documentation/quicktime-file-format/movie_header_atom).

The native Swift exporter independently loads the asset duration and checks every request before decoding. It follows Apple's [asynchronous media-loading guidance](https://developer.apple.com/documentation/avfoundation/loading-media-data-asynchronously), reports failures cleanly, and never clamps invalid requests into unrelated pictures. Six Python tests cover the parser, delayed startup, invalid ranges, and the failed landscape-offset regression. Corrected arithmetic was checked against both cached movies; final native decoding and popup pixels were verified in fresh CI recordings.

## Simulator discovery and input-mode selection

The earlier [tablet compilation failure](https://github.com/SkrOYC/ios-keyboard/actions/runs/43863882102/attempts/1) showed a booted simulator but only generic Xcode destinations. An [upstream runner-image reproducer](https://github.com/actions/runner-images/issues/12777#issuecomment-4963878428) describes Xcode querying before CoreSimulatorService is ready. This is consistent with the observed discovery failure, but the daemon's internal cause was not established.

`ios.zsh` refreshes the daemon connection through `bootstatus` and `simctl list` before each Xcode boundary, then verifies the same selected simulator is available and booted. The three iPhone appearance probes and tablet Release probe run in separate required `macos-26` matrix jobs, each with a 45-minute limit. This avoids sharing simulator state or combining probes within one timeout. There are no broad test retries, daemon resets, or relaxed acceptance checks.

The first recovery compiled tablet Release successfully but left the UI probe on the native keyboard. Native iPad accessibility taps reported invalid hit points. Explicit menu selection also failed before hex-key discovery in both configurations. Fixed-coordinate globe cycling passed the complete recovery and final runs. A native keyboard preview alone did not identify a crash or a definitive launch failure.

The material-refresh fixture also waits for finite positive key geometry before querying hittability. Remote accessibility bridges can briefly report infinite coordinates or empty frames. Settings navigation targets the actual Add New Keyboard button rather than the centre of its larger cell. Coordinate taps require the target centre to be on screen; an external switcher can extend slightly beyond the app bounds.

Observed system-switcher labels include Next keyboard and Emoji. The Emoji fallback also requires the Keyboard value to distinguish the external switcher from the separate shortcut inside the system keyboard. During asynchronous extension activation, setup waits for either visible extension keys or a ready system switcher. It returns as soon as the keys appear. These waits establish setup readiness; failed typing assertions are not retried.

An inspected failure screenshot showed an AutoFill editing menu before the first swipe and an empty field afterward. The fixture preserves restored focus rather than tapping an already active field, dismisses an observed AutoFill menu, and waits for it to disappear. The complete gesture sequence remains unchanged.

Failed UI probes request filtered extension logs and keyboard crash reports, while retaining the original failing result. This collection path is guarded so diagnostic errors cannot suppress result-bundle attachments. Material-refresh setup failures exercised the collection path. A native preview or a launch synchronizer warning alone does not establish an extension crash.

## Screenshot handling

The native exporter is compiled during project generation, before simulator interaction. Each job reuses that binary for its own evidence. The probe records the simulator through completion and exports frames around portrait and landscape popup markers. Full-screen XCTest attachments capture the base grids, symbols, pickers, and input states; app-only landscape captures were cropped and are no longer used.

The standard phone artifact is `lifecycle-evidence`; the other probes use `lifecycle-evidence-phone-dark`, `lifecycle-evidence-phone-contrast`, and `lifecycle-evidence-tablet`. Each contains logs, result bundles, screenshots, movies, frame requests, and appearance and contrast readbacks. Attachment export remains available if frame generation fails, and missing required frame evidence still fails the job. Artifacts expire after seven days.

Download artifacts with `direnv exec . gh run download` into ignored `build/simulator-cache` subdirectories. Keep the original files and named review copies so comparisons remain possible after artifact expiry. Material-refresh originals are cached under `build/simulator-cache/glass-complete`; named images and source mappings are under `build/simulator-cache/review/glass-complete`. Earlier flat-fill evidence remains under `build/simulator-cache/popup-contrast`. Video-derived landscape frames retain the recording orientation, while full-screen attachments are upright. Only CI simulator images are used.

## Visual correction and remaining boundaries

The first complete dark tablet images exposed underlying key letters through the translucent punctuation popup. An opaque adaptive backing corrected the original custom-fill renderer. The native-material refresh supersedes that backing: popup choices use native glass, and covered base glyphs are hidden until dismissal. Keeping popup content mounted before applying the material resolves the missing first popup in inspected portrait evidence. A neutral punctuation diagnostic identifies model opening without retaining characters.

The first native UIKit glass prototype passed functional tests, but inspected images showed rectangular material beyond the hex masks. The renderer instead supplies explicit rounded hex shapes to SwiftUI's [`glassEffect(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)). Each grid or popup shares a glass container. Inspected portrait and landscape images show separate hex silhouettes without rectangular leakage. Neutral native glass replaces the prominent Done button after reviewed images exposed poor title contrast.

All nine Python tests, geometry and spec parity, configuration, workflow, and shell checks pass. Each of the four simulator jobs passes 21 Core tests, 3 UIKit tests, and the full UI probe. Existing IPA assertions remain strict and `devenv.lock` is unchanged. Real-device swipe feel, overlapping thumbs, landscape reach, accessibility material preferences, VoiceOver, native-material performance, and signed installation remain unverified; see the [implementation report](IMPLEMENTATION_REPORT.md).
