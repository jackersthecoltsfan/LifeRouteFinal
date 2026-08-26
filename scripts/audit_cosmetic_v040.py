from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
toolbar = (WEB / "toolbar-cleanup-v1.js").read_text()
icons = (WEB / "icons.js").read_text()
delight = (WEB / "delight-ui-v1.js").read_text()
theme = (WEB / "theme-accordion-v1.js").read_text()

checks = []
def require(condition, message): checks.append((bool(condition), message))

require("icon('calendar', '▣', 19)" in toolbar, "Schedule uses a crisp vector calendar icon")
require("icon('briefcase', '◈', 19)" in toolbar, "Session Tools uses a crisp vector toolkit icon")
require("icon('package', '▤', 19)" in toolbar, "Resources uses a crisp vector resource icon")
require("icon('settings', '◎', 19)" in toolbar, "Setup uses a crisp vector settings icon")
require("🧩" not in toolbar, "top navigation no longer mixes emoji with vector icons")
require("icon('pin','⌂',20)" in toolbar and "icon('user','◎',20)" in toolbar, "Setup hub uses vector place/client icons")
require("iconName: 'clock'" in toolbar and "iconName: 'sparkles'" in toolbar and "iconName: 'briefcase'" in toolbar, "Session Tools hub uses vector icon definitions")
require(".lrHubIcon .lrIcon" in toolbar and "stroke-width:1.9" in toolbar, "hub icon stroke/size treatment is consistent")
require("min-height:44px!important" in (WEB / "aesthetic-polish-v1.js").read_text(), "interactive touch targets preserve Apple-sized minimums")
require("@media(prefers-reduced-motion:reduce)" in delight, "interaction polish preserves reduced-motion accessibility")
require("Classic" in theme and "Metallic" in theme and "Scenery" in theme and "Dynamic" in theme and "Fluid" in theme and "Living" in theme, "categorized Themes interface remains intact")
require("const paths =" in icons and "window.lifeRouteIcon" in icons, "shared inline vector icon system is available")

failed = [message for ok, message in checks if not ok]
print(f"v0.4.0 cosmetic audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for message in failed: print("FAIL:", message)
    raise SystemExit(1)
print("Cosmetic pass is coherent: vector icons, touch sizing, themes, and reduced-motion support are intact.")
