#!/usr/bin/env python3
"""Safe path policy for reusable LifeRoute build scratch and checkpoints.

The command-line interface deliberately accepts scratch names, not arbitrary
deletion paths.  Callers that need a different home for disposable tests can
use the functions with an explicit fixture home; the production CLI always
resolves the approved root below the current user's home directory.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from typing import Iterable, Sequence


SCRATCH_COMPONENTS = ("Library", "Developer", "LifeRouteBuilds")
DEFAULT_DURABLE_COMPONENTS = (
    ("Documents", "LifeRouteCheckpoints"),
    ("Documents", "LifeRouteEvidence"),
)
GENERATED_DIRECTORY_NAMES = frozenset(
    {
        "DerivedData",
        "derived-data",
        "build",
        "builds",
        "ModuleCache.noindex",
        "Index.noindex",
        "CompilationCache.noindex",
        "SDKExplicitPrecompiledModules",
        "SDKStatCaches.noindex",
        "Intermediates.noindex",
    }
)


class StoragePolicyError(RuntimeError):
    """Raised when a path would cross a storage boundary."""


def _resolved(path: Path) -> Path:
    return path.expanduser().resolve(strict=False)


def _inside(path: Path, root: Path, *, allow_root: bool = True) -> bool:
    try:
        relative = path.relative_to(root)
    except ValueError:
        return False
    return allow_root or relative != Path(".")


def scratch_root(home: Path | None = None) -> Path:
    base = _resolved(home if home is not None else Path.home())
    return base.joinpath(*SCRATCH_COMPONENTS)


def durable_roots(home: Path | None = None) -> tuple[Path, ...]:
    base = _resolved(home if home is not None else Path.home())
    return tuple(base.joinpath(*components) for components in DEFAULT_DURABLE_COMPONENTS)


def _safe_relative_name(value: str) -> tuple[str, ...]:
    candidate = Path(value)
    if candidate.is_absolute() or not value or any(part in ("", ".", "..") for part in candidate.parts):
        raise StoragePolicyError("scratch names must be non-empty relative paths without '.' or '..'")
    return candidate.parts


def scratch_path(name: str, *, home: Path | None = None) -> Path:
    root = _resolved(scratch_root(home))
    candidate = _resolved(root.joinpath(*_safe_relative_name(name)))
    if not _inside(candidate, root, allow_root=False):
        raise StoragePolicyError(f"scratch path escapes approved root: {candidate}")
    return candidate


def validate_scratch_path(path: Path, *, approved_root: Path | None = None) -> Path:
    """Validate an existing or future path without permitting a root target."""
    root = _resolved(approved_root if approved_root is not None else scratch_root())
    candidate = _resolved(path)
    if not _inside(candidate, root, allow_root=False):
        raise StoragePolicyError(f"path must be inside approved scratch root: {candidate}")
    return candidate


def _git_root() -> Path | None:
    try:
        value = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    return _resolved(Path(value)) if value else None


def protected_roots(
    *,
    home: Path | None = None,
    repository_root: Path | None = None,
    extra_roots: Iterable[Path] = (),
) -> tuple[Path, ...]:
    roots = list(durable_roots(home))
    git_root = _resolved(repository_root) if repository_root is not None else _git_root()
    if git_root is not None:
        roots.append(git_root)
    roots.extend(_resolved(root) for root in extra_roots)
    return tuple(dict.fromkeys(roots))


def _reject_symlinks(root: Path) -> None:
    """Refuse a closeout tree containing symlinks instead of following them."""
    if root.is_symlink():
        raise StoragePolicyError(f"refusing symlink closeout target: {root}")
    for current, directories, files in os.walk(root, topdown=True, followlinks=False):
        current_path = Path(current)
        linked_directories = [current_path / name for name in directories if (current_path / name).is_symlink()]
        linked_files = [current_path / name for name in files if (current_path / name).is_symlink()]
        if linked_directories or linked_files:
            linked = linked_directories + linked_files
            raise StoragePolicyError(f"refusing closeout tree containing symlink(s): {linked[0]}")


def validate_closeout_target(
    target: Path,
    *,
    approved_root: Path,
    protected: Sequence[Path] = (),
) -> Path:
    root = _resolved(approved_root)
    resolved_target = _resolved(target)
    if not _inside(resolved_target, root, allow_root=False):
        raise StoragePolicyError(f"closeout target must be inside approved scratch root: {resolved_target}")
    for protected_root in protected:
        protected_path = _resolved(protected_root)
        if _inside(resolved_target, protected_path) or _inside(protected_path, resolved_target):
            raise StoragePolicyError(f"closeout target overlaps protected root: {protected_path}")
    if not resolved_target.exists() or not resolved_target.is_dir():
        raise StoragePolicyError(f"closeout target must be an existing directory: {resolved_target}")
    _reject_symlinks(resolved_target)
    return resolved_target


def _tree_summary(root: Path) -> dict[str, int | str]:
    files = 0
    directories = 0
    bytes_total = 0
    for current, directory_names, file_names in os.walk(root, topdown=True, followlinks=False):
        directories += len(directory_names)
        for name in file_names:
            path = Path(current) / name
            files += 1
            bytes_total += path.stat().st_size
    return {"path": str(root), "files": files, "directories": directories, "bytes": bytes_total}


def closeout_scratch(
    target: Path,
    *,
    approved_root: Path,
    protected: Sequence[Path] = (),
    dry_run: bool = True,
    confirm: bool = False,
) -> dict[str, int | str | bool]:
    safe_target = validate_closeout_target(target, approved_root=approved_root, protected=protected)
    if not dry_run and not confirm:
        raise StoragePolicyError("closeout requires --confirm; use --dry-run to inspect")
    report = _tree_summary(safe_target)
    report["dry_run"] = dry_run
    if not dry_run:
        shutil.rmtree(safe_target)
        report["removed"] = True
    else:
        report["removed"] = False
    return report


def _is_generated_directory(path: Path) -> bool:
    return path.name in GENERATED_DIRECTORY_NAMES


def _copy_tree_without_generated_scratch(source: Path, destination: Path) -> list[str]:
    skipped: list[str] = []
    destination.mkdir(parents=True, exist_ok=False)
    for current, directory_names, file_names in os.walk(source, topdown=True, followlinks=False):
        current_path = Path(current)
        kept_directories: list[str] = []
        for name in directory_names:
            source_path = current_path / name
            if source_path.is_symlink():
                raise StoragePolicyError(f"checkpoint source contains symlink: {source_path}")
            if _is_generated_directory(source_path):
                skipped.append(str(source_path.relative_to(source)))
            else:
                kept_directories.append(name)
        directory_names[:] = kept_directories
        relative = current_path.relative_to(source)
        output_directory = destination / relative
        output_directory.mkdir(parents=True, exist_ok=True)
        for name in file_names:
            source_path = current_path / name
            if source_path.is_symlink():
                raise StoragePolicyError(f"checkpoint source contains symlink: {source_path}")
            shutil.copy2(source_path, output_directory / name)
    return skipped


def copy_checkpoint(
    source: Path,
    destination: Path,
    *,
    durable: Sequence[Path],
    artifacts: Sequence[Path] = (),
) -> dict[str, object]:
    source_path = _resolved(source)
    destination_path = _resolved(destination)
    if not source_path.is_dir():
        raise StoragePolicyError(f"checkpoint source must be an existing directory: {source_path}")
    if not any(_inside(destination_path, _resolved(root), allow_root=False) for root in durable):
        raise StoragePolicyError(f"checkpoint destination must be inside an approved durable root: {destination_path}")
    if _inside(destination_path, source_path) or _inside(source_path, destination_path):
        raise StoragePolicyError("checkpoint source and destination must not contain one another")
    if destination_path.exists():
        raise StoragePolicyError(f"checkpoint destination already exists: {destination_path}")

    skipped = _copy_tree_without_generated_scratch(source_path, destination_path)
    copied_artifacts: list[str] = []
    if artifacts:
        artifact_directory = destination_path / "artifacts"
        artifact_directory.mkdir()
        for artifact in artifacts:
            artifact_path = _resolved(artifact)
            if not artifact_path.is_file() or artifact_path.is_symlink():
                raise StoragePolicyError(f"explicit artifact must be a regular file: {artifact_path}")
            output = artifact_directory / artifact_path.name
            if output.exists():
                raise StoragePolicyError(f"duplicate artifact name: {output.name}")
            shutil.copy2(artifact_path, output)
            copied_artifacts.append(str(output.relative_to(destination_path)))

    manifest = {
        "policy": "LifeRoute durable checkpoint v1",
        "source": str(source_path),
        "destination": str(destination_path),
        "excluded_generated_directories": sorted(set(skipped)),
        "explicit_artifacts": copied_artifacts,
        "source_tree_sha256": _tree_digest(destination_path),
    }
    (destination_path / "CHECKPOINT_COPY_MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def _tree_digest(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        if path.name == "CHECKPOINT_COPY_MANIFEST.json" or not path.is_file():
            continue
        digest.update(str(path.relative_to(root)).encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("scratch-root", help="print the approved reusable scratch root")

    checkpoint = subparsers.add_parser("checkpoint-copy", help="copy durable evidence while excluding generated scratch")
    checkpoint.add_argument("source", type=Path)
    checkpoint.add_argument("destination", type=Path)
    checkpoint.add_argument("--artifact", action="append", type=Path, default=[])

    closeout = subparsers.add_parser("closeout", help="inspect or remove one named scratch directory")
    closeout.add_argument("name", help="relative name below the approved scratch root")
    mode = closeout.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="inspect only (default)")
    mode.add_argument("--confirm", action="store_true", help="remove after all guards pass")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "scratch-root":
            print(scratch_root())
            return 0
        if args.command == "checkpoint-copy":
            manifest = copy_checkpoint(
                args.source,
                args.destination,
                durable=durable_roots(),
                artifacts=args.artifact,
            )
            print(json.dumps(manifest, indent=2))
            return 0

        target = scratch_path(args.name)
        report = closeout_scratch(
            target,
            approved_root=scratch_root(),
            protected=protected_roots(),
            dry_run=not args.confirm,
            confirm=args.confirm,
        )
        print(json.dumps(report, indent=2))
        return 0
    except StoragePolicyError as error:
        print(f"LifeRoute storage policy refused operation: {error}", file=os.sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
