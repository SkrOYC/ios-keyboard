"""Check clock alignment and reject invalid frame requests before media decoding."""

import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("capture", "scripts/capture-popup-evidence.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def atom(kind, payload=b"", extended=False):
    if extended:
        return struct.pack("!I4sQ", 1, kind, len(payload) + 16) + payload
    return struct.pack("!I4s", len(payload) + 8, kind) + payload


def movie_header(created=2_082_844_900, scale=600, duration=60000):
    return b"\x00" * 4 + struct.pack("!IIII", created, created, scale, duration)


class CaptureClockTests(unittest.TestCase):
    def read_clock(self, movie):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "recording.mp4")
            path.write_bytes(movie)
            return module.recording_clock(path)

    def test_reads_movie_clock_after_skipping_media(self):
        movie = atom(b"ftyp", b"mp42") + atom(b"mdat", b"media") + atom(b"moov", atom(b"mvhd", movie_header()))
        self.assertEqual(self.read_clock(movie), (100, 100.0))

    def test_accepts_extended_atom_size(self):
        movie = atom(b"moov", atom(b"mvhd", movie_header()), extended=True)
        self.assertEqual(self.read_clock(movie), (100, 100.0))

    def test_rejects_missing_truncated_or_unsupported_headers(self):
        movies = [b"", atom(b"moov"), struct.pack("!I4s", 100, b"moov"), b"short",
                  struct.pack("!I4s", 1, b"moov"),
                  atom(b"moov", atom(b"mvhd", b"\x01" + b"\x00" * 19)),
                  atom(b"moov", atom(b"mvhd", movie_header()[:-1])),
                  atom(b"moov", atom(b"mvhd", movie_header(created=0))),
                  atom(b"moov", atom(b"mvhd", movie_header(scale=0))),
                  atom(b"moov", atom(b"mvhd", movie_header(duration=0))),
                  atom(b"moov", atom(b"mvhd", movie_header(duration=0xFFFFFFFF)))]
        for index, movie in enumerate(movies):
            with self.subTest(case=index), self.assertRaises(ValueError):
                self.read_clock(movie)

    def test_uses_recording_clock_instead_of_launcher_clock(self):
        requests = module.frame_requests({"portrait": 120}, "build/probe", (100, 100))
        self.assertEqual([request["seconds"] for request in requests], [24, 26, 28])
        self.assertEqual(requests[0]["output"], "build/probe-popup-portrait-4s.png")

    def test_rejects_out_of_range_requests_without_clamping(self):
        for stamp in (-10, 100, 450, float("nan"), float("inf")):
            with self.subTest(stamp=stamp), self.assertRaises(ValueError):
                module.frame_requests({"portrait": stamp}, "build/probe", (0, 100))

    def test_regression_rejects_landscape_request_beyond_recording_end(self):
        with self.assertRaisesRegex(ValueError, r"455\.280s.*433\.550s"):
            module.frame_requests({"landscape": 451.280}, "build/probe", (0, 433.55))
