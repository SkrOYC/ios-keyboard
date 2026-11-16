# CI recovery investigation

The failures need different handling. The missing simulator destination is consistent with a CoreSimulator readiness race. The frame-export failure contains a definite request-clock bug and must not be classified as a proven decoder outage. The recovery patch is ready for macOS CI validation; recovery is not yet claimed as verified.

## Evidence

The downloaded artifacts provide the following measurements. Times are offsets within recordings, not work timestamps.

| Recording attempt | Movie duration | Original requested frames | Files exported before failure | Corrected frame range |
| --- | --- | --- | --- | --- |
| 1 | 528.703 seconds | 453.278 to 509.355 seconds | Six | 411.711 to 467.788 seconds |
| 2 | 433.550 seconds | 412.962 to 459.280 seconds | Three portrait frames | 355.118 to 401.435 seconds |

In attempt 2, every landscape request was outside the movie: 455.280, 457.280, and 459.280 seconds. The same process had already decoded and written three PNG files. The paravirtual scaler warning therefore does not establish an unavailable decoder. The out-of-range request is a concrete defect; confirming that it caused the reported AVFoundation error requires a corrected macOS replay. See [attempt 2](https://github.com/SkrOYC/ios-keyboard/actions/runs/43863882102/attempts/2).

The original clock used the recorder launch time. The movie header creation time is later in both cached recordings, shifting the original requests into later UI states or beyond the movie. Apple defines the header creation clock, time scale, and duration in the [movie header format](https://developer.apple.com/documentation/quicktime-file-format/movie_header_atom).

The simulator failure is separate. `simctl` booted the selected SDK-matching tablet, but Xcode listed only generic destinations. This is a loss of concrete simulator discovery, rather than evidence that the selected tablet alone is unsupported. An [upstream runner-image reproducer](https://github.com/actions/runner-images/issues/12777#issuecomment-4963878428) reports that Xcode can query destinations before CoreSimulatorService is ready, while a preceding `simctl list` waits for the service. This matches the symptom, but the cached logs do not prove the daemon's internal cause. See [attempt 1](https://github.com/SkrOYC/ios-keyboard/actions/runs/43863882102/attempts/1).

## Local remediation

The recovery changes preserve all acceptance gates:

- `capture-popup-evidence.py` reads the pinned simulator's version-zero movie header and anchors frame requests to that creation clock. It reads the declared duration and rejects negative, nonfinite, or out-of-range requests. Invalid offsets are not clamped into unrelated images.
- `export-simulator-frames.swift` independently loads the actual asset duration and validates every request before decoding. It reports errors without an unhandled top-level crash. The API follows Apple's [asynchronous media-loading guidance](https://developer.apple.com/documentation/avfoundation/loading-media-data-asynchronously).
- `ios.zsh` refreshes CoreSimulator through `bootstatus` and `simctl list` before build and test boundaries. It checks that the same selected simulator remains available and booted. The test preflight runs before starting the recorder, so a readiness failure does not orphan the capture process.
- The native frame exporter is compiled with the pinned SDK during project generation, before the UI probes. The same binary is reused for phone and tablet evidence. Test attachments are exported even if frame generation fails, and the evidence failure still fails the stage.
- Six Python tests cover the recording clock, extended atom sizes, invalid headers, delayed launch-time alignment, invalid ranges, and the exact failed landscape-offset regression.

The parser deliberately supports the movie-header version observed in the pinned recordings. An unsupported format fails explicitly rather than guessing a clock. The local replay reads both real CI recordings and produces six in-range requests for each. This verifies clock arithmetic and request bounds; it does not verify the resulting popup pixels.

## Bounded macOS recovery sequence

Use this sequence before resuming the full milestone:

1. Compile the changed frame exporter on the pinned macOS runner, replay the cached movie with corrected requests, and inspect portrait and landscape PNGs. Preserve the original movie and errors.
2. Check simulator discovery at each Xcode boundary. Record the available-device snapshot and `xcodebuild -showdestinations` output. Retain the selected destination instead of silently substituting another.
3. If Xcode again reports no concrete simulators before any test starts, refresh the service through `simctl`, wait for the selected device, and permit at most one retry of that pre-test discovery operation. Do not retry XCTest assertions, compilation errors, signing errors, or media range errors as infrastructure failures.
4. Shut down the completed phone simulator before booting the tablet to reduce concurrent simulator pressure. If discovery remains unstable, place phone and tablet probes in separate macOS jobs with the same required checks and 45-minute limits.
5. Keep evidence export separate from test-result classification. Preserve the result bundle and test status even when frame export fails. A final required evidence gate must still fail if requested visual proof is missing; tablet tests and IPA checks need not be hidden by an earlier export error.
6. After the bounded probes pass, resume tablet Release/dark validation, inspect the compact picker and punctuation popup, and complete the 0.3.0/build 3 archive and IPA checks.

Only the readiness refresh is included in the simulator recovery change. Automated retry classification, simulator shutdown sequencing, job isolation, and evidence-stage separation remain recommendations pending a macOS probe. Do not add broad retries, erase simulator data, reset daemons indiscriminately, relax assertions, or switch toolchains based only on these symptoms.

## Validation status

`direnv exec . check` passes all nine Python tests, geometry and spec parity, configuration, shell syntax, and workflow checks. Both cached recordings pass the corrected clock and bounds replay. `devenv.lock`, application behavior, geometry, and IPA assertions are unchanged. Swift compilation, native frame decoding, and CoreSimulator recovery still require macOS CI; none is claimed as verified by the Linux checks.
