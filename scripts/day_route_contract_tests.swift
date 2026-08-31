import Foundation

@main
struct DayRouteContractTests {
    private static var assertionCount = 0

    static func main() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = ISO8601DateFormatter().date(from: "2026-08-30T12:00:00Z")!
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!

        let before = LifeRouteDayStop(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Pharmacy",
            address: "1 Main Street",
            position: .before,
            day: day
        )
        let after = LifeRouteDayStop(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Grocery",
            address: "2 Main Street",
            position: .after,
            day: day
        )

        var stored: [LifeRouteDayStop] = []
        let firstInsert = LifeRouteDayStopCollection.adding(before, to: stored, calendar: calendar)
        stored = firstInsert.stops
        expect(firstInsert.inserted, "first stop inserts")
        expect(stored.count == 1, "first stop is retained")

        let duplicate = LifeRouteDayStop(
            title: " Pharmacy ",
            address: " 1 MAIN STREET ",
            position: .before,
            day: day
        )
        let duplicateInsert = LifeRouteDayStopCollection.adding(duplicate, to: stored, calendar: calendar)
        stored = duplicateInsert.stops
        expect(!duplicateInsert.inserted, "semantic duplicate is rejected")
        expect(stored.count == 1, "duplicate is not inserted")

        let secondInsert = LifeRouteDayStopCollection.adding(after, to: stored, calendar: calendar)
        stored = secondInsert.stops
        expect(secondInsert.inserted, "distinct stop inserts")
        expect(LifeRouteDayStopCollection.stops(on: day, in: stored, calendar: calendar).count == 2, "same-day stops restore")
        expect(LifeRouteDayStopCollection.stops(on: nextDay, in: stored, calendar: calendar).isEmpty, "stops remain scoped to their day")

        let appointments = [
            LifeRouteRouteAppointment(id: "late", title: "Second appointment", address: "20 Main Street", start: day.addingTimeInterval(7_200)),
            LifeRouteRouteAppointment(id: "unlocated", title: "Remote appointment", address: "", start: day.addingTimeInterval(5_400)),
            LifeRouteRouteAppointment(id: "early", title: "First appointment", address: "10 Main Street", start: day.addingTimeInterval(3_600))
        ]
        let sequence = LifeRouteDaySequenceBuilder.waypoints(
            appointments: appointments,
            beforeStops: [before, before],
            afterStops: [after, after]
        )

        expect(sequence.map(\.title) == ["Pharmacy", "First appointment", "Remote appointment", "Second appointment", "Grocery"], "full-day sequence preserves boundary-stop and appointment order")
        expect(sequence.filter { $0.kind == .stop }.count == 2, "each intended stop appears once")
        expect(sequence.filter { $0.kind == .appointment }.count == 3, "all appointments remain in the generated day")
        expect(sequence.contains { $0.title == "Remote appointment" && $0.address.isEmpty }, "events without a route address are not silently removed")
        expect(!LifeRouteDaySequenceBuilder.waypoints(appointments: [], beforeStops: [before], afterStops: []).isEmpty, "a saved stop can generate a stop-only day")

        let anchored = LifeRouteDayStop(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            title: "Dunkin",
            address: "3 Main Street",
            position: .after,
            day: day,
            durationMinutes: 20,
            afterAppointmentID: "early"
        )
        let anchoredSequence = LifeRouteDaySequenceBuilder.waypoints(
            appointments: appointments,
            beforeStops: [],
            afterStops: [anchored, anchored, after]
        )
        expect(
            anchoredSequence.map(\.title) == ["First appointment", "Dunkin", "Remote appointment", "Second appointment", "Grocery"],
            "an intermediate stop remains directly after its anchored appointment"
        )
        expect(
            anchoredSequence.filter { $0.id == "stop:\(anchored.id.uuidString)" }.count == 1,
            "an anchored intermediate stop is not duplicated"
        )

