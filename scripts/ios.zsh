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

# Xcode must select its own compiler drivers. LD=ld from the Nix shell makes
# Xcode send clang driver arguments directly to the linker.
unset CC CXX LD LDPLUSPLUS AR AS NM RANLIB STRIP SDKROOT
mkdir -p build

report_failure() {
  rg -n -C 3 --max-columns 300 --max-columns-preview 'error:|failed|Failed|XCTAssert' "$1" || true
  tail -n 45 "$1"
}

generate_project() {
  /usr/bin/xcodebuild -version
  /usr/bin/xcrun --sdk iphoneos --show-sdk-version
  xcodegen --version
  xcodegen generate
}

prepare_simulator() {
  # A newer runtime can boot through simctl while being ineligible for Xcode.
  simulator_sdk=$(/usr/bin/xcrun --sdk iphonesimulator --show-sdk-version)
  /usr/bin/xcrun simctl list devices available --json > build/simulators.json
  simulator=$(python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
prefix = ".iOS-" + sys.argv[1].replace(".", "-")
phones = [d["udid"] for runtime, entries in devices.items()
          if runtime.endswith(prefix) or prefix + "-" in runtime
          for d in entries if d["name"].startswith("iPhone")]
if not phones:
    sys.exit("No available iPhone simulator matching SDK " + sys.argv[1])
print(phones[0])
' "$simulator_sdk" < build/simulators.json)
  print -r -- "$simulator" > build/simulator-id.txt
  print "Simulator: $simulator; SDK: $simulator_sdk"
  /usr/bin/defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
  /usr/bin/xcrun simctl boot "$simulator" || true
  /usr/bin/xcrun simctl bootstatus "$simulator" -b
}

compile_tests() {
  simulator=$(cat build/simulator-id.txt)
  if ! /usr/bin/xcodebuild build-for-testing \
    -project KeyboardHost.xcodeproj -scheme KeyboardHost -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator" -destination-timeout 30 \
    -derivedDataPath "$PWD/build/DerivedData" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
    > build/compile.log 2>&1; then
    report_failure build/compile.log
    return 1
  fi
  tail -n 8 build/compile.log
}

run_tests() {
  simulator=$(cat build/simulator-id.txt)
  rm -rf build/SmokeTests.xcresult
  if ! /usr/bin/xcodebuild test-without-building \
    -project KeyboardHost.xcodeproj -scheme KeyboardHost -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator" -destination-timeout 30 \
    -derivedDataPath "$PWD/build/DerivedData" -parallel-testing-enabled NO \
    -resultBundlePath "$PWD/build/SmokeTests.xcresult" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
    > build/simulator.log 2>&1; then
    /usr/bin/xcrun simctl io "$simulator" screenshot "$PWD/build/simulator-failure.png" || true
    report_failure build/simulator.log
    return 1
  fi
  /usr/bin/xcrun simctl io "$simulator" screenshot "$PWD/build/simulator.png"
  tail -n 25 build/simulator.log
}

archive_app() {
  if ! /usr/bin/xcodebuild archive \
    -project KeyboardHost.xcodeproj -scheme KeyboardHost -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$PWD/build/KeyboardHost.xcarchive" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
    > build/archive.log 2>&1; then
    report_failure build/archive.log
    return 1
  fi
  tail -n 8 build/archive.log
}

package_ipa() {
  app="$PWD/build/KeyboardHost.xcarchive/Products/Applications/KeyboardHost.app"
  test -d "$app/PlugIns/Keyboard.appex"
  /usr/bin/lipo -verify_arch arm64 "$app/KeyboardHost"
  /usr/bin/lipo -verify_arch arm64 "$app/PlugIns/Keyboard.appex/Keyboard"
  package_dir=$(mktemp -d "$PWD/build/package.XXXXXX")
  trap 'rm -rf "$package_dir"' EXIT
  mkdir -p "$package_dir/Payload"
  cp -R "$app" "$package_dir/Payload/"
  ipa_path="$PWD/build/KeyboardHost.ipa"
  rm -f "$ipa_path"
  (cd "$package_dir" && zip -qry "$ipa_path" Payload)
  python3 scripts/verify-ipa.py build/KeyboardHost.ipa
  python3 -c 'import hashlib, pathlib; p = pathlib.Path("build/KeyboardHost.ipa"); print(hashlib.sha256(p.read_bytes()).hexdigest() + "  KeyboardHost.ipa")' > build/KeyboardHost.ipa.sha256
  print 'Unsigned device IPA: build/KeyboardHost.ipa'
}

case "${1:-}" in
  project) generate_project ;;
  simulator) prepare_simulator ;;
  test-build) compile_tests ;;
  test-run) run_tests ;;
  archive) archive_app ;;
  package) package_ipa ;;
  build) generate_project; archive_app; package_ipa ;;
  test) generate_project; prepare_simulator; compile_tests; run_tests ;;
  *)
    print -u2 'Usage: zsh scripts/ios.zsh project|simulator|test-build|test-run|archive|package|build|test'
    exit 2
    ;;
esac
