from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
DELIGHT = WEB / "delight-ui-v1.js"
AESTHETIC = WEB / "aesthetic-polish-v1.js"
TAIL = WEB / "delight-tail-v1.js"
INDEX = WEB / "index.html"

checks = []
def check(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))

delight = DELIGHT.read_text() if DELIGHT.exists() else ""
aesthetic = AESTHETIC.read_text() if AESTHETIC.exists() else ""
tail = TAIL.read_text() if TAIL.exists() else ""
index = INDEX.read_text() if INDEX.exists() else ""

# Premium feel comes from bounded CSS motion and glass, not a second DOM-mutating
# pointer runtime. This keeps the web preview aligned with the iPhone hotfix.
check("navigation glass remains centered", "width:min(100%,590px)!important" in delight and "margin:9px auto 12px!important" in delight)
check("navigation targets remain tall", "min-height:55px!important" in delight or "min-height:51px!important" in delight)
check("button tactile compression remains", 'button:active,[role="button"]:active{' in delight and "scale(.945)" in delight)
check("fast tactile timing remains", "transition:transform .055s" in delight)
check("page entry remains transform-opacity based", "lrViewFlowIn" in delight and "translate3d" in delight and "opacity:" in delight)
check("context navigation entry remains lightweight", "lrContextFlowIn" in delight)
check("reduced motion exists", "prefers-reduced-motion:reduce" in delight and "prefers-reduced-motion:reduce" in aesthetic)
check("touch targets retain minimum size", "min-height:44px!important" in aesthetic)
check("no global pointermove", "pointermove" not in delight)
check("no mousemove tracking", "mousemove" not in delight)
check("no touchmove tracking", "touchmove" not in delight)
check("no interaction polling interval", "setInterval(" not in delight)
check("no interaction network work", not re.search(r"\bfetch\s*\(|XMLHttpRequest|WebSocket|EventSource", delight))
check("no synchronous interaction geometry", "offsetWidth" not in delight and "getBoundingClientRect" not in delight)
check("delayed nav rewrite removed", "setTimeout(finalize, 280)" not in tail)
check("nav rewrite is idempotently guarded", "if (!hasVector || label !== item[1])" in tail)
check("retired touch playground is not loaded", 'touch-playground-v1.js' not in index)
check("retired nav portal is not loaded", 'nav-portal-v1.js' not in index)
check("retired premium duplicate owner is not loaded", 'premium-interactions-v1.js' not in index)
check("retired liquid duplicate owner is not loaded", 'interaction-liquid-v4.js' not in index)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute v0.4.0 immersive UI audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Immersive UI audit failed: " + "; ".join(failed))
