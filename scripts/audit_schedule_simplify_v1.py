from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
PREPARE = ROOT / "scripts" / "prepare_build.sh"

errors = []

def require(condition, message):
    if not condition:
        errors.append(message)


schedule = (WEB / "schedule-simplify-v1.js").read_text()
prepare = PREPARE.read_text()
index = (WEB / "index.html").read_text()

require("schedule-simplify-v1.js" in prepare or "schedule-simplify-v1.js" in index, "Schedule simplification is not loaded")
for marker in [
    "#today > .metrics{display:none!important}",
    "dayInsight",
    "lrDayMore",
    "moveClearControlsIntoMore",
    "moveEndHomeToHomeSetup",
    "removeExactSmartBadges",
]:
    require(marker in schedule, f"Schedule simplification marker missing: {marker}")
require("window.scrollTo" not in schedule and "scrollIntoView" not in schedule, "Schedule simplification must not control scrolling")

if errors:
    print("Schedule simplification audit failed:")
    for item in errors:
        print(f"- {item}")
    raise SystemExit(1)

print("Schedule simplification audit passed: clutter is reduced without automatic scrolling.")
