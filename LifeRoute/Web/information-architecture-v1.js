// LifeRoute information architecture v1.
// Keeps the primary navigation intentionally small and routes existing features
// into the product hierarchy defined for Schedule, Session Tools, Resources,
// and Setup without removing the underlying feature views.
(() => {
  if (window.__lifeRouteInformationArchitectureV1Loaded) return;
  window.__lifeRouteInformationArchitectureV1Loaded = true;

  const safeIcon = (name, size = 19) => {
    if (typeof window.lifeRouteIcon === "function") return window.lifeRouteIcon(name, size);
    return "";
  };

  const customIcon = (name, size = 19) => {
    const paths = {
      puzzle: '<path d="M8.2 3.5H4.5a1 1 0 0 0-1 1v4.1h1.7a2.3 2.3 0 1 1 0 4.6H3.5v6.3a1 1 0 0 0 1 1h5.8v-1.8a2.3 2.3 0 1 1 4.6 0v1.8h4.6a1 1 0 0 0 1-1v-5.7h-1.8a2.3 2.3 0 1 1 0-4.6h1.8V4.5a1 1 0 0 0-1-1h-6v1.7a2.3 2.3 0 1 1-4.6 0V3.5Z"/>',
      book: '<path d="M4 4.5h5.2A2.8 2.8 0 0 1 12 7.3V21a3.2 3.2 0 0 0-3.2-3.2H4z"/><path d="M20 4.5h-5.2A2.8 2.8 0 0 0 12 7.3V21a3.2 3.2 0 0 1 3.2-3.2H20z"/>',
      bookmark: '<path d="M6 3.5h12v17l-6-3.8-6 3.8z"/>',
      leaf: '<path d="M20.5 4.2C12 4.4 5.7 7.7 5.1 14.1c-.2 2.4 1.6 4.6 4.1 4.7 6.5.3 10.1-6 11.3-14.6Z"/><path d="M4 21c2.2-5.5 6.1-9.2 12.1-11.6"/>',
      link: '<path d="M9.5 14.5 14.5 9.5"/><path d="M7.4 16.6 5.8 18.2a3.4 3.4 0 0 1-4.8-4.8l3.6-3.6a3.4 3.4 0 0 1 4.8 0"/><path d="m16.6 7.4 1.6-1.6A3.4 3.4 0 1 1 23 10.6l-3.6 3.6a3.4 3.4 0 0 1-4.8 0"/>',
      document: '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v5h5M9 12h6M9 16h6"/>',
      image: '<rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="9" cy="10" r="2"/><path d="m5 18 5-5 3 3 2-2 4 4"/>'
    };
    const body = paths[name];
    if (!body) return "";
    return `<svg class="lrIcon" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;
  };

  const icon = (name, size = 19) => customIcon(name, size) || safeIcon(name, size);

  const styles = document.createElement("style");
  styles.id = "lifeRouteInformationArchitectureV1Styles";
  styles.textContent = `
    .tabs{display:grid!important;grid-template-columns:repeat(4,minmax(0,1fr))!important;gap:6px!important;overflow:visible!important;padding:3px 0 5px!important}
    .tabs .tab{min-width:0!important;width:100%!important;padding:9px 3px!important;display:flex!important;flex-direction:column!important;align-items:center!important;justify-content:center!important;gap:4px!important;font-size:9.6px!important;line-height:1.05!important;white-space:normal!important;text-align:center!important;min-height:58px!important}
    .tabs .tab .lrIcon{margin:0!important;width:19px!important;height:19px!important}
    .tabs .tab.lrNestedTab{display:none!important}
    .lrHubGrid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:0 0 14px}
    .lrHubCard{appearance:none;text-align:left;background:linear-gradient(145deg,color-mix(in srgb,var(--blue) 6%,transparent),transparent),var(--panel);color:var(--text);border:1px solid var(--line);border-radius:17px!important;padding:14px!important;min-height:108px;display:flex;flex-direction:column;align-items:flex-start;justify-content:space-between;gap:12px;box-shadow:0 10px 28px rgba(0,0,0,.12)}
    .lrHubCard:active{transform:scale(.985)}.lrHubIcon{width:34px;height:34px;border-radius:11px;display:grid;place-items:center;background:color-mix(in srgb,var(--gold) 10%,var(--panel2));color:var(--gold);border:1px solid color-mix(in srgb,var(--gold) 23%,var(--line))}
    .lrHubText b{display:block;font-size:14px;letter-spacing:-.2px;margin-bottom:3px}.lrHubText span{display:block;font-size:10.5px;color:var(--muted);line-height:1.3;font-weight:560}
    .lrHubCard.active{border-color:color-mix(in srgb,var(--gold) 58%,var(--line));box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 28%,transparent)}
    .lrHubTitle{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:2px 0 10px}.lrHubTitle h2{margin:0!important;font-size:18px!important}.lrHubTitle .tiny{max-width:52%;text-align:right}
    #lrSetupLegacy[hidden]{display:none!important}.lrSetupBack{margin-bottom:10px!important}.lrSetupConnectionsMode .section{display:none!important}.lrSetupConnectionsMode .section.lrConnectionSection{display:block!important}
    .lrSavedPlaceCategories{margin-bottom:12px}.lrSavedPlaceCategories .lrHubCard{min-height:92px}.lrPlaceCategoryCount{font-size:9.5px;color:var(--muted);font-weight:700}
    .lrToolIntro{padding:18px 10px;text-align:center;color:var(--muted);font-size:11px;border:1px dashed var(--line);border-radius:14px;margin-bottom:8px}.toolGrid[data-lr-category="none"]>.toolCard{display:none!important}.toolGrid[data-lr-category="timer"]>.toolCard:not([data-lr-tool-group="timer"]),.toolGrid[data-lr-category="visuals"]>.toolCard:not([data-lr-tool-group="visuals"]),.toolGrid[data-lr-category="docs"]>.toolCard:not([data-lr-tool-group="docs"]){display:none!important}
    @media(max-width:520px){.lrHubGrid{grid-template-columns:1fr 1fr}.lrHubCard{padding:12px!important;min-height:102px}.lrHubText b{font-size:13px}.lrHubText span{font-size:9.8px}.tabs .tab{font-size:9px!important}}
  `;
  document.head.appendChild(styles);

  const parentTabForView = id => ({
    today: "today", week: "today", month: "today",
    tools: "tools",
    resources: "resources",
    setup: "setup", places: "setup", todos: "setup"
  })[id] || id;

  const activatePrimaryTab = id => {
    const parent = parentTabForView(id);
    document.querySelectorAll('.tabs .tab[data-lr-primary-nav="1"]').forEach(button => {
      button.classList.toggle("active", button.dataset.view === parent);
    });
  };

  const resetSessionTools = () => {
    const grid = document.querySelector("#tools .toolGrid");
    if (grid) grid.dataset.lrCategory = "none";
    document.querySelectorAll("#lrSessionToolsHub .lrHubCard").forEach(card => card.classList.remove("active"));
    const intro = document.getElementById("lrToolIntro");
    if (intro) intro.hidden = false;
  };

  const showSetupLauncher = () => {
    const setup = document.getElementById("setup");
    const legacy = document.getElementById("lrSetupLegacy");
    if (!setup || !legacy) return;
    legacy.hidden = true;
    legacy.classList.remove("lrSetupConnectionsMode");
    setup.dataset.lrSetupMode = "launcher";
  };

  const installShowViewWrapper = () => {
    const previous = window.showView;
    if (typeof previous !== "function" || previous.__lrInformationArchitectureV1) return;
    const wrapped = function lifeRouteShowViewWithInformationArchitecture(id) {
      const result = previous.apply(this, arguments);
      activatePrimaryTab(id);
      if (id === "tools") resetSessionTools();
      if (id === "setup") showSetupLauncher();
      return result;
    };
    wrapped.__lrInformationArchitectureV1 = true;
    window.showView = wrapped;
  };

  const labelPrimaryTab = (button, label, iconName) => {
    if (!button) return;
    button.dataset.lrPrimaryNav = "1";
    button.innerHTML = `${icon(iconName, 19)}<span>${label}</span>`;
  };

  const configureTopNavigation = () => {
    const tabs = document.querySelector(".tabs");
    if (!tabs) return false;
    const primary = {
      today: ["Schedule", "calendar"],
      tools: ["Session Tools", "puzzle"],
      resources: ["Resources", "book"],
      setup: ["Setup", "user"]
    };
    tabs.querySelectorAll(".tab").forEach(button => {
      const config = primary[button.dataset.view];
      if (config) {
        button.classList.remove("lrNestedTab");
        labelPrimaryTab(button, config[0], config[1]);
      } else {
        button.classList.add("lrNestedTab");
        button.removeAttribute("data-lr-primary-nav");
      }
    });
    tabs.style.setProperty("display", "grid", "important");
    tabs.style.setProperty("grid-template-columns", "repeat(4,minmax(0,1fr))", "important");
    tabs.style.setProperty("overflow", "visible", "important");
    activatePrimaryTab(document.querySelector(".view.active")?.id || "today");
    return true;
  };

  const classifyToolCards = () => {
    document.querySelectorAll("#tools .toolGrid > .toolCard").forEach(card => {
      const id = String(card.id || "").toLowerCase();
      const text = String(card.textContent || "").toLowerCase();
      let group = "docs";
      if (id.includes("timer") || text.includes("visual timer")) group = "timer";
      else if (/visual|first\s*\/\s*then|choice board|image|icon/.test(`${id} ${text}`)) group = "visuals";
      card.dataset.lrToolGroup = group;
    });
  };

  const showToolCategory = category => {
    classifyToolCards();
    const grid = document.querySelector("#tools .toolGrid");
    if (!grid) return;
    grid.dataset.lrCategory = category;
    const intro = document.getElementById("lrToolIntro");
    if (intro) intro.hidden = true;
    document.querySelectorAll("#lrSessionToolsHub .lrHubCard").forEach(card => card.classList.toggle("active", card.dataset.lrToolCategory === category));
    const first = grid.querySelector(`.toolCard[data-lr-tool-group="${category}"]`);
    first?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  const ensureSessionToolsHub = () => {
    const tools = document.getElementById("tools");
    const grid = tools?.querySelector(".toolGrid");
    if (!tools || !grid) return false;
    classifyToolCards();
    if (!document.getElementById("lrSessionToolsHub")) {
      const hub = document.createElement("div");
      hub.id = "lrSessionToolsHub";
      hub.innerHTML = `
        <div class="lrHubTitle"><h2>Session Tools</h2><span class="tiny">Fast tools for direct sessions</span></div>
        <div class="lrHubGrid">
          <button type="button" class="lrHubCard" data-lr-tool-category="timer"><span class="lrHubIcon">${safeIcon("clock", 20)}</span><span class="lrHubText"><b>Visual Timer</b><span>Quick visual countdowns for sessions and transitions.</span></span></button>
          <button type="button" class="lrHubCard" data-lr-tool-category="visuals"><span class="lrHubIcon">${icon("image", 20)}</span><span class="lrHubText"><b>Visuals Generator</b><span>Create visuals, First/Then supports, and choice boards.</span></span></button>
          <button type="button" class="lrHubCard" data-lr-tool-category="docs"><span class="lrHubIcon">${icon("document", 20)}</span><span class="lrHubText"><b>Documentation Tools</b><span>Session notes, scratch notes, planning, and documentation support.</span></span></button>
        </div>`;
      tools.insertBefore(hub, tools.firstChild);
      hub.querySelectorAll("[data-lr-tool-category]").forEach(button => {
        button.addEventListener("click", () => showToolCategory(button.dataset.lrToolCategory));
      });
    }
    if (!document.getElementById("lrToolIntro")) {
      const intro = document.createElement("div");
      intro.id = "lrToolIntro";
      intro.className = "lrToolIntro";
      intro.textContent = "Choose Visual Timer, Visuals Generator, or Documentation Tools above.";
      grid.insertBefore(intro, grid.firstChild);
    }
    resetSessionTools();
    return true;
  };

  const activateSetupPane = paneName => {
    const nav = document.getElementById("setupSubnav");
    nav?.querySelectorAll("[data-setup-pane]").forEach(button => button.classList.toggle("active", button.dataset.setupPane === paneName));
    const known = {
      general: document.getElementById("setupGeneral"),
      clients: document.getElementById("setupClients"),
      places: document.getElementById("places")
    };
    Object.entries(known).forEach(([name, pane]) => pane?.classList.toggle("active", name === paneName));
  };

  const markConnectionSections = () => {
    const legacy = document.getElementById("lrSetupLegacy");
    if (!legacy) return;
    legacy.querySelectorAll(".section").forEach(section => {
      const heading = String(section.querySelector("h2")?.textContent || section.textContent || "").toLowerCase();
      const isConnection = /calendar|navigation|maps|connection|provider|integration/.test(heading);
      section.classList.toggle("lrConnectionSection", isConnection);
    });
  };

  const openSetupSection = section => {
    const legacy = document.getElementById("lrSetupLegacy");
    if (!legacy) return;
    legacy.hidden = false;
    legacy.classList.remove("lrSetupConnectionsMode");
    if (section === "clients") {
      activateSetupPane("clients");
      document.getElementById("setupClients")?.scrollIntoView({ behavior: "smooth", block: "start" });
      return;
    }
    if (section === "connections") {
      activateSetupPane("general");
      markConnectionSections();
      legacy.classList.add("lrSetupConnectionsMode");
      legacy.querySelector(".lrConnectionSection")?.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  };

  const ensureSetupHub = () => {
    const setup = document.getElementById("setup");
    if (!setup) return false;
    let legacy = document.getElementById("lrSetupLegacy");
    if (!legacy) {
      legacy = document.createElement("div");
      legacy.id = "lrSetupLegacy";
      while (setup.firstChild) legacy.appendChild(setup.firstChild);
      setup.appendChild(legacy);
    }
    if (!document.getElementById("lrSetupHub")) {
      const hub = document.createElement("div");
      hub.id = "lrSetupHub";
      hub.innerHTML = `
        <div class="lrHubTitle"><h2>Setup</h2><span class="tiny">Personalize LifeRoute and connect services</span></div>
        <div class="lrHubGrid">
          <button type="button" class="lrHubCard" data-lr-setup="places"><span class="lrHubIcon">${icon("bookmark", 20)}</span><span class="lrHubText"><b>Saved Places</b><span>Home, relaxation, errands, and other places.</span></span></button>
          <button type="button" class="lrHubCard" data-lr-setup="clients"><span class="lrHubIcon">${safeIcon("user", 20)}</span><span class="lrHubText"><b>Clients</b><span>Manage client initials, locations, and useful profile details.</span></span></button>
          <button type="button" class="lrHubCard" data-lr-setup="tasks"><span class="lrHubIcon">${safeIcon("check", 20)}</span><span class="lrHubText"><b>Personal Tasks</b><span>Tasks and reminders outside of scheduled sessions.</span></span></button>
          <button type="button" class="lrHubCard" data-lr-setup="connections"><span class="lrHubIcon">${icon("link", 20)}</span><span class="lrHubText"><b>Connections</b><span>Connect calendars and choose your navigation app.</span></span></button>
        </div>`;
      setup.insertBefore(hub, legacy);
      hub.querySelector('[data-lr-setup="places"]').onclick = () => window.showView?.("places");
      hub.querySelector('[data-lr-setup="clients"]').onclick = () => openSetupSection("clients");
      hub.querySelector('[data-lr-setup="tasks"]').onclick = () => window.showView?.("todos");
      hub.querySelector('[data-lr-setup="connections"]').onclick = () => openSetupSection("connections");
    }
    showSetupLauncher();
    return true;
  };

  const placeCategoryForType = type => {
    const value = String(type || "").trim().toLowerCase();
    if (value === "home") return "home";
    if (["relaxation", "park", "coffee", "gym", "library"].includes(value)) return "relaxation";
    if (["errand", "grocery"].includes(value)) return "errand";
    return "other";
  };

  let selectedPlaceCategory = "";
  const updatePlaceCategoryCounts = () => {
    const counts = { home: 0, relaxation: 0, errand: 0, other: 0 };
    try {
      if (typeof places !== "undefined" && Array.isArray(places)) places.forEach(place => counts[placeCategoryForType(place.type)]++);
    } catch (_) {}
    Object.entries(counts).forEach(([key, count]) => {
      const node = document.querySelector(`[data-lr-place-category="${key}"] .lrPlaceCategoryCount`);
      if (node) node.textContent = `${count} saved`;
    });
  };

  const applyPlaceFilter = category => {
    selectedPlaceCategory = category;
    document.querySelectorAll("[data-lr-place-category]").forEach(button => button.classList.toggle("active", button.dataset.lrPlaceCategory === category));
    const cards = Array.from(document.querySelectorAll("#placesList > .card"));
    cards.forEach(card => {
      const type = String(card.querySelector(".small")?.textContent || "").split("·")[0].trim();
      card.style.display = placeCategoryForType(type) === category ? "" : "none";
    });
    const canonical = { home: "Home", relaxation: "Relaxation", errand: "Errand", other: "Other" }[category];
    const typeSelect = document.getElementById("placeType");
    if (typeSelect && canonical) typeSelect.value = canonical;
  };

  const ensureSavedPlacesCategories = () => {
    const placesView = document.getElementById("places");
    if (!placesView) return false;
    const typeSelect = document.getElementById("placeType");
    if (typeSelect && !Array.from(typeSelect.options).some(option => option.value === "Relaxation")) {
      const option = document.createElement("option");
      option.value = "Relaxation";
      option.textContent = "Relaxation";
      const errand = Array.from(typeSelect.options).find(item => item.value === "Errand");
      if (errand) typeSelect.insertBefore(option, errand);
      else typeSelect.appendChild(option);
    }
    if (!document.getElementById("lrSavedPlaceCategories")) {
      const hub = document.createElement("div");
      hub.id = "lrSavedPlaceCategories";
      hub.className = "lrSavedPlaceCategories";
      hub.innerHTML = `
        <div class="lrHubTitle"><h2>Saved Places</h2><span class="tiny">Choose a category to view or add</span></div>
        <div class="lrHubGrid">
          <button type="button" class="lrHubCard" data-lr-place-category="home"><span class="lrHubIcon">${safeIcon("home", 20)}</span><span class="lrHubText"><b>Home</b><span>Your start and end-of-day location.</span><span class="lrPlaceCategoryCount">0 saved</span></span></button>
          <button type="button" class="lrHubCard" data-lr-place-category="relaxation"><span class="lrHubIcon">${icon("leaf", 20)}</span><span class="lrHubText"><b>Relaxation</b><span>Parks, quiet spots, cafés, gyms, and unwind places.</span><span class="lrPlaceCategoryCount">0 saved</span></span></button>
          <button type="button" class="lrHubCard" data-lr-place-category="errand"><span class="lrHubIcon">${safeIcon("cart", 20)}</span><span class="lrHubText"><b>Errand</b><span>Stores, pharmacies, groceries, and practical stops.</span><span class="lrPlaceCategoryCount">0 saved</span></span></button>
          <button type="button" class="lrHubCard" data-lr-place-category="other"><span class="lrHubIcon">${safeIcon("pin", 20)}</span><span class="lrHubText"><b>Other</b><span>Anything useful that does not fit the other categories.</span><span class="lrPlaceCategoryCount">0 saved</span></span></button>
        </div>`;
      const firstSection = placesView.querySelector(".section");
      placesView.insertBefore(hub, firstSection || placesView.firstChild);
      hub.querySelectorAll("[data-lr-place-category]").forEach(button => {
        button.onclick = () => {
          applyPlaceFilter(button.dataset.lrPlaceCategory);
          document.getElementById("placesList")?.scrollIntoView({ behavior: "smooth", block: "start" });
        };
      });
    }
    updatePlaceCategoryCounts();
    if (selectedPlaceCategory) applyPlaceFilter(selectedPlaceCategory);
    return true;
  };

  const observeDynamicContent = () => {
    const tabs = document.querySelector(".tabs");
    if (tabs && !window.__lrIANavObserver) {
      const observer = new MutationObserver(() => configureTopNavigation());
      observer.observe(tabs, { childList: true });
      window.__lrIANavObserver = observer;
    }
    const placesList = document.getElementById("placesList");
    if (placesList && !window.__lrIAPlacesObserver) {
      const observer = new MutationObserver(() => {
        updatePlaceCategoryCounts();
        if (selectedPlaceCategory) applyPlaceFilter(selectedPlaceCategory);
      });
      observer.observe(placesList, { childList: true });
      window.__lrIAPlacesObserver = observer;
    }
    const toolGrid = document.querySelector("#tools .toolGrid");
    if (toolGrid && !window.__lrIAToolsObserver) {
      const observer = new MutationObserver(() => classifyToolCards());
      observer.observe(toolGrid, { childList: true });
      window.__lrIAToolsObserver = observer;
    }
  };

  const reconcile = () => {
    configureTopNavigation();
    ensureSessionToolsHub();
    ensureSetupHub();
    ensureSavedPlacesCategories();
    installShowViewWrapper();
    observeDynamicContent();
  };

  const start = () => {
    reconcile();
    [80, 250, 700, 1400].forEach(delay => setTimeout(reconcile, delay));
  };

  window.LifeRouteInformationArchitectureV1 = { reconcile, showToolCategory, showSetupLauncher, applyPlaceFilter };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
