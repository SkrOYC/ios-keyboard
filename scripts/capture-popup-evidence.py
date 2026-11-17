"""Record the CI simulator and export frames around popup probe markers."""

from datetime import datetime
import json
import math
from pathlib import Path
import re
import signal
import struct
import subprocess
import sys
import time


def recording_clock(path):
    """Read creation time and duration from the pinned simulator's version-zero mvhd."""
    def scan(source, end):
        while source.tell() < end:
            start = source.tell()
            if end - start < 8:
                raise ValueError("Truncated simulator movie atom")
            size, kind = struct.unpack("!I4s", source.read(8))
            header = 8
            if size == 1:
                if end - source.tell() < 8:
                    raise ValueError("Truncated simulator movie extended size")
                size = struct.unpack("!Q", source.read(8))[0]
                header = 16
            if size < header or start + size > end:
                raise ValueError("Invalid or unsupported simulator movie atom")
            if kind == b"moov":
                clock = scan(source, start + size)
                if clock is not None:
                    return clock
            elif kind == b"mvhd":
                if size - header < 20 or source.read(4) != b"\x00\x00\x00\x00":
                    raise ValueError("Expected a complete version-zero simulator movie header")
                created, _, scale, duration = struct.unpack("!IIII", source.read(16))
                if created == 0 or scale == 0 or duration == 0 or duration == 0xFFFFFFFF:
                    raise ValueError("Simulator movie has no usable creation time or duration")
                return created - 2_082_844_800, duration / scale
            source.seek(start + size)
        return None

    with path.open("rb") as source:
        clock = scan(source, path.stat().st_size)
    if clock is None:
        raise ValueError("Simulator movie has no movie header")
    return clock


def frame_requests(markers, output_prefix, clock):
    started, duration = clock
    requests = []
    for orientation, stamp in markers.items():
        for offset in (4, 6, 8):
            seconds = stamp - started + offset
            if not math.isfinite(seconds) or not 0 <= seconds < duration:
                raise ValueError(f"Popup {orientation} frame at {seconds:.3f}s is outside movie duration {duration:.3f}s")
            requests.append({"seconds": seconds, "output": f"{output_prefix}-popup-{orientation}-{offset}s.png"})
    return requests


def capture(simulator, log_path, output_prefix):
    movie = f"{output_prefix}-recording.mp4"
    done = Path(f"{output_prefix}-capture-done.txt")
    Path(movie).unlink(missing_ok=True)
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
    requests = frame_requests(markers, output_prefix, recording_clock(Path(movie)))
    request_path = Path(f"{output_prefix}-frame-requests.json")
    request_path.write_text(json.dumps(requests, indent=2) + "\n")
    if requests:
        subprocess.run(["build/export-simulator-frames", movie, str(request_path)], check=True, timeout=120)


if __name__ == "__main__":
    capture(sys.argv[1], Path(sys.argv[2]), sys.argv[3])
