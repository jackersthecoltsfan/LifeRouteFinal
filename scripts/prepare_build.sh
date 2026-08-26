set -euo pipefail

# Apply native/runtime patches in deterministic order. Release hardening runs
# after the feature patches so its checks see the final shared architecture.
PATCHES=(
  patch_route_times.py
  patch_location_context.py
  patch_address_autocomplete_v1.py
  patch_transport_mode.py
  patch_store_route_guard.py
  patch_store_routing_resilience.py
  patch_store_mapitems.py
  patch_route_reliability_v2.py
  patch_route_reliability_v3.py
  patch_gap_multistop.py
  patch_route_origin_choice.py
  patch_selected_gap_routes.py
  patch_live_activity.py
  patch_live_day.py
  patch_boundary_stop_timing.py
  patch_rbt_tools.py
  patch_tools_stability_v1.py
  patch_sleek_icons.py
  patch_provider_selection.py
  patch_day_navigation.py
  patch_auth_gate.py
  patch_auth_keychain_reliability_v1.py
  patch_home_location_v3.py
  patch_location_ui_consolidation_v1.py
  patch_stability.py
  patch_theme_settings.py
  patch_release_hardening_v1.py
  patch_theme_runtime_hardening_v1.py
  patch_location_services_hardening_v1.py
  patch_live_location_consumers_v1.py
  patch_external_service_limits_v1.py
  patch_external_links_hardening_v1.py
  patch_feature_regressions_v2.py
  patch_performance_cleanup_v2.py
  patch_visual_ai_v1.py
  patch_ai_everywhere_v2.py
  patch_aba_ai_note_v1.py
  patch_aba_note_quality_v2.py
  patch_day_ui_reliability_v1.py
  patch_interaction_finalize_v2.py
  patch_touch_delight_v2.py
  patch_interaction_performance_v3.py
  patch_no_programmatic_scroll_v4.py
  # v0.4.0 physical-device recovery sequence. Keep this order: cosmetics,
  # functionality, performance, stability, then the post-patch functionality audit.
  patch_cosmetic_icons_v040.py
  patch_global_interaction_reliability_v040.py
  patch_performance_v040.py
  patch_stability_v040.py
)
for patch in "${PATCHES[@]}"; do
  python3 "scripts/$patch"
done

# Normalize all shared feature scripts into one startup order for both native
# WKWebView and browser preview builds.
python3 - <<'PY'
from pathlib import Path
path = Path("LifeRoute/Web/index.html")
html = path.read_text()
core = [
    "global-bridge.js",
    "interaction-stability-v3.js",
    "calendar-hub.js",
    "auth-gate.js",
    "icons.js",
    "route-times.js",
    "smart-context.js",
    "live-location-v2.js",
    "address-autocomplete-v1.js",
    "home-location-v3.js",
    "todos.js",
    "grocery-stores.js",
    "transport-mode.js",
    "sleek-ui.js",
    "store-sleek-ui.js",
    "selected-gap-routes.js",
    "saved-place-gap-options.js",
    "live-day.js",
    "end-home-route-web.js",
    "day-controls-v5.js",
    "rbt-tools.js",
    "client-picker-sync-v1.js",
    "client-profiles-v1.js",
    "client-profile-tools-v1.js",
    "mileage-tracker-web.js",
    "resources-hub-web.js",
    "toolbar-cleanup-v1.js",
    "schedule-simplify-v1.js",
    "visual-timer-v2.js",
    "delight-ui-v1.js",
    "timer-native-audio-v1.js",
    "first-then-back.js",
    "visual-resolver.js",
    "ai-assistant-v1.js",
    "visual-resolver-ai-v2.js",
    "visual-quality-web.js",
    "visual-tools.js",
    "photo-source-picker-web.js",
    "visual-object-focus-v2.js",
    "image-playground-v1.js",
    "visual-resolver-bridge.js",
    "first-then-ai-studio-v1.js",
    "ai-planning-v1.js",
    "aba-ai-note-v1.js",
    "live-themes.js",
    "day-route-experience.js",
    "boundary-stop-planner.js",
    "stop-place-search-v4.js",
    "stop-duration-v1.js",
    "day-navigation-runtime.js",
    "nature-settings-web.js",
    "settings-classic-themes-web.js",
    "photoreal-nature-web.js",
    "dynamic-themes-web.js",
    "fluid-scenes-v1.js",
    "dynamic-animals-v1.js",
    "theme-catalog-v3.js",
    "ui-simplify-v4.js",
    "refined-ui-v2.js",
    "aesthetic-polish-v1.js",
    "stability-runtime.js",
    "delight-tail-v1.js",
]
if "</body>" not in html:
    raise SystemExit("Could not inject LifeRoute feature scripts: </body> not found")
