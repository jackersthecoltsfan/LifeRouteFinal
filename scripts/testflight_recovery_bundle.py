#!/usr/bin/env python3
"""Build a fail-closed, secret-free TestFlight recovery bundle.

The live LifeRoute TestFlight workflow runs this after archive/export and
before the Apple upload.  The bundle contains the shipped IPA, the matching
application and widget dSYMs, and a deliberately allow-listed archive
equivalent containing symbol/reconstruction metadata.  It never copies
signing keys, profiles, or the runner environment.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


SHA1_RE = re.compile(r"^[0-9a-f]{40}$")
UUID_RE = re.compile(
    r"\b[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\b"
)
PROHIBITED_NAME_RE = re.compile(
    r"(?:\.p8$|\.pem$|\.key$|\.env$|private|credential|secret|provision)",
    re.IGNORECASE,
)


class BundleError(RuntimeError):
    """A required recovery-bundle invariant failed."""


def fail(message: str) -> None:
    raise BundleError(message)


def require_directory(path: Path, label: str) -> None:
    if not path.is_dir():
        fail(f"Required {label} directory is missing: {path}")


def require_file(path: Path, label: str) -> None:
    if not path.is_file():
        fail(f"Required {label} file is missing: {path}")


def read_plist(path: Path, label: str) -> dict[str, Any]:
    require_file(path, label)
    try:
        with path.open("rb") as handle:
            value = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException) as error:
        fail(f"Unable to read {label} plist {path}: {error}")
    if not isinstance(value, dict):
        fail(f"{label} plist is not a dictionary: {path}")
    return value


def identity_from_plist(plist: dict[str, Any], label: str) -> dict[str, str]:
    fields = {
        "bundleIdentifier": plist.get("CFBundleIdentifier"),
        "marketingVersion": plist.get("CFBundleShortVersionString"),
        "buildNumber": plist.get("CFBundleVersion"),
        "executable": plist.get("CFBundleExecutable"),
    }
    missing = [key for key, value in fields.items() if not isinstance(value, str) or not value]
    if missing:
        fail(f"{label} plist is missing required fields: {', '.join(missing)}")
    return {key: str(value) for key, value in fields.items()}


def check_identity(
    actual: dict[str, str],
    expected_bundle_id: str,
    expected_version: str,
    expected_build: str,
    label: str,
) -> None:
    expected = {
        "bundleIdentifier": expected_bundle_id,
        "marketingVersion": expected_version,
        "buildNumber": expected_build,
    }
    mismatches = [
        f"{key}={actual[key]!r} (expected {value!r})"
        for key, value in expected.items()
        if actual.get(key) != value
    ]
    if mismatches:
        fail(f"{label} identity mismatch: {'; '.join(mismatches)}")


def extract_uuids(tool: str, path: Path, label: str) -> list[str]:
    try:
        result = subprocess.run(
            [tool, "--uuid", str(path)],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as error:
        fail(f"Unable to run {tool} for {label} {path}: {error}")
    output = f"{result.stdout}\n{result.stderr}"
    if result.returncode != 0:
        fail(f"UUID extraction failed for {label} {path}: {output.strip()}")
    uuids = sorted({match.upper() for match in UUID_RE.findall(output)})
    if not uuids:
        fail(f"No Mach-O UUIDs found for {label}: {path}")
    return uuids


def locate_dsym(
    dsym_root: Path,
    binary_uuids: list[str],
    label: str,
    uuid_tool: str,
) -> tuple[Path, list[str]]:
    require_directory(dsym_root, "archive dSYMs")
    candidates = sorted(path for path in dsym_root.rglob("*.dSYM") if path.is_dir())
    if not candidates:
        fail(f"No dSYM bundles exist under archive dSYMs: {dsym_root}")

    matches: list[tuple[Path, list[str]]] = []
    extraction_errors: list[str] = []
    for candidate in candidates:
        try:
            candidate_uuids = extract_uuids(uuid_tool, candidate, f"{label} dSYM")
        except BundleError as error:
            extraction_errors.append(str(error))
            continue
        if set(binary_uuids).issubset(candidate_uuids):
            matches.append((candidate, candidate_uuids))

    if len(matches) != 1:
        detail = "; ".join(extraction_errors[:2])
        if len(matches) == 0:
            fail(
                f"No {label} dSYM matched binary UUIDs {binary_uuids} under {dsym_root}."
                + (f" Extraction details: {detail}" if detail else "")
            )
        fail(f"Multiple {label} dSYMs matched binary UUIDs {binary_uuids}: {matches}")
    return matches[0]


def archive_identity(
    archive: Path, app_bundle_id: str, widget_bundle_id: str | None
) -> tuple[dict[str, str], dict[str, str], Path, Path | None]:
    products = archive / "Products" / "Applications"
    require_directory(products, "archive products")

    app_candidates = sorted(path for path in products.glob("*.app") if path.is_dir())
    app_matches: list[tuple[Path, dict[str, str]]] = []
    for app in app_candidates:
        plist = read_plist(app / "Info.plist", "application")
        identity = identity_from_plist(plist, "application")
        if identity["bundleIdentifier"] == app_bundle_id:
            app_matches.append((app, identity))
    if len(app_matches) != 1:
        fail(f"Expected exactly one archived app with bundle ID {app_bundle_id}; found {len(app_matches)}")
    app_path, app_identity = app_matches[0]
    app_binary = app_path / app_identity["executable"]
    require_file(app_binary, "application Mach-O")

    widget_path: Path | None = None
    widget_identity: dict[str, str] | None = None
    if widget_bundle_id:
        widget_candidates = sorted(path for path in app_path.rglob("*.appex") if path.is_dir())
        widget_matches: list[tuple[Path, dict[str, str]]] = []
        for widget in widget_candidates:
            plist = read_plist(widget / "Info.plist", "widget")
            identity = identity_from_plist(plist, "widget")
            if identity["bundleIdentifier"] == widget_bundle_id:
                widget_matches.append((widget, identity))
        if len(widget_matches) != 1:
            fail(
                f"Expected exactly one archived widget with bundle ID {widget_bundle_id}; "
                f"found {len(widget_matches)}"
            )
        widget_path, widget_identity = widget_matches[0]
        require_file(widget_path / widget_identity["executable"], "widget Mach-O")

    return app_identity, widget_identity or {}, app_path, widget_path


def ipa_plists(ipa: Path) -> tuple[dict[str, Any], dict[str, Any], str, str]:
    require_file(ipa, "exported IPA")
    try:
        archive = zipfile.ZipFile(ipa)
    except (OSError, zipfile.BadZipFile) as error:
        fail(f"Exported IPA is not a readable ZIP archive: {ipa}: {error}")
    with archive:
        names = set(archive.namelist())
        app_plist_names = sorted(name for name in names if name.startswith("Payload/") and name.endswith(".app/Info.plist"))
        if len(app_plist_names) != 1:
            fail(f"Expected exactly one app Info.plist in IPA; found {app_plist_names}")
        app_plist_name = app_plist_names[0]
        app_prefix = app_plist_name[: -len("Info.plist")]
        try:
            app_plist = plistlib.loads(archive.read(app_plist_name))
        except (KeyError, plistlib.InvalidFileException) as error:
            fail(f"Unable to read IPA application plist {app_plist_name}: {error}")
        widget_plist_names = sorted(
            name for name in names if name.startswith(app_prefix) and name.endswith(".appex/Info.plist")
        )
        widget_plist: dict[str, Any] = {}
        widget_plist_name = ""
        if widget_plist_names:
            widget_plist_name = widget_plist_names[0]
            try:
                widget_plist = plistlib.loads(archive.read(widget_plist_name))
            except (KeyError, plistlib.InvalidFileException) as error:
                fail(f"Unable to read IPA widget plist {widget_plist_name}: {error}")
        return app_plist, widget_plist, app_plist_name, widget_plist_name


def compare_ipa_identity(
    ipa: Path,
    app_bundle_id: str,
    widget_bundle_id: str | None,
    version: str,
    build: str,
    app_executable: str,
    widget_executable: str | None,
) -> None:
    app_plist_raw, widget_plist_raw, app_plist_name, widget_plist_name = ipa_plists(ipa)
    app_identity = identity_from_plist(app_plist_raw, "IPA application")
    check_identity(app_identity, app_bundle_id, version, build, "IPA application")
    with zipfile.ZipFile(ipa) as archive:
        app_prefix = app_plist_name[: -len("Info.plist")]
        if f"{app_prefix}{app_executable}" not in archive.namelist():
            fail(f"IPA is missing application executable: {app_prefix}{app_executable}")
        if widget_bundle_id:
            if not widget_plist_name:
                fail(f"IPA is missing widget Info.plist for bundle ID {widget_bundle_id}")
            widget_identity = identity_from_plist(widget_plist_raw, "IPA widget")
            check_identity(widget_identity, widget_bundle_id, version, build, "IPA widget")
            widget_prefix = widget_plist_name[: -len("Info.plist")]
            if widget_executable is None or f"{widget_prefix}{widget_executable}" not in archive.namelist():
                fail(f"IPA is missing widget executable under {widget_prefix}")


def file_sha256(path: Path) -> tuple[str, int]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
            size += len(chunk)
    return digest.hexdigest(), size


def directory_sha256(path: Path) -> tuple[str, int, int]:
    digest = hashlib.sha256()
    total_size = 0
    file_count = 0
    entries: list[Path] = []
    for entry in path.rglob("*"):
        if entry.is_file() or entry.is_symlink():
            entries.append(entry)
    for entry in sorted(entries, key=lambda item: item.relative_to(path).as_posix()):
        relative = entry.relative_to(path).as_posix()
        if entry.is_symlink():
            payload = os.readlink(entry).encode("utf-8")
            entry_hash = hashlib.sha256(payload).hexdigest()
            entry_size = len(payload)
            kind = "symlink"
        else:
            entry_hash, entry_size = file_sha256(entry)
            kind = "file"
        digest.update(f"{kind}\0{relative}\0{entry_size}\0{entry_hash}\n".encode("utf-8"))
        total_size += entry_size
        file_count += 1
    return digest.hexdigest(), total_size, file_count


def artifact_record(root: Path, path: Path, relative_path: str) -> dict[str, Any]:
    if path.is_file():
        digest, size = file_sha256(path)
        return {
            "path": relative_path,
            "type": "file",
            "sha256": digest,
            "sizeBytes": size,
        }
    if path.is_dir():
        digest, size, file_count = directory_sha256(path)
        return {
            "path": relative_path,
            "type": "directory",
            "sha256": digest,
            "sizeBytes": size,
            "fileCount": file_count,
        }
    fail(f"Retained artifact does not exist: {path}")


def copy_tree(source: Path, destination: Path) -> None:
    if destination.exists():
        fail(f"Refusing to overwrite staged path: {destination}")
    shutil.copytree(source, destination, symlinks=True)


def copy_file(source: Path, destination: Path) -> None:
    if destination.exists():
        fail(f"Refusing to overwrite staged path: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def copy_archive_equivalent(
    archive: Path,
    app_path: Path,
    widget_path: Path | None,
    destination: Path,
) -> None:
    """Copy only non-secret archive metadata needed for symbol recovery."""

    destination.mkdir(parents=True, exist_ok=True)
    copy_file(archive / "Info.plist", destination / "Info.plist")
    copy_file(app_path / "Info.plist", destination / "Products" / "Applications" / app_path.name / "Info.plist")
    if widget_path is not None:
        copy_file(
            widget_path / "Info.plist",
            destination / "Products" / "Applications" / app_path.name / "PlugIns" / widget_path.name / "Info.plist",
        )

    dsym_source = archive / "dSYMs"
    if dsym_source.is_dir():
        copy_tree(dsym_source, destination / "dSYMs")
    bcsymbolmaps = archive / "BCSymbolMaps"
    if bcsymbolmaps.is_dir():
        copy_tree(bcsymbolmaps, destination / "BCSymbolMaps")
    scm_blueprint = archive / "SCMBlueprint"
    if scm_blueprint.exists():
        if scm_blueprint.is_dir():
            copy_tree(scm_blueprint, destination / "SCMBlueprint")
        else:
            copy_file(scm_blueprint, destination / "SCMBlueprint")


def assert_no_prohibited_names(root: Path) -> None:
    prohibited = [path for path in root.rglob("*") if PROHIBITED_NAME_RE.search(path.name)]
    if prohibited:
        fail("Recovery bundle contains prohibited secret/provisioning-looking paths: " + ", ".join(map(str, prohibited)))


def iso_timestamp(value: str | None) -> str:
    if value:
        return value
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_receipt(path: Path, manifest: dict[str, Any]) -> None:
    source = manifest["source"]
    release = manifest["release"]
    workflow = manifest["workflow"]
    symbols = manifest["symbols"]
    lines = [
        "# LifeRoute TestFlight Recovery Bundle V1",
        "",
        "- Status: PASS — archive/export evidence validated before upload",
        f"- Generated: `{manifest['generatedAt']}`",
        "",
        "## Source and workflow",
        f"- Commit SHA: `{source['commitSha']}`",
        f"- Tree SHA: `{source['treeSha']}`",
        f"- Branch/ref: `{source['branch'] or 'unavailable'}` / `{source['ref'] or 'unavailable'}`",
        f"- Repository: `{workflow['repository']}`",
        f"- Workflow: `{workflow['name']}`",
        f"- Run: `{workflow['runNumber']}` (ID `{workflow['runId']}`, attempt `{workflow['runAttempt']}`)",
        f"- Run URL: {workflow['runUrl'] or 'unavailable'}",
        "",
        "## Release identity",
        f"- Marketing version/build: `{release['marketingVersion']}` / `{release['buildNumber']}`",
        f"- App bundle ID: `{release['appBundleIdentifier']}`",
        f"- Widget bundle ID: `{release['widgetBundleIdentifier'] or 'not applicable'}`",
        f"- Archive/export: `{release['archiveFilename']}` / `{release['ipaFilename']}`",
        f"- Archive retention form: `{release['archiveRetentionForm']}`",
        "",
        "## Symbols",
        f"- App binary UUIDs: `{', '.join(symbols['app']['binaryUuids'])}`",
        f"- App dSYM UUIDs: `{', '.join(symbols['app']['dsymUuids'])}`",
    ]
    if symbols.get("widget"):
        lines.extend(
            [
                f"- Widget binary UUIDs: `{', '.join(symbols['widget']['binaryUuids'])}`",
                f"- Widget dSYM UUIDs: `{', '.join(symbols['widget']['dsymUuids'])}`",
            ]
        )
    lines.extend(["- UUID pair validation: PASS", "", "## Retained artifacts", ""])
    for name, artifact in manifest["artifacts"].items():
        lines.append(f"- `{name}`: `{artifact['path']}` — SHA-256 `{artifact['sha256']}`")
    lines.extend(
        [
            "",
            "## Safety",
            "",
            "No signing keys, credentials, API private keys, or secret environment values are retained.",
            "The archive-equivalent directory is allow-listed to metadata, dSYMs, BCSymbolMaps, and SCM blueprint content; it does not copy embedded provisioning profiles.",
            "",
            "The manifest is machine-readable at `manifest.json`.",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_bundle(args: argparse.Namespace) -> Path:
    archive = Path(args.archive).resolve()
    ipa = Path(args.ipa).resolve()
    output = Path(args.output).resolve()
    require_directory(archive, "archive")
    require_file(ipa, "exported IPA")
    if output.exists():
        fail(f"Refusing to overwrite existing recovery bundle: {output}")
    if not SHA1_RE.fullmatch(args.source_sha):
        fail("source SHA must be a full lowercase 40-character commit SHA")
    if not SHA1_RE.fullmatch(args.source_tree_sha):
        fail("source tree SHA must be a full lowercase 40-character tree SHA")

    app_identity, widget_identity, app_path, widget_path = archive_identity(
        archive, args.app_bundle_id, args.widget_bundle_id
    )
    expected_version = args.marketing_version or app_identity["marketingVersion"]
    expected_build = str(args.build_number or app_identity["buildNumber"])
    check_identity(app_identity, args.app_bundle_id, expected_version, expected_build, "archived application")
    if args.widget_bundle_id:
        check_identity(widget_identity, args.widget_bundle_id, expected_version, expected_build, "archived widget")

    app_binary = app_path / app_identity["executable"]
    app_binary_uuids = extract_uuids(args.uuid_tool, app_binary, "application binary")
    app_dsym, app_dsym_uuids = locate_dsym(
        archive / "dSYMs", app_binary_uuids, "application", args.uuid_tool
    )

    widget_binary_uuids: list[str] = []
    widget_dsym: Path | None = None
    widget_dsym_uuids: list[str] = []
    if args.widget_bundle_id:
        widget_binary = widget_path / widget_identity["executable"]
        widget_binary_uuids = extract_uuids(args.uuid_tool, widget_binary, "widget binary")
        widget_dsym, widget_dsym_uuids = locate_dsym(
            archive / "dSYMs", widget_binary_uuids, "widget", args.uuid_tool
        )

    compare_ipa_identity(
        ipa,
        args.app_bundle_id,
        args.widget_bundle_id,
        expected_version,
        expected_build,
        app_identity["executable"],
        widget_identity.get("executable") if args.widget_bundle_id else None,
    )

    output.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=f".{output.name}.", dir=str(output.parent)))
    try:
        ipa_destination = staging / "ipa" / ipa.name
        copy_file(ipa, ipa_destination)
        copy_tree(app_dsym, staging / "symbols" / "app" / app_dsym.name)
        if widget_dsym:
            copy_tree(widget_dsym, staging / "symbols" / "widget" / widget_dsym.name)
        copy_archive_equivalent(archive, app_path, widget_path, staging / "archive-source")
        assert_no_prohibited_names(staging)

        artifacts: dict[str, dict[str, Any]] = {
            "ipa": artifact_record(staging, ipa_destination, f"ipa/{ipa.name}"),
            "applicationDsym": artifact_record(
                staging, staging / "symbols" / "app" / app_dsym.name, f"symbols/app/{app_dsym.name}"
            ),
            "archiveSource": artifact_record(staging, staging / "archive-source", "archive-source"),
        }
        if widget_dsym:
            artifacts["widgetDsym"] = artifact_record(
                staging,
                staging / "symbols" / "widget" / widget_dsym.name,
                f"symbols/widget/{widget_dsym.name}",
            )

        workflow_run_id = str(args.run_id)
        workflow_run_number = str(args.run_number)
        workflow_run_attempt = str(args.run_attempt)
        run_url = ""
        if args.repository and workflow_run_id:
            run_url = f"https://github.com/{args.repository}/actions/runs/{workflow_run_id}"
        manifest: dict[str, Any] = {
            "schemaVersion": 1,
            "kind": "liferoute.testflight.recovery-bundle",
            "generatedAt": iso_timestamp(args.timestamp),
            "source": {
                "commitSha": args.source_sha,
                "treeSha": args.source_tree_sha,
                "branch": args.source_branch or "",
                "ref": args.source_ref or "",
            },
            "release": {
                "marketingVersion": expected_version,
                "buildNumber": expected_build,
                "appBundleIdentifier": args.app_bundle_id,
                "widgetBundleIdentifier": args.widget_bundle_id or "",
                "archiveFilename": archive.name,
                "exportDirectory": Path(args.export_directory).name if args.export_directory else "",
                "ipaFilename": ipa.name,
                "archiveRetentionForm": "archive-source-equivalent",
                "archiveExportStatus": "validated",
            },
            "symbols": {
                "app": {
                    "bundleIdentifier": app_identity["bundleIdentifier"],
                    "executable": app_identity["executable"],
                    "binaryUuids": app_binary_uuids,
                    "dsymFilename": app_dsym.name,
                    "dsymUuids": app_dsym_uuids,
                    "matchedUuids": sorted(set(app_binary_uuids).intersection(app_dsym_uuids)),
                    "uuidMatch": set(app_binary_uuids).issubset(app_dsym_uuids),
                }
            },
            "workflow": {
                "repository": args.repository,
                "name": args.workflow,
                "runId": workflow_run_id,
                "runNumber": workflow_run_number,
                "runAttempt": workflow_run_attempt,
                "ref": args.workflow_ref or "",
                "runUrl": run_url,
            },
            "validation": {
                "ipaExists": True,
                "archiveBundlesExist": True,
                "applicationUuidMatch": set(app_binary_uuids).issubset(app_dsym_uuids),
                "widgetUuidMatch": bool(not widget_dsym or set(widget_binary_uuids).issubset(widget_dsym_uuids)),
                "versionBuildIdentityMatch": True,
                "secretFreeOutput": True,
            },
            "artifacts": artifacts,
        }
        if widget_dsym:
            manifest["symbols"]["widget"] = {
                "bundleIdentifier": widget_identity["bundleIdentifier"],
                "executable": widget_identity["executable"],
                "binaryUuids": widget_binary_uuids,
                "dsymFilename": widget_dsym.name,
                "dsymUuids": widget_dsym_uuids,
                "matchedUuids": sorted(set(widget_binary_uuids).intersection(widget_dsym_uuids)),
                "uuidMatch": set(widget_binary_uuids).issubset(widget_dsym_uuids),
            }
        write_json(staging / "manifest.json", manifest)
        write_receipt(staging / "RECEIPT.md", manifest)
        os.replace(staging, output)
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    return output


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--archive", required=True)
    result.add_argument("--ipa", required=True)
    result.add_argument("--export-directory")
    result.add_argument("--output", required=True)
    result.add_argument("--source-sha", required=True)
    result.add_argument("--source-tree-sha", required=True)
    result.add_argument("--source-ref", default="")
    result.add_argument("--source-branch", default="")
    result.add_argument("--marketing-version")
    result.add_argument("--build-number")
    result.add_argument("--app-bundle-id", required=True)
    result.add_argument("--widget-bundle-id")
    result.add_argument("--repository", required=True)
    result.add_argument("--workflow", required=True)
    result.add_argument("--run-id", required=True)
    result.add_argument("--run-number", required=True)
    result.add_argument("--run-attempt", default="1")
    result.add_argument("--workflow-ref", default="")
    result.add_argument("--timestamp")
    result.add_argument("--uuid-tool", default="dwarfdump")
    return result


def main(argv: Iterable[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        output = build_bundle(args)
    except BundleError as error:
        print(f"TESTFLIGHT RECOVERY BUNDLE FAILED: {error}", file=sys.stderr)
        return 1
    print(f"TESTFLIGHT RECOVERY BUNDLE PASS: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
