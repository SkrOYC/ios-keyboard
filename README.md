# ios-keyboard

A minimal custom iOS keyboard, built **without a Mac**:

1. You write Swift on Linux (or anywhere) and push.
2. GitHub Actions builds an **unsigned** `KeyboardHost.ipa` on a macOS runner.
3. SideStore (or AltStore) on the iPhone re-signs it with your **free Apple ID** — keyboard extension included — and installs it.

No Apple Developer Program ($99/yr), no certificates, and no secrets in CI.

## Architecture

```
ios-keyboard/
├── project.yml                  # XcodeGen spec (source of truth; .xcodeproj is generated in CI)
├── KeyboardHost/                # Container app (SwiftUI) — only exists to ship the extension
│   ├── KeyboardHostApp.swift
│   ├── ContentView.swift        # "How to enable" steps + a text field to try the keyboard
│   └── Info.plist
├── Keyboard/                    # Keyboard extension (UIKit, UIInputViewController)
│   ├── KeyboardViewController.swift
│   ├── DebugLog.swift           # On-keyboard debug line + memory readout (easy to remove)
│   └── Info.plist               # NSExtension: com.apple.keyboard-service, RequestsOpenAccess=false
└── .github/workflows/build.yml  # xcodegen → xcodebuild archive (unsigned) → .ipa artifact / Release
```

- **KeyboardHost** (`$(BASE_BUNDLE_ID)`) — iOS apps can't ship an extension alone, so this is the
  host. It shows how to turn the keyboard on in Settings.
- **Keyboard** (`$(BASE_BUNDLE_ID).Keyboard`) — `KeyboardViewController` subclasses
  `UIInputViewController` and types through `textDocumentProxy`: three letter rows, shift (one-shot),
  delete with auto-repeat, 🌐 next-keyboard (shown only when `needsInputModeSwitchKey` is true),
  space and return. It's plain UIKit with no SwiftUI, to keep memory low.
- The built app contains `KeyboardHost.app/PlugIns/Keyboard.appex`. CI checks it's there before
  packaging `Payload/KeyboardHost.app` into `KeyboardHost.ipa`.

Deployment target: iOS 16.0, Swift 5.

## Change the bundle id

Edit **one line** in `project.yml`:

```yaml
settings:
  base:
    BASE_BUNDLE_ID: com.skroyc.keyboard   # ← change this
```

The extension's id is derived from it as `<BASE_BUNDLE_ID>.Keyboard`, and it must stay prefixed by
the app's id. (`options.bundleIdPrefix` is only an XcodeGen default; you can change it to match.)
SideStore/AltStore rewrite bundle ids with your team id when signing, so the placeholder already
works for sideloading. Change it if you want your own reverse-DNS name.

## Build → sideload loop

### CI

`.github/workflows/build.yml` runs on every push to `main`, on PRs, and on manual
**Run workflow** (`workflow_dispatch`). It:

1. picks the latest stable Xcode on `macos-latest`,
2. `brew install xcodegen && xcodegen generate`,
3. `xcodebuild archive -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`,
4. zips `Payload/KeyboardHost.app` into `KeyboardHost.ipa`,
5. uploads it as the **`KeyboardHost-ipa`** artifact (plus `xcodebuild-log` for debugging).

**Releases for the phone:** artifacts are zipped and need a GitHub login, which is awkward on the
iPhone. Push a tag instead:

```sh
git tag v0.1.0 && git push origin v0.1.0
```

The `release` job then creates a GitHub Release with `KeyboardHost.ipa` attached. Open the release
page in Safari, tap the `.ipa`, then **Share › SideStore** (or open it from Files in SideStore).
Note: if the repo is **private**, you have to be signed in to GitHub in Safari to download it.

### One-time SideStore setup (from Linux)

SideStore is AltStore's fork that installs and refreshes apps **on the phone**. The computer is only
needed once, for the initial install and the pairing file. (Source: docs.sidestore.io → Installation.)

1. On the ThinkPad, install `usbmuxd` (`sudo apt install usbmuxd`), then install **iloader** from its
   only official sources: <https://github.com/nab138/iloader/releases> or iloader.app (`.deb` or AppImage).
