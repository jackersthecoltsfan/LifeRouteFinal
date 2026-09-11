#!/usr/bin/env python3
"""Check production SwiftUI/UIKit frames, optionally using existing simctl fixtures.

No layout replica or Xcode project changes. The opt-in DEBUG probe observes the
real root and toolbar. Coordinates are global UIKit points; screenshots are
pixels at the recorded window scale. Two samples 400 ms apart must agree within
one physical pixel. Launch fixtures do not certify ordinary theme switching,
scroll gestures, presentation, or physical-device acceptance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
THEMES = ["royal", "scenery.ocean.day", "scenery.mountains.day", "scenery.mountains.night"]
ROOTS = ["today", "schedule", "tools", "resources", "setup"]
PREFIX = "LIFEROUTE_ROOT_GEOMETRY "


def check(rows):
    groups = {}
    for row in rows:
        if row["scenePhase"] == "active" and row["toolbarVisible"]:
            groups.setdefault((row["pid"], row["theme"], row["root"]), {}).setdefault(row["role"], []).append(row)
    assert groups, "No active production-frame evidence"
    summary = []
    for (_, theme, root), roles in groups.items():
        settled = {}
        for role in ["root", "toolbar", "toolbar-host"]:
            samples = roles.get(role, [])
            assert len(samples) >= 2, f"{theme}/{root}: missing settling evidence for {role}"
            a, b = samples[-2:]
            tol = 1 / b["scale"] + 0.000001
            assert b["settleSample"] == 2, f"{theme}/{root}: still settling"
            assert max(abs(x-y) for x, y in zip(a["frame"], b["frame"])) <= tol, f"{theme}/{root}: unstable {role}"
            settled[role] = b
        r, bar, host = (settled[k] for k in ["root", "toolbar", "toolbar-host"])
        assert not r["hasFirstResponder"], "Keyboard/first-responder cases need separate state-specific evidence"
        x, y, width, height = r["windowBounds"]
        top, left, bottom, right = r["windowSafeArea"]
        expected = [x+left, y+top, width-left-right, height-top-bottom]
        assert max(abs(a-b) for a, b in zip(r["frame"], expected)) <= tol, f"{theme}/{root}: backdrop enlarged root {r['frame']} vs {expected}"
        clearance = y + height - bottom - (bar["frame"][1] + bar["frame"][3])
        token = bar.get("visualClearance", 10)  # Schema-1 diagnostic baseline predates this field.
        assert abs(clearance-token) <= tol, f"{theme}/{root}: physical safe area/visual clearance mismatch: {clearance}"
        assert abs(host["frame"][1]+host["frame"][3] - (y+height-bottom)) <= tol, f"{theme}/{root}: inset host bottom"
        # The actual UIKit page scroll viewport ends at the inset host's top.
        # Exclude offscreen sibling roots and nested horizontal controls.
        pages = [s for s in r["scrollViews"] if abs(s["frame"][0]-expected[0]) <= tol
                 and abs(s["frame"][2]-expected[2]) <= tol
                 and abs(s["frame"][1]-expected[1]) <= tol]
        assert pages, f"{theme}/{root}: no native page viewport"
        for page in pages:
            assert abs(page["frame"][1]+page["frame"][3]-host["frame"][1]) <= tol, f"{theme}/{root}: content reservation diverged"
        summary.append({"theme": theme, "root": root, "rootFrame": r["frame"],
                        "toolbarFrame": bar["frame"], "reservation": host["frame"][3],
                        "physicalBottom": bottom, "visualClearance": clearance, "tolerancePoints": tol,
                        "scale": r["scale"], "dynamicType": r["dynamicType"], "window": r["windowBounds"]})
    # Same controlled viewport/state/root must produce the same layout across themes.
    matched = {}
    for row in summary:
        key = (row["root"], tuple(row["window"]), row["dynamicType"], row["physicalBottom"])
        if key in matched:
            old = matched[key]
            for field in ["rootFrame", "toolbarFrame"]:
                assert max(abs(a-b) for a, b in zip(row[field], old[field])) <= row["tolerancePoints"], f"Theme changed {field}"
            assert abs(row["reservation"]-old["reservation"]) <= row["tolerancePoints"], "Theme changed content reservation"
        matched[key] = row
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--measurements", type=Path, help="Verify an existing probe JSON array")
    parser.add_argument("--app", type=Path, help="Already built Debug Simulator app")
    parser.add_argument("--simulator", help="Explicit already booted Simulator UDID; never a physical device")
    parser.add_argument("--all-roots", action="store_true")
    parser.add_argument("--themes", nargs="+", choices=THEMES, default=THEMES)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    out = args.output.resolve()
    assert out != ROOT and ROOT not in out.parents, "Evidence must remain outside the repository"
    out.mkdir(parents=True, exist_ok=True)
    if args.measurements:
        rows = json.loads(args.measurements.read_text())
    else:
        assert args.app and args.simulator, "Provide --app and --simulator, or --measurements"
        devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))["devices"]
        assert any(d["udid"] == args.simulator and d["state"] == "Booted" for group in devices.values() for d in group), "Requested Simulator is not booted"
        subprocess.run(["xcrun", "simctl", "install", args.simulator, str(args.app.resolve())], check=True)
        cases = [(theme, "setup") for theme in args.themes]
        if args.all_roots:
            cases += [(theme, root) for theme in THEMES[2:] for root in ROOTS[:-1]]
        rows = []
        binary_records = {str(p.relative_to(args.app)): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in sorted(args.app.rglob("*")) if p.is_file()}
        (out / "binary.json").write_text(json.dumps(binary_records, indent=2) + "\n")
        for theme, root in cases:
            label = theme.replace(".", "-") + "-" + root
            log = out / (label + ".log")
            assert not log.exists(), "Use a new evidence directory; do not overwrite prior runs"
            subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process", "--stdout="+str(log),
                            "--stderr="+str(log)+".stderr", args.simulator, "Com.Brandongood.LifeRoute",
                            "-LifeRouteThemeOverride", theme, "-LifeRouteSectionOverride", root,
                            "-LifeRouteRootGeometryTrace"], check=True)
            # A busy native runtime may need more than a fixed launch delay.
            # Wait for the actual second settled sample from every measured owner.
            deadline = time.monotonic() + 15
            case_rows = []
            while time.monotonic() < deadline:
                case_rows = [json.loads(line[len(PREFIX):]) for line in log.read_text().splitlines()
                             if line.startswith(PREFIX) and line.endswith("}")]
                ready = {r["role"] for r in case_rows if r["settleSample"] == 2
                         and r["scenePhase"] == "active" and r["theme"] == theme and r["root"] == root}
                if {"root", "toolbar", "toolbar-host"} <= ready:
                    break
                time.sleep(0.1)
            else:
                raise AssertionError(f"{theme}/{root}: no settled native samples within 15 seconds; see {log}")
            subprocess.run(["xcrun", "simctl", "io", args.simulator, "screenshot", str(out / (label+".png"))], check=True)
            rows += case_rows
        (out / "measurements.json").write_text(json.dumps(rows, indent=2)+"\n")
    summary = check(rows)
    (out / "results.json").write_text(json.dumps(summary, indent=2)+"\n")
    print(f"PASS: {len(summary)} production root/theme cases; settled root, toolbar, physical clearance and native page reservation")


if __name__ == "__main__":
    main()
