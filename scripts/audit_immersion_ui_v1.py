from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
PLAY = WEB / "touch-playground-v1.js"
DELIGHT = WEB / "delight-ui-v1.js"
AESTHETIC = WEB / "aesthetic-polish-v1.js"

checks = []

def check(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))

play = PLAY.read_text() if PLAY.exists() else ""
delight = DELIGHT.read_text() if DELIGHT.exists() else ""
aesthetic = AESTHETIC.read_text() if AESTHETIC.exists() else ""

# Reward feedback should be finite, reusable, and cheap.
check("single reusable reward halo exists", "lifeRouteRewardHalo" in play and "document.createElement('div')" in play)
check("reward halo is pointer transparent", "#lifeRouteRewardHalo" in play and "pointer-events:none" in play)
check("reward halo is transform-opacity animated", "@keyframes lrRewardPulse" in play and "transform:translate3d" in play and "opacity:" in play)
check("reward pulse is under 600ms", ".52s" in play)
check("reward class is cleared", "rewardHalo.classList.remove('lrRewardPulse')" in play)
check("reward timeout is bounded", "620" in play and "rewardTimer" in play)

# Screen transitions should create delight without layout tracking.
check("screen arrival sweep exists", "lrScreenArrivalSweep" in play)
check("screen arrival is short", ".58s" in play)
check("screen arrival uses translate3d", "skewX(-14deg) translate3d" in play)
check("no geometry polling for screen arrival", "ResizeObserver" not in play and "IntersectionObserver" not in play)

# Focus should feel premium and remain keyboard-accessible.
check("focus-visible ring exists", ":focus-visible" in play)
check("focus-visible has outline", "outline:2px solid" in play and "outline-offset:3px" in play)
check("form focus halo exists", "input:focus,select:focus,textarea:focus" in play)
check("form focus animation is short", ".16s" in play)
check("reduced motion cancels focus movement", "input:focus,select:focus,textarea:focus{transform:none!important}" in play)

# Hover richness must never create iPhone pointer churn.
check("depth hover is fine-pointer only", "@media(hover:hover) and (pointer:fine)" in play)
check("no global pointermove", "pointermove" not in play)
check("no mousemove tracking", "mousemove" not in play)
check("no touchmove tracking", "touchmove" not in play)

# Continuous animation budget is intentionally tiny and pausable.
check("no interval loops", "setInterval(" not in play)
check("requestAnimationFrame calls stay bounded", play.count("requestAnimationFrame(") <= 2)
check("no recursive RAF function", not re.search(r"function\s+(\w+)[^{]*\{[^}]*requestAnimationFrame\(\1\)", play, re.S))
check("ambient brand breath pauses on scroll", "html.lrUserScrolling .mark::after" in play)
check("ambient selected tab pauses on scroll", "html.lrUserScrolling .tabs .tab.active::after" in play)
check("ambient work pauses when hidden", "html.lrDocumentHidden" in play)

# Existing primary interaction contracts remain intact.
check("button animation remains fast", "INTERACTION_MS = 125" in aesthetic)
check("navigation glass remains centered", "width:min(100%,590px)!important" in delight and "margin:9px auto 12px!important" in delight)
check("navigation targets remain tall", "min-height:55px!important" in delight or "min-height:51px!important" in delight)
check("reduced motion block exists", "prefers-reduced-motion:reduce" in play)
check("no programmatic scrolling", all(token not in play for token in ["scrollIntoView(", "scrollTo(", "scrollBy("])) )
check("no network work", not re.search(r"\bfetch\s*\(|XMLHttpRequest|WebSocket|EventSource", play))

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute immersive UI audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit("Immersive UI audit failed: " + "; ".join(failed))
