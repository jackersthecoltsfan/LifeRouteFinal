// Web-preview optional final route leg: last appointment -> Home.
(() => {
  if (window.__lifeRouteEndHomeRouteLoaded) return;
  window.__lifeRouteEndHomeRouteLoaded = true;

  const PREF_KEY = "endDayAtHome";

  const homeAddress = () => String(window.prefs?.homeAddress || "").trim() ||
    String((window.places || []).find(place => String(place?.type || "").toLowerCase() === "home")?.address || "").trim();

  const enabled = () => !!window.prefs?.[PREF_KEY];
  const selectedKey = () => String(window.selectedDate || "");
  const listForDay = () => typeof window.dayEvents === "function" ? window.dayEvents(selectedKey()) : [];
  const lastEvent = () => {
    const list = listForDay();
    return list.length ? list[list.length - 1] : null;
  };

  const provider = () => String(window.prefs?.mapProvider || "apple");
  const openRoute = (origin, destination) => {
    let chosen = provider();
    if (chosen === "ask") chosen = confirm("OK = Google Maps\nCancel = Apple Maps") ? "google" : "apple";
    const url = chosen === "google"
      ? `https://www.google.com/maps/dir/?api=1&origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&travelmode=driving`
      : `https://maps.apple.com/?saddr=${encodeURIComponent(origin)}&daddr=${encodeURIComponent(destination)}&dirflg=d`;
    window.location.href = url;
  };

  const persistPref = value => {
    if (!window.prefs) return;
    window.prefs[PREF_KEY] = !!value;
    try { window.persist?.(); } catch (_) {}
  };

  const ensureStyles = () => {
    if (document.getElementById("endHomeRouteStyles")) return;
    const style = document.createElement("style");
    style.id = "endHomeRouteStyles";
    style.textContent = `
      .endHomeOption{margin-top:12px;padding:11px 12px;border-radius:15px;background:color-mix(in srgb,var(--panel2) 78%,transparent);border:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;gap:12px}.endHomeOption .title{font-size:12px}.endHomeOption .meta{font-size:9px;margin-top:2px}.endHomeRouteCard{border-color:color-mix(in srgb,var(--gold) 45%,var(--line))!important}.endHomeRouteCard .route{margin-top:8px}.endHomeLiveRow{border-top:1px solid var(--line);margin-top:7px;padding-top:11px}.endHomeRouteButton{white-space:nowrap}
    `;
    document.head.appendChild(style);
  };

  const ensureToggle = () => {
    ensureStyles();
    const hero = document.querySelector("#today .hero");
    if (!hero) return;
    let host = document.getElementById("endHomeOption");
    if (!host) {
      host = document.createElement("div");
      host.id = "endHomeOption";
      host.className = "endHomeOption";
      host.innerHTML = `
        <div class="grow"><div class="title">End day at Home</div><div class="meta" id="endHomeOptionMeta">Add the drive from your last appointment back home.</div></div>
        <label class="switch"><input id="endHomeToggle" type="checkbox"><span class="slider"></span></label>`;
      hero.appendChild(host);
      host.querySelector("#endHomeToggle")?.addEventListener("change", event => {
        persistPref(event.target.checked);
        render();
      });
    }
    const toggle = host.querySelector("#endHomeToggle");
    if (toggle) toggle.checked = enabled();
    const meta = host.querySelector("#endHomeOptionMeta");
    const home = homeAddress();
    if (meta) meta.textContent = home
      ? "Add last appointment → Home as the final route leg."
      : "Add a Home Address in Setup before enabling this route leg.";
  };

  const removeExisting = () => {
    document.getElementById("endHomeRouteCard")?.remove();
    document.getElementById("endHomeLiveRow")?.remove();
  };

  const renderTimelineLeg = (last, home) => {
    const timeline = document.getElementById("timeline");
    if (!timeline || !last) return;
    const card = document.createElement("div");
    card.id = "endHomeRouteCard";
    card.className = "card endHomeRouteCard";
    card.innerHTML = `
      <div class="row"><div class="grow"><div class="small">After ${window.time12 ? window.time12(last.end) : last.end || "last appointment"}</div><div class="title">Return Home</div><div class="meta"></div></div><span class="badge gold">FINAL LEG</span></div>
      <div class="route"><span>🚙 ${last.address ? "From " + String(last.title || "last appointment") : "From last appointment"} · exact drive time opens in Maps</span><button type="button" class="secondary endHomeRouteButton">Route home</button></div>`;
    card.querySelector(".meta").textContent = home;
    card.querySelector(".endHomeRouteButton")?.addEventListener("click", () => {
      if (!last.address) return alert("The last appointment needs a location before LifeRoute can route home from it.");
      openRoute(last.address, home);
    });
    timeline.appendChild(card);
  };

  const renderLiveLeg = (last, home) => {
    const sequence = document.querySelector("#liveDayPanel.show .liveDaySequence");
    if (!sequence || !last) return;
    const row = document.createElement("div");
    row.id = "endHomeLiveRow";
    row.className = "liveDayRow event endHomeLiveRow";
    row.innerHTML = `
      <div class="liveDayTime">${window.time12 ? window.time12(last.end) : String(last.end || "")}</div>
      <div class="liveDayRail"><span></span></div>
      <div class="grow"><div class="small">FINAL ROUTE LEG</div><div class="title">Return Home</div><div class="meta"></div><div class="tiny">Drive from ${String(last.title || "last appointment")} to Home. Exact travel time is calculated when opened in Maps.</div><div class="placeActions"><button type="button" class="secondary endHomeRouteButton">Route home</button></div></div>`;
    row.querySelector(".meta").textContent = home;
    row.querySelector(".endHomeRouteButton")?.addEventListener("click", () => {
      if (!last.address) return alert("The last appointment needs a location before LifeRoute can route home from it.");
      openRoute(last.address, home);
    });
    sequence.appendChild(row);
  };

  const render = () => {
    ensureToggle();
    removeExisting();
    if (!enabled()) return;
    const home = homeAddress();
    const last = lastEvent();
    if (!home || !last) return;
    renderTimelineLeg(last, home);
    renderLiveLeg(last, home);
  };

  const wrap = (name, delay = 0) => {
    const fn = window[name];
    if (typeof fn !== "function" || fn.__endHomeWrapped) return;
    const wrapped = function(...args) {
      const result = fn.apply(this, args);
      setTimeout(render, delay);
      return result;
    };
    wrapped.__endHomeWrapped = true;
    window[name] = wrapped;
  };

  const install = () => {
    wrap("renderToday", 0);
    wrap("generateLifeRouteDay", 40);
    wrap("endLifeRouteDay", 20);
    render();
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(install, 250), { once: true });
  else setTimeout(install, 250);
  [600, 1200, 2400].forEach(delay => setTimeout(install, delay));
})();