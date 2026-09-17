#!/usr/bin/env python3
"""Check automatic catalogue dependencies against the iOS CI path filters.

This is deliberately a narrow consistency check. It does not infer execution
graphs, expand shell commands, or promote specialized validators. The
catalogue remains the source of declared gate dependencies; this script only
checks that those declarations are present, resolvable, acyclic, and covered
by both path-filtered iOS CI events.
"""

from __future__ import annotations

import fnmatch
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CATALOGUE = ROOT / "scripts" / "qualification_catalogue.json"
IOS_WORKFLOW = ROOT / ".github" / "workflows" / "ios-ci.yml"
IOS_WORKFLOW_ID = ".github/workflows/ios-ci.yml"


class CoverageError(RuntimeError):
    pass


def repository_path(value: str) -> Path:
    if value.startswith("/") or ".." in Path(value).parts:
        raise CoverageError(f"dependency must be repository-relative: {value}")
    return ROOT / value


def extract_event_paths(text: str, event: str) -> list[str]:
    """Read the simple `on.<event>.paths` shape used by this repository.

    GitHub workflow syntax is intentionally not reimplemented here. The parser
    fails closed if the expected shape changes, so a workflow edit cannot make
    this checker silently report coverage from the wrong block.
    """

    lines = text.splitlines()
    event_start = re.compile(rf"^  {re.escape(event)}:\s*$")
    event_end = re.compile(r"^  [A-Za-z0-9_-]+:\s*$")
    paths_header = re.compile(r"^    paths:\s*$")
    item = re.compile(r"^      -\s+(['\"])(.*)\1\s*$")
    start = next((i for i, line in enumerate(lines) if event_start.match(line)), None)
    if start is None:
        raise CoverageError(f"workflow is missing on.{event}")

    paths_start = None
    for i in range(start + 1, len(lines)):
        line = lines[i]
        if event_end.match(line):
            break
        if paths_header.match(line):
            paths_start = i
            break
    if paths_start is None:
        raise CoverageError(f"workflow is missing on.{event}.paths")

    paths: list[str] = []
    for line in lines[paths_start + 1 :]:
        if event_end.match(line):
            break
        if not line.strip():
            continue
        match = item.match(line)
        if not match:
            raise CoverageError(f"unrecognized path-filter line in on.{event}: {line!r}")
        paths.append(match.group(2))
    if not paths:
        raise CoverageError(f"on.{event}.paths is empty")
    return paths


def all_gate_ids(gates: list[dict[str, Any]]) -> set[str]:
    ids = [gate.get("id") for gate in gates]
    if any(not isinstance(value, str) or not value for value in ids):
        raise CoverageError("every gate must have a non-empty string id")
    if len(ids) != len(set(ids)):
        raise CoverageError("gate IDs are not unique")
    return set(ids)


def check_prerequisites(gates: list[dict[str, Any]], ids: set[str]) -> None:
    graph = {gate["id"]: gate.get("prerequisiteGateIDs", []) for gate in gates}
    for gate_id, prerequisites in graph.items():
        if not isinstance(prerequisites, list):
            raise CoverageError(f"{gate_id}.prerequisiteGateIDs must be a list")
        missing = [item for item in prerequisites if item not in ids]
        if missing:
            raise CoverageError(f"{gate_id} references unknown prerequisites: {missing}")

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(gate_id: str) -> None:
        if gate_id in visiting:
            raise CoverageError(f"circular prerequisite graph at {gate_id}")
        if gate_id in visited:
            return
        visiting.add(gate_id)
        for prerequisite in graph[gate_id]:
            visit(prerequisite)
        visiting.remove(gate_id)
        visited.add(gate_id)

    for gate_id in graph:
        visit(gate_id)


def check_paths_exist(catalogue: dict[str, Any]) -> None:
    for gate in catalogue["gates"]:
        for dependency in gate.get("dependencies", []):
            if not isinstance(dependency, str):
                raise CoverageError(f"{gate['id']} has a non-string dependency")
            path = repository_path(dependency)
            if not path.exists():
                raise CoverageError(f"{gate['id']} references missing path: {dependency}")
    for entry in catalogue.get("specializedManualValidators", []):
        path_value = entry.get("path")
        if not isinstance(path_value, str) or not repository_path(path_value).exists():
            raise CoverageError(f"specialized validator path is missing: {path_value}")
        if entry.get("automatic") is not False:
            raise CoverageError(f"specialized validator is not explicitly manual: {path_value}")


def main() -> int:
    try:
        catalogue = json.loads(CATALOGUE.read_text())
        gates = catalogue["gates"]
        if not isinstance(gates, list):
            raise CoverageError("catalogue.gates must be a list")
        ids = all_gate_ids(gates)
        check_prerequisites(gates, ids)
        check_paths_exist(catalogue)

        workflow_text = IOS_WORKFLOW.read_text()
        push_paths = extract_event_paths(workflow_text, "push")
        pull_request_paths = extract_event_paths(workflow_text, "pull_request")

        automatic = [
            gate
            for gate in gates
            if gate.get("automatic") is True
            and IOS_WORKFLOW_ID in gate.get("workflow", [])
        ]
        required = sorted(
            {
                dependency
                for gate in automatic
                for dependency in gate.get("dependencies", [])
                if dependency != IOS_WORKFLOW_ID
            }
        )
        missing_push = [
            path for path in required if not any(fnmatch.fnmatchcase(path, pattern) for pattern in push_paths)
        ]
        missing_pull = [
            path
            for path in required
            if not any(fnmatch.fnmatchcase(path, pattern) for pattern in pull_request_paths)
        ]
        if missing_push or missing_pull:
            if missing_push:
                raise CoverageError(f"missing push coverage: {missing_push}")
            raise CoverageError(f"missing pull_request coverage: {missing_pull}")

        automatic_dependencies = set(required)
        specialized = catalogue.get("specializedManualValidators", [])
        accidental = sorted(
            entry["path"] for entry in specialized if entry["path"] in automatic_dependencies
        )
        if accidental:
            raise CoverageError(f"manual validators promoted into automatic dependencies: {accidental}")

        print(f"catalogue gates: {len(gates)}")
        print(f"automatic iOS CI gates: {len(automatic)}")
        print(f"automatic dependency paths covered: {len(required)}")
        print(f"specialized/manual validators preserved: {len(specialized)}")
        print("push and pull_request coverage: PASS")
        print("prerequisite graph: PASS")
        print("repository path existence: PASS")
        print("manual-only separation: PASS")
        return 0
    except (OSError, json.JSONDecodeError, KeyError, TypeError, CoverageError) as error:
        print(f"CI dependency coverage: FAIL CLOSED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
