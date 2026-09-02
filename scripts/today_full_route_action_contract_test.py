#!/usr/bin/env python3
"""Lock Today to the same existing full-route action used by Day Route."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TODAY = (ROOT / "LifeRoute" / "V054TodayView.swift").read_text()
DAY_ROUTE = (ROOT / "LifeRoute" / "DayRoutePlanningView.swift").read_text()
PROVIDER = (ROOT / "LifeRoute" / "FullRouteHandoffContracts.swift").read_text()
FIXTURES = (ROOT / "scripts" / "day_route_contract_tests.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Today full-route action contract failed: {message}")


def section(source: str, start: str, end: str) -> str:
    start_index = source.index(start)
    end_index = source.index(end, start_index)
    return source[start_index:end_index]


today_action = section(TODAY, "private func startRouteControl", "private func timeline")
day_route_action = section(DAY_ROUTE, "private var routeResultsCard", "private func stopRow")

shared_action_markers = (
    "planState.fullRoutePlan",
    "planState.hasStartedSequentialHandoff",
    "planState.nextSequentialLegIndex != nil",
    "planState.continueFullRoute(mode: planState.routeMode)",
    "planState.startFullRoute(mode: planState.routeMode)",
)
for marker in shared_action_markers:
    require(marker in today_action, f"Today retains canonical full-route marker: {marker}")
    require(marker in day_route_action, f"Day Route retains canonical full-route marker: {marker}")

require("planState.startRoute(" not in today_action, "Today never falls back to the single-leg launch API")
require("startRouteDecision" in today_action, "Today retains stale, wrong-day, and no-destination gating")
require("case .stale:" in today_action, "Today explicitly blocks stale generated itineraries")
require("if let itinerary = selectedItinerary" in TODAY and "startRouteControl(itinerary" in TODAY, "Today exposes the full-route control after Generate Full Day produces an itinerary")

provider_markers = (
    "case completeGoogleMaps(URL)",
    "case completeAppleMaps",
    "case sequential",
    "maximumGoogleMobileWaypoints = 3",
    "maximumURLLength = 2_048",
)
for marker in provider_markers:
    require(marker in PROVIDER, f"existing provider behavior remains present: {marker}")

fixture_markers = (
    "Google full-route planning preserves the exact leg order",
    "Google fallback retains every ordered leg",
    "Apple hands off a complete single-leg route",
    "Apple continuation retains the exact ordered legs",
    "Waze fallback retains every ordered leg",
)
for marker in fixture_markers:
    require(marker in FIXTURES, f"existing executable provider coverage remains present: {marker}")

print("LifeRoute Today full-route action contract passed: Today and Day Route share the canonical complete-route pathway")
