// LifeRoute sleek inline vector icon system.
// Uses crisp, theme-aware SVGs instead of emoji/PNG assets so icons stay sharp
// at every iPhone scale and automatically inherit the current theme color.
(() => {
  const paths = {
    car: '<path d="M4 13.5 5.6 9a2 2 0 0 1 1.9-1.3h9a2 2 0 0 1 1.9 1.3l1.6 4.5"/><path d="M3.5 13.5h17v4.2a1.8 1.8 0 0 1-1.8 1.8H5.3a1.8 1.8 0 0 1-1.8-1.8z"/><path d="M6.5 19.5v1.2M17.5 19.5v1.2M6.8 15.8h.01M17.2 15.8h.01"/>',
    walk: '<circle cx="12" cy="4.5" r="1.7"/><path d="m10.7 8.3 2.1 2.1 2.6 1.1M12.7 10.4l-1 4.2-3.2 3.7M11.7 14.6l3.2 2.2 1.6 3.2M9.3 9.3l-2.6 3"/>',
    transit: '<rect x="5" y="3.5" width="14" height="15" rx="3"/><path d="M7.5 8h9M8 13h.01M16 13h.01M8 18.5 6.5 21M16 18.5l1.5 2.5"/>',
    cart: '<path d="M3 5h2l1.8 9.1a2 2 0 0 0 2 1.6h7.9a2 2 0 0 0 1.9-1.4L20 9H6"/><circle cx="9" cy="19" r="1.2"/><circle cx="17" cy="19" r="1.2"/>',
    bag: '<path d="M6 8h12l-1 12H7z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>',
    package: '<path d="m4 7 8-4 8 4-8 4z"/><path d="M4 7v10l8 4 8-4V7M12 11v10"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    phone: '<path d="M7.2 3.8 4.8 5.1c-.8.4-1.1 1.3-.8 2.1 2.1 6 6.8 10.7 12.8 12.8.8.3 1.7 0 2.1-.8l1.3-2.4-4.4-2.2-1.2 1.8a13.6 13.6 0 0 1-7-7l1.8-1.2z"/>',
    home: '<path d="m3 11 9-8 9 8"/><path d="M5.5 9.5V21h13V9.5M9.5 21v-7h5v7"/>',
    calendar: '<rect x="3.5" y="5" width="17" height="16" rx="2.5"/><path d="M7.5 3v4M16.5 3v4M3.5 9h17"/>',
    week: '<rect x="3.5" y="4.5" width="17" height="16" rx="2.5"/><path d="M3.5 9h17M8 9v11M16 9v11"/>',
    pin: '<path d="M20 10c0 5.5-8 11-8 11S4 15.5 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.4"/>',
    route: '<circle cx="6" cy="18" r="2"/><circle cx="18" cy="6" r="2"/><path d="M7.5 16.5 10 14c2-2 2-4 0-6l-1-1M12.5 7.5 16.5 6"/>',
    navigation: '<path d="m21 3-8.5 18-2.2-7.3L3 11.5z"/>',
    refresh: '<path d="M20 7v5h-5"/><path d="M4 17v-5h5"/><path d="M18.2 9A7 7 0 0 0 6.5 6.5L4 9M5.8 15A7 7 0 0 0 17.5 17.5L20 15"/>',
    sparkles: '<path d="m12 3 1.2 3.3L16.5 7.5l-3.3 1.2L12 12l-1.2-3.3-3.3-1.2 3.3-1.2zM18 14l.8 2.2L21 17l-2.2.8L18 20l-.8-2.2L15 17l2.2-.8zM6 14l.6 1.6 1.6.6-1.6.6L6 18.4l-.6-1.6-1.6-.6 1.6-.6z"/>',
    user: '<circle cx="12" cy="8" r="3.5"/><path d="M5.5 20a6.5 6.5 0 0 1 13 0"/>',
    briefcase: '<rect x="3" y="7" width="18" height="13" rx="2.5"/><path d="M9 7V4h6v3M3 12h18M10 12v2h4v-2"/>',
    settings: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6V21H10v-.1a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H3v-4h.1a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1a1.7 1.7 0 0 0 1.9.3A1.7 1.7 0 0 0 10 3V3h4v.1a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9A1.7 1.7 0 0 0 21 10h.1v4H21a1.7 1.7 0 0 0-1.6 1Z"/>',
    map: '<path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3z"/><path d="M9 3v15M15 6v15"/>',
    coffee: '<path d="M5 8h11v5a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5z"/><path d="M16 10h2a2.5 2.5 0 0 1 0 5h-2M7 3v2M11 3v2M15 3v2"/>',
    gym: '<path d="M4 10v4M7 8v8M17 8v8M20 10v4M7 12h10"/>',
    tree: '<path d="m12 3-5 7h3l-4 6h5v5h2v-5h5l-4-6h3z"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'
  };

  window.lifeRouteIcon = function lifeRouteIcon(name, size = 18, extraClass = "") {
    const body = paths[name] || paths.check;
    const cls = `lrIcon ${extraClass || ""}`.trim();
    return `<svg class="${cls}" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;
  };

  const style = document.createElement("style");
  style.id = "lifeRouteIconStyles";
  style.textContent = `
    .lrIcon{display:inline-block;vertical-align:-.16em;flex:0 0 auto}
    .lrIconLabel{display:inline-flex;align-items:center;gap:6px}
    .lrInlineIcon{margin-right:4px;color:color-mix(in srgb,var(--blue) 82%,var(--text))}
    .tab .lrIcon{width:14px;height:14px;margin-right:5px;vertical-align:-.19em;opacity:.9}
    .tab.active .lrIcon{opacity:1}
    .provider .icon{display:flex;align-items:center;justify-content:flex-start;color:var(--blue)!important}
    .provider.active .icon{color:var(--gold)!important}
    .provider .icon .lrIcon{width:20px;height:20px}
    .integrationIcon{color:var(--blue);font-size:0!important}
    .integrationIcon .lrIcon{width:20px;height:20px}
    .bottomin button,.placeActions button,.todoActions button,.gapOptionButtons button,.storeOptionButtons button{display:inline-flex!important;align-items:center!important;justify-content:center!important;gap:6px!important}
    .transportIcon{display:flex;align-items:center;color:var(--blue)}
    .transportChoice.active .transportIcon{color:var(--gold)}
    .transportCurrent{display:flex;align-items:center;gap:7px}
  `;
  document.head.appendChild(style);

  const setIcon = (container, name, size = 18) => {
    if (!container || container.dataset.lrVectorIcon === name) return;
    container.dataset.lrVectorIcon = name;
    container.innerHTML = window.lifeRouteIcon(name, size);
  };

  const prependIcon = (element, name, size = 15) => {
    if (!element || element.dataset.lrIconReady) return;
    element.dataset.lrIconReady = "1";
    element.insertAdjacentHTML("afterbegin", window.lifeRouteIcon(name, size));
  };

  const decorateButton = button => {
    if (!button || button.dataset.lrIconReady) return;
    const text = String(button.textContent || "").trim().toLowerCase();
    let icon = null;
    if (text.includes("route") || text.includes("open in")) icon = "navigation";
    else if (text.includes("refresh")) icon = "refresh";
    else if (text.includes("find best") || text.includes("optimize")) icon = "sparkles";
    else if (text.includes("save place")) icon = "pin";
    else if (text === "done" || text.includes("mark done")) icon = "check";
    else if (text.includes("compare stores")) icon = "cart";
    if (icon) prependIcon(button, icon, 14);
  };

  const decorateStatic = root => {
    const scope = root || document;
    const providerIcons = {
      providerApple: "map",
      providerGoogle: "pin",
      providerAsk: "route"
    };
    Object.entries(providerIcons).forEach(([id, name]) => {
      const node = document.getElementById(id)?.querySelector(".icon");
      setIcon(node, name, 20);
    });

    document.querySelectorAll("#setup .integration").forEach(row => {
      const title = String(row.querySelector(".title")?.textContent || "").toLowerCase();
      const icon = row.querySelector(".integrationIcon");
      if (title.includes("apple") || title.includes("google")) setIcon(icon, "calendar", 20);
      else if (title.includes("central")) setIcon(icon, "briefcase", 20);
    });

    const tabIcons = {
      today: "calendar",
      week: "week",
      places: "pin",
      todos: "check",
      setup: "settings"
    };
    Object.entries(tabIcons).forEach(([view, name]) => {
      const tab = document.querySelector(`.tab[data-view="${view}"]`);
      prependIcon(tab, name, 14);
    });

    scope.querySelectorAll?.("button").forEach(decorateButton);
  };

  const start = () => {
    decorateStatic(document);
    const observer = new MutationObserver(records => {
      records.forEach(record => record.addedNodes.forEach(node => {
        if (node.nodeType !== 1) return;
        decorateStatic(node);
      }));
    });
    observer.observe(document.body, { childList: true, subtree: true });
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
