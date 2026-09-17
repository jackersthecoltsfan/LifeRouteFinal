#!/usr/bin/env python3
"""Fixture-only tests for LifeRoute scratch/evidence storage boundaries."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from liferoute_storage import (
    StoragePolicyError,
    closeout_scratch,
    copy_checkpoint,
    durable_roots,
    scratch_path,
    scratch_root,
    validate_closeout_target,
)


ROOT = Path(__file__).resolve().parents[1]


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="liferoute-storage-fixture-") as temporary:
        home = Path(temporary)
        scratch = scratch_root(home)
        durable = durable_roots(home)[0]
        scratch.mkdir(parents=True)
        durable.mkdir(parents=True)

        expect(scratch_path("LifeRoute/Debug-iphonesimulator", home=home).is_relative_to(scratch),
               "scratch paths resolve below the approved LifeRouteBuilds root")
        source = home / "run-input"
        (source / "receipts").mkdir(parents=True)
        (source / "receipts" / "receipt.log").write_text("durable evidence\n")
        (source / "DerivedData" / "Build").mkdir(parents=True)
        (source / "DerivedData" / "Build" / "routine.o").write_text("disposable\n")
        artifact = scratch / "LifeRoute" / "Release" / "LifeRoute.ipa"
        artifact.parent.mkdir(parents=True)
        artifact.write_bytes(b"final signed artifact fixture")

        destination = durable / "run-1"
        manifest = copy_checkpoint(source, destination, durable=(durable,), artifacts=(artifact,))
        expect((destination / "receipts" / "receipt.log").read_text() == "durable evidence\n",
               "durable evidence remains retained")
        expect(not (destination / "DerivedData").exists(),
               "routine DerivedData is excluded from checkpoint copies")
        expect((destination / "artifacts" / "LifeRoute.ipa").read_bytes() == artifact.read_bytes(),
               "explicit final artifacts are retained separately")
        expect(manifest["excluded_generated_directories"] == ["DerivedData"],
               "checkpoint manifest records the generated exclusion")
        saved_manifest = json.loads((destination / "CHECKPOINT_COPY_MANIFEST.json").read_text())
        expect(saved_manifest["explicit_artifacts"] == ["artifacts/LifeRoute.ipa"],
               "checkpoint manifest records explicit artifacts")

        target = scratch / "LifeRoute" / "Debug-iphonesimulator"
        (target / "Build").mkdir(parents=True)
        (target / "Build" / "intermediate.o").write_text("fixture scratch\n")
        dry_run = closeout_scratch(target, approved_root=scratch, protected=(durable,), dry_run=True)
        expect(dry_run["removed"] is False and target.exists(), "dry-run preserves scratch")
        removed = closeout_scratch(target, approved_root=scratch, protected=(durable,), dry_run=False, confirm=True)
        expect(removed["removed"] is True and not target.exists(), "confirmed fixture closeout removes scratch")

        for outside in (durable / "run-1", ROOT, home / "elsewhere"):
            outside.mkdir(parents=True, exist_ok=True)
            try:
                validate_closeout_target(outside, approved_root=scratch, protected=(durable, ROOT))
            except StoragePolicyError:
                pass
            else:
                raise AssertionError(f"outside closeout target was accepted: {outside}")

        cli_target = scratch / "cli-check"
        cli_target.mkdir()
        cli = subprocess.run(
            [sys.executable, str(ROOT / "scripts/liferoute_storage.py"), "closeout", "cli-check"],
            env={**dict(os.environ), "HOME": str(home)},
            text=True,
            capture_output=True,
        )
        expect(cli.returncode == 0 and cli_target.exists(), "CLI closeout defaults to dry-run")
        outside_cli = subprocess.run(
            [sys.executable, str(ROOT / "scripts/liferoute_storage.py"), "closeout", "../outside"],
            env={**dict(os.environ), "HOME": str(home)},
            text=True,
            capture_output=True,
        )
        expect(outside_cli.returncode == 2 and cli_target.exists(),
               "CLI rejects a path traversal closeout without touching the fixture")

    print("LifeRoute storage contract tests passed: scratch, filtered checkpoint, evidence retention, guarded closeout")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
