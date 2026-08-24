// LifeRoute grocery/store preferences + route-aware branch chooser.
// Store brands are saved with a to-do. When a gap option is tapped, LifeRoute
// uses native Apple MapKit local search + route times to compare nearby branches.
(() => {
  const initStorePreferences = () => {
  const TODO_STORE = "liferoute_todos_v1";
  const STORE_BRANDS = [
    "Walmart",
    "GIANT Food Stores",
    "BJ's Wholesale Club",
    "Target",
    "ALDI",
    "Wegmans",
    "ShopRite",
    "Costco",
    "Whole Foods Market",
    "Trader Joe's"
  ];
  const storeRequests = new Map();
  let storeRequestCounter = 0;

  const style = document.createElement("style");
  style.textContent = `
    .storePrefBox{margin-top:5px;padding:11px;border:1px solid var(--line);border-radius:14px;background:color-mix(in srgb,var(--panel2) 82%,transparent)}
    .storePrefIntro{margin-bottom:8px}.storePrefGrid{display:flex;gap:7px;flex-wrap:wrap}
    .storePrefChip{display:inline-flex;align-items:center;gap:6px;padding:8px 10px;border:1px solid var(--line);border-radius:999px;background:var(--panel);color:var(--muted);font-size:11px;font-weight:850;cursor:pointer}
    .storePrefChip input{width:auto;margin:0;accent-color:var(--gold)}
    .storePrefChip:has(input:checked){border-color:rgba(242,200,109,.65);color:var(--text);box-shadow:inset 0 0 0 1px rgba(242,200,109,.12)}
    .storePrefCustom{margin-top:8px}
    .storePreferenceSummary{margin-top:5px;color:var(--gold);font-size:10px;font-weight:800}
    .gapOption.storeSelectable{cursor:pointer}.gapOption.storeSelectable:active{transform:scale(.995)}
    .storeChooser{margin-top:10px;padding-top:10px;border-top:1px solid var(--line)}
    .storeChooserHead{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:7px}
    .storeOption{padding:10px;margin-top:7px;border:1px solid var(--line);border-radius:13px;background:color-mix(in srgb,var(--panel) 70%,var(--panel2))}
    .storeOption.best{border-color:rgba(242,200,109,.58);box-shadow:inset 0 0 0 1px rgba(242,200,109,.12)}
    .storeOption .fit{color:var(--green);font-weight:900}.storeOption .miss{color:var(--red);font-weight:900}.storeOption .unknown{color:var(--gold);font-weight:900}
    .storeOptionButtons{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}.storeOptionButtons button{font-size:10px;padding:7px 9px}
  `;
  document.head.appendChild(style);

  const saveTodos = () => {
    localStorage.setItem(TODO_STORE, JSON.stringify(window.lifeRouteTodos || []));
  };

  const getTodo = id => (window.lifeRouteTodos || []).find(todo => String(todo.id) === String(id));
  const cleanPreferences = values => Array.from(new Set((values || []).map(value => String(value || "").trim()).filter(Boolean)));
  const storeSummary = todo => cleanPreferences(todo?.storePreferences).map(name => name.replace(" Food Stores", "").replace(" Wholesale Club", "")).join(" · ");

  const injectStorePreferenceControls = () => {
    const addressInput = document.getElementById("todoAddress");
    const form = addressInput?.closest(".formgrid");
    if (!form || document.getElementById("todoStorePreferences")) return;

    const wrapper = document.createElement("div");
    wrapper.className = "full storePrefBox";
    wrapper.id = "todoStorePreferences";
    wrapper.innerHTML = `
      <div class="storePrefIntro">
        <label style="margin-bottom:3px">Store preferences (optional)</label>
        <div class="tiny">For groceries or shopping, choose any chains you like. Leave the location field blank and LifeRoute will compare nearby branches for each gap.</div>
      </div>
      <div class="storePrefGrid">
        ${STORE_BRANDS.map((brand, index) => `<label class="storePrefChip"><input type="checkbox" data-store-pref value="${esc(brand)}" id="storePref-${index}">${esc(brand.replace(" Food Stores", "").replace(" Wholesale Club", ""))}</label>`).join("")}
      </div>
      <div class="storePrefCustom"><input id="todoCustomStores" placeholder="Other store chains, comma separated"></div>
    `;

    const addressGroup = addressInput.parentElement;
    addressGroup?.after(wrapper);
  };

  const selectedStorePreferences = () => {
    const checked = Array.from(document.querySelectorAll("[data-store-pref]:checked")).map(input => input.value);
    const custom = String(document.getElementById("todoCustomStores")?.value || "")
      .split(",")
      .map(value => value.trim())
      .filter(Boolean);
    return cleanPreferences(checked.concat(custom));
  };

  const clearStorePreferenceControls = () => {
    document.querySelectorAll("[data-store-pref]").forEach(input => { input.checked = false; });
    const custom = document.getElementById("todoCustomStores");
    if (custom) custom.value = "";
  };

  injectStorePreferenceControls();

  const originalAddTodo = window.addLifeRouteTodo;
  if (typeof originalAddTodo === "function") {
    window.addLifeRouteTodo = function addLifeRouteTodoWithStorePreferences() {
      const before = (window.lifeRouteTodos || []).length;
      const preferences = selectedStorePreferences();
      const title = String(document.getElementById("todoTitle")?.value || "").trim();
      originalAddTodo();
      const list = window.lifeRouteTodos || [];
      if (list.length <= before) return;

      const todo = list[list.length - 1];
      if (preferences.length) {
        todo.storePreferences = preferences;
        todo.locationMode = "store-preferences";
        todo.address = "";
        if (/\b(grocer(?:y|ies)|food shopping)\b/i.test(title) && todo.category === "Errand") {
          todo.category = "Shopping";
        }
        saveTodos();
        clearStorePreferenceControls();
        if (typeof window.renderTodos === "function") window.renderTodos();
        if (typeof window.renderToday === "function") window.renderToday();
        setStatus(`To-do added · ${preferences.length} store preference${preferences.length === 1 ? "" : "s"}`);
      }
    };
  }

  const todoIDFromCard = card => {
    const action = Array.from(card.querySelectorAll("button[onclick]")).find(button =>
      /(?:complete|delete)LifeRouteTodo\('/.test(button.getAttribute("onclick") || "")
    );
    const match = (action?.getAttribute("onclick") || "").match(/(?:complete|delete)LifeRouteTodo\('([^']+)'\)/);
    return match?.[1] || "";
  };

  const decorateTodoCards = () => {
    const openTodos = (window.lifeRouteTodos || []).filter(todo => !todo.completed);
    const routeReady = openTodos.filter(todo => String(todo.address || "").trim() || cleanPreferences(todo.storePreferences).length).length;
    const locatedCount = document.getElementById("todoLocatedCount");
    if (locatedCount) locatedCount.textContent = String(routeReady);

    document.querySelectorAll("#todoList .todoCard").forEach(card => {
      const todo = getTodo(todoIDFromCard(card));
      if (!todo || !cleanPreferences(todo.storePreferences).length) return;
      const meta = card.querySelector(".meta");
      if (meta) meta.textContent = `Any ${storeSummary(todo)} · branch chosen by route`;
      if (!card.querySelector(".storePreferenceSummary")) {
        const title = card.querySelector(".title");
        const line = document.createElement("div");
        line.className = "storePreferenceSummary";
        line.textContent = "🛒 Compare nearby branches inside a schedule gap";
        title?.after(line);
      }
    });
  };

  const originalRenderTodos = window.renderTodos;
  if (typeof originalRenderTodos === "function") {
    window.renderTodos = function renderTodosWithStores(...args) {
      const result = originalRenderTodos.apply(this, args);
      decorateTodoCards();
      return result;
    };
  }

  const parseGapPanel = panelID => {
    const match = String(panelID || "").match(/^gapTodo-(\d{4}-\d{2}-\d{2})-(\d+)$/);
    if (!match) return null;
    return { dateKey: match[1], gapIndex: Number(match[2]) };
  };

  const safeID = value => String(value || "").replace(/[^a-zA-Z0-9_-]/g, "-");
  const departureISO = (dateKey, time, addMinutes = 0) => {
    const date = new Date(`${dateKey}T${time || "12:00"}:00`);
    if (Number.isNaN(date.getTime())) return null;
    date.setMinutes(date.getMinutes() + Number(addMinutes || 0));
    return date.toISOString();
  };

  const chooserFor = (panel, todoID) => {
    let chooser = panel.querySelector(`#storeChooser-${safeID(todoID)}`);
    if (!chooser) {
      chooser = document.createElement("div");
      chooser.className = "storeChooser";
      chooser.id = `storeChooser-${safeID(todoID)}`;
      const target = Array.from(panel.querySelectorAll(".gapOption")).find(option => todoIDFromCard(option) === String(todoID));
      (target || panel).appendChild(chooser);
    }
    return chooser;
  };

  window.openLifeRouteStoreOptions = function openLifeRouteStoreOptions(todoID, panelID) {
    const todo = getTodo(todoID);
    const prefs = cleanPreferences(todo?.storePreferences);
    const parsed = parseGapPanel(panelID);
    const panel = document.getElementById(panelID);
    if (!todo || !prefs.length || !parsed || !panel) return;

    const list = dayEvents(parsed.dateKey);
    const previous = list[parsed.gapIndex];
    const next = list[parsed.gapIndex + 1];
    const chooser = chooserFor(panel, todoID);
    if (!previous || !next || !String(previous.address || "").trim() || !String(next.address || "").trim()) {
      chooser.innerHTML = '<div class="storeChooserHead"><b>Store routes unavailable</b></div><div class="tiny">Both neighboring calendar events need locations before LifeRoute can compare store detours.</div>';
      return;
    }

    storeRequestCounter += 1;
    const requestID = `stores-${storeRequestCounter}-${Date.now()}`;
    storeRequests.set(requestID, {
      requestID,
      todoID: String(todoID),
      panelID,
      dateKey: parsed.dateKey,
      gapIndex: parsed.gapIndex,
      previous,
      next,
      rawGap: Math.max(0, mins(next.start) - mins(previous.end)),
      locations: [],
      routeResults: new Map()
    });

    chooser.innerHTML = `<div class="storeChooserHead"><b>Finding nearby stores…</b><span class="tiny">${esc(storeSummary(todo))}</span></div><div class="tiny">Searching around this part of your route, then comparing the detour to your next event.</div>`;
    setStatus("Finding grocery/store options…");

    if (!postNative({
      action: "searchStoreLocations",
      requestID,
      queries: prefs,
      nearAddresses: [previous.address, next.address],
      limitPerQuery: 4
    })) {
      chooser.innerHTML = '<div class="storeChooserHead"><b>Store search needs the iPhone build</b></div><div class="tiny">Nearby-branch search uses Apple MapKit inside LifeRoute.</div>';
    }
  };

  const renderStoreOptions = request => {
    const todo = getTodo(request.todoID);
    const panel = document.getElementById(request.panelID);
    if (!todo || !panel) return;
    const chooser = chooserFor(panel, request.todoID);

    const candidates = request.locations.map(location => {
      const out = request.routeResults.get(`${location.id}|out`);
      const back = request.routeResults.get(`${location.id}|back`);
      const routeComplete = !!out?.minutes && !!back?.minutes;
      const drive = Number(out?.minutes || 0) + Number(back?.minutes || 0);
      const duration = Number(todo.duration || 30);
      const required = drive + duration;
      const slack = request.rawGap - required;
      const fit = routeComplete && slack >= 0;
      const distanceMeters = Number(out?.distanceMeters || 0) + Number(back?.distanceMeters || 0);
      const brandOrder = cleanPreferences(todo.storePreferences).findIndex(pref => pref === location.brand);
      let score = fit ? 10000 : -Math.abs(Math.min(0, slack)) * 20;
      score -= drive * 4;
      score -= Math.max(0, brandOrder) * 8;
      if (!routeComplete) score -= 5000;
      return { location, out, back, routeComplete, drive, duration, required, slack, fit, distanceMeters, score };
    }).sort((a, b) => b.score - a.score);

    if (!candidates.length) {
      chooser.innerHTML = '<div class="storeChooserHead"><b>No nearby branches found</b></div><div class="tiny">Try adding another store chain to this to-do.</div>';
      return;
    }

    chooser.innerHTML = `<div class="storeChooserHead"><b>Best nearby store routes</b><span class="tiny">${candidates.length} option${candidates.length === 1 ? "" : "s"}</span></div>` + candidates.slice(0, 10).map((item, index) => {
      let status;
      if (!item.routeComplete) status = '<span class="unknown">Route unavailable</span>';
      else if (item.fit) status = `<span class="fit">Fits · ${fmt(item.slack)} left</span>`;
      else status = `<span class="miss">Needs ${fmt(Math.abs(item.slack))} more</span>`;
      const miles = item.distanceMeters > 0 ? `${(item.distanceMeters / 1609.344).toFixed(item.distanceMeters < 16093 ? 1 : 0)} mi driving · ` : "";
      const routeLine = item.routeComplete
        ? `${fmt(item.out.minutes)} there + ${fmt(item.duration)} shopping + ${fmt(item.back.minutes)} to next`
        : "Could not calculate both route legs";
      return `<div class="storeOption ${index === 0 && item.fit ? "best" : ""}">
        <div class="row"><div class="grow"><div class="small">${index === 0 && item.fit ? "★ BEST ROUTE · " : ""}${esc(item.location.brand || "Store")}</div><div class="title">${esc(item.location.name || item.location.brand || "Store")}</div><div class="meta">${esc(item.location.address || "Address unavailable")}</div></div><div>${status}</div></div>
        <div class="tiny" style="margin-top:6px">${miles}${routeLine}</div>
        <div class="storeOptionButtons"><button class="secondary" onclick="event.stopPropagation();routeTo('${encodeURIComponent(item.location.address || item.location.name || item.location.brand)}')">Route here</button></div>
      </div>`;
    }).join("");
    setStatus("Store routes ready");
  };

  const handleStoreLocations = evt => {
    const request = storeRequests.get(String(evt.requestID || ""));
    if (!request) return;
    request.locations = (Array.isArray(evt.locations) ? evt.locations : []).slice(0, 18).map((location, index) => ({
      ...location,
      id: `${request.requestID}|loc-${index}`
    }));

    const panel = document.getElementById(request.panelID);
    const chooser = panel ? chooserFor(panel, request.todoID) : null;
    if (!request.locations.length) {
      if (chooser) chooser.innerHTML = '<div class="storeChooserHead"><b>No nearby branches found</b></div><div class="tiny">Try another store preference or check the neighboring event locations.</div>';
      return;
    }

    const segments = [];
    request.locations.forEach(location => {
      segments.push({
        id: `${location.id}|out`,
        date: request.dateKey,
        origin: request.previous.address,
        destination: location.address || location.name || location.brand,
        destinationLatitude: location.latitude,
        destinationLongitude: location.longitude,
        departure: departureISO(request.dateKey, request.previous.end, 0)
      });
      segments.push({
        id: `${location.id}|back`,
        date: request.dateKey,
        origin: location.address || location.name || location.brand,
        originLatitude: location.latitude,
        originLongitude: location.longitude,
        destination: request.next.address,
        departure: departureISO(request.dateKey, request.previous.end, Number(getTodo(request.todoID)?.duration || 30) + 15)
      });
    });

    if (chooser) chooser.innerHTML = `<div class="storeChooserHead"><b>Comparing ${request.locations.length} nearby branches…</b><span class="tiny">route times</span></div><div class="tiny">Calculating previous event → store → next event.</div>`;
    if (!postNative({ action: "requestRouteTimes", segments })) renderStoreOptions(request);
  };

  const handleStoreRouteTimes = evt => {
    const results = Array.isArray(evt.results) ? evt.results : [];
    if (!results.length) return;
    const request = Array.from(storeRequests.values()).find(candidate =>
      results.some(result => String(result.id || "").startsWith(`${candidate.requestID}|`))
    );
    if (!request) return;

    results.forEach(result => {
      const id = String(result.id || "");
      if (!id.startsWith(`${request.requestID}|`)) return;
      request.routeResults.set(id, result);
    });
    renderStoreOptions(request);
  };

  const previousNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithStoreSearch(evt) {
    if (typeof previousNativeEvent === "function") previousNativeEvent(evt);
    if (!evt || !evt.type) return;
    if (evt.type === "storeLocations") handleStoreLocations(evt);
    if (evt.type === "routeTimes") handleStoreRouteTimes(evt);
  };

  const decorateGapOptions = () => {
    document.querySelectorAll(".gapSuggest .gapOption").forEach(option => {
      const todoID = todoIDFromCard(option);
      const todo = getTodo(todoID);
      if (!todo || !cleanPreferences(todo.storePreferences).length) return;
      const panel = option.closest(".gapSuggest");
      if (!panel) return;

      option.classList.add("storeSelectable");
      const meta = option.querySelector(".meta");
      if (meta) meta.textContent = `Any ${storeSummary(todo)} · tap to compare branches`;

      const row = option.querySelector(":scope > .row");
      if (row?.children?.[1]) row.children[1].innerHTML = '<span class="unknown">Choose store route</span>';
      const tiny = option.querySelector(":scope > .tiny");
      if (tiny) tiny.textContent = `${fmt(todo.duration || 30)} shopping · exact drive time depends on the branch you choose`;

      const buttons = option.querySelector(".gapOptionButtons");
      if (buttons && !buttons.querySelector(".storeCompareButton")) {
        const button = document.createElement("button");
        button.className = "secondary storeCompareButton";
        button.textContent = "Compare stores";
        button.onclick = event => {
          event.stopPropagation();
          openLifeRouteStoreOptions(todo.id, panel.id);
        };
        buttons.insertBefore(button, buttons.firstChild);
      }

      if (!option.dataset.storeClickReady) {
        option.dataset.storeClickReady = "1";
        option.addEventListener("click", event => {
          if (event.target.closest("button,input,a")) return;
          openLifeRouteStoreOptions(todo.id, panel.id);
        });
      }
    });
  };

  const observer = new MutationObserver(() => {
    decorateTodoCards();
    decorateGapOptions();
  });
  observer.observe(document.body, { childList: true, subtree: true });

  decorateTodoCards();
  decorateGapOptions();
  };

  if (document.readyState === "loading") {
    window.addEventListener("DOMContentLoaded", () => setTimeout(initStorePreferences, 0));
  } else {
    setTimeout(initStorePreferences, 0);
  }
})();
