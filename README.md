# LifeRoute

LifeRoute v0.9.1 is a native SwiftUI schedule, routing, and ABA clinical-support
app with an embedded Live Day Activity extension. The checked-in Swift, Xcode
project, assets, and extension are the canonical v0.9.1 candidate source.

Today is the single day-planning command center. A root-owned route planner
publishes one immutable generated itinerary; Today, usable-gap and Gap Filler
logic, total driving, Leave By / Leave In, Live Day, and the Lock Screen Live
Activity all project from that same snapshot. Calendar remains the schedule
browsing and appointment-management surface.

Start current engineering work with:

- `LIFEROUTE_HANDOFF.md`
- `docs/BUILD_ARCHITECTURE.md`
- `scripts/prepare_build.sh`
- `scripts/validate_fast.sh`
- `scripts/validate_full.sh`

Native/TestFlight is authoritative. `LifeRoute/Web/` is a separately published,
non-authoritative preview and is not embedded in the shipping app.

See `INTEGRATIONS.md` for provider configuration and `TESTFLIGHT_SETUP.md` for
the exact-SHA, explicitly authorized release process.
