"""Validate the unsigned device artifact on Linux or macOS before sideloading."""

import argparse
import json
import plistlib
import stat
import zipfile
from pathlib import Path, PurePosixPath


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        require(len(names) == len(set(names)), "Duplicate archive entries")
        require(archive.testzip() is None, "ZIP checksum failure")
        for name in names:
            parts = PurePosixPath(name).parts
            require(parts and parts[0] == "Payload" and ".." not in parts,
                    f"Unexpected archive path: {name}")
            require(not name.endswith("embedded.mobileprovision"),
                    "Expected an unsigned IPA without a provisioning profile")
        roots = {PurePosixPath(name).parts[1] for name in names
                 if len(PurePosixPath(name).parts) > 1}
        require(roots == {"KeyboardHost.app"}, "Expected exactly KeyboardHost.app")
        host_root = "Payload/KeyboardHost.app/"
        keyboard_root = host_root + "PlugIns/Keyboard.appex/"
        host = plistlib.loads(archive.read(host_root + "Info.plist"))
        keyboard = plistlib.loads(archive.read(keyboard_root + "Info.plist"))
        require(host["CFBundlePackageType"] == "APPL", "Host is not an app")
        require(keyboard["CFBundlePackageType"] == "XPC!", "Keyboard is not an extension")
        require(keyboard["CFBundleIdentifier"] == host["CFBundleIdentifier"] + ".Keyboard",
                "Keyboard bundle ID must be prefixed by the host bundle ID")
        for key in ("CFBundleShortVersionString", "CFBundleVersion"):
            require(host[key] == keyboard[key], f"Host and keyboard disagree on {key}")
        for root, info in ((host_root, host), (keyboard_root, keyboard)):
            require(info["CFBundleSupportedPlatforms"] == ["iPhoneOS"],
                    "IPA must contain device binaries, not simulator binaries")
            require(info["MinimumOSVersion"] == "26.0", "Expected iOS 26.0 minimum")
            require("$(" not in info["CFBundleIdentifier"], "Unresolved bundle ID")
            executable = archive.getinfo(root + info["CFBundleExecutable"])
            require(executable.file_size > 0, "Empty executable")
            require(stat.S_IMODE(executable.external_attr >> 16) & 0o111,
                    "Executable permission was lost during packaging")
        extension = keyboard["NSExtension"]
        require(extension["NSExtensionPointIdentifier"] == "com.apple.keyboard-service",
                "Wrong extension point")
        require(extension["NSExtensionPrincipalClass"].endswith(".KeyboardViewController"),
                "Wrong keyboard entry point")
        require(extension["NSExtensionAttributes"]["RequestsOpenAccess"] is False,
                "Keyboard unexpectedly requests Full Access")
        return {"host": host["CFBundleIdentifier"], "keyboard": keyboard["CFBundleIdentifier"],
                "version": host["CFBundleShortVersionString"], "build": host["CFBundleVersion"],
                "minimum_ios": host["MinimumOSVersion"], "signing": "Apple ID required on install"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.ipa), indent=2))
