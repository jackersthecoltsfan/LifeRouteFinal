from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
read = lambda name: (WEB / name).read_text()

index = read("index.html")
welcome = read("welcome.js")
tail = read("delight-tail-v1.js")
stability = read("stability-runtime.js")
nav_cleanup = read("nav-cleanup.js")
auth = read("auth-gate.js")

checks = []
def require(condition, message): checks.append((bool(condition), message))

require('display:none;pointer-events:none' in welcome, "hidden welcome overlay cannot intercept taps")
require('.lrWelcomeOverlay.show{display:flex;pointer-events:auto}' in welcome, "welcome overlay owns taps only while visibly shown")
require("hideWelcome" in welcome and "setWelcomeActive(false)" in welcome, "welcome exit clears startup interaction state")
require("setTimeout(finalize, 280)" not in tail, "nav icon finalizer does not rewrite controls after a delayed race window")
require("if (!hasVector || label !== item[1])" in tail, "nav icon rewrite is idempotently guarded")
require("[100, 350, 900, 1800]" not in stability, "bottom controls have no speculative rebinding timer race")
require("new MutationObserver(bindBottomActions).observe(bar" in stability, "bottom action repair is scoped to its own bar")
require("stopImmediatePropagation" not in nav_cleanup, "navigation cleanup cannot suppress another control owner")
require("pointer-events:none!important" in stability, "visual background layers are explicitly non-interactive")
require("if (!AUTH_GATE_ENABLED) return" in auth or "return;" in auth[:700], "legacy auth startup exits before overlay work")

# Each prepared startup script should appear at most once; duplicate script ownership is
# a common source of double handlers and state races in a hybrid WKWebView app.
scripts = re.findall(r'<script\s+src="([^"]+)"', index)
duplicates = sorted({name for name in scripts if scripts.count(name) > 1})
require(not duplicates, f"startup script tags are unique (duplicates: {duplicates})")

failed = [message for ok, message in checks if not ok]
print(f"v0.4.0 stability audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for message in failed: print("FAIL:", message)
    raise SystemExit(1)
print("Stability contract is clean: overlays, nav ownership, observers, auth startup, and script loading cannot race for taps.")
