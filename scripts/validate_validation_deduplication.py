#!/usr/bin/env python3
"""Focused contract for the Phase 5D controlled reuse modes."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    prepare = read("scripts/prepare_build.sh")
    full = read("scripts/validate_full.sh")
    semantic = read("scripts/validate_current.py")
    smoke = read("scripts/run_simulator_smoke.sh")
    timer = read("scripts/run_visual_timer_feedback_contract_tests.sh")
    workflow = read(".github/workflows/ios-ci.yml")
    catalogue = json.loads(read("scripts/qualification_catalogue.json"))

    require("LIFEROUTE_PREPARE_SKIP_FAST" in prepare, "prepare guard missing")
    require("bash scripts/validate_fast.sh" in prepare, "prepare default fast path missing")
    require("LIFEROUTE_FULL_SKIP_FAST" in full, "full guard missing")
    require("run_fast(sources)" in semantic, "standalone full fast prerequisite missing")
    require("LIFEROUTE_SKIP_FAST_VALIDATION" in semantic, "full guarded skip missing")
    require("LIFEROUTE_SIMULATOR_RUNTIME_ONLY" in smoke, "Simulator runtime-only guard missing")
    require("run_session_note_contract_tests.sh" in smoke, "smoke default contract path missing")
    require("LIFEROUTE_VISUAL_TIMER_NATIVE_ONLY" in timer, "native-only Timer guard missing")
    require('"Visual Timer feedback"' in timer, "Timer default contract path missing")

    for token in (
        "LIFEROUTE_VALIDATION_SOURCE_SHA",
        "LIFEROUTE_VALIDATION_SOURCE_TREE",
        "Q-SEM-FULL",
    ):
        require(token in smoke, f"smoke identity safeguard missing: {token}")
        require(token in timer, f"Timer identity safeguard missing: {token}")
    for token in (
        "LIFEROUTE_VALIDATION_SOURCE_SHA",
        "LIFEROUTE_VALIDATION_SOURCE_TREE",
        "Q-PREP",
    ):
        require(token in full, f"full identity safeguard missing: {token}")

    require("name: Run fast validation" not in workflow, "duplicate direct fast step remains")
    require("source_sha: ${{ steps.source_identity.outputs.sha }}" in workflow, "source SHA output missing")
    require("LIFEROUTE_FULL_SKIP_FAST: '1'" in workflow, "full CI reuse mode missing")
    require("LIFEROUTE_PREPARE_SKIP_FAST: '1'" in workflow, "native prepare reuse mode missing")
    require("LIFEROUTE_SIMULATOR_RUNTIME_ONLY: '1'" in workflow, "runtime-only CI mode missing")

    dedup = catalogue.get("deduplication", {})
    require(dedup.get("normalIosCiEvent"), "catalogue invocation map missing")
    require(dedup["normalIosCiEvent"]["Q-SEM-FAST"]["before"] == 4, "Q-SEM-FAST before count drifted")
    require(dedup["normalIosCiEvent"]["Q-SEM-FAST"]["after"] == 1, "Q-SEM-FAST after count drifted")
    require(dedup["normalIosCiEvent"]["simulatorContractPrelude"]["before"] == 9, "smoke before count drifted")
    require(dedup["normalIosCiEvent"]["simulatorContractPrelude"]["after"] == 0, "smoke after count drifted")
    require(dedup["uniqueAvoidedExecutions"] == 13, "unique avoided count drifted")

    print("controlled validation deduplication contract: PASS")
    print("default local modes remain self-contained: PASS")
    print("CI reuse modes require named gate plus exact SHA/tree: PASS")
    print("catalogue invocation map: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
