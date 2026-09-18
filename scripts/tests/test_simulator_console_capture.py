import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from simulator_console_capture import CAPTURE_INCOMPLETE, FAIL, PASS, capture_simctl_launch, classify_capture


class SimulatorConsoleCaptureTests(unittest.TestCase):
    def test_positive_pass_fixture_requires_existing_pass_marker(self):
        state, marker = classify_capture(
            "trace\nROOT_OWNERSHIP_TEST_PASS 482 assertions",
            ("ROOT_OWNERSHIP_TEST_PASS",),
            ("ROOT_OWNERSHIP_TEST_FAIL",),
        )
        self.assertEqual((state, marker), (PASS, "ROOT_OWNERSHIP_TEST_PASS 482 assertions"))

    def test_explicit_fail_fixture_remains_fail(self):
        state, marker = classify_capture(
            "ROOT_OWNERSHIP_TEST_FAIL 7: assertion",
            ("ROOT_OWNERSHIP_TEST_PASS",),
            ("ROOT_OWNERSHIP_TEST_FAIL",),
        )
        self.assertEqual((state, marker), (FAIL, "ROOT_OWNERSHIP_TEST_FAIL 7: assertion"))

    def test_missing_output_is_incomplete_not_pass(self):
        state, marker = classify_capture("", ("ROOT_OWNERSHIP_TEST_PASS",), ("ROOT_OWNERSHIP_TEST_FAIL",))
        self.assertEqual((state, marker), (CAPTURE_INCOMPLETE, None))

    def test_partial_output_is_incomplete_not_pass(self):
        state, marker = classify_capture(
            "LIFEROUTE_ROOT_OWNERSHIP {\"event\":\"created\"}",
            ("ROOT_OWNERSHIP_TEST_PASS",),
            ("ROOT_OWNERSHIP_TEST_FAIL",),
        )
        self.assertEqual((state, marker), (CAPTURE_INCOMPLETE, None))

    def test_failure_marker_cannot_be_promoted_by_a_later_pass(self):
        state, marker = classify_capture(
            "ROOT_OWNERSHIP_TEST_FAIL 1: assertion\nROOT_OWNERSHIP_TEST_PASS 482 assertions",
            ("ROOT_OWNERSHIP_TEST_PASS",),
            ("ROOT_OWNERSHIP_TEST_FAIL",),
        )
        self.assertEqual(state, FAIL)
        self.assertEqual(marker, "ROOT_OWNERSHIP_TEST_FAIL 1: assertion")

    def test_timed_out_console_fallback_is_incomplete(self):
        fake_simctl = (sys.executable, "-c", "import time; time.sleep(0.20)")
        with tempfile.TemporaryDirectory(prefix="simulator-console-test-") as directory:
            root = Path(directory)
            result = capture_simctl_launch(
                simulator="synthetic-device",
                bundle_id="synthetic.bundle",
                arguments=(),
                stdout_path=root / "stdout.log",
                stderr_path=root / "stderr.log",
                timeout_seconds=0.02,
                redirect_probe_seconds=0.01,
                simctl_command=fake_simctl,
                pass_markers=("PASS",),
                fail_markers=("FAIL",),
                cwd=root,
            )
        self.assertEqual(result.state, CAPTURE_INCOMPLETE)
        self.assertEqual(result.mode, "direct-console")
        self.assertIn("timed out", result.reason)


if __name__ == "__main__":
    unittest.main()
