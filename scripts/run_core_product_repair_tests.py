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
    parser.add_argument('--fixtures', type=Path, default=ROOT/'scripts/core_product_repair_tests.swift')
    parser.add_argument('--test-arg', action='append', default=[])
    args = parser.parse_args()
    root, out = args.source.resolve(), args.output.resolve()
    assert root != out and root not in out.parents
    out.mkdir(parents=True, exist_ok=False)
    read = lambda path: (root/path).read_text()
    route = read('LifeRoute/DayRoutePlanningCore.swift')
    routing = read('LifeRoute/RoutingLocationDomain.swift')
    seams = {
        'launch_configuration': between(
            route,
            'struct LifeRouteLiveLaunchConfiguration:',
            'struct LifeRouteDayRouteLeg:'
        ),
        'route': between(route, 'struct LifeRouteDayRouteLeg:', '    func startFullRoute(')
        + between(route, '    private func googleTravelMode(', '    private static func buildRoute(')
        + between(route, '    private static func inputFingerprint(', '    private static func routeDuration(')
        + ROUTE_ENDPOINT + '\n}\n',
        'routing_models': between(routing, 'enum LifeRoutePlaceKind:', 'final class LifeRouteAddressAutocomplete:'),
    }
    (out/'extractions.json').write_text(json.dumps({
        'source': str(root),
        'seams': {k: {'sha256': hashlib.sha256(v.encode()).hexdigest(), 'bytes': len(v.encode())} for k,v in seams.items()},
        'fixtures': str(args.fixtures.resolve()),
        'production_sha256': hashlib.sha256(route.encode()).hexdigest(),
        'limitations': 'Production planner with controlled route-building and MapKit endpoints. No raw phone database or native recommendation acceptance.'
    }, indent=2)+'\n')
    fixtures = args.fixtures.read_text()
    source = 'import Foundation\nimport Combine\nimport CoreLocation\nimport MapKit\nimport OSLog\n'
    source += '\n'.join(seams.values()) + '\n' + fixtures
    (out/'main.swift').write_text(source)
    contracts = ['DayRouteContracts.swift','DayItineraryContracts.swift','LiveDayRunContracts.swift',
                 'FullRouteHandoffContracts.swift']
    command = ['xcrun','swiftc','-swift-version','5','-D','DEBUG','-parse-as-library','-module-cache-path',str(out/'module-cache')]
    command += [str(root/'LifeRoute'/name) for name in contracts]
    command += [str(out/'main.swift'),'-o',str(out/'core-product-tests')]
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0', PYTHONDONTWRITEBYTECODE='1')
    result = subprocess.run(command, env=env, text=True, capture_output=True)
    (out/'compile.log').write_text(result.stdout+result.stderr)
    if result.returncode:
        print(result.stdout+result.stderr)
        raise SystemExit(result.returncode)
    result = subprocess.run([str(out/'core-product-tests'), *args.test_arg], env=env, text=True, capture_output=True)
    (out/'results.log').write_text(result.stdout+result.stderr)
    print(result.stdout+result.stderr)
    raise SystemExit(result.returncode)


