import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("repeat_diagnostics", "scripts/report-repeat-actions.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RepeatDiagnosticsTests(unittest.TestCase):
    def test_only_neutral_delete_actions_are_printable(self):
        motion = "delete motion phase=move first=true travel=-175.2 count=1"
        text = f"time 30 MB · {motion}\ntime 30 MB · delete\ntime 30 MB · insert private-text\nprivate-text"
        self.assertEqual(module.actions(text), [motion, "delete"])
        self.assertEqual(module.actions("time 30 MB · delete private-text"), [])
        self.assertEqual(module.actions("time 30 MB · delete motion phase=private first=true travel=-1.0 count=1"), [])

    def test_empty_malformed_and_bounded(self):
        self.assertEqual(module.actions(""), [])
        self.assertEqual(module.actions("malformed input"), [])
        self.assertEqual(module.actions("prefix · delete\n" * 500), ["delete"] * 40)
        self.assertEqual(module.actions("prefix · delete motion phase=move first=true travel=-" + "1" * 200 + ".0 count=1"), [])

    def test_reads_only_the_matching_extension(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, identifier in [("keyboard", "example.Keyboard"), ("other", "example.Other")]:
                container = root / name
                (container / "Library/Caches").mkdir(parents=True)
                (container / ".com.apple.mobile_container_manager.metadata.plist").write_bytes(
                    plistlib.dumps({"MCMMetadataIdentifier": identifier}))
                (container / "Library/Caches/keyboard.log").write_text("prefix · delete\n")
            broken = root / "broken"
            broken.mkdir()
            (broken / ".com.apple.mobile_container_manager.metadata.plist").write_text("malformed")
            self.assertEqual(module.read_actions(root, "example.Keyboard"), ["delete"])
            self.assertEqual(module.read_actions(root, "missing"), [])
            self.assertEqual(module.read_actions(root / "missing", "example.Keyboard"), [])


if __name__ == "__main__":
    unittest.main()
