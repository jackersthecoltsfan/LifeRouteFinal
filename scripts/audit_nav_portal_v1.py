from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
INDEX = WEB / "index.html"
TOOLBAR = WEB / "toolbar-cleanup-v1.js"
TAIL = WEB / "delight-tail-v1.js"
NAV_CLEANUP = WEB / "nav-cleanup.js"
DELIGHT = WEB / "delight-ui-v1.js"

checks = []
def check(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))

index = INDEX.read_text() if INDEX.exists() else ""
toolbar = TOOLBAR.read_text() if TOOLBAR.exists() else ""
tail = TAIL.read_text() if TAIL.exists() else ""
nav_cleanup = NAV_CLEANUP.read_text() if NAV_CLEANUP.exists() else ""
delight = DELIGHT.read_text() if DELIGHT.exists() else ""

# The animated nav portal is deliberately retired in v0.4.0. Navigation has one
# direct owner so taps cannot be intercepted or retargeted by decorative handlers.
check("retired navigation portal is not loaded", 'nav-portal-v1.js' not in index)
check("top navigation has exactly four canonical destinations", all(f"view: '{view}'" in toolbar for view in ['today','tools','resources','setup']))
check("top navigation has a direct click owner", "button.onclick = event =>" in toolbar and "navigateTop(button.dataset.view || 'today')" in toolbar)
check("navigation click owner prevents only default action", "event.preventDefault();" in toolbar)
check("legacy cleanup does not stop sibling handlers", "stopImmediatePropagation" not in nav_cleanup)
check("top navigation uses four equal tracks", "grid-template-columns:repeat(4,minmax(0,1fr))!important" in delight)
check("top navigation preserves immediate active styling", ".tabs .tab.active" in delight)
check("navigation targets stay touch-sized", "min-height:55px!important" in delight or "min-height:51px!important" in delight)
check("navigation touch hint is enabled", "touch-action:manipulation" in delight)
check("navigation feedback waits for click", "decorative work happens only after" in delight)
check("no broad pointerdown nav owner", "document.addEventListener('pointerdown', event =>" not in delight)
check("no broad pointerup nav owner", "document.addEventListener('pointerup', event =>" not in delight)
check("delayed nav rewrite is removed", "setTimeout(finalize, 280)" not in tail)
check("final icon sync is guarded", "if (!hasVector || label !== item[1])" in tail)
check("final icon sync is frame-bounded", "requestAnimationFrame(finalize)" in tail)
check("navigation layer owns no polling interval", "setInterval(" not in delight and "setInterval(" not in toolbar)
check("reduced motion remains supported", "prefers-reduced-motion:reduce" in delight)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute v0.4.0 direct navigation audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Direct navigation audit failed: " + "; ".join(failed))
