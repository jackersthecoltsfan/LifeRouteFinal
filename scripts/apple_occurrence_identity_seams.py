#!/usr/bin/env python3
"""Compile unchanged importer and appointment-node construction with synthetic inputs.

Only EventKit data access is doubled in the importer. No calendars, credentials,
MapKit endpoints, existing user data or native UI are accessed by these fixtures.
"""
import hashlib
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def between(text, start, end):
    assert text.count(start) == 1, f"Expected one production seam: {start}"
    begin = text.index(start)
    return text[begin:text.index(end, begin)]

provider = (ROOT / "LifeRoute/CalendarProviderCore.swift").read_text()
fetch = between(provider, "    private func fetchAppleCalendarEvents()", "    private var hasAppleCalendarReadAccess")
route = (ROOT / "LifeRoute/DayRoutePlanningCore.swift").read_text()
node = between(route, "            let appointmentNode = LifeRouteItineraryNode(", "            let anchoredStops =")
output = "import Foundation\nstruct AppleImportProbe {\nlet eventStore: ProbeEventStore\n"
output += "func fetch() -> [LifeRouteCalendarEvent] { fetchAppleCalendarEvents() }\n" + fetch + "}\n"
output += "enum AppleRouteNodeProbe {\nstatic func node(_ appointment: LifeRouteRouteAppointment) -> LifeRouteItineraryNode {\n"
output += node + "return appointmentNode\n}\n}\n"
Path(sys.argv[1]).write_text(output)
print("Production importer/node seams SHA256: " + hashlib.sha256(output.encode()).hexdigest())
