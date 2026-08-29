from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOMAIN = ROOT / "LifeRoute" / "CalendarDomain.swift"
CONTENT = ROOT / "LifeRoute" / "ContentView.swift"
PROJECT = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"

errors: list[str] = []
checks: list[str] = []


def require(condition: bool, message: str) -> None:
    if condition:
        checks.append(message)
    else:
        errors.append(message)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Could not read {path.relative_to(ROOT)}: {exc}")
        return ""


domain = read(DOMAIN)
content = read(CONTENT)
project = read(PROJECT)

require("import Foundation" in domain and "import Combine" in domain, "Calendar domain is native Foundation/Combine")
for forbidden in ["WebKit", "UIKit", "JavaScript", "WKWebView", "MutationObserver", "UserDefaults", "localStorage"]:
    require(forbidden not in domain, f"Calendar domain avoids unrelated runtime/browser persistence dependency: {forbidden}")

for source in ["manual", "apple", "google", "calendarLink"]:
    require(f"case {source}" in domain, f"Normalized calendar source exists: {source}")
require("struct LifeRouteCalendarEvent: Identifiable, Codable, Hashable" in domain, "Calendar event is a plain normalized value model")
require("final class CalendarCoreState: ObservableObject" in domain, "Calendar state has one explicit native owner")
require("configured.firstWeekday = 2" in domain, "Week calculations explicitly start on Monday")
require("func events(on date: Date)" in domain, "Day event grouping exists")
require("func weekDates(containing date: Date? = nil)" in domain, "Week grouping exists")
require("func monthDates(containing date: Date? = nil)" in domain, "Month grouping exists")
require("func visibleEvents(in range: LifeRouteCalendarRange)" in domain, "Range event selection exists")
require("func shiftSelection(_ range: LifeRouteCalendarRange, by amount: Int)" in domain, "Day/Week/Month period navigation exists")
require("func addManualEvent(" in domain, "Manual appointment creation exists")
require("guard !cleanTitle.isEmpty" in domain, "Manual appointments reject blank titles")
require("guard end > start" in domain, "Manual appointments reject invalid time ranges")
require("@Published private(set) var events" in domain, "Event mutations remain owned by CalendarCoreState")

require("@StateObject private var calendarState = CalendarCoreState()" in content, "Root view owns one CalendarCoreState")
schedule_call = re.search(r"ScheduleCoreView\(([^\n]*)\)", content)
require(bool(schedule_call) and "calendarState: calendarState" in schedule_call.group(1), "Schedule receives the root calendar state explicitly even as reviewed provider dependencies are added")
require("Picker(\"Schedule range\"" in content and "LifeRouteCalendarRange.allCases" in content, "Schedule exposes Day / Week / Month native selection")
require("calendarState.shiftSelection(selectedRange, by: -1)" in content and "calendarState.shiftSelection(selectedRange, by: 1)" in content, "Schedule period controls use calendar owner")
require("DatePicker(\"Selected date\"" in content, "Schedule allows direct date selection")
require("CalendarEventsView" in content and "CalendarEventRow" in content, "Schedule renders normalized calendar events natively")
require("Button(\"Add appointment\")" in content and "calendarState.addManualEvent(" in content, "Manual appointment form writes through CalendarCoreState")
require("calendarState.removeEvent(id: eventID)" in content and "if event.source == .manual" in content, "Manual appointment deletion is wired without exposing provider-event deletion")
require(".accessibilityLabel(\"Delete \\(event.title)\")" in content, "Manual appointment deletion has an explicit accessibility label")
require("Appointment saved locally on this iPhone." in content, "UI states durable manual-appointment storage truthfully")
require("UserDefaults" not in content and "@AppStorage" not in content, "Calendar UI avoids ad-hoc preference persistence")
require("CalendarDomain.swift in Sources" in project, "Calendar domain is compiled into the active target")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView runtime remains quarantined")

if errors:
    print("LifeRoute v0.5.0 calendar-core audit FAILED")
    for error in errors:
        print(f"- FAIL: {error}")
    raise SystemExit(1)

print(f"LifeRoute v0.5.0 calendar-core audit passed ({len(checks)} checks).")
for check in checks:
    print(f"- OK: {check}")
