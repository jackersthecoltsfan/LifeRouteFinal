from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Could not harden {label}: expected source not found")
    path.write_text(text.replace(old, new, 1))


def insert_before(path: Path, marker: str, block: str, label: str):
    text = path.read_text()
    if block in text:
        return
    if marker not in text:
        raise SystemExit(f"Could not harden {label}: marker not found")
    path.write_text(text.replace(marker, block + marker, 1))


# Boundary stop planning must not route from a coordinate left over from an old
# foreground session. Two minutes matches the browser geolocation maximum age.
boundary = Path("LifeRoute/Web/boundary-stop-planner.js")
insert_before(
    boundary,
    "  const selectionKey = (date, mode) => `${date}|${mode}`;\n",
    '''  const freshLiveLocation = () => {\n    const state = nativeStateValue();\n    const live = state?.currentLocation;\n    if (live?.latitude == null || live?.longitude == null) return null;\n    let age = Infinity;\n    try { age = Number(window.LifeRouteLiveLocation?.freshnessMs?.()); } catch (_) {}\n    if (!Number.isFinite(age)) {\n      const stamp = Date.parse(String(live?.timestamp || ""));\n      if (Number.isFinite(stamp)) age = Date.now() - stamp;\n    }\n    return age <= 120000 ? live : null;\n  };\n''',
    "boundary live-location freshness helper",
)
replace_once(
    boundary,
    '''      const live = nativeStateValue()?.currentLocation;\n      const useLive = isToday(date) && live?.latitude != null && live?.longitude != null;\n''',
    '''      const live = freshLiveLocation();\n      const useLive = isToday(date) && live?.latitude != null && live?.longitude != null;\n''',
    "boundary stale-location guard",
)

# General stop/place search uses the same freshness rule for its route center.
search = Path("LifeRoute/Web/stop-place-search-v4.js")
insert_before(
    search,
    "  let state = null;\n",
    '''  const freshLiveLocation = () => {\n    const live = window.nativeState?.currentLocation;\n    if (live?.latitude == null || live?.longitude == null) return null;\n    let age = Infinity;\n    try { age = Number(window.LifeRouteLiveLocation?.freshnessMs?.()); } catch (_) {}\n    if (!Number.isFinite(age)) {\n      const stamp = Date.parse(String(live?.timestamp || ""));\n      if (Number.isFinite(stamp)) age = Date.now() - stamp;\n    }\n    return age <= 120000 ? live : null;\n  };\n\n''',
    "stop search live-location freshness helper",
)
replace_once(
    search,
    '''      const live = window.nativeState?.currentLocation;\n      const useLive = selectedDay() === todayKey() && live?.latitude != null && live?.longitude != null;\n''',
    '''      const live = freshLiveLocation();\n      const useLive = selectedDay() === todayKey() && live?.latitude != null && live?.longitude != null;\n''',
    "stop search stale-location guard",
)

print("All route consumers now reject stale live-location coordinates before using them as an origin.")
