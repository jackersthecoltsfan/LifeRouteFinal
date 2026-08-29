#!/usr/bin/env python3
"""Validate only the generated, non-authoritative browser preview artifact."""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path


dist = Path("dist")
index = dist / "index.html"
preview = dist / "web-preview.js"
assert dist.is_dir(), "dist directory missing"
assert index.is_file(), "dist/index.html missing"
assert preview.is_file(), "dist/web-preview.js missing"

html = index.read_text(encoding="utf-8", errors="ignore")
sha = (os.environ.get("GITHUB_SHA") or "local")[:8]
if sha != "local":
    assert f'name="liferoute-web-build" content="{sha}"' in html, "exact-SHA web build marker missing"

script_refs = re.findall(r'<script[^>]+src=["\']([^"\']+\.js)(?:\?[^"\']*)?["\']', html, flags=re.I)
assert script_refs.count("web-preview.js") == 1, "web-preview bootstrap must load exactly once"
assert len(script_refs) == len(set(script_refs)), "duplicate script reference in deployed HTML"
for reference in script_refs:
    assert (dist / reference).is_file(), f"loaded script does not resolve: {reference}"

quarantined = {"global-bridge.js", "auth-gate.js", "stability-runtime.js", "day-navigation-runtime.js"}
assert not quarantined.intersection(script_refs), "quarantined WKWebView runtime became an active preview dependency"

for name in sorted(set(script_refs + ["web-preview.js"])):
    result = subprocess.run(["node", "--check", str(dist / name)], capture_output=True, text=True, check=False)
    assert result.returncode == 0, f"JavaScript syntax failed for {name}: {result.stderr or result.stdout}"

corpus = "\n".join(path.read_text(encoding="utf-8", errors="ignore") for path in dist.rglob("*") if path.is_file())
for marker in ["BEGIN PRIVATE KEY", "BEGIN RSA PRIVATE KEY", "BEGIN EC PRIVATE KEY", "APPLE_PRIVATE_KEY", "MATCH_PASSWORD", "FASTLANE_PASSWORD"]:
    assert marker.casefold() not in corpus.casefold(), f"forbidden secret marker present: {marker}"

print(f"LifeRoute web preview validation passed for {sha}.")
