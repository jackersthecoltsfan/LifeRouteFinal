#!/usr/bin/env python3
"""Focused tests for the fail-closed Xcode warning assessor."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ASSESSOR = ROOT / "scripts" / "assess_xcode_warnings.py"


class AssessXcodeWarningsTests(unittest.TestCase):
    def run_assessor(self, debug: str, release: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            debug_path = Path(directory) / "debug.log"
            release_path = Path(directory) / "release.log"
            debug_path.write_text(debug, encoding="utf-8")
            release_path.write_text(release, encoding="utf-8")
            environment = dict(os.environ)
            environment["PYTHONDONTWRITEBYTECODE"] = "1"
            return subprocess.run(
                [sys.executable, str(ASSESSOR), str(debug_path), str(release_path)],
                check=False,
                capture_output=True,
                text=True,
                env=environment,
            )

    def test_both_known_app_intents_spellings_are_non_blocking(self) -> None:
        result = self.run_assessor(
            "warning: Metadata extraction skipped. No AppIntents.framework dependency found.\n",
            "2026 appintentsmetadataprocessor warning: Metadata extraction skipped, no AppIntents.framework dependency found\n",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Known Xcode no-AppIntents notice lines: 2", result.stdout)
        self.assertIn("Unexpected compiler warning lines: 0", result.stdout)

    def test_signed_widget_strip_notice_remains_blocking_and_visible(self) -> None:
        result = self.run_assessor(
            "warning: not stripping binary because it is signed: LifeRouteLiveActivityWidget.appex/LifeRouteLiveActivityWidget\n",
            "",
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("not stripping binary because it is signed", result.stderr)

    def test_unexpected_warning_remains_blocking(self) -> None:
        result = self.run_assessor("warning: synthetic unexpected warning\n", "")
        self.assertEqual(result.returncode, 1)
        self.assertIn("synthetic unexpected warning", result.stderr)


if __name__ == "__main__":
    unittest.main()
