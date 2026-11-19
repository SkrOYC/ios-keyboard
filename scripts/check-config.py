"""Check the source configuration before spending time on a macOS build."""

import plistlib
import re
from pathlib import Path

import yaml


def main():
    spec = yaml.safe_load(Path("project.yml").read_text())
    settings = spec["settings"]["base"]
    assert settings["IPHONEOS_DEPLOYMENT_TARGET"] == "26.0"
    assert settings["DEVELOPMENT_TEAM"] == ""
    assert settings["MARKETING_VERSION"] == "0.3.0"
    assert settings["CURRENT_PROJECT_VERSION"] == "3"
    assert settings["TARGETED_DEVICE_FAMILY"] == "1,2"
    assert spec["options"]["deploymentTarget"]["iOS"] == "26.0"
    assert spec["targets"]["Keyboard"]["settings"]["base"]["APPLICATION_EXTENSION_API_ONLY"] is True
    workflow = yaml.safe_load(Path(".github/workflows/build.yml").read_text())
    assert workflow["jobs"]["build"]["runs-on"] == "macos-26"
    assert workflow["jobs"]["build"]["timeout-minutes"] == 45
    build_job = workflow["jobs"]["build"]
    assert build_job["strategy"] == {
        "fail-fast": False,
        "matrix": {"probe": ["phone", "phone-dark", "phone-contrast", "tablet"]},
    }
    assert build_job["env"] == {
        "IOS_PROBE_APPEARANCE": "${{ (matrix.probe == 'phone-dark' || matrix.probe == 'tablet') && 'dark' || 'light' }}",
        "IOS_PROBE_CONTRAST": "${{ matrix.probe == 'phone-contrast' && 'enabled' || 'disabled' }}",
    }
    steps = {step.get("name"): step for step in build_job["steps"]}
    for name, command, condition in (
        ("Boot matching iOS simulator", "ios-simulator", "matrix.probe != 'tablet'"),
        ("Compile host, keyboard, and UI tests", "ios-test-build", "matrix.probe != 'tablet'"),
        ("Enable and exercise the keyboard in Settings", "ios-test-run", "matrix.probe != 'tablet'"),
        ("Exercise Release keyboard on iPad", "ios-ipad-test", "matrix.probe == 'tablet'"),
        ("Archive unsigned device app", "ios-archive", "matrix.probe == 'phone'"),
        ("Package and verify device IPA", "ios-package", "matrix.probe == 'phone'"),
    ):
        step = steps[name]
        assert step["run"] == "direnv exec . " + command
        assert step["if"] == condition
        assert not step.get("continue-on-error", False)
    assert not build_job.get("continue-on-error", False)
    evidence = steps["Upload logs and simulator evidence"]
    assert evidence["if"] == "always()"
    assert evidence["with"]["name"] == "${{ matrix.probe == 'phone' && 'lifecycle-evidence' || matrix.probe == 'phone-dark' && 'lifecycle-evidence-phone-dark' || matrix.probe == 'phone-contrast' && 'lifecycle-evidence-phone-contrast' || 'lifecycle-evidence-tablet' }}"
    assert steps["Upload verified IPA"]["if"] == "matrix.probe == 'phone'"
    assert spec["targets"]["KeyboardHost"]["dependencies"] == [
        {"target": "Keyboard", "embed": True}
    ]
    assert spec["targets"]["Keyboard"]["settings"]["base"][
        "PRODUCT_BUNDLE_IDENTIFIER"
    ] == "$(BASE_BUNDLE_ID).Keyboard"
    for target in ("KeyboardHost", "Keyboard"):
        with Path(target, "Info.plist").open("rb") as source:
            info = plistlib.load(source)
        assert "NSAppTransportSecurity" not in info
        assert "com.apple.security.application-groups" not in Path(target, "Info.plist").read_text()
        assert info["CFBundleIdentifier"] == "$(PRODUCT_BUNDLE_IDENTIFIER)"
        assert info["CFBundleVersion"] == "$(CURRENT_PROJECT_VERSION)"
        if target == "Keyboard":
            extension = info["NSExtension"]
            assert extension["NSExtensionPointIdentifier"] == "com.apple.keyboard-service"
            assert extension["NSExtensionAttributes"]["RequestsOpenAccess"] is False
    smoke = spec["targets"]["KeyboardSmokeTests"]
    assert smoke["type"] == "bundle.ui-testing"
    assert {source["path"] for source in smoke["sources"]} == {"KeyboardSmokeTests", "Keyboard/Core"}
    logic = spec["targets"]["KeyboardLogicTests"]
    assert logic["type"] == "bundle.unit-test"
    assert {source["path"] for source in logic["sources"]} == {"Keyboard/Core", "KeyboardLogicTests"}
    assert "KeyboardLogicTests" in spec["targets"]["KeyboardHost"]["scheme"]["testTargets"]
    renderer = spec["targets"]["KeyboardViewTests"]
    assert renderer["type"] == "bundle.unit-test"
    assert {source["path"] for source in renderer["sources"]} == {
        "Keyboard/Core", "Keyboard/HexKeyboardView.swift", "Keyboard/HexGlassRendererView.swift",
        "Keyboard/PopupPlateView.swift", "Keyboard/DebugLog.swift",
        "Keyboard/KeyboardViewController.swift", "KeyboardViewTests"
    }
    conditions = spec["targets"]["Keyboard"]["settings"]["configs"]
    assert conditions == {
        "Debug": {"SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) DEBUG DEVTOOLS"},
        "Release": {"SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) DEVTOOLS"},
    }, "Debug and the Release sideload archive must include tuning controls"
    assert "DEVTOOLS" not in settings.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "")
    assert renderer["settings"]["configs"] == conditions
    assert Path("Keyboard/DebugLog.swift").read_text().splitlines()[2] == "#if DEVTOOLS"
    assert "DebugLog.enabled" not in Path("Keyboard/KeyboardViewController.swift").read_text()
    assert "KeyboardViewTests" in spec["targets"]["KeyboardHost"]["scheme"]["testTargets"]
    for source in Path("Keyboard/Core").glob("*.swift"):
        assert "import UIKit" not in source.read_text(), "Core must remain independent of UIKit"
        assert re.findall(r"^import ([A-Za-z0-9_]+)$", source.read_text(), re.MULTILINE) == ["Foundation"]
    forbidden = re.compile(r"\b(URLSession|NWConnection|CFNetwork|UIImpactFeedbackGenerator|UISelectionFeedbackGenerator|UINotificationFeedbackGenerator|UILexicon|UITextChecker)\b")
    for directory in ("Keyboard", "KeyboardHost"):
        for source in Path(directory).rglob("*.swift"):
            assert not forbidden.search(source.read_text()), "Network, haptic, and correction APIs are out of scope"
    assert "CODE_SIGN_ENTITLEMENTS" not in Path("project.yml").read_text()
    print("Source configuration: host, embedded keyboard, bundle IDs, and plists OK")


if __name__ == "__main__":
    main()
