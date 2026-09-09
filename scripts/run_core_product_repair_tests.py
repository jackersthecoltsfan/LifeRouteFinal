#!/usr/bin/env python3
"""Execute production gap recommendation seam on macOS; no Simulator required.

Only route-building and MapKit endpoints are doubles.
The candidate, date, duration, fit, limits, and publication remain production.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def between(text, start, end):
    return text[text.index(start):text.index(end, text.index(start))]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    root, out = args.source.resolve(), args.output.resolve()
    assert root != out and root not in out.parents
    out.mkdir(parents=True, exist_ok=False)
    read = lambda path: (root/path).read_text()
    route = read('LifeRoute/DayRoutePlanningCore.swift')
    routing = read('LifeRoute/RoutingLocationDomain.swift')
    seams = {
        'route': between(route, 'struct LifeRouteDayRouteLeg:', '    func startFullRoute(')
        + between(route, '    private func googleTravelMode(', '    private static func buildRoute(')
        + between(route, '    private static func inputFingerprint(', '    private static func routeDuration(')
        + ROUTE_ENDPOINT + '\n}\n',
        'routing_models': between(routing, 'enum LifeRoutePlaceKind:', 'final class LifeRouteAddressAutocomplete:'),
    }
    (out/'extractions.json').write_text(json.dumps({
        'source': str(root),
        'seams': {k: {'sha256': hashlib.sha256(v.encode()).hexdigest(), 'bytes': len(v.encode())} for k,v in seams.items()},
        'limitations': 'Actual displayed Cat food model values with surrogate UUID and unverified auxiliary defaults; controlled gap and MapKit endpoints. No raw phone database or native recommendation acceptance.'
    }, indent=2)+'\n')
    fixtures = (ROOT/'scripts/core_product_repair_tests.swift').read_text()
    source = 'import Foundation\nimport Combine\nimport CoreLocation\nimport MapKit\nimport OSLog\n'
    source += '\n'.join(seams.values()) + '\n' + fixtures
    (out/'main.swift').write_text(source)
    contracts = ['DayRouteContracts.swift','DayItineraryContracts.swift','LiveDayRunContracts.swift',
                 'FullRouteHandoffContracts.swift']
    command = ['xcrun','swiftc','-swift-version','5','-parse-as-library','-module-cache-path',str(out/'module-cache')]
    command += [str(root/'LifeRoute'/name) for name in contracts]
    command += [str(out/'main.swift'),'-o',str(out/'core-product-tests')]
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0', PYTHONDONTWRITEBYTECODE='1')
    result = subprocess.run(command, env=env, text=True, capture_output=True)
    (out/'compile.log').write_text(result.stdout+result.stderr)
    if result.returncode:
        print(result.stdout+result.stderr)
        raise SystemExit(result.returncode)
    result = subprocess.run([str(out/'core-product-tests')], env=env, text=True, capture_output=True)
    (out/'results.log').write_text(result.stdout+result.stderr)
    print(result.stdout+result.stderr)
    raise SystemExit(result.returncode)


ROUTE_ENDPOINT = r'''
    static var fixtureTravelSeconds: TimeInterval = 300
    static var fixtureFailLocation = false
    static var fixtureQueries: [String] = []
    static var fixtureSuspended = false
    private static var fixtureRouteWaiter: CheckedContinuation<TimeInterval, Error>?
    static var fixtureIsWaiting: Bool { fixtureRouteWaiter != nil }
    static func resumeFixtureRoute() {
        fixtureRouteWaiter?.resume(returning: fixtureTravelSeconds)
        fixtureRouteWaiter = nil
    }
    private static func buildRoute(
        appointments: [LifeRouteRouteAppointment], beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop], returnHome: Bool, homeAddress: String,
        currentLocation: CLLocation?, mode: LifeRouteTransportMode
    ) async throws -> BuiltRoute {
        let nodes = appointments.map { LifeRouteItineraryNode(id: "event:\($0.id)", kind: .appointment,
            title: $0.title, address: $0.address, start: $0.start, end: $0.end, isRoutable: true) }
        let leg = LifeRouteDayRouteLeg(id: "leg:fixture", sequence: 1, fromNodeID: nodes[0].id, toNodeID: nodes[1].id,
            fromTitle: nodes[0].title, fromAddress: nodes[0].address, toTitle: nodes[1].title,
            toAddress: nodes[1].address, travelTimeSeconds: 600, distanceMeters: 2000)
        return BuiltRoute(nodes: nodes, legs: [leg])
    }
    private static func mapItem(for address: String, fallbackName: String) async throws -> MKMapItem {
        fixtureQueries.append(address)
        if fixtureFailLocation && address == "Any Walmart" { throw DayRoutePlanningError.locationNotFound(address) }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 40, longitude: -75)))
        item.name = fallbackName
        return item
    }
    private static func routeDuration(from: MKMapItem, to: MKMapItem, mode: LifeRouteTransportMode) async throws -> TimeInterval {
        if fixtureSuspended {
            return try await withCheckedThrowingContinuation { fixtureRouteWaiter = $0 }
        }
        return fixtureTravelSeconds
    }
'''

if __name__ == '__main__':
    main()
