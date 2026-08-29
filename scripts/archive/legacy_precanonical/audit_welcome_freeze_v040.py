from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
WELCOME = WEB / "welcome.js"
PBX = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"
HOST_PLIST = ROOT / "LifeRoute" / "Info.plist"
LIVE_PLIST = ROOT / "LifeRouteLiveActivity" / "Info.plist"
TESTFLIGHT = ROOT / ".github" / "workflows" / "testflight.yml"

welcome = WELCOME.read_text(encoding="utf-8")
pbx = PBX.read_text(encoding="utf-8")
host_plist = HOST_PLIST.read_text(encoding="utf-8")
live_plist = LIVE_PLIST.read_text(encoding="utf-8")
testflight = TESTFLIGHT.read_text(encoding="utf-8")

checks: list[tuple[bool, str]] = []

def require(condition: bool, message: str) -> None:
    checks.append((bool(condition), message))

# Freeze prevention on the exact first-run screen shown in physical-device testing.
require("__lifeRouteWelcomePerformanceV040" in welcome, "v0.4.0 welcome performance marker is present")
require("MutationObserver" not in welcome, "welcome owns no DOM MutationObserver")
require("setInterval(" not in welcome, "welcome owns no recurring interval")
require("backdrop-filter" not in welcome, "welcome avoids live backdrop blur")
require("@keyframes lrWelcome" not in welcome, "welcome has no infinite startup animation")
require("WELCOME_RETRY_DELAYS = [0, 500, 1500, 3500]" in welcome, "settings replay lookup is bounded")
require("ensureWelcome();\n    installReplay();\n    setTimeout(maybeShow, 220);" in welcome, "startup mounts only welcome plus bounded replay setup")
require("ensureWelcome();ensureTour()" not in welcome and "ensureWelcome(); ensureTour()" not in welcome, "tour DOM is not pre-mounted on startup")
require("document.documentElement.dataset.lifeRouteWelcomeActive = '1'" in welcome, "welcome explicitly marks lightweight startup mode")
require("delete document.documentElement.dataset.lifeRouteWelcomeActive" in welcome, "welcome startup mode is removed on exit")
require('html[data-life-route-welcome-active="1"] .app{visibility:hidden!important}' in welcome, "underlying app painting is suspended while welcome is visible")
require('html[data-life-route-welcome-active="1"] #lifeRouteDelightBackdrop' in welcome, "ambient backdrop is disabled while welcome is visible")
require("touch-action:manipulation!important" in welcome, "welcome actions are optimized for immediate touch")
require("version: '2.1.0'" in welcome, "welcome runtime version is upgraded")

# Apple-visible version contract. prepare_build runs the patch after Live Activity
# target creation, so every prepared target must resolve to marketing version 0.4.0.
versions = re.findall(r"MARKETING_VERSION = ([^;]+);", pbx)
require(len(versions) >= 4, "prepared project contains host and Live Activity Debug/Release marketing versions")
require(bool(versions) and set(versions) == {"0.4.0"}, "all prepared targets use marketing version 0.4.0")
require("<string>$(MARKETING_VERSION)</string>" in host_plist, "host Info.plist exposes MARKETING_VERSION to Apple")
require("<string>$(MARKETING_VERSION)</string>" in live_plist, "Live Activity Info.plist exposes MARKETING_VERSION to Apple")
require('CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER}"' in testflight, "TestFlight build number increments from GitHub run number")
require("<key>manageAppVersionAndBuildNumber</key><false/>" in testflight, "App Store export preserves the prepared 0.4.0 version/build values")

failed = [message for ok, message in checks if not ok]
print(f"LifeRoute v0.4.0 welcome/version audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for message in failed:
        print("FAIL:", message)
    raise SystemExit(1)

print("Welcome startup is observer-free/static/touch-safe, and the next Apple/TestFlight marketing version is locked to 0.4.0.")
