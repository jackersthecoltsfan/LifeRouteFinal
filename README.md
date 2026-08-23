# LifeRoute

LifeRoute is an iPhone-first schedule and routing app designed to combine calendar inputs, identify useful gaps, save frequent places, and hand routes to Apple Maps or Google Maps.

## Current branch architecture

- Apple Calendar: native EventKit read path implemented.
- Google Calendar: read-only OAuth configuration scaffolded.
- CentralReach: read-only schedule API scaffolded.
- Apple Maps + Google Maps: route/place handoff implemented.
- Saved places: local storage with membership/frequent-place gap suggestions.
- Customizable blue/gold, light, ocean, and graphite themes.
- GitHub Actions: simulator compile check plus manual TestFlight release workflow.

See `INTEGRATIONS.md` and `TESTFLIGHT_SETUP.md` for the remaining credential/setup work.
