from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
DELIGHT = WEB / "delight-ui-v1.js"
ICONS = WEB / "icons.js"
INDEX = WEB / "index.html"
WELCOME = WEB / "welcome.js"

checks = []
def check(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))

delight = DELIGHT.read_text() if DELIGHT.exists() else ""
icons = ICONS.read_text() if ICONS.exists() else ""
index = INDEX.read_text() if INDEX.exists() else ""
welcome = WELCOME.read_text() if WELCOME.exists() else ""

# v0.4.0 web touch reliability: one active feedback owner, and it never mutates
# the touched control before the browser has delivered its real click.
check("active delight interaction layer exists", DELIGHT.exists() and len(delight) > 1500)
check("immediate CSS active response exists", 'button:active,[role="button"]:active{' in delight)
check("fast touch-down timing remains", "transition:transform .055s" in delight)
check("tap manipulation stays enabled", "touch-action:manipulation" in delight)
check("feedback waits for real click", "decorative work happens only after" in delight and "document.addEventListener('click', event =>" in delight)
check("no broad pointerdown control handler", "document.addEventListener('pointerdown', event =>" not in delight)
check("no broad pointerup control handler", "document.addEventListener('pointerup', event =>" not in delight)
check("no pre-click pressed class mutation", "classList.add('lrTouchPressed')" not in delight and "classList.remove('lrTouchPressed')" not in delight)
check("haptic remains attached to completed clicks", "haptic(control);" in delight)
check("sound remains attached to completed clicks", "playSound(classifySound(control));" in delight)

# Retired experimental interaction owners may stay in the repository for history,
# but they must not be loaded into the prepared browser artifact.
for retired in ["touch-playground-v1.js", "interaction-liquid-v4.js", "premium-interactions-v1.js", "nav-portal-v1.js"]:
    check(f"retired interaction owner is not loaded: {retired}", f'<script src="{retired}"></script>' not in index and f'defer src="{retired}"' not in index)

# Runtime pressure and hit-testing safety.
check("icon system avoids whole-body observation", "observer.observe(document.body" not in icons)
check("icon observation is scoped", "roots.forEach(root => observer.observe(root" in icons)
check("interaction layer has no polling interval", "setInterval(" not in delight)
check("interaction layer avoids synchronous geometry reads", "offsetWidth" not in delight and "getBoundingClientRect" not in delight)
check("interaction layer has no network work", not re.search(r"\bfetch\s*\(|XMLHttpRequest|WebSocket|EventSource", delight))
check("hidden welcome is pointer transparent", "display:none;pointer-events:none" in welcome)
check("visible welcome explicitly owns taps", ".lrWelcomeOverlay.show{display:flex;pointer-events:auto}" in welcome)

# Navigation and accessibility contracts remain intact.
check("top navigation remains four-column", "grid-template-columns:repeat(4,minmax(0,1fr))!important" in delight)
check("reduced motion remains supported", "prefers-reduced-motion:reduce" in delight)
check("buttons avoid permanent transform will-change", 'button,[role="button"]{transform-origin:center;will-change:transform' not in delight)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute v0.4.0 web touch reliability audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Web touch reliability audit failed: " + "; ".join(failed))
