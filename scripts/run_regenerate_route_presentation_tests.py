#!/usr/bin/env python3
"""Exercise the production route-regeneration state lifecycle on macOS.

Only the asynchronous route-service boundary is replaced. Publication,
generation tokens, loading state, retained results, and error handling remain
the production DayRoutePlanningCore implementation.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def between(text: str, start: str, end: str) -> str:
    begin = text.index(start)
    return text[begin:text.index(end, begin)]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    root = args.source.resolve()
    output = args.output.resolve()
    if root == output or root in output.parents:
        raise SystemExit("Output must be outside the source worktree")
    output.mkdir(parents=True, exist_ok=False)

    route = (root / "LifeRoute/DayRoutePlanningCore.swift").read_text()
    routing = (root / "LifeRoute/RoutingLocationDomain.swift").read_text()
    seams = {
        "route": (
            between(route, "struct LifeRouteDayRouteLeg:", "    func startFullRoute(")
            + between(route, "    private func googleTravelMode(", "    private static func buildRoute(")
            + between(route, "    private static func inputFingerprint(", "    private static func routeDuration(")
            + ROUTE_ENDPOINT
            + "\n}\n"
        ),
        "routing_models": between(
            routing,
            "enum LifeRoutePlaceKind:",
            "final class LifeRouteAddressAutocomplete:",
        ),
    }
    (output / "extractions.json").write_text(
        json.dumps(
            {
                "source": str(root),
                "seams": {
                    name: {
                        "sha256": hashlib.sha256(value.encode()).hexdigest(),
                        "bytes": len(value.encode()),
                    }
                    for name, value in seams.items()
                },
                "mocked_boundary": "asynchronous route service only",
            },
            indent=2,
        )
        + "\n"
    )

    fixtures = (root / "scripts/regenerate_route_presentation_tests.swift").read_text()
    source = "import Foundation\nimport Combine\nimport CoreLocation\nimport MapKit\nimport OSLog\n"
    source += "\n".join(seams.values()) + "\n" + fixtures
    (output / "main.swift").write_text(source)

    contracts = [
        "DayRouteContracts.swift",
        "DayItineraryContracts.swift",
        "LiveDayRunContracts.swift",
        "FullRouteHandoffContracts.swift",
    ]
    command = [
        "xcrun",
        "swiftc",
        "-swift-version",
        "5",
        "-parse-as-library",
        "-module-cache-path",
        str(output / "module-cache"),
    ]
    command += [str(root / "LifeRoute" / name) for name in contracts]
    command += [str(output / "main.swift"), "-o", str(output / "regenerate-route-tests")]
    environment = dict(os.environ, GIT_OPTIONAL_LOCKS="0", PYTHONDONTWRITEBYTECODE="1")
    compiled = subprocess.run(command, env=environment, text=True, capture_output=True)
    (output / "compile.log").write_text(compiled.stdout + compiled.stderr)
    if compiled.returncode:
        print(compiled.stdout + compiled.stderr)
        raise SystemExit(compiled.returncode)

    result = subprocess.run(
        [str(output / "regenerate-route-tests")],
        env=environment,
        text=True,
        capture_output=True,
    )
    (output / "results.log").write_text(result.stdout + result.stderr)
    print(result.stdout + result.stderr)
    raise SystemExit(result.returncode)


ROUTE_ENDPOINT = r'''
    static var fixtureBuildSuspended = false
    static var fixtureBuildShouldFail = false
    private static var fixtureBuildWaiter: CheckedContinuation<Void, Never>?
    static var fixtureBuildWaiting: Bool { fixtureBuildWaiter != nil }

    static func resumeFixtureBuild() {
        let waiter = fixtureBuildWaiter
        fixtureBuildWaiter = nil
        waiter?.resume()
    }

    private static func buildRoute(
        appointments: [LifeRouteRouteAppointment], beforeStops: [LifeRouteDayStop],
        afterStops: [LifeRouteDayStop], returnHome: Bool, homeAddress: String,
        currentLocation: CLLocation?, mode: LifeRouteTransportMode
    ) async throws -> BuiltRoute {
        if fixtureBuildSuspended {
            await withCheckedContinuation { fixtureBuildWaiter = $0 }
        }
        if fixtureBuildShouldFail {
            throw DayRoutePlanningError.routeUnavailable("Controlled destination")
        }
        let nodes = appointments.map {
            LifeRouteItineraryNode(
                id: "event:\($0.id)", kind: .appointment, title: $0.title,
                address: $0.address, start: $0.start, end: $0.end,
                isAllDay: $0.isAllDay, isRoutable: true
            )
        }
        let leg = LifeRouteDayRouteLeg(
            id: "leg:regeneration-fixture", sequence: 1,
            fromNodeID: nodes[0].id, toNodeID: nodes[1].id,
            fromTitle: nodes[0].title, fromAddress: nodes[0].address,
            toTitle: nodes[1].title, toAddress: nodes[1].address,
            travelTimeSeconds: 600, distanceMeters: 2_000
        )
        return BuiltRoute(nodes: nodes, legs: [leg])
    }

    private static func mapItem(for address: String, fallbackName: String) async throws -> MKMapItem {
        let item = MKMapItem(
            placemark: MKPlacemark(
                coordinate: CLLocationCoordinate2D(latitude: 40, longitude: -75)
            )
        )
        item.name = fallbackName
        return item
    }

    private static func flexiblePlaceMapItems(
        for query: String,
        from source: MKMapItem,
        to destination: MKMapItem,
        limit: Int
    ) async throws -> [MKMapItem] {
        [try await mapItem(for: query, fallbackName: query)]
    }

    private static func resolvedFlexiblePlaceAddress(_ item: MKMapItem, fallback: String) -> String {
        fallback
    }

    private static func routeDuration(
        from: MKMapItem, to: MKMapItem, mode: LifeRouteTransportMode
    ) async throws -> TimeInterval {
        600
    }
'''


if __name__ == "__main__":
    main()
