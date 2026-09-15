#!/usr/bin/env python3
"""Execute the owner-follow-up presentation policies from production Swift."""
import argparse
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = args.output.resolve()
assert output != root and root not in output.parents, 'Evidence must be outside the checkout'
output.mkdir(parents=True, exist_ok=True)


def declaration(path, marker):
    text = path.read_text()
    assert marker in text, f'Missing owner-required policy: {marker}'
    start = text.index(marker)
    opening = text.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]


source = 'import Foundation\n'
source += declaration(root/'LifeRoute/CalendarDomain.swift', 'enum LifeRouteCalendarRange:')
source += '\n' + declaration(root/'LifeRoute/V054ScheduleView.swift', 'enum LifeRouteCalendarDisplayMode:')
source += '\n' + declaration(root/'LifeRoute/V054TodayView.swift', 'enum LifeRouteItineraryScrollPolicy {')
source += '\nenum AppSection { case today, schedule, tools, resources, setup }\n'
source += 'enum DockPolicy {\n' + declaration(root/'LifeRoute/UI01Presentation.swift', 'static func symbolName(for section: AppSection)') + '\n}\n'
source += r'''
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}
check(LifeRouteCalendarDisplayMode.allCases == [.day, .month], "Exactly two display modes")
check(LifeRouteCalendarDisplayMode(restoring: .week) == .day, "Obsolete Week falls back to Day")
check(LifeRouteCalendarDisplayMode(restoring: .day).range == .day, "Day remains Day")
check(LifeRouteCalendarDisplayMode(restoring: .month).range == .month, "Month remains Month")
let now = Date(timeIntervalSince1970: 1772958600)
for zone in ["America/New_York", "Pacific/Honolulu", "Asia/Tokyo"] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    let sameDay = calendar.startOfDay(for: now)
    let otherDay = calendar.date(byAdding: .day, value: -1, to: sameDay)!
    check(LifeRouteCalendarDisplayMode.day.title(selectedDate: sameDay, now: now, calendar: calendar) == "Today", "Same local date is Today")
    check(LifeRouteCalendarDisplayMode.day.title(selectedDate: otherDay, now: now, calendar: calendar) == "Day", "Another local date is Day")
    check(LifeRouteCalendarDisplayMode.month.title(selectedDate: sameDay, now: now, calendar: calendar) == "Month", "Month label is stable")
    check(LifeRouteCalendarDisplayMode.month.title(selectedDate: otherDay, now: now, calendar: calendar) == "Month", "Month preserves its label across dates")
}
for (section, symbol) in [(AppSection.today, "sun.max.fill"), (.schedule, "calendar"), (.tools, "wrench.and.screwdriver.fill"), (.resources, "book.fill"), (.setup, "gearshape.fill")] {
    check(DockPolicy.symbolName(for: section) == symbol, "Centralized native dock mapping")
}
func owns(_ x: Double, _ y: Double, _ offset: Double, _ maximum: Double = 400) -> Bool {
    LifeRouteItineraryScrollPolicy.innerOwnsPan(horizontalVelocity: x, verticalVelocity: y, offsetY: offset, minimumOffsetY: 0, maximumOffsetY: maximum)
}
check(owns(0, -100, 200), "Inner scroll owns upward movement in middle")
check(owns(0, 100, 200), "Inner scroll owns downward movement in middle")
check(!owns(0, -100, 400), "Next upward swipe at bottom reaches ancestor")
check(!owns(0, 100, 0), "Next downward swipe at top reaches ancestor")
check(owns(0, -100, 0), "Top can scroll toward bottom")
check(owns(0, 100, 400), "Bottom can scroll toward top")
check(!owns(100, 20, 200), "Horizontal root paging remains available")
check(!owns(0, -100, 0, 0), "Short content delegates to outer page")
check(!owns(0, -100, 399.8), "Subpixel bottom boundary delegates")
print("PASS: \(checks) owner-follow-up presentation assertions")
'''
swift = output/'OwnerFollowupPolicies.swift'
swift.write_text(source)
environment = dict(os.environ)
environment.pop('SDKROOT', None)
environment['CLANG_MODULE_CACHE_PATH'] = str(output/'module-cache')
subprocess.run(['xcrun', '--sdk', 'macosx', 'swiftc', str(swift), '-o', str(output/'policies')], check=True, env=environment)
subprocess.run([str(output/'policies')], check=True, env=environment)
