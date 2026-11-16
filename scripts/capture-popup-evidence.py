"""Record the CI simulator and export frames around popup probe markers."""

from datetime import datetime
import json
from pathlib import Path
import re
import signal
import subprocess
import sys
import time


def capture(simulator, log_path, output_prefix):
    movie = f"{output_prefix}-recording.mp4"
    done = Path(f"{output_prefix}-capture-done.txt")
    Path(movie).unlink(missing_ok=True)
    started = time.time()
    with Path(f"{output_prefix}-capture.log").open("w") as diagnostic:
        recorder = subprocess.Popen([
            "xcrun", "simctl", "io", simulator, "recordVideo", "--codec=h264", movie
        ], stdout=diagnostic, stderr=diagnostic)
        deadline = time.monotonic() + 900
        try:
            while not done.exists() and time.monotonic() < deadline:
                if recorder.poll() is not None:
                    raise RuntimeError("Simulator recording stopped before the UI probe finished")
                time.sleep(0.2)
        finally:
            recorder.send_signal(signal.SIGINT)
            try:
                recorder.wait(timeout=30)
            except subprocess.TimeoutExpired:
                recorder.kill()
                recorder.wait()
    if not done.exists():
        raise RuntimeError("The UI probe did not finish before the recording deadline")
    pattern = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+[+-]\d{4}).*HEX_POPUP_(PORTRAIT|LANDSCAPE)", re.MULTILINE)
    markers = {}
    for stamp, orientation in pattern.findall(log_path.read_text(errors="replace")):
        markers[orientation.lower()] = datetime.strptime(stamp, "%Y-%m-%d %H:%M:%S.%f%z").timestamp()
    if done.read_text().strip() == "success" and len(markers) != 2:
        raise RuntimeError("The UI probe did not emit both popup markers")
    requests = [{"seconds": max(0, stamp - started + offset),
                 "output": f"{output_prefix}-popup-{orientation}-{offset}s.png"}
                for orientation, stamp in markers.items() for offset in (4, 6, 8)]
    request_path = Path(f"{output_prefix}-frame-requests.json")
    request_path.write_text(json.dumps(requests, indent=2) + "\n")
    if requests:
        subprocess.run(["xcrun", "swift", "scripts/export-simulator-frames.swift", movie, str(request_path)], check=True, timeout=120)


if __name__ == "__main__":
    capture(sys.argv[1], Path(sys.argv[2]), sys.argv[3])