        stored.append(anchored)
        let encoded = try JSONEncoder().encode(stored)
        let decoded = try JSONDecoder().decode([LifeRouteDayStop].self, from: encoded)
        expect(decoded == stored, "persisted stops round-trip with stable identity")
        expect(decoded.last?.afterAppointmentID == "early", "intermediate-stop appointment ownership persists")

        let removed = LifeRouteDayStopCollection.removing(id: before.id, from: decoded)
        expect(removed.count == 2 && !removed.contains(where: { $0.id == before.id }), "removal prevents a deleted stop from returning")

        testRouteBufferContracts()
        testCanonicalItineraryProjection()
        testUsableGapAndCandidateFit()
        testReturnHomeAndStopOnlyContracts()
        testUnsafeRouteBoundariesRemainVisible()
        testStableIdentityAndOrdering()
        testFullRouteHandoffs()

        print("Day route executable contract fixtures passed (\(assertionCount) assertions).")
    }

    // Catches a route preference that silently changes the established ten-minute
    // default, omits a supported preset, or permits an unbounded custom value.
    private static func testRouteBufferContracts() {
        let standard = LifeRouteRouteBuffer()
        expect(standard.minutes == 10, "Route Buffer defaults to ten minutes")
        expect(standard.seconds == 600, "Route Buffer exposes exact seconds")
        expect(
            LifeRouteRouteBuffer.presets.map(\.minutes) == [0, 5, 10, 15, 20, 30],
            "Route Buffer exposes the approved presets in order"
        )
        expect(LifeRouteRouteBuffer(customMinutes: -5).minutes == 0, "custom Route Buffer clamps below zero")
        expect(
            LifeRouteRouteBuffer(customMinutes: 500).minutes == LifeRouteRouteBuffer.maximumCustomMinutes,
            "custom Route Buffer clamps above its documented bound"
        )
    }

    // Catches a planner that counts the buffer once per leg, omits an
    // intermediate stop duration, or gives Today and Live Day different timing.
    private static func testCanonicalItineraryProjection() {
        let itinerary = exampleIntermediateStopItinerary()

        expect(itinerary.nodes.map(\.id) == ["origin:home", "stop:dunkin", "event:life"], "canonical itinerary preserves route-node order")
        expect(itinerary.totalRawTravelSeconds == 42 * 60, "total raw driving sums only MapKit leg durations")
        expect(itinerary.totalRawDistanceMeters == 25_000, "total raw distance sums generated MapKit legs")
        expect(
            itinerary.timeline.map(\.kind) == [.origin, .drive, .stop, .drive, .appointment],
            "timeline interleaves origin, raw drives, stop, and appointment"
        )

        let now = date("2026-09-01T10:24:00Z")
        let leaveBy = date("2026-09-01T10:48:00Z")
        let guidance = itinerary.departureGuidance(at: now)
        expect(guidance?.appointmentNodeID == "event:life", "departure guidance targets the next timed appointment")
        expect(guidance?.leaveBy == leaveBy, "Leave By works backward through both legs, the stop, and one buffer")
        expect(guidance?.rawTravelSeconds == 42 * 60, "departure guidance keeps raw travel separate")
        expect(guidance?.intermediateStopSeconds == 20 * 60, "departure guidance includes intermediate stop duration")
        expect(guidance?.bufferSeconds == 10 * 60, "two route legs receive one appointment buffer")
        expect(guidance?.state == .leaveIn, "a future departure reports Leave In")
        expect(guidance?.secondsUntilDeparture == 24 * 60, "10:24 reports Leave In 24 minutes for a 10:48 departure")
        expect(guidance?.overdueSeconds == 0, "future departure is not overdue")

        let leaveNow = itinerary.departureGuidance(at: leaveBy)
        expect(leaveNow?.state == .leaveNow, "Leave In clamps to Leave Now at the departure boundary")
        expect(leaveNow?.secondsUntilDeparture == 0, "Leave Now never exposes a negative countdown")

        let overdue = itinerary.departureGuidance(at: date("2026-09-01T10:49:00Z"))
        expect(overdue?.state == .overdue, "a missed departure reports overdue")
        expect(overdue?.secondsUntilDeparture == 0, "overdue guidance clamps Leave In to zero")
        expect(overdue?.overdueSeconds == 60, "overdue guidance exposes elapsed lateness separately")

        let live = LifeRouteLiveDayProjection.make(from: itinerary, at: now)
        expect(live?.departure == guidance, "Today and Live Day consume the exact same departure result")
        expect(live?.phaseLabel == "LEAVE IN", "Live Day projects the route-aware departure phase")
        expect(live?.primaryTitle == "LiFe", "Live Day projects the appointment title")
        expect(live?.countdownTarget == leaveBy, "Live Day counts down to Leave By rather than event start")
        expect(live?.routeSummary == "42 min drive · +10 min buffer", "Live Day keeps raw drive and buffer transparent")
        expect(live?.plannedStopSummary == "Dunkin · 20 min", "Live Day projects the intermediate stop from the itinerary")
        expect(live?.returnHomePlanned == false, "Live Day projects the canonical Return Home choice")
    }

    // Catches raw calendar time being presented as usable time or a candidate
    // being accepted without both required route legs.
    private static func testUsableGapAndCandidateFit() {
        let previous = LifeRouteItineraryNode(
            id: "event:morning",
            kind: .appointment,
            title: "Morning appointment",
            address: "1 A Street",
            start: date("2026-09-01T09:00:00Z"),
            end: date("2026-09-01T10:00:00Z")
        )
        let next = LifeRouteItineraryNode(
            id: "event:next",
            kind: .appointment,
            title: "Next appointment",
            address: "2 B Street",
            start: date("2026-09-01T11:30:00Z"),
            end: date("2026-09-01T12:30:00Z")
        )
        let directLeg = LifeRouteItineraryLeg(
            id: "leg:morning-next",
            sequence: 1,
            fromNodeID: previous.id,
            toNodeID: next.id,
            rawTravelSeconds: 28 * 60,
            rawDistanceMeters: 12_000
        )
        let itinerary = LifeRouteGeneratedItinerary(
            id: "day:gap",
            selectedDay: date("2026-09-01T00:00:00Z"),
            generatedAt: date("2026-09-01T08:00:00Z"),
            returnHome: false,
            routeBuffer: .tenMinutes,
            inputFingerprint: "gap-fixture",
            nodes: [previous, next],
            legs: [directLeg]
        )

        let gap = itinerary.usableGaps.first
        expect(itinerary.usableGaps.count == 1, "two timed commitments produce one usable-gap projection")
        expect(gap?.rawCalendarGapSeconds == 90 * 60, "gap reports the raw ninety-minute calendar interval")
        expect(gap?.requiredTravelSeconds == 28 * 60, "gap reports raw required travel separately")
        expect(gap?.requiredStopSeconds == 0, "direct gap has no preselected stop duration")
        expect(gap?.bufferSeconds == 10 * 60, "gap applies one arrival buffer")
        expect(gap?.usableSeconds == 52 * 60, "ninety minutes minus drive and one buffer yields fifty-two usable minutes")
        expect(gap?.isRouteSafe == true, "complete direct route data produces route-safe usable time")
        expect(
            itinerary.timeline.map(\.kind) == [.appointment, .usableGap, .drive, .appointment],
            "timeline places usable gap before the required drive to the next commitment"
        )

        guard let gap else {
            expect(false, "usable gap fixture exists")
            return
        }

        let located = LifeRouteGapCandidate.located(
            id: "place:coffee",
            title: "Coffee",
            durationSeconds: 20 * 60,
            inboundTravelSeconds: 15 * 60,
            outboundTravelSeconds: 17 * 60
        )
        let locatedFit = gap.fit(located)
        expect(locatedFit.state == .fits, "located candidate fits when two routes, activity, and one buffer fit")
        expect(locatedFit.availableActivitySeconds == 48 * 60, "located candidate capacity replaces the direct leg with both candidate legs")
        expect(locatedFit.remainingSeconds == 28 * 60, "located fit reports remaining slack after the visit")

        let exactLocated = LifeRouteGapCandidate.located(
            id: "place:exact",
            title: "Exact fit",
            durationSeconds: 48 * 60,
            inboundTravelSeconds: 15 * 60,
            outboundTravelSeconds: 17 * 60
        )
        expect(gap.fit(exactLocated).state == .fits, "located candidate exact fit passes")

        let tooLongLocated = LifeRouteGapCandidate.located(
            id: "place:too-long",
            title: "One minute too long",
            durationSeconds: 49 * 60,
            inboundTravelSeconds: 15 * 60,
            outboundTravelSeconds: 17 * 60
        )
        expect(gap.fit(tooLongLocated).state == .doesNotFit, "located candidate one minute over fails")

        let missingInbound = LifeRouteGapCandidate.located(
            id: "place:no-inbound",
            title: "Unknown inbound",
            durationSeconds: 10 * 60,
            inboundTravelSeconds: nil,
            outboundTravelSeconds: 17 * 60
        )
        let missingOutbound = LifeRouteGapCandidate.located(
            id: "place:no-outbound",
            title: "Unknown outbound",
            durationSeconds: 10 * 60,
            inboundTravelSeconds: 15 * 60,
            outboundTravelSeconds: nil
        )
        expect(gap.fit(missingInbound).state == .routeUnavailable, "located candidate requires an inbound route")
        expect(gap.fit(missingOutbound).state == .routeUnavailable, "located candidate requires an outbound route")

        let exactTodo = LifeRouteGapCandidate.locationlessTodo(
            id: "todo:exact",
            title: "Paperwork",
            durationSeconds: 52 * 60
        )
        let tooLongTodo = LifeRouteGapCandidate.locationlessTodo(
            id: "todo:too-long",
            title: "Long paperwork",
            durationSeconds: 53 * 60
        )
        expect(gap.fit(exactTodo).state == .fits, "locationless To-Do exact fit uses already-derived usable time")
        expect(gap.fit(tooLongTodo).state == .doesNotFit, "locationless To-Do one minute over fails")

        let stop = LifeRouteItineraryNode(
            id: "stop:planned",
            kind: .stop,
            title: "Planned stop",
            address: "3 C Street",
            stopDurationSeconds: 20 * 60
        )
        let withStop = LifeRouteGeneratedItinerary(
            id: "day:required-stop",
            selectedDay: itinerary.selectedDay,
            generatedAt: itinerary.generatedAt,
            returnHome: false,
            routeBuffer: .tenMinutes,
            inputFingerprint: "required-stop-fixture",
            nodes: [previous, stop, next],
            legs: [
                .init(id: "leg:in", sequence: 1, fromNodeID: previous.id, toNodeID: stop.id, rawTravelSeconds: 15 * 60, rawDistanceMeters: 6_000),
                .init(id: "leg:out", sequence: 2, fromNodeID: stop.id, toNodeID: next.id, rawTravelSeconds: 17 * 60, rawDistanceMeters: 7_000),
            ]
        )
        let plannedGap = withStop.usableGaps.first
        expect(plannedGap?.requiredTravelSeconds == 32 * 60, "required-route gap sums every actual leg")
        expect(plannedGap?.requiredStopSeconds == 20 * 60, "required-route gap subtracts selected stop duration")
        expect(plannedGap?.usableSeconds == 28 * 60, "required-route gap subtracts travel, stop, and one buffer")
    }

    // Catches Return Home inflating appointment safety margins or stop-only days
    // fabricating appointment departure guidance.
    private static func testReturnHomeAndStopOnlyContracts() {
        let origin = LifeRouteItineraryNode(id: "origin:home", kind: .origin, title: "Home", address: "1 Home Street")
        let appointment = LifeRouteItineraryNode(
            id: "event:work",
            kind: .appointment,
            title: "Work",
            address: "2 Work Street",
            start: date("2026-09-01T12:00:00Z"),
            end: date("2026-09-01T14:00:00Z")
        )
        let home = LifeRouteItineraryNode(id: "home:return", kind: .home, title: "Home", address: "1 Home Street")
        let outbound = LifeRouteItineraryLeg(id: "leg:outbound", sequence: 1, fromNodeID: origin.id, toNodeID: appointment.id, rawTravelSeconds: 10 * 60, rawDistanceMeters: 5_000)
        let inbound = LifeRouteItineraryLeg(id: "leg:return", sequence: 2, fromNodeID: appointment.id, toNodeID: home.id, rawTravelSeconds: 15 * 60, rawDistanceMeters: 7_000)

        let returning = LifeRouteGeneratedItinerary(
            id: "day:returning",
            selectedDay: date("2026-09-01T00:00:00Z"),
            generatedAt: date("2026-09-01T09:00:00Z"),
            returnHome: true,
            routeBuffer: .tenMinutes,
            inputFingerprint: "returning",
            nodes: [origin, appointment, home],
            legs: [outbound, inbound]
        )
        expect(returning.returnHome, "generated itinerary retains Return Home on")
        expect(returning.nodes.filter { $0.kind == .home }.count == 1, "Return Home adds one final Home node")
        expect(returning.totalRawTravelSeconds == 25 * 60, "Return Home contributes its raw MapKit travel")
        expect(returning.departureGuidance(at: date("2026-09-01T10:00:00Z"))?.leaveBy == date("2026-09-01T11:40:00Z"), "Return Home does not add another appointment buffer")

        let notReturning = LifeRouteGeneratedItinerary(
            id: "day:not-returning",
            selectedDay: returning.selectedDay,
            generatedAt: returning.generatedAt,
            returnHome: false,
            routeBuffer: .tenMinutes,
            inputFingerprint: "not-returning",
            nodes: [origin, appointment],
            legs: [outbound]
        )
        expect(!notReturning.returnHome, "generated itinerary retains Return Home off")
        expect(notReturning.nodes.allSatisfy { $0.kind != .home }, "Return Home off has no final Home node")
        expect(notReturning.totalRawTravelSeconds == 10 * 60, "Return Home off excludes the return leg")

        let stop = LifeRouteItineraryNode(id: "stop:errand", kind: .stop, title: "Errand", address: "3 Store Street", stopDurationSeconds: 30 * 60)
        let stopOnly = LifeRouteGeneratedItinerary(
            id: "day:stop-only",
            selectedDay: returning.selectedDay,
            generatedAt: returning.generatedAt,
            returnHome: true,
            routeBuffer: .tenMinutes,
            inputFingerprint: "stop-only",
            nodes: [origin, stop, home],
            legs: [
                .init(id: "leg:stop-out", sequence: 1, fromNodeID: origin.id, toNodeID: stop.id, rawTravelSeconds: 8 * 60, rawDistanceMeters: 3_000),
                .init(id: "leg:stop-home", sequence: 2, fromNodeID: stop.id, toNodeID: home.id, rawTravelSeconds: 9 * 60, rawDistanceMeters: 3_500),
            ]
        )
        expect(stopOnly.timeline.map(\.kind) == [.origin, .drive, .stop, .drive, .home], "stop-only itinerary remains fully displayable")
        expect(stopOnly.totalRawTravelSeconds == 17 * 60, "stop-only itinerary retains raw travel")
        expect(stopOnly.departureGuidance(at: date("2026-09-01T09:00:00Z")) == nil, "stop-only itinerary fabricates no appointment Leave By")
        expect(LifeRouteLiveDayProjection.make(from: stopOnly, at: date("2026-09-01T09:00:00Z")) == nil, "stop-only itinerary fabricates no Live Day departure")
    }

    // Catches the planner silently bridging missing route data or turning an
    // all-day/unlocated event into a route-safe timed commitment.
    private static func testUnsafeRouteBoundariesRemainVisible() {
        let origin = LifeRouteItineraryNode(id: "origin:current", kind: .origin, title: "Current Location", address: "Current Location")
        let unlocated = LifeRouteItineraryNode(
            id: "event:remote",
            kind: .appointment,
            title: "Remote appointment",
            address: "",
            start: date("2026-09-01T10:00:00Z"),
            end: date("2026-09-01T11:00:00Z"),
            isRoutable: false
        )
        let allDay = LifeRouteItineraryNode(
            id: "event:all-day",
            kind: .appointment,
            title: "All-day context",
            address: "4 Context Street",
            start: date("2026-09-01T00:00:00Z"),
            end: date("2026-09-02T00:00:00Z"),
            isAllDay: true
        )
        let visible = LifeRouteGeneratedItinerary(
            id: "day:unroutable",
            selectedDay: date("2026-09-01T00:00:00Z"),
            generatedAt: date("2026-09-01T08:00:00Z"),
            returnHome: false,
            routeBuffer: .tenMinutes,
            inputFingerprint: "unroutable",
            nodes: [origin, unlocated, allDay],
            legs: []
        )
        expect(visible.timeline.map(\.kind) == [.origin, .appointment, .appointment], "unlocated and all-day events remain visible")
        expect(visible.departureGuidance(at: date("2026-09-01T09:00:00Z")) == nil, "unlocated next event produces no fabricated departure")
        expect(visible.usableGaps.isEmpty, "all-day event does not become a timed gap anchor")

        let first = LifeRouteItineraryNode(
            id: "event:first",
            kind: .appointment,
            title: "First",
            address: "1 First Street",
            start: date("2026-09-01T09:00:00Z"),
            end: date("2026-09-01T10:00:00Z")
        )
        let second = LifeRouteItineraryNode(
            id: "event:second",
            kind: .appointment,
            title: "Second",
            address: "2 Second Street",
            start: date("2026-09-01T11:30:00Z"),
            end: date("2026-09-01T12:30:00Z")
        )
        let missingLeg = LifeRouteGeneratedItinerary(
            id: "day:missing-leg",
            selectedDay: visible.selectedDay,
            generatedAt: visible.generatedAt,
            returnHome: false,
            routeBuffer: .tenMinutes,
            inputFingerprint: "missing-leg",
            nodes: [first, second],
            legs: []
        )
        let unsafeGap = missingLeg.usableGaps.first
        expect(unsafeGap?.rawCalendarGapSeconds == 90 * 60, "missing-leg gap still reports raw calendar time")
        expect(unsafeGap?.isRouteSafe == false, "missing required leg marks the gap route-unsafe")
        expect(unsafeGap?.usableSeconds == nil, "missing required leg never fabricates usable time")
        if let unsafeGap {
            expect(unsafeGap.fit(.locationlessTodo(id: "todo", title: "Todo", durationSeconds: 10 * 60)).state == .routeUnavailable, "locationless To-Do cannot use an unsafe gap")
        } else {
            expect(false, "unsafe gap remains inspectable")
        }
    }

    // Catches duplicate stable instances entering the canonical plan or a
    // sanitizer sorting explicit user stop order as a side effect.
    private static func testStableIdentityAndOrdering() {
        let origin = LifeRouteItineraryNode(id: "origin", kind: .origin, title: "Origin", address: "1 Main")
        let firstStop = LifeRouteItineraryNode(id: "stop:first", kind: .stop, title: "First", address: "2 Main", stopDurationSeconds: 5 * 60)
        let repeatedAddress = LifeRouteItineraryNode(id: "stop:second", kind: .stop, title: "Second", address: "2 Main", stopDurationSeconds: 5 * 60)
        let appointment = LifeRouteItineraryNode(
            id: "event",
            kind: .appointment,
            title: "Appointment",
            address: "3 Main",
            start: date("2026-09-01T12:00:00Z"),
            end: date("2026-09-01T13:00:00Z")
        )
        let firstLeg = LifeRouteItineraryLeg(id: "leg:first", sequence: 1, fromNodeID: origin.id, toNodeID: firstStop.id, rawTravelSeconds: 60, rawDistanceMeters: 100)
        let secondLeg = LifeRouteItineraryLeg(id: "leg:second", sequence: 2, fromNodeID: firstStop.id, toNodeID: repeatedAddress.id, rawTravelSeconds: 60, rawDistanceMeters: 100)
        let thirdLeg = LifeRouteItineraryLeg(id: "leg:third", sequence: 3, fromNodeID: repeatedAddress.id, toNodeID: appointment.id, rawTravelSeconds: 60, rawDistanceMeters: 100)
        let itinerary = LifeRouteGeneratedItinerary(
            id: "stable-day",
            selectedDay: date("2026-09-01T00:00:00Z"),
            generatedAt: date("2026-09-01T08:00:00Z"),
            returnHome: false,
            routeBuffer: .tenMinutes,
            inputFingerprint: "stable-fingerprint",
            nodes: [origin, firstStop, firstStop, repeatedAddress, appointment],
            legs: [firstLeg, firstLeg, secondLeg, thirdLeg]
        )
        expect(itinerary.id == "stable-day" && itinerary.inputFingerprint == "stable-fingerprint", "generated itinerary retains stable identity and fingerprint")
        expect(itinerary.nodes.map(\.id) == ["origin", "stop:first", "stop:second", "event"], "duplicate node ID is removed without reordering distinct visits")
        expect(itinerary.legs.map(\.id) == ["leg:first", "leg:second", "leg:third"], "duplicate leg ID is removed without reordering legs")
        expect(itinerary.nodes.filter { $0.address == "2 Main" }.count == 2, "distinct stable stop IDs may intentionally revisit one address")
    }

    private static func exampleIntermediateStopItinerary() -> LifeRouteGeneratedItinerary {
        let origin = LifeRouteItineraryNode(
            id: "origin:home",
            kind: .origin,
            title: "Home",
            address: "1 Home Street"
        )
        let stop = LifeRouteItineraryNode(
            id: "stop:dunkin",
            kind: .stop,
            title: "Dunkin",
            address: "2 Coffee Street",
            stopDurationSeconds: 20 * 60
        )
        let appointment = LifeRouteItineraryNode(
            id: "event:life",
            kind: .appointment,
            title: "LiFe",
            address: "3 Session Street",
            start: date("2026-09-01T12:00:00Z"),
            end: date("2026-09-01T14:00:00Z")
        )
        return LifeRouteGeneratedItinerary(
            id: "day:life",
            selectedDay: date("2026-09-01T00:00:00Z"),
            generatedAt: date("2026-09-01T09:00:00Z"),
            returnHome: false,
            routeBuffer: .tenMinutes,
            inputFingerprint: "life-fixture",
            nodes: [origin, stop, appointment],
            legs: [
                .init(id: "leg:home-dunkin", sequence: 1, fromNodeID: origin.id, toNodeID: stop.id, rawTravelSeconds: 18 * 60, rawDistanceMeters: 10_000),
                .init(id: "leg:dunkin-life", sequence: 2, fromNodeID: stop.id, toNodeID: appointment.id, rawTravelSeconds: 24 * 60, rawDistanceMeters: 15_000),
            ]
        )
    }

    private static func date(_ value: String) -> Date {
        guard let result = ISO8601DateFormatter().date(from: value) else {
            fatalError("Invalid fixture date: \(value)")
        }
        return result
    }

    private static func testFullRouteHandoffs() {
        let fourLegs = routeLegs(count: 4)
        let googlePlan = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .googleMaps,
            legs: fourLegs,
            travelMode: "driving"
        )!
        expect(googlePlan.orderedLegs == fourLegs, "Google full-route planning preserves the exact leg order")
        expect(!googlePlan.requiresSequentialContinuation, "Google uses one complete handoff within the mobile waypoint limit")
        if case .completeGoogleMaps(let url) = googlePlan.strategy {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            expect(query.first(where: { $0.name == "origin" }) == nil, "Google omits origin for current-location routes")
            expect(query.first(where: { $0.name == "destination" })?.value == "4 Main Street", "Google keeps the final ordered destination")
            expect(query.first(where: { $0.name == "waypoints" })?.value == "1 Main Street|2 Main Street|3 Main Street", "Google preserves every intermediate waypoint in order")
            expect(url.absoluteString.count <= LifeRouteFullRouteHandoffPlanner.maximumURLLength, "Google complete handoff stays within the documented URL limit")
        } else {
            expect(false, "Google within-limit route produces a complete URL")
        }

        let overLimitGoogle = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .googleMaps,
            legs: routeLegs(count: 5),
            travelMode: "driving"
        )!
        expect(overLimitGoogle.requiresSequentialContinuation, "Google never truncates a route beyond three mobile waypoints")
        expect(overLimitGoogle.orderedLegs.count == 5, "Google fallback retains every ordered leg")

        let longAddress = String(repeating: "Long Address Segment ", count: 150)
        let oversizedURLPlan = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .googleMaps,
            legs: [
                LifeRouteFullRouteLegDescriptor(sequence: 1, fromTitle: "Home", fromAddress: longAddress, toTitle: "Stop", toAddress: longAddress)
            ],
            travelMode: "driving"
        )!
        expect(oversizedURLPlan.requiresSequentialContinuation, "Google falls back rather than emitting an oversized URL")

        let appleSingle = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .appleMaps,
            legs: routeLegs(count: 1),
            travelMode: "driving"
        )!
        expect(appleSingle.strategy == .completeAppleMaps, "Apple hands off a complete single-leg route")

        let appleMulti = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .appleMaps,
            legs: fourLegs,
            travelMode: "driving"
        )!
        expect(appleMulti.requiresSequentialContinuation, "Apple multi-leg routes use LifeRoute sequential continuation")
        expect(appleMulti.orderedLegs == fourLegs, "Apple continuation retains the exact ordered legs")

        let wazePlan = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .waze,
            legs: fourLegs,
            travelMode: "driving"
        )!
        expect(wazePlan.requiresSequentialContinuation, "Waze uses explicit sequential fallback")
        expect(wazePlan.orderedLegs == fourLegs, "Waze fallback retains every ordered leg")

        let malformed = [fourLegs[1], fourLegs[0]]
        let malformedPlan = LifeRouteFullRouteHandoffPlanner.plan(
            provider: .googleMaps,
            legs: malformed,
            travelMode: "driving"
        )!
        expect(malformedPlan.requiresSequentialContinuation, "an unverified sequence never receives a complete provider handoff")
        expect(malformedPlan.orderedLegs == malformed, "fallback never silently sorts or rewrites malformed input")
    }

    private static func routeLegs(count: Int) -> [LifeRouteFullRouteLegDescriptor] {
        (1...count).map { sequence in
            LifeRouteFullRouteLegDescriptor(
                sequence: sequence,
                fromTitle: sequence == 1 ? "Current Location" : "Stop \(sequence - 1)",
                fromAddress: sequence == 1 ? "Current Location" : "\(sequence - 1) Main Street",
                toTitle: "Stop \(sequence)",
                toAddress: "\(sequence) Main Street"
            )
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertionCount += 1
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
