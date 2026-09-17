#!/usr/bin/env python3
"""Strict, deterministic extraction of bounded source text.

This module intentionally supports only exact marker blocks.  It is not a
Swift parser and does not provide regular-expression or declaration modes.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
from typing import Any


class SourceExtractionError(ValueError):
    """Raised when a source extraction boundary is not unambiguous."""


@dataclass(frozen=True)
class MarkerBlockSpec:
    """A strict exact-marker extraction request."""

    label: str
    source_path: Path
    logical_source_path: str
    start_marker: str
    end_marker: str
    include_start: bool = False
    include_end: bool = False

    @property
    def mode(self) -> str:
        return "marker_block"


@dataclass(frozen=True)
class Extraction:
    """Extracted bytes plus deterministic provenance."""

    label: str
    logical_source_path: str
    mode: str
    source_sha256: str
    extraction_sha256: str
    source_byte_count: int
    extraction_byte_count: int
    start_match_count: int
    end_match_count: int
    include_start: bool
    include_end: bool
    start_marker: str
    end_marker: str
    data: bytes

    def manifest(self) -> dict[str, Any]:
        """Return only stable, logical provenance fields."""

        return {
            "boundary_inclusion": {
                "end": "included" if self.include_end else "excluded",
                "start": "included" if self.include_start else "excluded",
            },
            "end_marker": self.end_marker,
            "end_match_count": self.end_match_count,
            "extraction_byte_count": self.extraction_byte_count,
            "extraction_sha256": self.extraction_sha256,
            "label": self.label,
            "logical_source_path": self.logical_source_path,
            "mode": self.mode,
            "schema_version": 1,
            "source_byte_count": self.source_byte_count,
            "source_sha256": self.source_sha256,
            "start_marker": self.start_marker,
            "start_match_count": self.start_match_count,
        }

    def manifest_bytes(self) -> bytes:
        """Serialize provenance deterministically with no incidental identity."""

        return (
            json.dumps(self.manifest(), indent=2, sort_keys=True, ensure_ascii=False)
            + "\n"
        ).encode("utf-8")


def _require_nonempty_marker(name: str, marker: str) -> None:
    if not marker:
        raise SourceExtractionError(f"{name} marker must not be empty")


def extract_marker_block(spec: MarkerBlockSpec) -> Extraction:
    """Extract one exact marker block and fail closed on every ambiguity."""

    _require_nonempty_marker("start", spec.start_marker)
    _require_nonempty_marker("end", spec.end_marker)
    if not spec.label:
        raise SourceExtractionError("logical extraction label must not be empty")
    if not spec.logical_source_path:
        raise SourceExtractionError("logical source path must not be empty")

    source_bytes = spec.source_path.read_bytes()
    try:
        source = source_bytes.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise SourceExtractionError(
            f"source is not valid UTF-8: {spec.source_path}"
        ) from error

    start_count = source.count(spec.start_marker)
    end_count = source.count(spec.end_marker)
    if start_count != 1:
        raise SourceExtractionError(
            f"expected exactly one start marker for {spec.label}, found {start_count}"
        )
    if end_count != 1:
        raise SourceExtractionError(
            f"expected exactly one end marker for {spec.label}, found {end_count}"
        )

    start_position = source.find(spec.start_marker)
    end_position = source.find(spec.end_marker)
    if end_position <= start_position:
        raise SourceExtractionError(
            f"end marker must occur after start marker for {spec.label}"
        )

    extraction_start = start_position if spec.include_start else start_position + len(spec.start_marker)
    extraction_end = end_position + len(spec.end_marker) if spec.include_end else end_position
    data = source[extraction_start:extraction_end].encode("utf-8")
    if not data:
        raise SourceExtractionError(
            f"empty extraction is not allowed for {spec.label}"
        )

    return Extraction(
        label=spec.label,
        logical_source_path=spec.logical_source_path,
        mode=spec.mode,
        source_sha256=hashlib.sha256(source_bytes).hexdigest(),
        extraction_sha256=hashlib.sha256(data).hexdigest(),
        source_byte_count=len(source_bytes),
        extraction_byte_count=len(data),
        start_match_count=start_count,
        end_match_count=end_count,
        include_start=spec.include_start,
        include_end=spec.include_end,
        start_marker=spec.start_marker,
        end_marker=spec.end_marker,
        data=data,
    )


def write_extraction(
    extraction: Extraction,
    output_path: Path,
    manifest_path: Path | None = None,
) -> None:
    """Write exact extracted bytes and, optionally, deterministic provenance."""

    output_path.write_bytes(extraction.data)
    if manifest_path is not None:
        manifest_path.write_bytes(extraction.manifest_bytes())


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--logical-source-path", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--mode", choices=["marker_block"], required=True)
    parser.add_argument("--start", dest="start_marker", required=True)
    parser.add_argument("--end", dest="end_marker", required=True)
    parser.add_argument("--include-start", action="store_true")
    parser.add_argument("--include-end", action="store_true")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    extraction = extract_marker_block(
        MarkerBlockSpec(
            label=args.label,
            source_path=args.source,
            logical_source_path=args.logical_source_path,
            start_marker=args.start_marker,
            end_marker=args.end_marker,
            include_start=args.include_start,
            include_end=args.include_end,
        )
    )
    write_extraction(extraction, args.output, args.manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