ROUTE_ENDPOINT = r'''
    static var fixtureTravelSeconds: TimeInterval = 300
    static var fixtureFailLocation = false
    static var fixtureQueries: [String] = []
    static var fixtureSuspended = false
    static var fixtureLookupFailures: [String: Error] = [:]
    static var fixtureRouteFailures: [String: Error] = [:]
    static var fixtureSearchResults: [String: [String]] = [:]
    static var fixtureCoordinates: [String: CLLocationCoordinate2D] = [:]
    static var fixtureSearchRegions: [MKCoordinateRegion] = []
    static var fixtureSearchContexts: [String] = []
    static var fixtureSearchResultCounts: [Int] = []
    static var fixtureTravelSecondsByLeg: [String: TimeInterval] = [:]
    static var fixtureRouteQueries: [String] = []
    static var fixtureFailures: [String] = []
    private static var fixtureAddresses: [ObjectIdentifier: String] = [:]
    private static var fixtureRouteWaiters: [CheckedContinuation<TimeInterval, Error>] = []
    static var fixtureIsWaiting: Bool { !fixtureRouteWaiters.isEmpty }
    static var fixturePendingRouteCount: Int { fixtureRouteWaiters.count }
    func fixtureGapTask(_ gapID: String) -> Task<Void, Never>? { gapEvaluationTasks[gapID] }
    static func resumeFixtureRoute(error: Error? = nil) {
        guard !fixtureRouteWaiters.isEmpty else { return }
        let waiter = fixtureRouteWaiters.removeFirst()
        if let error { waiter.resume(throwing: error) }
        else { waiter.resume(returning: fixtureTravelSeconds) }
    }
    private static func buildRoute(
        appointments: [LifeRouteRouteAppointment], beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop], returnHome: Bool, homeAddress: String,
        currentLocation: CLLocation?, mode: LifeRouteTransportMode
    ) async throws -> BuiltRoute {
        let orderedAppointments = appointments.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }
        let nodes = orderedAppointments.map { LifeRouteItineraryNode(id: "event:\($0.id)", kind: .appointment,
            title: $0.title, address: $0.address, start: $0.start, end: $0.end, isRoutable: true) }
        let legs = zip(nodes, nodes.dropFirst()).enumerated().map { index, pair in
            let (source, destination) = pair
            return LifeRouteDayRouteLeg(
                id: "leg:\(source.id)->\(destination.id)", sequence: index + 1,
                fromNodeID: source.id, toNodeID: destination.id,
                fromTitle: source.title, fromAddress: source.address,
                toTitle: destination.title, toAddress: destination.address,
                travelTimeSeconds: 600, distanceMeters: 2000
            )
        }
        return BuiltRoute(nodes: nodes, legs: legs)
    }
    private static func mapItem(for address: String, fallbackName: String) async throws -> MKMapItem {
        fixtureQueries.append(address)
        if let error = fixtureLookupFailures[address] {
            fixtureFailures.append(address)
            throw error
        }
        if fixtureFailLocation && address == "Any Walmart" { throw DayRoutePlanningError.locationNotFound(address) }
        return fixtureMapItem(address: address, name: fallbackName)
    }
    private static func flexiblePlaceMapItems(
        for query: String,
        from source: MKMapItem,
        to destination: MKMapItem,
        limit: Int
    ) async throws -> [MKMapItem] {
        fixtureQueries.append(query)
        if let error = fixtureLookupFailures[query] {
            fixtureFailures.append(query)
            throw error
        }
        if fixtureFailLocation && query == "Any Walmart" {
            throw DayRoutePlanningError.locationNotFound(query)
        }
        let results = fixtureSearchResults[query] ?? [query]
        guard !results.isEmpty else { throw DayRoutePlanningError.locationNotFound(query) }
        fixtureSearchResultCounts.append(results.count)
        fixtureSearchContexts.append(
            "\(fixtureAddresses[ObjectIdentifier(source)] ?? "")->\(fixtureAddresses[ObjectIdentifier(destination)] ?? "")"
        )
        if let region = routeContextSearchRegion(from: source, to: destination) {
            fixtureSearchRegions.append(region)
        }
        return routeContextShortlist(
            results.map { fixtureMapItem(address: $0, name: $0) },
            from: source,
            to: destination,
            limit: limit
        )
    }
    private static func resolvedFlexiblePlaceAddress(_ item: MKMapItem, fallback: String) -> String {
        fixtureAddresses[ObjectIdentifier(item)] ?? fallback
    }
    private static func fixtureMapItem(address: String, name: String) -> MKMapItem {
        let coordinate = fixtureCoordinates[address]
            ?? CLLocationCoordinate2D(latitude: 40, longitude: -75)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        fixtureAddresses[ObjectIdentifier(item)] = address
        return item
    }
    private static func routeDuration(from: MKMapItem, to: MKMapItem, mode: LifeRouteTransportMode) async throws -> TimeInterval {
        let key = "\(fixtureAddresses[ObjectIdentifier(from)] ?? "")->\(fixtureAddresses[ObjectIdentifier(to)] ?? "")"
        fixtureRouteQueries.append(key)
        if let error = fixtureRouteFailures[key] {
            fixtureFailures.append(key)
            throw error
        }
        if fixtureSuspended {
            return try await withCheckedThrowingContinuation { fixtureRouteWaiters.append($0) }
        }
        return fixtureTravelSecondsByLeg[key] ?? fixtureTravelSeconds
    }
'''

if __name__ == '__main__':
    main()
