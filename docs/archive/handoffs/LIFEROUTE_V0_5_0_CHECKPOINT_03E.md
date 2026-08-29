# LifeRoute v0.5.0 Checkpoint 03E — Native Calendar Providers

Feature commit: `98ebb84eceedecdc4b724947d9158a9c8c1d7430`

Scope:
- Apple Calendar EventKit read/import path extracted from the quarantined WebView coordinator.
- Google Calendar read-only PKCE OAuth extracted into a standalone native provider core.
- Google refresh token remains stored in Keychain.
- Provider refresh is explicit/user-triggered rather than polled at startup.
- Provider events replace only their own source inside `CalendarCoreState`; manual events are protected.
- The legacy WebView coordinator remains quarantined and is not compiled into the active target.

Validation status: **Green.** The original 03E feature commit was followed by composable regression-audit corrections during 03F. The complete provider layer then passed the accumulated provider audit and iOS Simulator build at the green 03F exact head `431c2db03b4786f5b84d513e11a04a187f551177` (iOS CI #639), and has continued to pass through the green 04A/04B exact-head builds.

Next functional checkpoint was 03F: client-specific native visual supports, with every icon/choice board/First-Then visual/schedule owned by a client and no cross-client references.
