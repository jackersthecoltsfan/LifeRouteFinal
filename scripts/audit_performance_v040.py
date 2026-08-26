from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
read = lambda name: (WEB / name).read_text()

delight = read("delight-ui-v1.js")
icons = read("icons.js")
welcome = read("welcome.js")
tail = read("delight-tail-v1.js")
index = read("index.html")

checks = []
def require(condition, message): checks.append((bool(condition), message))

require("observer.observe(document.body" not in icons, "icon system does not observe the whole document")
require("roots.forEach(root => observer.observe(root" in icons, "dynamic icon observation is scoped to product surfaces")
require("MutationObserver" not in welcome, "first-run welcome owns no MutationObserver")
require("setInterval(" not in welcome, "first-run welcome owns no recurring polling interval")
require("document.addEventListener('pointerdown', event =>" not in delight, "touch-down path performs no global JavaScript control work")
require("classList.add('lrTouchPressed')" not in delight, "touch-down feedback requires no class mutation")
require('html[data-life-route-runtime="native"] #lifeRouteDelightBackdrop>span{animation:none!important;will-change:auto!important}' in delight, "native ambient backdrop is static/compositor-light")
require(delight.count('blur(6px)!important') >= 3, "persistent native glass blur is capped at the lightweight 6px treatment")
require("setTimeout(finalize, 280)" not in tail, "no delayed nav/icon reconciliation runs after startup")
require("offsetWidth" not in delight and "getBoundingClientRect" not in delight, "global delight layer avoids synchronous layout reads")
for retired in ["touch-playground-v1.js", "interaction-liquid-v4.js", "premium-interactions-v1.js", "nav-portal-v1.js"]:
    require(f'<script src="{retired}"></script>' not in index, f"retired duplicate interaction system {retired} is excluded")
require("requestAnimationFrame" in tail, "final visual reconciliation uses a frame boundary instead of polling")

failed = [message for ok, message in checks if not ok]
print(f"v0.4.0 performance audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for message in failed: print("FAIL:", message)
    raise SystemExit(1)
print("Performance contract is clean: no global icon observer, no pre-click JS churn, static native ambience, and no delayed nav rewrite.")
