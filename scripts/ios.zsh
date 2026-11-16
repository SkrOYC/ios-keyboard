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
  /usr/bin/xcrun --sdk macosx swiftc -swift-version 5 scripts/export-simulator-frames.swift -o build/export-simulator-frames
}

prepare_simulator() {
  local device_family=${1:-iPhone}
  # A newer runtime can boot through simctl while being ineligible for Xcode.
  simulator_sdk=$(/usr/bin/xcrun --sdk iphonesimulator --show-sdk-version)
  /usr/bin/xcrun simctl list devices available --json > build/simulators.json
  simulator=$(python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
prefix = ".iOS-" + sys.argv[1].replace(".", "-")
phones = [d["udid"] for runtime, entries in devices.items()
          if runtime.endswith(prefix) or prefix + "-" in runtime
          for d in entries if d["name"].startswith(sys.argv[2])]
if not phones:
    sys.exit("No available matching simulator for SDK " + sys.argv[1])
print(phones[0])
' "$simulator_sdk" "$device_family" < build/simulators.json)
  print -r -- "$simulator" > build/simulator-id.txt
  print "Simulator: $simulator; SDK: $simulator_sdk"
  /usr/bin/defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
  /usr/bin/xcrun simctl boot "$simulator" || true
  /usr/bin/xcrun simctl bootstatus "$simulator" -b
  /usr/bin/xcrun simctl help ui > build/simulator-ui-help.txt
  local probe_appearance=light
  if [[ $device_family == iPad ]]; then probe_appearance=dark; fi
  /usr/bin/xcrun simctl ui "$simulator" appearance "$probe_appearance"
}

ensure_simulator_ready() {
  # Refresh the daemon connection at each Xcode boundary, not only during boot.
  /usr/bin/xcrun simctl bootstatus "$simulator" -b
  /usr/bin/xcrun simctl list devices available --json > build/simulator-readiness.json
  python3 -c '
import json, sys
devices = [device for entries in json.load(sys.stdin)["devices"].values() for device in entries]
selected = next((device for device in devices if device["udid"] == sys.argv[1]), None)
if selected is None or selected.get("state") != "Booted":
    sys.exit("The selected simulator is not available and booted")
' "$simulator" < build/simulator-readiness.json
}

compile_tests() {
  local probe_configuration=${1:-Debug}
  local compile_log="build/compile-${probe_configuration}.log"
  simulator=$(cat build/simulator-id.txt)
  ensure_simulator_ready
  if ! /usr/bin/xcodebuild build-for-testing \
    -project KeyboardHost.xcodeproj -scheme KeyboardHost -configuration "$probe_configuration" \
    -destination "platform=iOS Simulator,id=$simulator" -destination-timeout 30 \
    -derivedDataPath "$PWD/build/DerivedData" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
    > "$compile_log" 2>&1; then
    report_failure "$compile_log"
    return 1
  fi
  tail -n 8 "$compile_log"
}

run_tests() {
  local probe_name=${1:-SmokeTests}
  local probe_configuration=${2:-Debug}
  local probe_log="build/${probe_name}.log"
  local probe_result="build/${probe_name}.xcresult"
  local probe_screenshots="build/screenshots/${probe_name}"
  simulator=$(cat build/simulator-id.txt)
  ensure_simulator_ready
  rm -rf "$probe_result"
  local popup_capture_pid
  local capture_done="build/${probe_name}-capture-done.txt"
  rm -f "$capture_done"
  python3 scripts/capture-popup-evidence.py "$simulator" "$probe_log" "build/${probe_name}" &
  popup_capture_pid=$!
  if ! /usr/bin/xcodebuild test-without-building \
    -project KeyboardHost.xcodeproj -scheme KeyboardHost -configuration "$probe_configuration" \
    -destination "platform=iOS Simulator,id=$simulator" -destination-timeout 30 \
    -derivedDataPath "$PWD/build/DerivedData" -parallel-testing-enabled NO \
    -resultBundlePath "$PWD/$probe_result" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
    > "$probe_log" 2>&1; then
    print -r -- failure > "$capture_done"
    wait "$popup_capture_pid" 2>/dev/null || true
    /usr/bin/xcrun simctl io "$simulator" screenshot "$PWD/build/${probe_name}-failure.png" || true
    /usr/bin/xcrun xcresulttool export attachments --path "$probe_result" --output-path "$probe_screenshots" || true
    report_failure "$probe_log"
    return 1
  fi
  print -r -- success > "$capture_done"
  local capture_result=0
  wait "$popup_capture_pid" || capture_result=$?
  /usr/bin/xcrun xcresulttool export attachments --help > build/xcresult-export-help.txt
  /usr/bin/xcrun xcresulttool export attachments --path "$probe_result" --output-path "$probe_screenshots"
  /usr/bin/xcrun simctl io "$simulator" screenshot "$PWD/build/${probe_name}.png"
  tail -n 25 "$probe_log"
  return "$capture_result"
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
  /usr/bin/lipo "$app/KeyboardHost" -verify_arch arm64
  /usr/bin/lipo "$app/PlugIns/Keyboard.appex/Keyboard" -verify_arch arm64
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
  ipad-test) prepare_simulator iPad; compile_tests Release; run_tests TabletTests Release ;;
  archive) archive_app ;;
  package) package_ipa ;;
  build) generate_project; archive_app; package_ipa ;;
  test) generate_project; prepare_simulator; compile_tests; run_tests ;;
  *)
    print -u2 'Usage: zsh scripts/ios.zsh project|simulator|test-build|test-run|ipad-test|archive|package|build|test'
    exit 2
    ;;
esac
