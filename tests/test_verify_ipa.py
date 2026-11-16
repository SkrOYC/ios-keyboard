import importlib.util
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path

spec = importlib.util.spec_from_file_location("verify_ipa", "scripts/verify-ipa.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class VerifyIPATests(unittest.TestCase):
    def make_ipa(self, path, *, platform="iPhoneOS", extension_id="com.example.keyboard.Keyboard",
                 executable_mode=0o100755, full_access=False, profile=False, missing_extension=False):
        common = {"CFBundleShortVersionString": "0.2.0", "CFBundleVersion": "2",
                  "CFBundleSupportedPlatforms": [platform], "MinimumOSVersion": "26.0"}
        host = dict(common, CFBundleIdentifier="com.example.keyboard",
                    CFBundlePackageType="APPL", CFBundleExecutable="KeyboardHost")
        keyboard = dict(common, CFBundleIdentifier=extension_id,
                        CFBundlePackageType="XPC!", CFBundleExecutable="Keyboard",
                        NSExtension={"NSExtensionPointIdentifier": "com.apple.keyboard-service",
                                     "NSExtensionPrincipalClass": "Keyboard.KeyboardViewController",
                                     "NSExtensionAttributes": {"RequestsOpenAccess": full_access}})
        with zipfile.ZipFile(path, "w") as archive:
            bundles = [("Payload/KeyboardHost.app/", host)]
            if not missing_extension:
                bundles.append(("Payload/KeyboardHost.app/PlugIns/Keyboard.appex/", keyboard))
            for root, info in bundles:
                archive.writestr(root + "Info.plist", plistlib.dumps(info))
                entry = zipfile.ZipInfo(root + info["CFBundleExecutable"])
                entry.external_attr = executable_mode << 16
                archive.writestr(entry, b"fixture executable")
            if profile:
                archive.writestr("Payload/KeyboardHost.app/embedded.mobileprovision", b"profile")

    def test_valid_unsigned_device_ipa(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "app.ipa")
            self.make_ipa(path)
            self.assertEqual(module.verify(path)["keyboard"], "com.example.keyboard.Keyboard")

    def test_rejects_unsuitable_sideload_artifacts(self):
        cases = [{"platform": "iPhoneSimulator"}, {"extension_id": "com.other.Keyboard"},
                 {"executable_mode": 0o100644}, {"full_access": True}, {"profile": True},
                 {"missing_extension": True}]
        for case in cases:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as directory:
                path = Path(directory, "app.ipa")
                self.make_ipa(path, **case)
                with self.assertRaises((ValueError, KeyError)):
                    module.verify(path)


if __name__ == "__main__":
    unittest.main()
