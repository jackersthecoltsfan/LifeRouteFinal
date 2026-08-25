// LifeRoute Day route experience: one clean Day timeline, one directions origin picker,
// and lightweight before/after stop slots. The persistent boundary planner owns
// stop discovery/search/save behavior so this file never duplicates that logic.
(() => {
  if (window.__lifeRouteDayRouteExperienceLoaded) return;
  window.__lifeRouteDayRouteExperienceLoaded = true;

  const clean = value => String(value || "").trim();
  const safe = value => typeof window.esc === "function"
    ? window.esc(String(value || ""))
    : String(value || "").replace(/[&<>"']/g, ch => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"})[ch]);
  const icon = (name, size = 15, cls = "") => typeof window.lifeRouteIcon === "function"
    ? window.lifeRouteIcon(name, size, cls)
    : "";

  const selectedDay = () => {
    if (clean(window.selectedDate)) return clean(window.selectedDate);
    try { return clean(selectedDate); } catch (_) { return ""; }
  };
  const prefsState = () => {
    if (window.prefs) return window.prefs;
    try { return prefs; } catch (_) { return {}; }
  };
  const placesState = () => {
    if (Array.isArray(window.places)) return window.places;
    try { return Array.isArray(places) ? places : []; } catch (_) { return []; }
  };
  const nativeStateValue = () => {
    if (window.nativeState) return window.nativeState;
    try { return nativeState; } catch (_) { return {}; }
  };
  const eventsForDay = () => typeof window.dayEvents === "function" ? window.dayEvents(selectedDay()) : [];
  const homeAddress = () => clean(prefsState()?.homeAddress) || clean(placesState().find(place => String(place?.type || "").toLowerCase() === "home")?.address);
  const todayKey = () => typeof window.localDateKey === "function" ? window.localDateKey(new Date()) : "";

  const clientCode = client => {
    const pair = value => {
      const letters = clean(value).replace(/[^a-z]/gi, "").slice(0, 2);
      return letters ? letters[0].toUpperCase() + letters.slice(1).toLowerCase() : "";
    };
    return `${pair(client?.first2)}${pair(client?.last2)}` || clean(client?.name) || "Client";
  };

  const clientOrigins = () => (Array.isArray(prefsState()?.clients) ? prefsState().clients : [])
    .filter(client => clean(client?.address))
    .map(client => ({ label: clientCode(client), address: clean(client.address), icon: "user" }));

  const transportFlag = () => {
    const mode = clean(prefsState()?.transportMode || "driving");
    return mode === "walking" ? "w" : mode === "transit" ? "r" : "d";
  };

  const selectedProvider = () => {
    let provider = clean(prefsState()?.mapProvider || "apple");
    if (provider === "ask") provider = window.confirm("OK = Google Maps\nCancel = Apple Maps") ? "google" : "apple";
    return provider === "google" ? "google" : "apple";
  };

  const launchDirections = (destination, origin = "") => {
    const dest = clean(destination);
    if (!dest) return;
    const start = clean(origin);
    const provider = selectedProvider();
    const mode = clean(prefsState()?.transportMode || "driving");

    try {
      if (typeof window.postNative === "function" && window.postNative({
        action: "openRoute",
        provider,
        origin: start || undefined,
        destination: dest
      })) return;
    } catch (_) {}

    if (provider === "google") {
      const params = new URLSearchParams({ api: "1", destination: dest, travelmode: mode });
      if (start) params.set("origin", start);
      window.location.href = `https://www.google.com/maps/dir/?${params.toString()}`;
      return;
    }

    const params = new URLSearchParams({ daddr: dest, dirflg: transportFlag() });
    if (start) params.set("saddr", start);
    window.location.href = `https://maps.apple.com/?${params.toString()}`;
  };

  const ensureOriginPicker = () => {
    let overlay = document.getElementById("lifeRouteOriginPicker");
    if (overlay) return overlay;
    overlay = document.createElement("div");
    overlay.id = "lifeRouteOriginPicker";
    overlay.className = "lrOriginOverlay";
    overlay.innerHTML = `
      <div class="lrOriginSheet" role="dialog" aria-modal="true" aria-labelledby="lrOriginTitle">
        <div class="lrOriginHandle"></div>
        <div class="small">START DIRECTIONS</div>
        <div class="title" id="lrOriginTitle">Choose a starting point</div>
        <div class="meta" id="lrOriginDestination"></div>
        <div class="lrOriginChoices" id="lrOriginChoices"></div>
        <button type="button" class="secondary lrOriginCancel">Cancel</button>
      </div>`;
    document.body.appendChild(overlay);
    overlay.querySelector(".lrOriginCancel").onclick = () => overlay.classList.remove("show");
    overlay.onclick = event => { if (event.target === overlay) overlay.classList.remove("show"); };
    return overlay;
  };

  window.lifeRouteChooseRouteOrigin = function lifeRouteChooseRouteOrigin(destination, options = {}) {
    const dest = clean(destination);
    if (!dest) return;
    const overlay = ensureOriginPicker();
    const meta = overlay.querySelector("#lrOriginDestination");
    if (meta) meta.textContent = `To ${clean(options.destinationLabel) || dest}`;
    const choices = overlay.querySelector("#lrOriginChoices");
    if (!choices) return;

    const items = [{ label: "Live location", address: "", icon: "navigation", note: "Use where you are now" }];
    const home = homeAddress();
    if (home) items.push({ label: "Home", address: home, icon: "home", note: home });
    clientOrigins().forEach(client => items.push({ ...client, note: client.address }));

    choices.innerHTML = items.map((item, index) => `
      <button type="button" class="lrOriginChoice ${index === 0 ? "primary" : "secondary"}" data-origin-index="${index}">
        <span class="lrOriginChoiceIcon">${icon(item.icon, 17)}</span>
        <span class="grow"><b>${safe(item.label)}</b><small>${safe(item.note || "")}</small></span>
        ${icon("navigation", 14)}
      </button>`).join("");
    choices.querySelectorAll("[data-origin-index]").forEach(button => {
      button.onclick = () => {
        const item = items[Number(button.dataset.originIndex)];
        overlay.classList.remove("show");
        launchDirections(dest, item?.address || "");
      };
    });
    overlay.classList.add("show");
  };

  window.routeTo = encoded => window.lifeRouteChooseRouteOrigin(decodeURIComponent(encoded || ""));
  window.openPlace = encoded => window.lifeRouteChooseRouteOrigin(decodeURIComponent(encoded || ""));
  window.lifeRouteLaunchDirections = launchDirections;

  const boundaryContext = mode => {
    const list = eventsForDay();
    if (!list.length) return null;
    if (mode === "before") {
      const live = nativeStateValue()?.currentLocation;
      const home = homeAddress();
      const origin = selectedDay() === todayKey() && live?.latitude != null && live?.longitude != null
        ? { label: "Live location" }
        : home ? { label: "Home" } : { label: "Your start" };
      return { origin, final: { label: clean(list[0]?.title) || "first appointment" } };
    }
    return {
      origin: { label: clean(list.at(-1)?.title) || "last appointment" },
      final: homeAddress() ? { label: "Home" } : null
    };
  };

  const boundaryCard = mode => {
    const before = mode === "before";
    const panelId = `boundaryGap-${mode}-${selectedDay()}`.replace(/[^a-zA-Z0-9_-]/g, "-");
    const card = document.createElement("div");
    card.className = `card lrBoundaryGap lrBoundaryGap-${mode}`;
    card.dataset.boundaryMode = mode;
    const context = boundaryContext(mode);
    const routeLabel = before
      ? `${context?.origin?.label || "Your start"} → stop → ${context?.final?.label || "first appointment"}`
      : `${context?.origin?.label || "Last appointment"} → stop${context?.final?.label ? ` → ${context.final.label}` : ""}`;
    card.innerHTML = `
      <div class="lrBoundarySummary">
        <div class="lrBoundarySummaryText">
          <div class="small">${before ? "BEFORE FIRST" : "AFTER LAST"}</div>
          <div class="title">${before ? "Stop on the way" : "Stop on the way home"}</div>
          <div class="meta">${safe(routeLabel)}</div>
        </div>
        <button type="button" class="secondary lrBoundaryOpen" data-lr-boundary-open="${mode}" aria-controls="${panelId}" aria-expanded="false">Find a stop</button>
      </div>
      <div class="gapSuggest lrBoundaryPanel" id="${panelId}" style="display:none"></div>`;

    // Direct fallback keeps the button usable even if a later enhancement script
    // is still loading. The persistent planner's capture handler takes ownership
    // once available and prevents this fallback from firing twice.
    card.querySelector(".lrBoundaryOpen").onclick = event => {
      event.preventDefault();
      event.stopPropagation();
      if (typeof window.lifeRouteOpenBoundaryPlanner === "function") {
        window.lifeRouteOpenBoundaryPlanner(mode, panelId, event.currentTarget);
      }
    };
    card.onclick = event => {
      if (event.target.closest("button,a,input,select")) return;
      if (typeof window.lifeRouteOpenBoundaryPlanner === "function") {
        window.lifeRouteOpenBoundaryPlanner(mode, panelId, card.querySelector(".lrBoundaryOpen"));
      }
    };
    return card;
  };

  const renderBoundaryCards = () => {
    const timeline = document.getElementById("timeline");
    const list = eventsForDay();
    if (!timeline || !list.length) return;
    timeline.querySelectorAll(".lrBoundaryGap").forEach(node => node.remove());
    timeline.prepend(boundaryCard("before"));
    timeline.appendChild(boundaryCard("after"));
    requestAnimationFrame(() => window.decorateLifeRouteBoundaryStops?.());
  };
  window.renderLifeRouteBoundaryCards = renderBoundaryCards;

  const simplifyDay = () => {
    const today = document.getElementById("today");
    if (!today) return;
    today.classList.add("lrSimpleDay");
    const heroP = today.querySelector(".hero > p");
    if (heroP) heroP.textContent = "Your appointments, travel, and useful stops in one route.";
    const labels = today.querySelectorAll(".metrics .metric span");
    if (labels[0]) labels[0].textContent = "scheduled";
    if (labels[1]) labels[1].textContent = "travel";
    if (labels[2]) labels[2].textContent = "open between";
  };

  const wrapRenderToday = () => {
    const previous = window.renderToday;
    if (typeof previous !== "function" || previous.__dayRouteExperienceWrapped) return false;
    const wrapped = function renderTodayWithBoundaryStops(...args) {
      const value = previous.apply(this, args);
      simplifyDay();
      renderBoundaryCards();
      return value;
    };
    wrapped.__dayRouteExperienceWrapped = true;
    window.renderToday = wrapped;
    return true;
  };

  const style = document.createElement("style");
  style.id = "lifeRouteDayRouteExperienceStyles";
  style.textContent = `
    #today.lrSimpleDay .hero{padding:12px 14px!important;margin-bottom:9px!important}#today.lrSimpleDay .hero h2{font-size:17px!important;margin-bottom:2px!important}#today.lrSimpleDay .hero p{font-size:10.5px!important;opacity:.86}
    #today.lrSimpleDay .metrics{grid-template-columns:repeat(3,1fr)!important;gap:6px!important}#today.lrSimpleDay .metrics .metric{padding:9px 10px!important;border-radius:14px!important}#today.lrSimpleDay .metrics .metric b{font-size:16px!important}#today.lrSimpleDay .metrics .metric:nth-child(4){display:none!important}
    #today.lrSimpleDay .section{margin-top:12px!important}#today.lrSimpleDay .sectionHead{margin-bottom:6px!important}#today.lrSimpleDay #timeline>.card{margin-bottom:7px!important}
    .lrBoundaryGap{border-style:solid!important;border-color:color-mix(in srgb,var(--gold) 22%,var(--line))!important;background:color-mix(in srgb,var(--panel) 88%,transparent)!important}.lrBoundarySummary{display:flex;align-items:center;gap:10px}.lrBoundarySummaryText{flex:1;min-width:0}.lrBoundaryGap .small{font-size:8px!important;font-weight:900;color:var(--gold);letter-spacing:.08em}.lrBoundaryGap .title{font-size:13.5px!important}.lrBoundaryGap .meta{font-size:9.5px!important}.lrBoundaryOpen{flex:0 0 auto;white-space:nowrap;font-size:9.5px!important;padding:7px 10px!important;min-height:35px!important}
    .lrOriginOverlay{position:fixed;inset:0;z-index:35000;display:none;align-items:flex-end;justify-content:center;padding:12px;background:rgba(2,7,14,.68);backdrop-filter:blur(14px);-webkit-backdrop-filter:blur(14px)}.lrOriginOverlay.show{display:flex}.lrOriginSheet{width:min(620px,100%);max-height:82vh;overflow:auto;padding:17px;border-radius:24px 24px 18px 18px;background:color-mix(in srgb,var(--panel) 96%,#07111f);border:1px solid var(--line);box-shadow:0 30px 90px rgba(0,0,0,.45)}.lrOriginHandle{width:40px;height:4px;border-radius:99px;background:var(--line);margin:0 auto 12px}.lrOriginChoices{display:grid;gap:6px;margin:12px 0}.lrOriginChoice{width:100%;display:flex!important;align-items:center!important;gap:9px!important;text-align:left!important;padding:10px 11px!important}.lrOriginChoice b{display:block;font-size:11.5px}.lrOriginChoice small{display:block;margin-top:2px;color:var(--muted);font-size:8.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.lrOriginChoiceIcon{width:24px;display:grid;place-items:center}.lrOriginCancel{width:100%}
    @media(max-width:520px){#today.lrSimpleDay .metrics .metric{padding:8px 7px!important}#today.lrSimpleDay .metrics .metric b{font-size:15px!important}.lrBoundarySummary{align-items:flex-start}.lrBoundaryOpen{margin-top:1px}}
  `;
  document.head.appendChild(style);

  const start = () => {
    simplifyDay();
    wrapRenderToday();
    renderBoundaryCards();
    [250, 700, 1500].forEach(delay => setTimeout(() => {
      wrapRenderToday();
      simplifyDay();
      renderBoundaryCards();
    }, delay));
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(start, 80), { once: true });
  else setTimeout(start, 80);
})();