#!/usr/bin/env zsh
set -euo pipefail

if [[ $OSTYPE != darwin* ]]; then
  print -u2 'iOS builds and simulator tests require macOS. Push to GitHub Actions from Linux.'
  exit 1
fi

export DEVELOPER_DIR="/Applications/Xcode_${XCODE_VERSION}.app/Contents/Developer"
if [[ ! -d $DEVELOPER_DIR ]]; then
  print -u2 "Required Xcode ${XCODE_VERSION} is missing: $DEVELOPER_DIR"
  exit 1
fi

/usr/bin/xcodebuild -version
/usr/bin/xcrun --sdk iphoneos --show-sdk-version
xcodegen --version
xcodegen generate
mkdir -p build

case "${1:-}" in
  build)
    if ! /usr/bin/xcodebuild archive \
      -project KeyboardHost.xcodeproj \
      -scheme KeyboardHost \
      -configuration Release \
      -destination 'generic/platform=iOS' \
      -archivePath "$PWD/build/KeyboardHost.xcarchive" \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
      > build/archive.log 2>&1; then
      tail -n 100 build/archive.log
      exit 1
    fi
    app="$PWD/build/KeyboardHost.xcarchive/Products/Applications/KeyboardHost.app"
    test -d "$app/PlugIns/Keyboard.appex"
    /usr/bin/lipo -verify_arch arm64 "$app/KeyboardHost"
    /usr/bin/lipo -verify_arch arm64 "$app/PlugIns/Keyboard.appex/Keyboard"
    package_dir=$(mktemp -d "$PWD/build/package.XXXXXX")
    trap 'rm -rf "$package_dir"' EXIT
    mkdir -p "$package_dir/Payload"
    cp -R "$app" "$package_dir/Payload/"
    rm -f "$PWD/build/KeyboardHost.ipa"
    ipa_path="$PWD/build/KeyboardHost.ipa"
    (cd "$package_dir" && zip -qry "$ipa_path" Payload)
    python3 scripts/verify-ipa.py build/KeyboardHost.ipa
    python3 -c 'import hashlib, pathlib; p = pathlib.Path("build/KeyboardHost.ipa"); print(hashlib.sha256(p.read_bytes()).hexdigest() + "  KeyboardHost.ipa")' > build/KeyboardHost.ipa.sha256
    print 'Unsigned device IPA: build/KeyboardHost.ipa'
    ;;
  test)
    # Select an available iPhone on the required iOS major, regardless of model.
    simulator=$(/usr/bin/xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
phones = [d["udid"] for runtime, entries in devices.items()
          if ".iOS-26-" in runtime for d in entries if d["name"].startswith("iPhone")]
if not phones:
    sys.exit("No available iOS 26 iPhone simulator")
print(phones[0])
')
    /usr/bin/xcrun simctl boot "$simulator" || true
    /usr/bin/xcrun simctl bootstatus "$simulator" -b
    # Ensure the software keyboard appears even when a runner has a hardware keyboard.
    /usr/bin/defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
    rm -rf build/SmokeTests.xcresult
    if ! /usr/bin/xcodebuild test \
      -project KeyboardHost.xcodeproj \
      -scheme KeyboardHost \
      -configuration Debug \
      -destination "platform=iOS Simulator,id=$simulator" \
      -parallel-testing-enabled NO \
      -resultBundlePath "$PWD/build/SmokeTests.xcresult" \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
      > build/simulator.log 2>&1; then
      tail -n 120 build/simulator.log
      exit 1
    fi
    /usr/bin/xcrun simctl io "$simulator" screenshot "$PWD/build/simulator.png"
    tail -n 25 build/simulator.log
    ;;
  *)
    print -u2 'Usage: zsh scripts/ios.zsh build|test'
    exit 2
    ;;
esac
