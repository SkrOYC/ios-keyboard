"""Capture simulator popups while the UI probe holds the period key."""

import subprocess
import sys
import time
from pathlib import Path


def capture(simulator, log_path, output_prefix):
    pending = {"HEX_POPUP_PORTRAIT": "portrait", "HEX_POPUP_LANDSCAPE": "landscape"}
    deadline = time.monotonic() + 600
    while pending and time.monotonic() < deadline:
        text = log_path.read_text(errors="replace") if log_path.exists() else ""
        for marker, orientation in list(pending.items()):
            if marker not in text:
                continue
            # The UI probe holds for four seconds; wait past the 420 ms popup delay.
            time.sleep(2)
            output = f"{output_prefix}-popup-{orientation}.png"
            subprocess.run(["xcrun", "simctl", "io", simulator, "screenshot", output], check=True)
            del pending[marker]
        if pending:
            time.sleep(0.2)
    if pending:
        raise RuntimeError("The UI probe did not emit both popup capture markers")


if __name__ == "__main__":
    capture(sys.argv[1], Path(sys.argv[2]), sys.argv[3])
