from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    # Prefer replacing the old contract whenever it still exists. Only treat the
    # patch as already applied when the old contract is gone and the new one is
    # present. This matters for empty/common replacement strings.
    if old in text:
        path.write_text(text.replace(old, new, 1))
        return
    if new and new in text:
        return
    raise SystemExit(f"{label}: expected source pattern not found in {path}")


# Clear Day must work in WKWebView without depending on a JavaScript confirm
# panel. Use the shared selected-date bridge and make the action immediate.
day = WEB / "day-controls-v5.js"
replace_once(
    day,
    '  const dateKey = () => clean(window.selectedDate);',
    '  const dateKey = () => clean(window.selectedDate || (typeof selectedDate !== "undefined" ? selectedDate : ""));',
    "Clear Day selected-date bridge",
)
replace_once(
    day,
    '    if (!window.confirm("Clear this day\'s LifeRoute plan? Calendar events from connected providers will stay.")) return;\n\n',
    '',
    "Clear Day native-safe confirmation removal",
)
replace_once(
    day,
    '    try { window.persist?.(); } catch (_) {}\n    try { window.renderAll?.(); } catch (_) { try { window.renderToday?.(); } catch (_) {} }\n  };',
    '    try { window.persist?.(); } catch (_) {}\n    try { window.renderAll?.(); } catch (_) { try { window.renderToday?.(); } catch (_) {} }\n    const button = document.querySelector("[data-lr-clear-day]");\n    if (button) {\n      const previous = button.textContent;\n      button.textContent = "Cleared ✓";\n      button.disabled = true;\n      setTimeout(() => { button.textContent = previous || "Clear day"; button.disabled = false; }, 900);\n    }\n    document.dispatchEvent(new CustomEvent("liferoute:day-cleared", { detail: { dateKey: day } }));\n  };',
    "Clear Day visible completion feedback",
)

# Clear All is destructive, so keep a confirmation step without relying on
# WKWebView's JavaScript confirm panel. First tap arms for four seconds; the
# second tap performs the wipe. This works identically on web and iPhone.
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

print("Feature regressions fixed: Clear Day works directly, Clear All uses native-safe two-tap confirmation, and Resources use native handoff.")
