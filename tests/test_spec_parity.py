"""Verify the parity check rejects changes to each shared contract."""

import contextlib
import io
import os
from pathlib import Path
import runpy
import tempfile
import unittest


class SpecParityTests(unittest.TestCase):
    def test_rejects_changed_swift_constants(self):
        paths = ["docs/spec/hex7x4.html", "Keyboard/Core/LetterOrder.swift",
                 "Keyboard/Core/TouchMachine.swift", "Keyboard/Core/PopupModel.swift"]
        originals = {path: Path(path).read_text() for path in paths}
        checker = Path("scripts/check-spec-parity.py").resolve()
        cases = [
            (paths[1], "wqzeasxtrdcgfnvyuhmiljbopk", "qwzeasxtrdcgfnvyuhmiljbopk"),
            (paths[1], "147*2580", "174*2580"),
            (paths[2], "threshold = 70.0", "threshold = 71.0"),
            (paths[2], "holdMilliseconds = 420.0", "holdMilliseconds = 421.0"),
        ]
        previous = Path.cwd()
        try:
            with tempfile.TemporaryDirectory() as directory:
                os.chdir(directory)
                for path, old, new in cases:
                    with self.subTest(contract=old):
                        for relative, text in originals.items():
                            target = Path(relative)
                            target.parent.mkdir(parents=True, exist_ok=True)
                            target.write_text(text.replace(old, new) if relative == path else text)
                        with self.assertRaises(AssertionError), contextlib.redirect_stdout(io.StringIO()):
                            runpy.run_path(str(checker), run_name="__main__")
        finally:
            os.chdir(previous)
