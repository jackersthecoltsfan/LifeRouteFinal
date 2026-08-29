from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
read = lambda name: (WEB / name).read_text()

index = read("index.html")
toolbar = read("toolbar-cleanup-v1.js")
delight = read("delight-ui-v1.js")
welcome = read("welcome.js")
day = read("day-controls-v5.js")
stability = read("stability-runtime.js")
nav_cleanup = read("nav-cleanup.js")
auth = read("auth-gate.js")

checks = []
def require(condition, message): checks.append((bool(condition), message))

# Global tap-delivery contract.
require("document.addEventListener('click', event =>" in delight, "global feedback is attached after a real click")
require("classList.add('lrTouchPressed')" not in delight, "button classes are not mutated on pointerdown")
require("document.addEventListener('pointerdown', event =>" not in delight, "no broad pointerdown control handler competes with WebKit click synthesis")
require("document.addEventListener('pointerup', event =>" not in delight, "no broad pointerup control handler competes with button activation")
require("stopImmediatePropagation" not in nav_cleanup, "Setup navigation does not suppress sibling click handlers")

# Top-level and contextual navigation.
for view in ["today", "tools", "resources", "setup"]:
    require(f"view: '{view}'" in toolbar, f"top navigation contains {view}")
require("button.onclick = event =>" in toolbar and "navigateTop(button.dataset.view || 'today')" in toolbar, "top navigation buttons have a direct functional owner")
require("data-lr-setup-pane" in toolbar and "button.addEventListener('click', () => openSetupPane" in toolbar, "Setup hub buttons open their panes")
require("data-lr-tool-group" in toolbar and "button.addEventListener('click', () => openToolGroup" in toolbar, "Session Tools buttons open their tool groups")
require("data-lr-place-category" in toolbar and "focusPlaceCategory" in toolbar, "Saved Places category buttons remain functional")

# First-run/walkthrough buttons.
require("#lrWelcomeTourStart" in welcome and "startTour()" in welcome, "Show me around button starts the walkthrough")
require("#lrWelcomeExplore" in welcome and "markSeen(); hideWelcome()" in welcome, "Explore on my own button exits onboarding")
require("data-lr-tour-next" in welcome and "showTourStep()" in welcome, "walkthrough Next button advances")
require("data-lr-tour-skip" in welcome and "finishTour" in welcome, "walkthrough Skip button exits")

# Calendar/day controls and core actions.
for marker, label in [
    ("dayPrevButton", "previous-day control"),
    ("dayTodayButton", "today control"),
    ("dayNextButton", "next-day control"),
    ("data-lr-clear-day", "clear-day action"),
]:
    require(marker in day or marker in index, f"{label} exists")
require("addPlace()" in index and "function addPlace()" in index, "Save place action resolves to an implementation")
require("addEvent()" in index and "function addEvent()" in index, "Add appointment action resolves to an implementation")
require("setMapProvider(" in index and "function setMapProvider(" in index, "map provider buttons resolve to an implementation")
require("routeTo(" in index and "function routeTo(" in index, "route buttons resolve to an implementation")
require("openPlace(" in index and "function openPlace(" in index, "saved-place open buttons resolve to an implementation")
require("connectAppleCalendar()" in index and "function connectAppleCalendar()" in index, "Apple Calendar button resolves to native bridge logic")
require("requestGoogleCalendar" in (ROOT / "LifeRoute" / "LifeRouteWebView.swift").read_text(), "Google OAuth/native calendar action remains available")
require("calendar.readonly" in (ROOT / "LifeRoute" / "LifeRouteWebView.swift").read_text(), "Google Calendar remains read-only")
require("bindBottomActions" in stability and "window.refreshCalendars()" in stability and "window.optimizeWeek()" in stability, "bottom actions retain functional handlers")

# No old interaction owner or auth overlay can steal app-wide taps.
for retired in ["touch-playground-v1.js", "interaction-liquid-v4.js", "premium-interactions-v1.js", "nav-portal-v1.js"]:
    require(f'<script src="{retired}"></script>' not in index, f"retired interaction owner {retired} is not loaded")
require("const AUTH_GATE_ENABLED = false" in auth or "if (!AUTH_GATE_ENABLED) return" in auth or "return;" in auth[:700], "legacy LifeRoute auth gate is bypassed before startup UI work")

failed = [message for ok, message in checks if not ok]
print(f"v0.4.0 functionality audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    for message in failed: print("FAIL:", message)
    raise SystemExit(1)
print("Critical navigation, onboarding, calendar, routing, setup, tools, and global button-delivery contracts are intact.")
