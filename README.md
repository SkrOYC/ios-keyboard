# iOS keyboard

A SwiftUI host app and a UIKit keyboard extension for iOS and iPadOS 26. Write code on Linux, build and test on a public GitHub macOS runner, then sign and install the IPA with a free Apple ID.

The keyboard types letters, supports one-shot shift, repeats delete while held, and includes space, return, and keyboard switching. It requests no Full Access and uses no network or App Group. `project.yml` defines both app targets; XcodeGen generates the Xcode project.

## Development environment

Install [Nix and devenv](https://devenv.sh/getting-started/) and [direnv](https://direnv.net/docs/installation.html) on the development machine. The environment was initialized with `devenv init --include-envrc`.

Approve the environment and run its checks:

```sh
direnv allow
direnv exec . check
```

`devenv.nix` declares the development tools, including GitHub CLI, Python with PyYAML, validation tools, USB device tools, and the Linux iloader app. `devenv.lock` pins the packages. XcodeGen is included on macOS. Xcode 26.4.1 and its iOS SDK are declared through `XCODE_VERSION` and checked before a build. GitHub supplies the licensed Xcode installation at `/Applications/Xcode_26.4.1.app`; Linux cannot run the Apple SDK.

Run project commands through `direnv exec .`. To update the pinned environment, run `direnv exec . devenv update`, then rerun the checks and the GitHub workflow.

## Build and test

[GitHub Actions](https://github.com/SkrOYC/ios-keyboard/actions) runs on branch pushes, pull requests, version tags, and manual dispatch. The repository is public and uses a standard `macos-26` runner, which [doesn't consume private repository CI minutes](https://docs.github.com/en/billing/concepts/product-billing/github-actions). Build artifacts expire after seven days.

The workflow uses the same devenv configuration and `direnv exec` commands as local development.

GitHub shows separate steps for loading tools, generating the project, booting the simulator, compiling the tests, running the UI test, archiving, and packaging. Local `ios-test` and `ios-build` commands run those stages in sequence. The stages perform these checks:

1. `check` validates the configuration, shell scripts, workflow, and IPA verifier.
2. `ios-test` installs the host in an iPhone simulator, enables the extension through Settings, and tests typing, shift, space, delete, return, and rotation.
3. `ios-build` archives the Release app without Apple credentials, checks both ARM64 executables, and packages `build/KeyboardHost.ipa`.
4. `ipa-check` validates the packaged app, extension, bundle IDs, versions, device platform, executable permissions, and keyboard configuration.

On a Mac with the declared Xcode installation, run:

```sh
direnv exec . ios-test
direnv exec . ios-build
```

Download the `KeyboardHost-ipa` artifact from a successful run. The `lifecycle-evidence` artifact contains compiler logs, the XCTest result bundle, and simulator screenshots. An unsigned IPA requires signing before a physical device can install it.

## Download on the phone

Push a version tag after the branch is ready:

```sh
direnv exec . git tag v0.3.0
direnv exec . git push origin v0.3.0
```

The tagged workflow reruns the checks and publishes the IPA and its SHA-256 checksum to [GitHub Releases](https://github.com/SkrOYC/ios-keyboard/releases). Public release downloads work without a GitHub login.

To download and validate the release from Linux:

```sh
direnv exec . gh release download --pattern 'KeyboardHost.ipa*' --dir build --clobber
direnv exec . zsh -c 'cd build && sha256sum -c KeyboardHost.ipa.sha256'
direnv exec . ipa-check build/KeyboardHost.ipa
```

## Prepare the device without an Apple ID

Connect an iPhone or iPad with iOS or iPadOS 26 or later, unlock it, and trust the computer. On Linux, the host must run the `usbmuxd` service. The devenv environment provides the daemon and client tools; starting a privileged USB service is a host setup step.

Probe USB communication and pairing:

```sh
direnv exec . phone-check
```

If pairing hasn't been established, run `direnv exec . idevicepair pair`, approve **Trust** on the device, and repeat `phone-check`. Apple ID credentials aren't needed for this check.

## Final step: sign and install

Use [iloader](https://iloader.app/) for the first installation from Linux:

```sh
direnv exec . iloader
```

Enter the real signing Apple ID and its two-factor authentication code in iloader. Choose the connected device and import the downloaded `KeyboardHost.ipa`. Keep the keyboard extension when the installer offers to remove extensions. Trust the developer profile in **Settings > General > VPN & Device Management**, and enable **Settings > Privacy & Security > Developer Mode** if requested.

After installation:

1. Open **Keyboard Host**.
2. Go to **Settings > General > Keyboard > Keyboards > Add New Keyboard** and add **Keyboard Host**.
3. Return to the host app, tap **Type here**, and switch to the keyboard with the globe key.
4. Try typing, shift, space, held delete, return, and rotation. Reinstall a subsequent build and confirm that the keyboard remains usable.

[SideStore](https://docs.sidestore.io/docs/intro) is an optional next step for refreshing signed apps on the device. Its setup requires the same signing account. Free provisioning expires after seven days, and app and identifier limits apply; keep the host and extension bundle IDs stable.

Apple authentication, provisioning, physical installation, and refresh require a real Apple ID. Simulator success and IPA validation don't prove that those steps succeeded.

## Product configuration and diagnostics

Change `BASE_BUNDLE_ID` in `project.yml` to change the host ID. The extension derives its ID as `$(BASE_BUNDLE_ID).Keyboard`. Both targets share the version and build number. UI test targets are simulator-only and aren't included in the IPA.

`Keyboard/DebugLog.swift` shows the last keyboard event and memory footprint, and writes a bounded file in the extension's cache. Set `DebugLog.enabled` to `false` to remove the strip. For device diagnostics, run `direnv exec . idevicesyslog` or `direnv exec . idevicecrashreport -e crashes`.

## License

MIT. See [LICENSE](LICENSE).
