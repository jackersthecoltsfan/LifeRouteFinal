# Web preview ownership classification

Native iOS and TestFlight are authoritative. Nothing under `LifeRoute/Web/` is
embedded in the app target, and `LifeRouteWebView.swift` is not in Sources. The
Pages preview is a separate browser artifact built by
`scripts/build_web_preview.py`.

## Active preview

Shell/assets: `index.html`, `config.js`, `manifest.webmanifest`,
`liferoute-logo-source.png`, `liferoute-logo.b64`.

Browser bootstrap modules: `web-routing-bridge.js`,
`web-store-search-fallback.js`, `web-routing-resilience.js`,
`web-store-late-guard.js`, `web-store-direct-v2.js`,
`web-store-panel-persistence.js`, `welcome.js`, `nav-cleanup.js`,
`rbt-tools.js`, `icloud-calendar-web.js`, `google-calendar-web.js`,
`google-calendar-stability.js`, `google-calendar-persistence-web.js`,
`first-then-back.js`, `visual-quality-web.js`, `photo-source-picker-web.js`,
`end-home-route-web.js`, `mileage-tracker-web.js`, `resources-hub-web.js`,
`nature-settings-web.js`, `settings-classic-themes-web.js`,
`photoreal-nature-web.js`, and `dynamic-themes-web.js`.

## Quarantined legacy runtime

`global-bridge.js`, `auth-gate.js`, `stability-runtime.js`, and
`day-navigation-runtime.js` are explicitly forbidden active preview dependencies
and remain excluded from the shipping Xcode target.

## Historical

All other Web JavaScript files are historical native-rebuild/reference donors.
They are copied into the preview artifact today for preservation but are not
loaded by `index.html` or the preview bootstrap. This includes prior ABA/AI,
calendar, routing, theme, visual-support, timer, navigation, and UI-era modules.

## Delete candidates

No Web file is deleted in Phase A. The historical set—especially superseded
versioned modules such as `web-store-sheet-v3.js`, old `*-v1` through `*-v5`
layers, and unused visual resolver variants—is a Phase B delete-candidate
inventory. Deletion requires proof that no active preview or historical need
remains; it must not reactivate WKWebView.
