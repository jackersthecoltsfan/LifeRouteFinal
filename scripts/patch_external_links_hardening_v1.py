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


# Calendar subscription URLs can contain effectively secret tokens. Never fetch
# them over plaintext HTTP and never let an unreachable host hang the browser.
calendar = Path("LifeRoute/Web/calendar-hub.js")
insert_before(
    calendar,
    "  let nativeFeedPending = new Map();\n",
    '''  const fetchCalendarFeedWithTimeout = async (url, timeoutMs = 20000) => {\n    const controller = new AbortController();\n    const timer = setTimeout(() => controller.abort(), timeoutMs);\n    try {\n      return await fetch(url, { method: "GET", credentials: "omit", cache: "no-store", redirect: "follow", signal: controller.signal });\n    } finally {\n      clearTimeout(timer);\n    }\n  };\n\n''',
    "browser calendar-feed timeout helper",
)
replace_once(
    calendar,
    '        const response = await fetch(url, { method: "GET", credentials: "omit", cache: "no-store" });\n',
    '        const response = await fetchCalendarFeedWithTimeout(url);\n',
    "browser calendar-feed request deadline",
)
replace_once(
    calendar,
    '      if (!/^(https?:\\/\\/|webcal:\\/\\/)/i.test(url)) {\n        alert("Paste a read-only https:// or webcal:// calendar subscription link.");\n',
    '      if (!/^(https:\\/\\/|webcal:\\/\\/)/i.test(url)) {\n        alert("Paste a secure read-only https:// or webcal:// calendar subscription link.");\n',
    "calendar feed HTTPS-only validation",
)

# The native feed loader already has a 25-second timeout. Restrict its transport
# to HTTPS as well so private subscription tokens cannot cross plaintext HTTP.
native = Path("LifeRoute/LifeRouteWebView.swift")
replace_once(
    native,
    '                  scheme == "https" || scheme == "http" else {\n',
    '                  scheme == "https" else {\n',
    "native calendar-feed HTTPS-only transport",
)
replace_once(
    native,
    '                    "message": "Use an https:// or webcal:// calendar subscription link."\n',
    '                    "message": "Use a secure https:// or webcal:// calendar subscription link."\n',
    "native calendar-feed security message",
)

# Generic visual lookup uses Wikimedia for safe generic activity/object terms.
# Bound it just like the Living Creatures lookup so poor connectivity never
# leaves a visual-generation flow hanging indefinitely.
visual = Path("LifeRoute/Web/visual-resolver.js")
insert_before(
    visual,
    "  const commonsSearch = async (query, originalText) => {\n",
    '''  const fetchWithTimeout = async (url, options = {}, timeoutMs = 14000) => {\n    const controller = new AbortController();\n    const timer = setTimeout(() => controller.abort(), timeoutMs);\n    try { return await fetch(url, { ...options, signal: controller.signal }); }\n    finally { clearTimeout(timer); }\n  };\n\n''',
    "visual resolver network deadline",
)
replace_once(
    visual,
    '    const response = await fetch(`https://commons.wikimedia.org/w/api.php?${params.toString()}`, {\n',
    '    const response = await fetchWithTimeout(`https://commons.wikimedia.org/w/api.php?${params.toString()}`, {\n',
    "visual resolver Wikimedia deadline",
)

# Custom resource shortcuts are navigation only. Keep them HTTPS-only and keep
# noopener/noreferrer isolation already used by the launcher.
resources = Path("LifeRoute/Web/resources-hub-web.js")
replace_once(
    resources,
    '      return /^https?:$/.test(url.protocol) ? url.href : "";\n',
    '      return url.protocol === "https:" ? url.href : "";\n',
    "custom resource HTTPS-only normalization",
)
replace_once(
    resources,
    '        if (!name || !url) return alert("Add a resource name and a valid web address.");\n',
    '        if (!name || !url) return alert("Add a resource name and a secure https:// web address.");\n',
    "custom resource HTTPS-only message",
)

print("External-link hardening applied: secure calendar/resource URLs plus browser calendar and visual lookup deadlines.")