2. Plug in the iPhone, tap **Trust**, open iloader, sign in with your (signing) Apple ID, select the
   device, and choose **Install SideStore (Stable)**. iloader installs SideStore, imports its
   certificate and **places the pairing file** automatically.
3. On the iPhone, go to Settings › General › VPN & Device Management and **trust** your Apple ID's
   developer app. Turn on **Settings › Privacy & Security › Developer Mode** if iOS asks.
4. Install **LocalDevVPN** from the App Store and connect it. SideStore needs this on-device VPN (and
   Wi‑Fi) whenever it installs or refreshes apps.
5. Open SideStore, sign in with the same Apple ID, and in **My Apps** tap the `7 DAYS` counter to
   finish setup.

If SideStore later says the pairing file is invalid, re-run iloader → **Manage Pairing File** →
**Place** for SideStore. (iloader can also install an `.ipa` directly over USB, which is handy as a fallback.)

Use a **separate Apple ID** for signing, not your main account, with 2FA on.

### Each iteration

push → wait for CI (≈3–6 min) → download the `.ipa` (Release or artifact) → open in SideStore → install.
Installing over the old version keeps your keyboard enabled.

### Free Apple ID limits

- **7-day expiry.** Signed apps stop launching after 7 days. SideStore refreshes them on the phone
  (with LocalDevVPN on and Wi‑Fi). Open it every few days, or set up an iOS Shortcuts automation to refresh.
- **3 active sideloaded apps** at once, and SideStore itself counts as one.
- **10 App IDs per 7 days.** This app uses **2** (host + keyboard). Changing the bundle id or
  installing extra apps uses more, so don't churn bundle ids.
- No push notifications or iCloud. **App Groups** (sharing data between the app and keyboard) can be
  unreliable with free signing, so this starter avoids them.

## Enable the keyboard on the iPhone

1. **Settings › General › Keyboard › Keyboards › Add New Keyboard…**
2. Under *Third-Party Keyboards*, choose **Keyboard**.
3. In any text field, long-press 🌐 and pick it. (The host app has a field for trying it.)

`RequestsOpenAccess` is `false`, so there's no "Allow Full Access" toggle. The keyboard has no
network or shared container. If you later set it to `true`, test with Full Access both on and off.

Third-party keyboards never appear in secure (password) fields or phone-number pads, and an app can
refuse them.

## Memory limit

Keyboard extensions get roughly **50–70 MB** (it varies by device and iOS version). Going over gets
the extension **killed silently**, and iOS just falls back to the previous keyboard. To stay safe:

- prefer UIKit over SwiftUI in the extension, and reuse views rather than rebuilding them,
- don't load big images, fonts, dictionaries or ML models eagerly. Use memory-mapped files instead,
- watch the debug line, which shows the live `phys_footprint` (the number iOS checks).

## Debugging without a Mac

There's no Xcode console, so:

- **Debug line on the keyboard.** `DebugLog.log("…")` shows the last event and the current memory
  above the keys. To remove it, set `DebugLog.enabled = false`, or delete `Keyboard/DebugLog.swift`
  and its calls.
- **File log.** The same lines go to `Library/Caches/keyboard.log` in the extension's sandbox (capped
  at 64 KB). That's handy if you later add an App Group or Full Access and want the host app to show it.
- **Device logs from Linux.** Install `libimobiledevice`, plug in the phone, and run
  `idevicesyslog | grep -i keyboard`. It shows extension launches, crashes and jetsam (memory) kills.
  `idevicecrashreport -e ./crashes` pulls crash reports.
- **On the phone.** Settings › Privacy & Security › Analytics & Improvements › Analytics Data
  lists `Keyboard-…` crash reports and `JetsamEvent-…` entries.
- **CI logs.** The `xcodebuild-log` artifact has the full compiler output when a build fails.
- If you need a simulator or debugger now and then, rent a cloud Mac (MacinCloud, AWS EC2 Mac) for an hour.

## License

MIT. See [LICENSE](LICENSE).
