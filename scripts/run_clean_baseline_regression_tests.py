#!/usr/bin/env python3
"""Run anonymous Calendar -> Today -> Planner and route-context regressions.

Production calendar/projection/planner code is extracted verbatim. Only storage,
route construction, and MapKit service endpoints use existing controlled doubles.
The same fixture can execute on macOS or in a dedicated iOS Simulator app.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess

from run_core_product_repair_tests import between, ROUTE_ENDPOINT


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--simulator', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    assert ROOT != out and ROOT not in out.parents
    out.mkdir(parents=True, exist_ok=False)
    read = lambda path: (ROOT / path).read_text()
    route = read('LifeRoute/DayRoutePlanningCore.swift')
    today = read('LifeRoute/V054TodayView.swift')
    projection = (
        between(today, '    private var selectedDay: Date', '    private var selectedDayStops:')
        + between(today, '    private var routeAppointments:', '    private var beforeStops:')
    )
    seams = {
        'planner': between(route, 'struct LifeRouteDayRouteLeg:', '    func startFullRoute(')
        + between(route, '    private func googleTravelMode(', '    private static func buildRoute(')
        + between(route, '    private static func inputFingerprint(', '    private static func routeDuration('),
        'today_projection': projection,
        'routing_models': between(read('LifeRoute/RoutingLocationDomain.swift'),
                                  'enum LifeRoutePlaceKind:', 'final class LifeRouteAddressAutocomplete:'),
    }
    storage = between(read('scripts/calendar_cross_provider_dedup_tests.swift'),
                      '@MainActor\nfinal class LifeRoutePersistenceStore', '@main\nstruct CalendarCrossProviderDedupTests')
    source = 'import Foundation\nimport Combine\nimport CoreLocation\nimport MapKit\nimport OSLog\n'
    source += seams['planner'] + ROUTE_ENDPOINT + '\n}\n' + seams['routing_models'] + storage
    # Only access visibility changes; the actual Today mapping remains verbatim.
    source += '@MainActor struct CleanBaselineTodayProjection {\nlet calendarState: CalendarCoreState\n'
    source += projection.replace('private var routeAppointments:', 'var routeAppointments:') + '\n}\n'
    source += read('scripts/clean_baseline_regression_tests.swift')
    (out / 'main.swift').write_text(source)
    contracts = ['CalendarDomain.swift', 'DayRouteContracts.swift', 'DayItineraryContracts.swift',
                 'LiveDayRunContracts.swift', 'FullRouteHandoffContracts.swift']
    manifest = {
        'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'seams': {name: hashlib.sha256(value.encode()).hexdigest() for name, value in seams.items()},
        'sources': {name: hashlib.sha256(read('LifeRoute/' + name).encode()).hexdigest() for name in contracts},
        'fixture_sha256': hashlib.sha256(read('scripts/clean_baseline_regression_tests.swift').encode()).hexdigest(),
        'limitations': 'Controlled service/storage endpoints; actual Today projection and planner publication. Not physical acceptance.',
    }
    (out / 'extractions.json').write_text(json.dumps(manifest, indent=2) + '\n')
    command = ['xcrun', 'swiftc', '-swift-version', '5', '-D', 'DEBUG', '-parse-as-library',
               '-module-cache-path', str(out / 'module-cache')]
    if args.simulator:
        sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
        app = out / 'CleanBaselineHarness.app'
        app.mkdir()
        executable = app / 'CleanBaselineHarness'
        command += ['-sdk', sdk, '-target', 'arm64-apple-ios16.2-simulator']
        with (app / 'Info.plist').open('wb') as handle:
            plistlib.dump({'CFBundleIdentifier': 'com.example.liferoute.clean-baseline-harness',
                          'CFBundleExecutable': executable.name, 'CFBundleName': 'Clean Baseline Harness',
                          'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1',
                          'CFBundleShortVersionString': '1.0', 'MinimumOSVersion': '16.2',
                          'LSRequiresIPhoneOS': True, 'UIDeviceFamily': [1],
                          'UILaunchScreen': {}}, handle)
    else:
        executable = out / 'clean-baseline-tests'
    command += [str(ROOT / 'LifeRoute' / name) for name in contracts]
    command += [str(out / 'main.swift'), '-o', str(executable)]
    result = subprocess.run(command, text=True, capture_output=True)
    (out / 'compile.log').write_text(result.stdout + result.stderr)
    if result.returncode:
        print(result.stdout + result.stderr)
        raise SystemExit(result.returncode)
    if args.simulator:
        subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
        print(app)
    else:
        result = subprocess.run([str(executable)], text=True, capture_output=True)
        (out / 'results.log').write_text(result.stdout + result.stderr)
        print(result.stdout + result.stderr)
        raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