for name in core:
    html = html.replace(f'<script src="{name}"></script>', "")
html = html.replace("</body>", "\n".join(f'<script src="{name}"></script>' for name in core) + "\n</body>", 1)
path.write_text(html)
print("LifeRoute core scripts normalized into one deterministic startup order.")
PY

python3 -m py_compile scripts/*.py
plutil -lint LifeRoute/Info.plist
plutil -lint LifeRouteLiveActivity/Info.plist

CORE_JS=(
  global-bridge.js interaction-stability-v3.js calendar-hub.js auth-gate.js icons.js route-times.js smart-context.js live-location-v2.js
  address-autocomplete-v1.js home-location-v3.js
  todos.js grocery-stores.js transport-mode.js sleek-ui.js store-sleek-ui.js
  selected-gap-routes.js saved-place-gap-options.js live-day.js end-home-route-web.js day-controls-v5.js
  rbt-tools.js client-picker-sync-v1.js client-profiles-v1.js client-profile-tools-v1.js
  mileage-tracker-web.js resources-hub-web.js toolbar-cleanup-v1.js schedule-simplify-v1.js visual-timer-v2.js
  delight-ui-v1.js timer-native-audio-v1.js first-then-back.js
  visual-resolver.js ai-assistant-v1.js visual-resolver-ai-v2.js visual-quality-web.js visual-tools.js
  photo-source-picker-web.js visual-object-focus-v2.js image-playground-v1.js visual-resolver-bridge.js
  first-then-ai-studio-v1.js ai-planning-v1.js aba-ai-note-v1.js live-themes.js
  day-route-experience.js boundary-stop-planner.js stop-place-search-v4.js stop-duration-v1.js
  day-navigation-runtime.js nature-settings-web.js settings-classic-themes-web.js
  photoreal-nature-web.js dynamic-themes-web.js fluid-scenes-v1.js dynamic-animals-v1.js
  theme-catalog-v3.js ui-simplify-v4.js refined-ui-v2.js aesthetic-polish-v1.js stability-runtime.js delight-tail-v1.js
)
for js in "${CORE_JS[@]}"; do
  test -s "LifeRoute/Web/$js"
  node --check "LifeRoute/Web/$js"
  grep -q "<script src=\"$js\"></script>" LifeRoute/Web/index.html
done

BROWSER_JS=(
  welcome.js nav-cleanup.js icloud-calendar-web.js google-calendar-web.js
  google-calendar-stability.js google-calendar-persistence-web.js
  web-routing-bridge.js web-store-search-fallback.js web-routing-resilience.js
  web-store-late-guard.js web-store-direct-v2.js web-store-panel-persistence.js
)
for js in "${BROWSER_JS[@]}"; do
  test -s "LifeRoute/Web/$js"
  node --check "LifeRoute/Web/$js"
done

# Existing focused gates.
python3 scripts/audit_client_pickers.py
python3 scripts/audit_client_profiles.py
python3 scripts/audit_toolbar_cleanup.py
python3 scripts/audit_stop_duration.py
python3 scripts/audit_stop_place_search.py
python3 scripts/audit_live_day_activity.py
python3 scripts/audit_theme_catalog.py
python3 scripts/audit_runtime_polish.py
python3 scripts/audit_visual_timer.py
python3 scripts/audit_tools_section.py
python3 scripts/audit_auth_enabled_v2.py
python3 scripts/audit_auth_security_contract_v1.py
python3 scripts/audit_address_setup_v1.py
python3 scripts/audit_address_autocomplete_contract_v1.py
python3 scripts/audit_home_persistence_v1.py
python3 scripts/audit_schedule_simplify_v1.py
python3 scripts/audit_aba_note_quality_v2.py
python3 scripts/audit_appearance.py
python3 scripts/audit_stability.py
python3 scripts/audit_feature_parity_performance_ai.py
python3 scripts/audit_interaction_performance_v3.py
python3 scripts/audit_no_programmatic_scroll_v5.py

# AI-specific independent review angles.
python3 scripts/audit_ai_user_journeys_v2.py
python3 scripts/audit_ai_runtime_release_v2.py

# Independent multi-angle release gates.
python3 scripts/audit_user_journeys.py
python3 scripts/audit_runtime_release.py
python3 scripts/audit_theme_runtime_deep.py
python3 scripts/audit_live_location_deep.py
python3 scripts/audit_external_services.py
python3 scripts/audit_state_invariants.py

# v0.4.0 requested ordered physical-device release audits. Functionality is
# deliberately repeated after performance/stability to catch pass-induced breakage.
echo "=== v0.4.0 ordered audit 1/5: COSMETIC ==="
python3 scripts/audit_cosmetic_v040.py
echo "=== v0.4.0 ordered audit 2/5: FUNCTIONALITY PASS 1 ==="
python3 scripts/audit_functionality_v040.py
echo "=== v0.4.0 ordered audit 3/5: PERFORMANCE ==="
python3 scripts/audit_performance_v040.py
echo "=== v0.4.0 ordered audit 4/5: STABILITY ==="
python3 scripts/audit_stability_v040.py
echo "=== v0.4.0 ordered audit 5/5: FUNCTIONALITY PASS 2 ==="
python3 scripts/audit_functionality_v040.py

# Critical native bridge contracts.
for marker in \
  requestRouteTimes searchStoreLocations requestCurrentLocation startLiveLocation stopLiveLocation CLLocationManagerDelegate \
  addressAutocomplete MKLocalSearchCompleterDelegate \
  openRoute openExternalURL analyzeVisualSubject VNGenerateObjectnessBasedSaliencyImageRequest routeTransportType \
  aiGenerateText LanguageModelSession segmentVisualSubject VNGenerateForegroundInstanceMaskRequest openImagePlayground ImagePlaygroundViewController \
  recognizeVisualText VNRecognizeTextRequest \
  scheduleDayNotifications startLiveDayActivity endLiveDayActivity \
  authSetCredentials authVerifyCredentials authBiometricUnlock LocalAuthentication; do
  grep -q "$marker" LifeRoute/LifeRouteWebView.swift
done

# Live Activity target contracts.
grep -q 'LifeRouteLiveActivity.appex' LifeRoute.xcodeproj/project.pbxproj
grep -q 'LifeRouteActivityAttributes.swift in Sources' LifeRoute.xcodeproj/project.pbxproj
grep -q 'NSSupportsLiveActivities' LifeRoute/Info.plist
test -s LifeRoute/LiveActivityManager.swift
test -s LifeRouteShared/LifeRouteActivityAttributes.swift
test -s LifeRouteLiveActivity/LifeRouteLiveActivityWidget.swift

# Native stability contracts.
grep -q 'webView.scrollView.bounces = false' LifeRoute/LifeRouteWebView.swift
grep -q 'lifeRouteNativeRuntimeBootstrap' LifeRoute/LifeRouteWebView.swift
grep -q 'function refreshCalendars()' LifeRoute/Web/index.html
grep -q '__lifeRouteThemePerformanceV2' LifeRoute/Web/live-themes.js

# Critical Day/gap contracts.
grep -q 'class="lrDayPager"' LifeRoute/Web/index.html
grep -q 'id="dayPrevButton"' LifeRoute/Web/index.html
grep -q 'id="dayTodayButton"' LifeRoute/Web/index.html
grep -q 'id="dayNextButton"' LifeRoute/Web/index.html
grep -q 'lifeRouteOpenBoundaryPlanner' LifeRoute/Web/boundary-stop-planner.js
grep -q 'LifeRouteStopPlaceSearchV4' LifeRoute/Web/stop-place-search-v4.js
grep -q 'LifeRouteStopDurationV1' LifeRoute/Web/stop-duration-v1.js
grep -q 'planned stop time' LifeRoute/Web/live-day.js
grep -q 'LifeRouteDayControlsV5' LifeRoute/Web/day-controls-v5.js
grep -q 'endDayAtHome' LifeRoute/Web/end-home-route-web.js
grep -q 'data-lr-clear-day' LifeRoute/Web/day-controls-v5.js

# Saved-client field-tool + profile contracts.
grep -q 'sessionPlanClient' LifeRoute/Web/client-picker-sync-v1.js
grep -q 'LifeRouteClientProfilesV1' LifeRoute/Web/client-profiles-v1.js
grep -q 'clientPreferredActivities' LifeRoute/Web/client-profiles-v1.js
grep -q 'clientCurrentTargets' LifeRoute/Web/client-profiles-v1.js
grep -q 'applyLifeRouteClientProfileToTools' LifeRoute/Web/client-profile-tools-v1.js

# AI intelligence contracts.
grep -q 'LifeRouteAI' LifeRoute/Web/ai-assistant-v1.js
grep -q 'visualSearchTerms' LifeRoute/Web/ai-assistant-v1.js
grep -q 'sessionPlan' LifeRoute/Web/ai-assistant-v1.js
grep -q 'dayBrief' LifeRoute/Web/ai-assistant-v1.js
grep -q 'routeBrief' LifeRoute/Web/ai-assistant-v1.js
grep -q 'LifeRouteImageStudio' LifeRoute/Web/image-playground-v1.js
grep -q 'LifeRouteAIPlanning' LifeRoute/Web/ai-planning-v1.js
grep -q 'LifeRouteABAAINote' LifeRoute/Web/aba-ai-note-v1.js
grep -q 'wikimedia-ai-semantic' LifeRoute/Web/visual-resolver-ai-v2.js

# Toolbar + timer + appearance + auth contracts.
grep -q 'LifeRouteToolbarCleanupV1' LifeRoute/Web/toolbar-cleanup-v1.js
grep -q "child.dataset?.view === 'month'" LifeRoute/Web/toolbar-cleanup-v1.js
grep -q "Preserve the user's scroll position" LifeRoute/Web/toolbar-cleanup-v1.js
grep -q 'LifeRouteVisualTimerV2' LifeRoute/Web/visual-timer-v2.js
grep -q 'CHIME_PERIOD_MS = 500' LifeRoute/Web/visual-timer-v2.js
grep -q 'END_HZ = 1320' LifeRoute/Web/visual-timer-v2.js
grep -q '0.25 \* gainScale' LifeRoute/Web/visual-timer-v2.js
grep -q 'boost:5' LifeRoute/Web/timer-native-audio-v1.js
grep -q 'playGlassTone(frequency: Double, intensity: Double, boost: Double = 5.0)' LifeRoute/LifeRouteWebView.swift
grep -q 'decorative work happens only after' LifeRoute/Web/delight-ui-v1.js
grep -q 'transition:transform .055s' LifeRoute/Web/delight-ui-v1.js
! grep -q "classList.add('lrTouchPressed')" LifeRoute/Web/delight-ui-v1.js
grep -q "action:'haptic'" LifeRoute/Web/delight-ui-v1.js
grep -q 'grid-template-columns:repeat(4,minmax(0,1fr))!important' LifeRoute/Web/delight-ui-v1.js
grep -q 'window.scrollTo = noProgrammaticScroll' LifeRoute/Web/interaction-stability-v3.js
! grep -q 'DIRECT SESSION TOOLKIT' LifeRoute/Web/rbt-tools.js
! grep -q 'const AUTH_GATE_ENABLED = false' LifeRoute/Web/auth-gate.js
grep -q 'NSFaceIDUsageDescription' LifeRoute/Info.plist
grep -q 'lifeRouteAestheticPolishV1Styles' LifeRoute/Web/aesthetic-polish-v1.js
grep -q 'min-height:44px!important' LifeRoute/Web/aesthetic-polish-v1.js

echo "LifeRoute feature preflight + ordered v0.4.0 cosmetic/function/performance/stability/function audits passed."
