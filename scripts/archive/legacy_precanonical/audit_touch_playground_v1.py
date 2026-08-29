from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
PLAY = WEB / "touch-playground-v1.js"
DELIGHT = WEB / "delight-ui-v1.js"
INDEX = WEB / "index.html"

checks = []

def check(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))

play = PLAY.read_text() if PLAY.exists() else ""
delight = DELIGHT.read_text() if DELIGHT.exists() else ""
index = INDEX.read_text() if INDEX.exists() else ""

# 1) Touch response and cleanup.
check("touch playground exists", PLAY.exists() and len(play) > 1500)
check("pointerdown is passive", "pointerdown" in play and "passive:true" in play)
check("pointerup is passive", "pointerup" in play and "passive:true" in play)
check("pointercancel cleanup exists", "pointercancel" in play and "clearBloom(control)" in play)
check("tap manipulation stays enabled", "touch-action:manipulation" in delight)
check("no touch polling interval", "setInterval(" not in play)
check("no MutationObserver in touch layer", "MutationObserver" not in play)

# 2) Animation budget: compositor-friendly only.
check("touch bloom uses transform", "transform:translate3d" in play)
check("touch bloom uses opacity", "opacity:" in play)
check("touch bloom avoids top-left animation", not re.search(r"@keyframes[^}]+(?:left|top):", play, re.S))
check("release animation is short", ".24s" in play)
check("bloom animation is short", ".34s" in play)
check("reduced motion supported", "prefers-reduced-motion:reduce" in play)
check("no blur work in touch layer", "filter:blur(" not in play and "backdrop-filter" not in play)

# 3) Scroll and lifecycle safety.
check("scroll listener is passive", "window.addEventListener('scroll'" in play and "passive:true" in play)
check("scrolling pauses ambient background", "lrUserScrolling #lifeRouteDelightBackdrop>span" in play)
check("hidden page pauses ambient background", "lrDocumentHidden #lifeRouteDelightBackdrop>span" in play)
check("visibility lifecycle hook exists", "visibilitychange" in play)
programmatic_scroll_tokens = ["scrollIntoView(", "scrollTo(", "scrollBy("]
check("touch layer has no programmatic scrolling", all(token not in play for token in programmatic_scroll_tokens))

# 4) DOM pressure and leak resistance.
check("touch bloom removes on animation end", "animationend" in play and "bloom.remove()" in play)
check("touch bloom has timeout fallback", "setTimeout(() => bloom.remove(), 450)" in play)
check("one bloom is cleared before adding", "clearBloom(control);" in play)
check("release class self-cleans", "lrTouchReleaseGlow'), 420" in play)
check("touch layer has no network work", not re.search(r"\bfetch\s*\(|XMLHttpRequest|WebSocket", play))

# 5) Navigation / active state delight.
check("top navigation remains four-column", "grid-template-columns:repeat(4,minmax(0,1fr))!important" in delight)
check("active top tab shimmer exists", ".tabs .tab.active::after" in play)
check("context tab shimmer exists", ".lrContextTab.active::after" in play)
check("place tab shimmer exists", ".lrPlaceCategory.active::after" in play)
check("primary action glint exists", "lrPrimaryGlint" in play)

# 6) Shared startup contract.
check("touch playground is loaded", "touch-playground-v1.js" in index)
check("touch playground is deferred", 'defer src="touch-playground-v1.js"' in index)
check("no permanent button will-change transform", "button,[role=\"button\"]{transform-origin:center;will-change:transform" not in delight)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute touch playground audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Touch playground audit failed: " + "; ".join(failed))
