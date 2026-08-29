from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"Could not patch {label}: marker not found")
    return text.replace(old, new, 1)


# Replace the travel-mode emoji with the shared crisp vector icon set.
transport_path = Path("LifeRoute/Web/transport-mode.js")
transport = transport_path.read_text()
transport = replace_once(
    transport,
    '''    const MODES = [
      { id: "driving", label: "Driving", icon: "🚙", note: "Car route times" },
      { id: "walking", label: "Walking", icon: "🚶", note: "Walking route times" },
      { id: "transit", label: "Transit", icon: "🚆", note: "Public transit route times" }
    ];
    const validModes = new Set(MODES.map(mode => mode.id));
''',
    '''    const MODES = [
      { id: "driving", label: "Driving", iconName: "car", note: "Car route times" },
      { id: "walking", label: "Walking", iconName: "walk", note: "Walking route times" },
      { id: "transit", label: "Transit", iconName: "transit", note: "Public transit route times" }
    ];
    const validModes = new Set(MODES.map(mode => mode.id));
    const modeIcon = mode => typeof window.lifeRouteIcon === "function"
      ? window.lifeRouteIcon(mode?.iconName || "car", 21)
      : "";
''',
    "transport vector icon metadata",
)
transport = replace_once(
    transport,
    '''          <div class="transportIcon">${mode.icon}</div>
''',
    '''          <div class="transportIcon">${modeIcon(mode)}</div>
''',
    "transport option icon",
)
transport = replace_once(
    transport,
    '''      if (current) current.textContent = `${selected.icon} ${selected.label} is used when LifeRoute decides whether a route or errand fits inside a gap.`;
''',
    '''      if (current) current.innerHTML = `${modeIcon(selected)}<span>${selected.label} is used when LifeRoute decides whether a route or errand fits inside a gap.</span>`;
''',
    "transport current-mode icon",
)
transport_path.write_text(transport)


# Replace to-do category emoji with subtle line icons. The existing helper name
# is intentionally retained so downstream templates do not need rewriting.
todos_path = Path("LifeRoute/Web/todos.js")
todos = todos_path.read_text()
todos = replace_once(
    todos,
    '''  const categoryEmoji = value => ({
    Errand: "🛍️", Shopping: "🛒", Chore: "🧹", Call: "📞", Pickup: "📦", Other: "✓"
  })[value] || "✓";
''',
    '''  const categoryIconName = value => ({
    Errand: "bag", Shopping: "cart", Chore: "check", Call: "phone", Pickup: "package", Other: "check"
  })[value] || "check";
  const categoryEmoji = value => typeof window.lifeRouteIcon === "function"
    ? window.lifeRouteIcon(categoryIconName(value), 14, "lrInlineIcon")
    : "•";
''',
    "to-do category vector icons",
)
todos_path.write_text(todos)


# Replace the grocery comparison emoji with the same cart glyph used elsewhere.
stores_path = Path("LifeRoute/Web/grocery-stores.js")
stores = stores_path.read_text()
stores = replace_once(
    stores,
    '''        line.textContent = "🛒 Compare nearby branches inside a schedule gap";
''',
    '''        line.innerHTML = `${typeof window.lifeRouteIcon === "function" ? window.lifeRouteIcon("cart", 13, "lrInlineIcon") : ""}Compare nearby branches inside a schedule gap`;
''',
    "grocery comparison vector icon",
)
stores_path.write_text(stores)


# The small blue car shown beside every timeline travel estimate was still an
# emoji. Replace it with the same thin-line car glyph used by the transport UI.
routes_path = Path("LifeRoute/Web/route-times.js")
routes = routes_path.read_text()
routes = replace_once(
    routes,
    '''          travelText = "🚙 Calculating drive time…";
''',
    '''          travelText = `${typeof window.lifeRouteIcon === "function" ? window.lifeRouteIcon("car", 14, "lrInlineIcon") : ""}Calculating drive time…`;
''',
    "timeline calculating car icon",
)
routes = replace_once(
    routes,
    '''          travelText = `🚙 ${fmt(event.drive)}${distance}${origin}`;
''',
    '''          travelText = `${typeof window.lifeRouteIcon === "function" ? window.lifeRouteIcon("car", 14, "lrInlineIcon") : ""}${fmt(event.drive)}${distance}${origin}`;
''',
    "timeline route car icon",
)
routes = replace_once(
    routes,
    '''          travelText = "🚙 Route time unavailable";
''',
    '''          travelText = `${typeof window.lifeRouteIcon === "function" ? window.lifeRouteIcon("car", 14, "lrInlineIcon") : ""}Route time unavailable`;
''',
    "timeline unavailable car icon",
)
routes = replace_once(
    routes,
    '''          travelText = "🚙 Route time pending";
''',
    '''          travelText = `${typeof window.lifeRouteIcon === "function" ? window.lifeRouteIcon("car", 14, "lrInlineIcon") : ""}Route time pending`;
''',
    "timeline pending car icon",
)
routes_path.write_text(routes)


# The legacy inline Day renderer still contained a fallback car emoji even
# though route-times replaces that visual once the runtime helpers load. Remove
# the glyph from the prepared HTML too so there is no flash/regression path.
index_path = Path("LifeRoute/Web/index.html")
index = index_path.read_text()
index = replace_once(
    index,
    '''<div class="route"><span>🚙 ${e.drive||"—"}m est. + ${e.buffer||0}m buffer</span><button class="secondary" onclick="routeTo('${encodeURIComponent(e.address)}')">Route</button></div>''',
    '''<div class="route"><span>Travel · ${e.drive||"—"}m est. + ${e.buffer||0}m buffer</span><button class="secondary" onclick="routeTo('${encodeURIComponent(e.address)}')">Route</button></div>''',
    "legacy inline timeline car glyph",
)
index_path.write_text(index)

print("Replaced LifeRoute emoji-style UI glyphs, including the timeline car, with the sleek SVG icon system.")
