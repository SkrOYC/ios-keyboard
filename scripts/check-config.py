"""Check the source configuration before spending time on a macOS build."""

import plistlib
from pathlib import Path

import yaml


def main():
    spec = yaml.safe_load(Path("project.yml").read_text())
    settings = spec["settings"]["base"]
    assert settings["IPHONEOS_DEPLOYMENT_TARGET"] == "26.0"
    assert settings["DEVELOPMENT_TEAM"] == ""
    assert spec["targets"]["KeyboardHost"]["dependencies"] == [
        {"target": "Keyboard", "embed": True}
    ]
    assert spec["targets"]["Keyboard"]["settings"]["base"][
        "PRODUCT_BUNDLE_IDENTIFIER"
    ] == "$(BASE_BUNDLE_ID).Keyboard"
    for target in ("KeyboardHost", "Keyboard"):
        with Path(target, "Info.plist").open("rb") as source:
            info = plistlib.load(source)
        assert info["CFBundleIdentifier"] == "$(PRODUCT_BUNDLE_IDENTIFIER)"
        assert info["CFBundleVersion"] == "$(CURRENT_PROJECT_VERSION)"
        if target == "Keyboard":
            extension = info["NSExtension"]
            assert extension["NSExtensionPointIdentifier"] == "com.apple.keyboard-service"
            assert extension["NSExtensionAttributes"]["RequestsOpenAccess"] is False
    logic = spec["targets"]["KeyboardLogicTests"]
    assert logic["type"] == "bundle.unit-test"
    assert {source["path"] for source in logic["sources"]} == {"Keyboard/Core", "KeyboardLogicTests"}
    assert "KeyboardLogicTests" in spec["targets"]["KeyboardHost"]["scheme"]["testTargets"]
    for source in Path("Keyboard/Core").glob("*.swift"):
        assert "import UIKit" not in source.read_text(), "Core must remain independent of UIKit"
    assert "CODE_SIGN_ENTITLEMENTS" not in Path("project.yml").read_text()
    print("Source configuration: host, embedded keyboard, bundle IDs, and plists OK")


if __name__ == "__main__":
    main()
