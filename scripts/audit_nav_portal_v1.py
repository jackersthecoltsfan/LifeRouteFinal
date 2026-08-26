from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
PORTAL = WEB / "nav-portal-v1.js"
INDEX = WEB / "index.html"

checks = []

def check(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))

portal = PORTAL.read_text() if PORTAL.exists() else ""
index = INDEX.read_text() if INDEX.exists() else ""

check("navigation portal exists", PORTAL.exists() and len(portal) > 1200)
check("single reusable portal node", portal.count("document.createElement('div')") == 1 and "lifeRouteNavPortal" in portal)
check("portal ignores pointer events", "pointer-events:none" in portal)
check("portal uses transform and opacity", "transform:translate3d" in portal and "opacity:" in portal)
check("portal animation stays under half second", ".46s" in portal)
check("portal cleanup is bounded", "540" in portal and "portalTimer" in portal)
check("portal resets on pointer cancel", "pointercancel" in portal and "classList.remove('lrPortalOpen')" in portal)
check("portal resets when hidden", "visibilitychange" in portal and "document.hidden" in portal)
check("portal pointerup listener is passive", "pointerup" in portal and "passive:true" in portal)
check("portal has no pointermove tracking", "pointermove" not in portal and "mousemove" not in portal and "touchmove" not in portal)
check("portal has no polling", "setInterval(" not in portal)
check("portal uses at most one RAF", portal.count("requestAnimationFrame(") <= 1)
check("portal has no recursive RAF", not re.search(r"function\s+(\w+)[^{]*\{[^}]*requestAnimationFrame\(\1\)", portal, re.S))
check("portal has no blur workload", "filter:blur(" not in portal and "backdrop-filter" not in portal)
check("portal has no network work", not re.search(r"\bfetch\s*\(|XMLHttpRequest|WebSocket|EventSource", portal))
programmatic_scroll_tokens = ["scrollIntoView(", "scrollTo(", "scrollBy("]
check("portal has no programmatic scrolling", all(token not in portal for token in programmatic_scroll_tokens))
check("portal respects reduced motion", "prefers-reduced-motion:reduce" in portal and "animation:none!important" in portal)
check("portal targets navigation only", ".tabs .tab,.lrContextTab,.lrPlaceCategory,.lrDayPager button" in portal)
check("portal is loaded deferred", 'defer src="nav-portal-v1.js"' in index)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute navigation portal audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Navigation portal audit failed: " + "; ".join(failed))
