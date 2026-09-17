#!/usr/bin/env python3
"""Deterministic contract tests for the strict source extraction utility."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from source_extract import (  # noqa: E402
    MarkerBlockSpec,
    SourceExtractionError,
    extract_marker_block,
    write_extraction,
)


BEGIN = "// BEGIN BLOCK"
END = "// END BLOCK"
LABEL = "contract-test-block"
LOGICAL_SOURCE = "fixtures/Source.swift"


def expect_failure(make_value, expected_fragment: str) -> None:
    try:
        make_value()
    except SourceExtractionError as error:
        assert expected_fragment in str(error), str(error)
    else:
        raise AssertionError(f"expected SourceExtractionError containing {expected_fragment!r}")


def spec(path: Path, *, label: str = LABEL, logical_path: str = LOGICAL_SOURCE) -> MarkerBlockSpec:
    return MarkerBlockSpec(
        label=label,
        source_path=path,
        logical_source_path=logical_path,
        start_marker=BEGIN,
        end_marker=END,
    )


def write(path: Path, data: bytes) -> None:
    path.write_bytes(data)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="source-extract-contract-") as temporary:
        directory = Path(temporary)
        source_path = directory / "one" / "Source.swift"
        source_path.parent.mkdir()
        original = (
            "prefix é\r\n"
            f"{BEGIN}\r\n"
            "line with exact bytes 🧭\r\n"
            f"{END}\r\n"
            "suffix\r\n"
        ).encode("utf-8")
        write(source_path, original)

        extraction = extract_marker_block(spec(source_path))
        expected_data = "\r\nline with exact bytes 🧭\r\n".encode("utf-8")
        assert extraction.data == expected_data
        assert extraction.source_sha256 == hashlib.sha256(original).hexdigest()
        assert extraction.extraction_sha256 == hashlib.sha256(expected_data).hexdigest()
        assert extraction.source_byte_count == len(original)
        assert extraction.extraction_byte_count == len(expected_data)
        assert extraction.start_match_count == 1
        assert extraction.end_match_count == 1
        assert extraction.manifest()["boundary_inclusion"] == {
            "start": "excluded",
            "end": "excluded",
        }

        write_extraction(
            extraction,
            directory / "output.swift",
            directory / "manifest.json",
        )
        assert (directory / "output.swift").read_bytes() == expected_data
        manifest_bytes = (directory / "manifest.json").read_bytes()
        assert manifest_bytes == extraction.manifest_bytes()
        manifest = json.loads(manifest_bytes)
        assert list(manifest) == sorted(manifest)
        assert str(directory) not in manifest_bytes.decode("utf-8")
        assert "timestamp" not in manifest
        assert "pid" not in manifest

        missing_start = directory / "missing-start.swift"
        write(missing_start, b"near // BEGIN BLOK\n// END BLOCK\n")
        expect_failure(lambda: extract_marker_block(spec(missing_start)), "start marker")

        missing_end = directory / "missing-end.swift"
        write(missing_end, f"{BEGIN}\ncontent\n".encode())
        expect_failure(lambda: extract_marker_block(spec(missing_end)), "end marker")

        duplicate_start = directory / "duplicate-start.swift"
        write(duplicate_start, f"{BEGIN}\n{BEGIN}\ncontent\n{END}\n".encode())
        expect_failure(lambda: extract_marker_block(spec(duplicate_start)), "found 2")

        duplicate_end = directory / "duplicate-end.swift"
        write(duplicate_end, f"{BEGIN}\ncontent\n{END}\n{END}\n".encode())
        expect_failure(lambda: extract_marker_block(spec(duplicate_end)), "found 2")

        end_before_start = directory / "end-before-start.swift"
        write(end_before_start, f"{END}\n{BEGIN}\ncontent\n".encode())
        expect_failure(lambda: extract_marker_block(spec(end_before_start)), "after start")

        empty = directory / "empty.swift"
        write(empty, f"{BEGIN}{END}".encode())
        expect_failure(lambda: extract_marker_block(spec(empty)), "empty extraction")

        outside_a = directory / "outside-a.swift"
        outside_b = directory / "outside-b.swift"
        bounded = f"{BEGIN}\nunchanged\n{END}\n".encode()
        write(outside_a, b"before-a\n" + bounded + b"after-a\n")
        write(outside_b, b"before-b and different\n" + bounded + b"after-b\n")
        extraction_a = extract_marker_block(spec(outside_a))
        extraction_b = extract_marker_block(spec(outside_b))
        assert extraction_a.data == extraction_b.data
        assert extraction_a.extraction_sha256 == extraction_b.extraction_sha256
        assert extraction_a.source_sha256 != extraction_b.source_sha256

        inside_changed = directory / "inside-changed.swift"
        write(inside_changed, f"before\n{BEGIN}\nchanged\n{END}\nafter\n".encode())
        changed = extract_marker_block(spec(inside_changed))
        assert changed.extraction_sha256 != extraction_a.extraction_sha256

        identical_one = directory / "different-path-a" / "Source.swift"
        identical_two = directory / "different-path-b" / "Source.swift"
        identical_one.parent.mkdir()
        identical_two.parent.mkdir()
        write(identical_one, original)
        write(identical_two, original)
        first = extract_marker_block(spec(identical_one))
        second = extract_marker_block(spec(identical_two))
        assert first.data == second.data
        assert first.extraction_sha256 == second.extraction_sha256
        assert first.manifest_bytes() == second.manifest_bytes()

        session_source_path = ROOT / "LifeRoute/LifeRouteIntelligenceCore.swift"
        session_source_bytes = session_source_path.read_bytes()
        session_source = session_source_bytes.decode("utf-8", errors="strict")
        session_start = "// BEGIN SESSION NOTE PRODUCTION INSTRUCTIONS"
        session_end = "// END SESSION NOTE PRODUCTION INSTRUCTIONS"
        legacy_data = session_source.split(session_start, 1)[1].split(session_end, 1)[0].encode("utf-8")
        session_extraction = extract_marker_block(
            MarkerBlockSpec(
                label="session-note-production-instructions",
                source_path=session_source_path,
                logical_source_path="LifeRoute/LifeRouteIntelligenceCore.swift",
                start_marker=session_start,
                end_marker=session_end,
            )
        )
        assert legacy_data == session_extraction.data
        assert hashlib.sha256(legacy_data).hexdigest() == session_extraction.extraction_sha256

    print("PASS source extraction contracts: strict marker blocks, byte/hash identity, deterministic provenance, Session Note shadow equality")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
