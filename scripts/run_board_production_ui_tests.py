#!/usr/bin/env python3
"""Exercise shipping board routes with preserved, synthetic Simulator data.

Never accepts a physical device. Existing native state and preferences are
copied and hash-verified before fixture setup, then restored in a finally block.
The result bundle and resulting synthetic state remain in external evidence.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import zlib

from liferoute_storage import scratch_path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = "Com.Brandongood.LifeRoute"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--simulator", required=True)
parser.add_argument("--app", required=True, type=Path)
parser.add_argument("--output", required=True, type=Path)
parser.add_argument("--test", action="append")
args = parser.parse_args()
os.environ.pop("SDKROOT", None)
out = args.output.resolve()
assert out != ROOT and ROOT not in out.parents
out.mkdir(parents=True, exist_ok=False)
os.chmod(out, 0o700)


def run(command, **kwargs):
    return subprocess.run(command, check=True, text=True, **kwargs)


def manifest(directory):
    if not directory.exists():
        return None
    if directory.is_file():
        return hashlib.sha256(directory.read_bytes()).hexdigest()
    return {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(directory.rglob("*")) if p.is_file()}


def png(rgb):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    pixels = b"".join(b"\x00" + bytes(rgb) * 128 for _ in range(128))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 128, 128, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))


devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))["devices"]
assert any(d["udid"] == args.simulator and d["state"] == "Booted" for group in devices.values() for d in group)
subprocess.run(["xcrun", "simctl", "terminate", args.simulator, BUNDLE], capture_output=True)
run(["xcrun", "simctl", "install", args.simulator, str(args.app.resolve())])
container = Path(subprocess.check_output(["xcrun", "simctl", "get_app_container", args.simulator, BUNDLE, "data"], text=True).strip())
native = container / "Library/Application Support/LifeRoute/NativeState"
preferences = container / "Library/Preferences" / (BUNDLE + ".plist")
targets = {"native": native, "preferences": preferences}
before = {key: manifest(path) for key, path in targets.items()}
backup = out / "preserved"
backup.mkdir(mode=0o700)
for key, path in targets.items():
    if path.is_dir():
        shutil.copytree(path, backup / key)
    elif path.exists():
        shutil.copy2(path, backup / key)
    assert manifest(backup / key) == before[key], "Preservation failed"
(out / "preservation.json").write_text(json.dumps(before, indent=2))

exit_code = None
try:
    if native.exists():
        shutil.rmtree(native)  # Exact preserved Simulator fixture scope only.
    native.mkdir(parents=True)
    icons = []
    for index, (label, color) in enumerate([("Apple", (220, 40, 40)), ("Book", (35, 105, 230)), ("Break", (30, 170, 95))], 1):
        icons.append(dict(id=f"10000000-0000-0000-0000-{index:012d}",
                          clientID="7F164E34-BD4A-4A30-AFDB-70A4AE8C7D3E", clientCode="GENERAL",
                          label=label, imageData=base64.b64encode(png(color)).decode(), createdAt="2026-09-15T12:00:00Z"))
    fixture = dict(schemaVersion=7, clients=[], visualIcons=icons, choiceBoards=[], visualSchedules=[])
    (native / "native-state-v1.json").write_text(json.dumps(fixture))
    shutil.copytree(ROOT / "scripts/fixtures/living-theme-ui/NativeUI.xcodeproj", out / "NativeUI.xcodeproj")
    shutil.copy2(ROOT / "scripts/board_production_ui_tests.swift", out / "NativeUI.swift")
    (out / "manifest.json").write_text(json.dumps(dict(
        simulator=args.simulator, app=manifest(args.app), test=manifest(out / "NativeUI.swift")), indent=2))
    derived_data = scratch_path('ui-fixtures/board-production/derived-data')
    derived_data.mkdir(parents=True, exist_ok=True)
    command = ["xcodebuild", "test", "-project", str(out / "NativeUI.xcodeproj"), "-scheme", "NativeUI",
               "-destination", "platform=iOS Simulator,id=" + args.simulator,
               "-derivedDataPath", str(derived_data), "-resultBundlePath", str(out / "boards.xcresult"),
               "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO"]
    for test in args.test or ["testCreateFirstThen", "testCreateChoiceBoard", "testCreateSchedule", "testCreateTokenBoard",
                              "testExportActions", "testDockAndThemeReentry"]:
        command.append("-only-testing:NativeUI/BoardProductionUI/" + test)
    with (out / "xcodebuild.log").open("w") as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
    exit_code = result.returncode
finally:
    subprocess.run(["xcrun", "simctl", "terminate", args.simulator, BUNDLE], capture_output=True)
    if native.exists():
        shutil.copytree(native, out / "resulting-synthetic-state")
    for key, path in targets.items():
        if path.is_dir():
            shutil.rmtree(path)
        elif path.exists():
            path.unlink()
        if (backup / key).is_dir():
            shutil.copytree(backup / key, path)
        elif (backup / key).exists():
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(backup / key, path)
        assert manifest(path) == before[key], "Original Simulator state restoration failed"
    (out / "result.json").write_text(json.dumps(dict(exit=exit_code, original_state_restored=True), indent=2))

assert exit_code == 0, "Production board UI test failed; inspect retained result bundle and log"
print("PASS: shipping board creation routes; original Simulator state restored")
