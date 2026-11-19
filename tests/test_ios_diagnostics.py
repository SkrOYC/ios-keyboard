import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
COLLECTOR = (ROOT / "scripts/ios.zsh").read_text().split(
    '  python3 - "$probe_name" "$simulator" <<\'PY\'\n', 1
)[1].split("\nPY\n", 1)[0]


class ExtensionDiagnosticsTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.home = Path(directory.name)
        (self.home / "build").mkdir()
        self.reports = self.home / "Library/Logs/DiagnosticReports"
        self.reports.mkdir(parents=True)

    def collect(self):
        output = io.StringIO()
        with patch.object(Path, "home", return_value=self.home), \
                patch("sys.argv", ["diagnostics", "Probe", "sim"]), \
                contextlib.chdir(self.home), contextlib.redirect_stdout(output):
            exec(compile(COLLECTOR, "extension-diagnostics", "exec"), {})
        return output.getvalue()

    def test_reports_exception_and_faulting_stack_after_metadata(self):
        body = {"procName": "Keyboard", "exception": {"type": "EXC_BAD_ACCESS"},
                "termination": {"indicator": "SIGSEGV"}, "faultingThread": 0,
                "threads": [{"frames": [{"symbol": "layoutSubviews"}]}]}
        (self.reports / "Keyboard-fixture.ips").write_text(
            json.dumps({"name": "Keyboard"}) + "\n" + json.dumps(body)
        )
        output = self.collect()
        self.assertIn("EXC_BAD_ACCESS", output)
        self.assertIn("SIGSEGV", output)
        self.assertIn("layoutSubviews", output)
        self.assertTrue((self.home / "build/Probe-crash-0.txt").exists())

    def test_accepts_a_single_json_object(self):
        (self.reports / "Keyboard-fixture.ips").write_text(json.dumps({
            "procName": "Keyboard", "termination": {"namespace": "JETSAM"}
        }))
        self.assertIn("JETSAM", self.collect())

    def test_reports_when_no_crashes_exist(self):
        self.assertEqual(self.collect(), "Keyboard crash reports: 0\n")

    def test_process_sample_output_is_bounded(self):
        (self.home / "build/Probe-process-1.sample.txt").write_text(
            "".join(f"stack-frame-{index}\n" for index in range(200))
        )
        output = self.collect()
        self.assertIn("stack-frame-139\n", output)
        self.assertNotIn("stack-frame-140\n", output)

    def test_bad_report_does_not_hide_action_logs(self):
        (self.reports / "Keyboard-fixture.ips").write_text("invalid report")
        (self.home / "build/Probe-process-1.sample.txt").mkdir()
        log = (self.home / "Library/Developer/CoreSimulator/Devices/sim/data/Containers"
               / "Data/PluginKitPlugin/fixture/Library/Caches/keyboard.log")
        log.parent.mkdir(parents=True)
        log.write_text("ready\n")
        output = self.collect()
        self.assertIn("unreadable report", output)
        self.assertIn("Keyboard process sample: unreadable report", output)
        self.assertIn("Recent neutral keyboard actions:\nready", output)


if __name__ == "__main__":
    unittest.main()
