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


source = 'import Foundation\nimport SwiftUI\n'
source += declaration(root/'LifeRoute/CalendarDomain.swift', 'enum LifeRouteCalendarRange:')
source += '\n' + declaration(root/'LifeRoute/V054ScheduleView.swift', 'enum LifeRouteCalendarDisplayMode:')
source += '\n' + declaration(root/'LifeRoute/V054TodayView.swift', 'enum LifeRouteItineraryScrollPolicy {')
source += '\nenum AppSection { case today, schedule, tools, resources, setup }\n'
source += '\n' + declaration(root/'LifeRoute/LifeRouteDockGlyph.swift', 'struct LifeRouteDockGlyph: Shape') + '\n'
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
let dockSections: [AppSection] = [.today, .schedule, .tools, .resources, .setup]
for size: CGFloat in [24, 28, 44] {
    let frame = CGRect(x: 7, y: 11, width: size, height: size)
    let paths = dockSections.map { LifeRouteDockGlyph(section: $0).path(in: frame) }
    for path in paths {
        check(!path.isEmpty, "Every root has visible native vector geometry")
        let bounds = path.boundingRect
        check(frame.insetBy(dx: 0.825, dy: 0.825).contains(bounds), "Native glyph retains stroke clearance inside its frame")
        check(bounds.width >= size * 0.5 && bounds.height >= size * 0.5, "Native glyph remains recognizable at toolbar scale")
    }
    for first in paths.indices {
        for second in paths.indices where second > first {
            check(!CFEqual(paths[first].cgPath, paths[second].cgPath), "Every root has a distinct native vector silhouette")
        }
    }
}
func coordinates(_ path: Path) -> [CGFloat] {
    var values: [CGFloat] = []
    path.cgPath.applyWithBlock { element in
        let value = element.pointee
        values.append(CGFloat(value.type.rawValue))
        let count: Int
        switch value.type {
        case .moveToPoint, .addLineToPoint: count = 1
        case .addQuadCurveToPoint: count = 2
        case .addCurveToPoint: count = 3
        case .closeSubpath: count = 0
        @unknown default: count = 0
        }
        for index in 0..<count { values += [value.points[index].x, value.points[index].y] }
    }
    return values
}
let wideFrame = CGRect(x: 0, y: 0, width: 56, height: 28)
for section in dockSections {
    let square = LifeRouteDockGlyph(section: section).path(in: CGRect(x: 0, y: 0, width: 28, height: 28))
    let expected = square.applying(CGAffineTransform(translationX: 14, y: 0))
    let wide = LifeRouteDockGlyph(section: section).path(in: wideFrame)
    let actualPoints = coordinates(wide), expectedPoints = coordinates(expected)
    check(actualPoints.count == expectedPoints.count && zip(actualPoints, expectedPoints).allSatisfy { abs($0 - $1) < 0.0001 }, "A wide proposal centers each glyph without stretching it")
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
