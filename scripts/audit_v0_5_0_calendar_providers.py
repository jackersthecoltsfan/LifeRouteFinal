from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROVIDER = ROOT / "LifeRoute" / "CalendarProviderCore.swift"
CALENDAR = ROOT / "LifeRoute" / "CalendarDomain.swift"
CONTENT = ROOT / "LifeRoute" / "ContentView.swift"
PLIST = ROOT / "LifeRoute" / "Info.plist"
PROJECT = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"

errors: list[str] = []
checks: list[str] = []

def require(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)

def read(path: Path) -> str:
    try: return path.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"Could not read {path.relative_to(ROOT)}: {exc}")
        return ""

provider = read(PROVIDER)
calendar = read(CALENDAR)
content = read(CONTENT)
plist = read(PLIST)
project = read(PROJECT)

for framework in ["EventKit", "AuthenticationServices", "CryptoKit", "Security"]:
    require(f"import {framework}" in provider, f"Provider core uses native {framework}")
for forbidden in ["WebKit", "WKWebView", "WKScriptMessage", "JavaScript", "MutationObserver", "localStorage", "UserDefaults", "Timer.scheduledTimer", "setInterval"]:
    require(forbidden not in provider, f"Provider core avoids legacy/polling dependency: {forbidden}")
require("https://www.googleapis.com/auth/calendar.readonly" in provider, "Google Calendar scope remains read-only")
require("client_secret" not in provider.lower(), "No Google OAuth client secret is embedded")
require('URLQueryItem(name: "code_challenge_method", value: "S256")' in provider, "Google OAuth uses PKCE S256")
require('guard params["state"] == state' in provider, "Google OAuth validates state")
require("ASWebAuthenticationSession" in provider and "prefersEphemeralWebBrowserSession = false" in provider, "Google OAuth uses native authenticated session")
require("kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly" in provider, "Google refresh token stays in device-only Keychain")
require("SecItemCopyMatching" in provider and "SecItemDelete" in provider, "Google Keychain credential lifecycle is explicit")

require("requestFullAccessToEvents" in provider and "requestAccess(to: .event)" in provider, "Apple Calendar supports modern and fallback EventKit permission paths")
require("predicateForEvents" in provider and "source: .apple" in provider, "Apple events normalize directly to native calendar events")
require("source: .google" in provider and "fetchGoogleCalendarEvents" in provider, "Google events normalize directly to native calendar events")
require("connectOrRefreshApple" in provider and "connectOrRefreshGoogle" in provider, "Provider refresh is explicit and user-triggerable")
require("while true" not in provider and "repeat" in provider, "No unbounded provider polling loop; repeat is limited to Google API pagination")

require("func replaceProviderEvents" in calendar and "guard source != .manual" in calendar, "Provider replacement cannot delete manual appointments")
require("incoming.filter { $0.source == source }" in calendar, "Provider replacement accepts only matching normalized source data")
require("func removeProviderEvents" in calendar, "Provider source can be cleared independently")

require("@StateObject private var providerState = CalendarProviderCore()" in content, "Root app owns one CalendarProviderCore")
require("ScheduleCoreView(router: router, calendarState: calendarState, providerState: providerState)" in content, "Schedule receives calendar/provider state explicitly")
require("Connect Apple Calendar" in content and "Refresh Apple Calendar" in content, "Schedule exposes native Apple provider controls")
require("Connect Google Calendar" in content and "Refresh Google Calendar" in content, "Schedule exposes native Google provider controls")
require("Disconnect Google Calendar" in content, "Schedule exposes explicit Google disconnect")
require("Providers refresh only when you request it." in content, "Provider UI documents bounded refresh behavior")

for key in ["NSCalendarsFullAccessUsageDescription", "NSCalendarsUsageDescription", "GOOGLE_OAUTH_CLIENT_ID", "GOOGLE_OAUTH_REDIRECT_SCHEME", "CFBundleURLTypes"]:
    require(key in plist, f"Provider configuration exists: {key}")
require("CalendarProviderCore.swift in Sources" in project, "Provider core compiles in the active target")
require("LifeRouteWebView.swift in Sources" not in project and "Web in Resources" not in project, "Legacy WebView runtime remains quarantined")

if errors:
    print("LifeRoute v0.5.0 calendar-provider audit FAILED")
    for error in errors: print(f"- FAIL: {error}")
    raise SystemExit(1)
print(f"LifeRoute v0.5.0 calendar-provider audit passed ({len(checks)} checks).")
for check in checks: print(f"- OK: {check}")
