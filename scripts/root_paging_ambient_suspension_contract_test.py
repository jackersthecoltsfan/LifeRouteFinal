#!/usr/bin/env python3
"""Prove Prototype B pauses ambient work without replacing page interaction."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = (ROOT / "LifeRoute/V054ContentView.swift").read_text()
COORDINATOR = (ROOT / "LifeRoute/LifeRouteVisualActivityCoordinator.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Root-paging ambient suspension contract failed: {message}")


shell_start = CONTENT.index("private var interactivePageRootShell")
shell_end = CONTENT.index("#endif", shell_start)
shell = CONTENT[shell_start:shell_end]
require(".tabViewStyle(.page(indexDisplayMode: .never))" in shell, "Prototype B retains native finger-tracked page style")
require("LifeRouteRootPagingAmbientSuspensionModifier(router: router)" in shell, "Prototype B owns the bounded ambient suspension observer")
require("offset(" not in shell and "transition(" not in shell, "the optimizer adds no replacement page motion")

modifier_start = CONTENT.index("private struct LifeRouteRootPagingAmbientSuspensionModifier")
modifier_end = CONTENT.index("#endif", modifier_start)
modifier = CONTENT[modifier_start:modifier_end]
require(".simultaneousGesture(" in modifier, "page gesture remains owned by TabView")
require("router.shouldShowBottomToolbar" in modifier, "ambient suspension starts only at a root screen")
require("abs(value.translation.width) >= abs(value.translation.height) * 1.2" in modifier, "vertical scrolling does not start root paging suspension")
require("coordinator.acquireAmbientSuspension()" in modifier, "horizontal paging reuses the shared reference-counted coordinator")
require("coordinator.releaseAmbientSuspension(requestID)" in modifier, "the exact request is released")
require("settleDelayNanoseconds: UInt64 = 320_000_000" in modifier, "suspension covers the bounded settle animation")
require(".onChange(of: scenePhase)" in modifier, "backgrounding cannot leak a paging suspension request")
require(".onChange(of: router.shouldShowBottomToolbar)" in modifier, "entering a deep screen releases any paging suspension")
require("@Published" not in modifier, "gesture progress introduces no published per-frame state")
require("offset(" not in modifier and "router.select" not in modifier, "optimizer cannot alter page position or selection")

require("private var activeRequests = Set<UUID>()" in COORDINATOR, "shared coordinator remains reference counted")
require("func setThemeCenterVisible(_ isVisible: Bool)" in COORDINATOR, "Theme Center keeps the same suspension owner")

print("LifeRoute Prototype B ambient-suspension contract passed: page semantics preserved, ambient clock paused only for root drag/settle")
