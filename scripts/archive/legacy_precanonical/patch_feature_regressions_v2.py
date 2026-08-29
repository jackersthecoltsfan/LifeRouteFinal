from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if old in text:
        path.write_text(text.replace(old, new, 1))
        return
    if new and new in text:
        return
    raise SystemExit(f"{label}: expected source pattern not found in {path}")


# Clear Day is a one-tap, selected-date-only route reset. It must never delete
# appointments/manual events, places, clients, To-Dos, preferences, or other dates.
day = WEB / "day-controls-v5.js"
replace_once(
    day,
    '  const dateKey = () => clean(window.selectedDate);',
    '  const dateKey = () => clean(window.selectedDate || (typeof selectedDate !== "undefined" ? selectedDate : ""));',
    "Clear Day selected-date bridge",
)
old_clear = '''  const clearDay = () => {
    const day = dateKey();
    if (!day) return;
    if (!window.confirm("Clear this day's LifeRoute plan? Calendar events from connected providers will stay.")) return;

    try { window.endLifeRouteDay?.(); } catch (_) {}
    endLiveActivity();
    clearDateKeys(GENERATED_STORE, day);
    clearDateKeys(GAP_STORE, day);
    clearDateKeys(BOUNDARY_STORE, day);

    if (Array.isArray(window.events)) {
      window.events = window.events.filter(event => !(event?.date === day && (!event?.source || event.source === "manual")));
    }
    try { window.persist?.(); } catch (_) {}
    try { window.renderAll?.(); } catch (_) { try { window.renderToday?.(); } catch (_) {} }
  };'''
new_clear = '''  const clearDay = () => {
    const day = dateKey();
    if (!day) return;

    try { window.endLifeRouteDay?.(); } catch (_) {}
    endLiveActivity();
    clearDateKeys(GENERATED_STORE, day);
    if (typeof window.clearLifeRouteGapRoutesForDay === "function") window.clearLifeRouteGapRoutesForDay(day);
    else clearDateKeys(GAP_STORE, day);
    if (typeof window.clearLifeRouteBoundaryStopsForDay === "function") window.clearLifeRouteBoundaryStopsForDay(day);
    else clearDateKeys(BOUNDARY_STORE, day);
    try { window.renderAll?.(); } catch (_) { try { window.renderToday?.(); } catch (_) {} }
    const button = document.querySelector("[data-lr-clear-day]");
    if (button) {
      const previous = button.textContent;
      button.textContent = "Cleared ✓";
      button.disabled = true;
      setTimeout(() => { button.textContent = previous || "Clear day"; button.disabled = false; }, 900);
    }
    try { window.setStatus?.("Cleared this day's routes · appointments and saved data kept"); } catch (_) {}
    document.dispatchEvent(new CustomEvent("liferoute:day-cleared", { detail: { dateKey: day } }));
  };'''
replace_once(day, old_clear, new_clear, "Clear Day route-only scope")

# Clear All is destructive, so keep a confirmation step without relying on
# WKWebView's JavaScript confirm panel. First tap arms for four seconds; the
# second tap performs the wipe.
replace_once(
    day,
    '  const clearAll = () => {\n    if (!window.confirm("Clear all LifeRoute plans, saved places, clients, To-Dos, calendar links, and preferences on this device? Your LifeRoute sign-in will stay.")) return;\n',
    '  let clearAllArmedUntil = 0;\n  const clearAll = () => {\n    const now = Date.now();\n    const button = document.querySelector("[data-lr-clear-all]");\n    if (now > clearAllArmedUntil) {\n      clearAllArmedUntil = now + 4000;\n      if (button) {\n        button.dataset.originalLabel = button.dataset.originalLabel || button.textContent || "Clear all";\n        button.textContent = "Tap again to clear all";\n        button.classList.add("lrClearAllArmed");\n      }\n      setTimeout(() => {\n        if (Date.now() <= clearAllArmedUntil) return;\n        if (button) {\n          button.textContent = button.dataset.originalLabel || "Clear all";\n          button.classList.remove("lrClearAllArmed");\n        }\n      }, 4100);\n      return;\n    }\n    clearAllArmedUntil = 0;\n',
    "Clear All native-safe two-step confirmation",
)

# Resource links should leave the native app through iOS rather than replacing
# LifeRoute inside its WKWebView. Browser fallback remains unchanged.
resources = WEB / "resources-hub-web.js"
replace_once(
    resources,
    '  const launch = url => {\n    const safeURL = normalizeURL(url);\n    if (!safeURL) return;\n    const opened = window.open(safeURL, "_blank", "noopener,noreferrer");\n    if (!opened) window.location.href = safeURL;\n  };',
    '  const launch = url => {\n    const safeURL = normalizeURL(url);\n    if (!safeURL) return;\n    try {\n      if (typeof window.postNative === "function" && window.postNative({ action: "openExternalURL", url: safeURL })) return;\n    } catch (_) {}\n    const opened = window.open(safeURL, "_blank", "noopener,noreferrer");\n    if (!opened) window.location.href = safeURL;\n  };',
    "Resource native external-link handoff",
)

print("Feature regressions fixed: Clear Day is one-tap and route-scoped, Clear All uses native-safe two-tap confirmation, and Resources use native handoff.")
