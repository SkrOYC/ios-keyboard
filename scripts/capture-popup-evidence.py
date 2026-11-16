"""Capture simulator popups from live UI-probe log markers."""

import selectors
import subprocess
import sys
import time
from pathlib import Path


def capture(simulator, output_prefix):
    pending = {"HEX_POPUP_PORTRAIT": "portrait", "HEX_POPUP_LANDSCAPE": "landscape"}
    deadline = time.monotonic() + 600
    with Path(f"{output_prefix}-capture.log").open("w") as diagnostic:
        stream = subprocess.Popen([
            "xcrun", "simctl", "spawn", simulator, "log", "stream", "--style", "compact",
            "--level", "debug", "--predicate", 'eventMessage BEGINSWITH "HEX_POPUP_"'
        ], stdout=subprocess.PIPE, stderr=diagnostic, text=True, bufsize=1)
        selector = selectors.DefaultSelector()
        selector.register(stream.stdout, selectors.EVENT_READ)
        try:
            while pending and time.monotonic() < deadline:
                if not selector.select(timeout=0.2):
                    continue
                line = stream.stdout.readline()
                if not line and stream.poll() is not None:
                    raise RuntimeError("Simulator log stream stopped before both popup markers")
                for marker, orientation in list(pending.items()):
                    if marker not in line:
                        continue
                    diagnostic.write(line)
                    diagnostic.flush()
                    # The probe holds for eight seconds after resolving its coordinates.
                    time.sleep(4)
                    output = f"{output_prefix}-popup-{orientation}.png"
                    subprocess.run(["xcrun", "simctl", "io", simulator, "screenshot", output], check=True, timeout=30)
                    del pending[marker]
        finally:
            selector.close()
            stream.terminate()
            try:
                stream.wait(timeout=5)
            except subprocess.TimeoutExpired:
                stream.kill()
                stream.wait()
    if pending:
        raise RuntimeError("The UI probe did not emit both popup capture markers")


if __name__ == "__main__":
    capture(sys.argv[1], sys.argv[2])
