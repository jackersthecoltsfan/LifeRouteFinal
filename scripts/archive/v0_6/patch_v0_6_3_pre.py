#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "LifeRoute/LiveDayActivityCore.swift"
text = path.read_text(encoding="utf-8")

if "day: Date = Date()" not in text:
    marker = '''    func start(
        events: [LifeRouteCalendarEvent],
        savedPlaces: [LifeRouteSavedPlace],
        routeEstimates: [UUID: LifeRouteRouteEstimate],
        returnHomePlanned: Bool
    ) async {'''
    replacement = '''    func start(
        events: [LifeRouteCalendarEvent],
        savedPlaces: [LifeRouteSavedPlace],
        routeEstimates: [UUID: LifeRouteRouteEstimate],
        returnHomePlanned: Bool,
        day: Date = Date()
    ) async {'''
    if text.count(marker) != 1:
        raise SystemExit("v0.6.3 pre-patch failed: Live Activity start signature")
    text = text.replace(marker, replacement, 1)
    text = text.replace(
        'message = "Add a timed event today before starting Live Day on the Lock Screen."',
        'message = "Add a timed event on the selected day before starting Live Day on the Lock Screen."',
        1,
    )
    text = text.replace(
        "dayLabel: Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())",
        "dayLabel: day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())",
        1,
    )
    path.write_text(text, encoding="utf-8")

print("LifeRoute v0.6.3 selected-day Live Activity pre-patch applied.")
