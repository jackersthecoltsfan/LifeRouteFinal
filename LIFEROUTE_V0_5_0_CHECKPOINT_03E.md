# LifeRoute v0.5.0 Checkpoint 03E — Native Calendar Providers

Feature commit: `98ebb84eceedecdc4b724947d9158a9c8c1d7430`

Scope:
- Apple Calendar EventKit read/import path extracted from the quarantined WebView coordinator.
- Google Calendar read-only PKCE OAuth extracted into a standalone native provider core.
- Google refresh token remains stored in Keychain.
- Provider refresh is explicit/user-triggered rather than polled at startup.
- Provider events replace only their own source inside `CalendarCoreState`; manual events are protected.
- The legacy WebView coordinator remains quarantined and is not compiled into the active target.

Validation status: pending exact-head CI at the commit that adds this record.

Next functional checkpoint: client-specific native visual supports. Every saved visual icon, choice board, First/Then visual selection, and visual schedule must be owned by a four-letter client code and must draw only from that client’s visual library. Persistence remains deferred to checkpoint 04; the ownership model must be correct before persistence is added.
