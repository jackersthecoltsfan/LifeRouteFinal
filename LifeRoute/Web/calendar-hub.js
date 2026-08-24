// LifeRoute calendar hub, read-only calendar feeds, smart manual appointments, navigation, and dramatic themes.
(() => {
  const CALENDAR_VIEWS = ["today", "week", "month"];
  const CALENDAR_LABELS = { today: "Day", week: "Week", month: "Month" };
  const FEED_SOURCE = "calendarlink";
  const FEED_KEY = "liferoute_readonly_calendar_links_v1";
  const THEME_OPTIONS = [
    ["solar-flare", "Solar Flare"],
    ["electric-storm", "Electric Storm"],
    ["ultraviolet", "Ultraviolet"],
    ["molten-gold", "Molten Gold"],
    ["arctic-pulse", "Arctic Pulse"],
    ["emerald-tempest", "Emerald Tempest"],
    ["rose-nebula", "Rose Nebula"],
    ["royal-cosmos", "Royal Cosmos"],
    ["sapphire-tide", "Sapphire Tide"],
    ["phantom-silver", "Phantom Silver"]
  ];

  const htmlEscape = value => String(value ?? "").replace(/[&<>"']/g, char => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;"
  })[char]);

  const normalizePair = value => {
    const letters = String(value || "").replace(/[^a-z]/gi, "").slice(0, 2);
    return letters ? letters.charAt(0).toUpperCase() + letters.slice(1).toLowerCase() : "";
  };

  const codeForClient = client => `${normalizePair(client?.first2)}${normalizePair(client?.last2)}`;
  const clientForTitle = title => {
    const raw = String(title || "").trim().toLowerCase();
    if (!raw || !Array.isArray(window.prefs?.clients)) return null;
    return prefs.clients.find(client => {
      const code = codeForClient(client).toLowerCase();
      return code.length === 4 && (
        raw === code ||
        new RegExp(`(^|[^a-z0-9])${code.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}([^a-z0-9]|$)`, "i").test(raw)
      );
    }) || null;
  };

  const installStyles = () => {
    if (document.getElementById("calendarHubStyles")) return;
    const style = document.createElement("style");
    style.id = "calendarHubStyles";
    style.textContent = `
      .tabs{grid-template-columns:repeat(3,1fr)!important}
      .calendarLegacyTab{display:none!important}
      .calendarHubNav{display:none;gap:7px;padding:5px;margin:0 0 16px;border:1px solid var(--line);border-radius:16px;background:color-mix(in srgb,var(--panel) 84%,transparent);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px)}
      .calendarHubNav.show{display:flex}.calendarHubNav button{flex:1;min-height:38px;border:0;border-radius:12px;background:transparent;color:var(--muted);font-size:12px;font-weight:900}.calendarHubNav button.active{background:var(--panel2);color:var(--text);box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 48%,var(--line)),0 8px 24px rgba(0,0,0,.12)}
      .lrBackRow{position:sticky;top:calc(5px + env(safe-area-inset-top));z-index:70;display:flex;align-items:center;margin:10px 0 -6px;pointer-events:none}.lrBackButton{pointer-events:auto;display:inline-flex;align-items:center;gap:7px;min-height:38px;padding:8px 12px;border-radius:999px!important;background:color-mix(in srgb,var(--panel) 91%,transparent)!important;color:var(--text)!important;border:1px solid var(--line)!important;box-shadow:0 10px 28px rgba(0,0,0,.18);backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);font-size:11px!important}.lrBackButton.isHome{opacity:.5}
      html[data-web-preview="true"] .lrBackRow{top:92px}
      .calendarLinkCard{overflow:hidden}.calendarLinkActions{display:flex;gap:7px;flex-wrap:wrap;margin-top:10px}.calendarLinkActions button{font-size:11px;padding:8px 10px}.calendarLinkList{display:grid;gap:8px;margin-top:11px}.calendarLinkItem{display:grid;grid-template-columns:1fr auto;gap:8px;align-items:center;padding:10px;border-radius:13px;background:var(--panel2);border:1px solid var(--line)}.calendarLinkURL{font-size:9px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%}.calendarHelp{margin-top:10px;padding:11px;border-radius:13px;background:color-mix(in srgb,var(--blue) 6%,var(--panel2));border:1px solid color-mix(in srgb,var(--blue) 22%,var(--line));font-size:10px;line-height:1.5;color:var(--muted)}.calendarHelp b{color:var(--text)}.feedStatus{margin-top:8px;font-size:10px;color:var(--muted)}
      .manualAutoStatus{grid-column:1/-1;min-height:16px;margin-top:-1px;font-size:9.5px;color:var(--muted)}.manualAutoStatus.ready{color:var(--green)}.manualAutoStatus.loading{color:var(--gold)}
      #lifeRouteThemeFX{display:none;position:fixed;inset:0;z-index:1;pointer-events:none;overflow:hidden;mix-blend-mode:screen}
      html[data-theme="solar-flare"] #lifeRouteThemeFX,html[data-theme="electric-storm"] #lifeRouteThemeFX,html[data-theme="ultraviolet"] #lifeRouteThemeFX,html[data-theme="molten-gold"] #lifeRouteThemeFX,html[data-theme="arctic-pulse"] #lifeRouteThemeFX,html[data-theme="emerald-tempest"] #lifeRouteThemeFX,html[data-theme="rose-nebula"] #lifeRouteThemeFX,html[data-theme="royal-cosmos"] #lifeRouteThemeFX,html[data-theme="sapphire-tide"] #lifeRouteThemeFX,html[data-theme="phantom-silver"] #lifeRouteThemeFX{display:block}
      #lifeRouteThemeFX .fxOrb{position:absolute;width:52vw;height:52vw;max-width:620px;max-height:620px;border-radius:50%;filter:blur(60px);opacity:.18;background:var(--fx-a);animation:lrFxDriftA 16s ease-in-out infinite alternate}
      #lifeRouteThemeFX .fxOrb.two{right:-18%;top:34%;background:var(--fx-b);animation:lrFxDriftB 21s ease-in-out infinite alternate;opacity:.14}
      #lifeRouteThemeFX .fxOrb.three{left:22%;bottom:-24%;background:var(--fx-c);animation:lrFxDriftC 18s ease-in-out infinite alternate;opacity:.12}
      #lifeRouteThemeFX .fxBeam{position:absolute;left:-30%;top:42%;width:160%;height:11%;background:linear-gradient(90deg,transparent,var(--fx-beam),transparent);filter:blur(26px);opacity:.12;transform:rotate(-14deg);animation:lrFxBeam 13s ease-in-out infinite alternate}
      @keyframes lrFxDriftA{from{transform:translate3d(-20%,-18%,0) scale(.85)}to{transform:translate3d(45%,32%,0) scale(1.18)}}@keyframes lrFxDriftB{from{transform:translate3d(18%,-25%,0) scale(.92)}to{transform:translate3d(-46%,28%,0) scale(1.22)}}@keyframes lrFxDriftC{from{transform:translate3d(-12%,18%,0) scale(.8)}to{transform:translate3d(38%,-34%,0) scale(1.25)}}@keyframes lrFxBeam{from{transform:translate3d(-8%,-25%,0) rotate(-14deg)}to{transform:translate3d(12%,36%,0) rotate(8deg)}}
      html[data-theme="solar-flare"]{--bg:#120402;--bg2:#321007;--panel:rgba(49,17,10,.90);--panel2:#421a0d;--line:rgba(255,184,103,.24);--text:#fff9f0;--muted:#dcbca1;--blue:#ff715b;--gold:#ffd071;--green:#a8efb1;--red:#ff9c8f;--metal-base:#100201;--metal-deep:#3a1005;--metal-a:#e54922;--metal-b:#ffcf5a;--metal-c:#74210e;--fx-a:#ff4b20;--fx-b:#ffbd36;--fx-c:#ff775e;--fx-beam:rgba(255,229,155,.8)}
      html[data-theme="electric-storm"]{--bg:#020611;--bg2:#091438;--panel:rgba(8,20,55,.91);--panel2:#0d2451;--line:rgba(100,211,255,.25);--text:#f4fbff;--muted:#a7bed8;--blue:#43d6ff;--gold:#d9bcff;--green:#77f3cf;--red:#ff84ad;--metal-base:#01040e;--metal-deep:#101b48;--metal-a:#00c8ff;--metal-b:#9d61ff;--metal-c:#164ea8;--fx-a:#00d9ff;--fx-b:#7a38ff;--fx-c:#136fff;--fx-beam:rgba(169,237,255,.82)}
      html[data-theme="ultraviolet"]{--bg:#08010f;--bg2:#260735;--panel:rgba(35,7,48,.91);--panel2:#351052;--line:rgba(238,106,255,.22);--text:#fff6ff;--muted:#cfadd6;--blue:#e85cff;--gold:#ffca78;--green:#8bf3c1;--red:#ff82b3;--metal-base:#07000c;--metal-deep:#2e073f;--metal-a:#c02cff;--metal-b:#ff6fca;--metal-c:#65158a;--fx-a:#c125ff;--fx-b:#ff38b7;--fx-c:#7d2dff;--fx-beam:rgba(251,176,255,.82)}
      html[data-theme="molten-gold"]{--bg:#080603;--bg2:#241807;--panel:rgba(35,25,9,.92);--panel2:#39270e;--line:rgba(255,210,91,.25);--text:#fffaf0;--muted:#d4c1a0;--blue:#ffb640;--gold:#ffe17c;--green:#a4e6a4;--red:#ff9b7a;--metal-base:#060401;--metal-deep:#2e1c05;--metal-a:#e89a16;--metal-b:#ffe06a;--metal-c:#7a4b0d;--fx-a:#ff9e00;--fx-b:#ffe96d;--fx-c:#ff6f00;--fx-beam:rgba(255,241,169,.88)}
      html[data-theme="arctic-pulse"]{--bg:#011018;--bg2:#082d3c;--panel:rgba(5,37,49,.90);--panel2:#0c3c50;--line:rgba(151,242,255,.24);--text:#f5feff;--muted:#acd4db;--blue:#80efff;--gold:#d8f7ff;--green:#8cf3d2;--red:#ff9cad;--metal-base:#010d13;--metal-deep:#073241;--metal-a:#64eaff;--metal-b:#d1fbff;--metal-c:#16778b;--fx-a:#62efff;--fx-b:#d8ffff;--fx-c:#23a9d1;--fx-beam:rgba(219,255,255,.9)}
      html[data-theme="emerald-tempest"]{--bg:#010b08;--bg2:#092b21;--panel:rgba(7,39,29,.91);--panel2:#0d4533;--line:rgba(92,240,177,.22);--text:#f3fff9;--muted:#a7d0be;--blue:#59e4ad;--gold:#d9dc75;--green:#70f4b0;--red:#ff9b9b;--metal-base:#010906;--metal-deep:#073527;--metal-a:#2fd99a;--metal-b:#bedf5b;--metal-c:#116b4c;--fx-a:#15e6a1;--fx-b:#c7ef54;--fx-c:#18a874;--fx-beam:rgba(195,255,218,.84)}
      html[data-theme="rose-nebula"]{--bg:#0c0209;--bg2:#30091e;--panel:rgba(45,9,29,.90);--panel2:#4b1130;--line:rgba(255,126,185,.22);--text:#fff6fa;--muted:#d5adbf;--blue:#ff74b5;--gold:#ffd18e;--green:#9ce5bb;--red:#ff7798;--metal-base:#0a0107;--metal-deep:#360921;--metal-a:#eb3a87;--metal-b:#ffb06b;--metal-c:#851d51;--fx-a:#ff2f91;--fx-b:#ff8d6b;--fx-c:#bd2d6a;--fx-beam:rgba(255,191,219,.85)}
      html[data-theme="royal-cosmos"]{--bg:#030617;--bg2:#15113f;--panel:rgba(18,17,58,.91);--panel2:#23205a;--line:rgba(153,139,255,.23);--text:#f7f6ff;--muted:#b9b6d7;--blue:#8b8cff;--gold:#f4ca6e;--green:#89e2be;--red:#ff93aa;--metal-base:#020414;--metal-deep:#1b144a;--metal-a:#6168ed;--metal-b:#d4aa4f;--metal-c:#3a2b91;--fx-a:#5f67ff;--fx-b:#d39bff;--fx-c:#f0bd45;--fx-beam:rgba(198,192,255,.84)}
      html[data-theme="sapphire-tide"]{--bg:#010816;--bg2:#062d52;--panel:rgba(6,35,68,.91);--panel2:#0c4775;--line:rgba(88,198,255,.23);--text:#f2fbff;--muted:#a8c8dc;--blue:#4ec8ff;--gold:#d5c87d;--green:#81e5c0;--red:#ff9aab;--metal-base:#010611;--metal-deep:#07365d;--metal-a:#148ee4;--metal-b:#4ee9df;--metal-c:#0b5da6;--fx-a:#0a9cff;--fx-b:#25f0de;--fx-c:#2354ff;--fx-beam:rgba(152,232,255,.86)}
      html[data-theme="phantom-silver"]{--bg:#05070a;--bg2:#161c25;--panel:rgba(24,30,39,.92);--panel2:#27313d;--line:rgba(207,225,246,.21);--text:#f7f9fb;--muted:#b7c0ca;--blue:#b9d9fa;--gold:#d5d9e0;--green:#9de3c0;--red:#ff9fa6;--metal-base:#030507;--metal-deep:#1c232d;--metal-a:#8fa9c3;--metal-b:#eef4fa;--metal-c:#445466;--fx-a:#c4e3ff;--fx-b:#ffffff;--fx-c:#7a9fc5;--fx-beam:rgba(240,249,255,.88)}
      @media(max-width:680px){.lrBackRow{margin-top:7px}.calendarHubNav{margin-top:0}.calendarLinkItem{grid-template-columns:1fr}.calendarLinkActions button{flex:1}}
    `;
    document.head.appendChild(style);
  };

  const mountThemeFX = () => {
    if (document.getElementById("lifeRouteThemeFX")) return;
    const fx = document.createElement("div");
    fx.id = "lifeRouteThemeFX";
    fx.setAttribute("aria-hidden", "true");
    fx.innerHTML = '<div class="fxOrb"></div><div class="fxOrb two"></div><div class="fxOrb three"></div><div class="fxBeam"></div>';
    document.body.prepend(fx);
  };

  const extendThemes = () => {
    const select = document.getElementById("themeSelect");
    if (!select) return;
    THEME_OPTIONS.forEach(([value, label]) => {
      if (select.querySelector(`option[value="${value}"]`)) return;
      const option = document.createElement("option");
      option.value = value;
      option.textContent = label;
      select.appendChild(option);
    });
    if (prefs?.theme && select.querySelector(`option[value="${CSS.escape(prefs.theme)}"]`)) {
      select.value = prefs.theme;
    }
  };

  const setupCalendarHub = () => {
    const tabs = document.querySelector(".tabs");
    const today = document.getElementById("today");
    if (!tabs || !today) return;

    CALENDAR_VIEWS.forEach(id => tabs.querySelector(`[data-view="${id}"]`)?.classList.add("calendarLegacyTab"));

    let calendarTab = tabs.querySelector('[data-view="calendar"]');
    if (!calendarTab) {
      calendarTab = document.createElement("button");
      calendarTab.className = "tab";
      calendarTab.dataset.view = "calendar";
      calendarTab.textContent = "Calendar";
      tabs.insertBefore(calendarTab, tabs.firstElementChild);
    }

    let nav = document.getElementById("calendarHubNav");
    if (!nav) {
      nav = document.createElement("div");
      nav.id = "calendarHubNav";
      nav.className = "calendarHubNav";
      nav.innerHTML = CALENDAR_VIEWS.map(id => `<button type="button" data-calendar-view="${id}">${CALENDAR_LABELS[id]}</button>`).join("");
      today.parentNode.insertBefore(nav, today);
    }

    let activeCalendarView = localStorage.getItem("liferoute_calendar_view") || "today";
    if (!CALENDAR_VIEWS.includes(activeCalendarView)) activeCalendarView = "today";
    const historyStack = [];
    let navigatingBack = false;

    const activeViewID = () => document.querySelector(".view.active")?.id || "today";
    const currentState = () => ({ id: activeViewID() });

    const originalShowView = window.showView;
    if (typeof originalShowView !== "function") return;

    const syncNavigation = id => {
      const calendarMode = CALENDAR_VIEWS.includes(id);
      calendarTab.classList.toggle("active", calendarMode);
      tabs.querySelectorAll(".tab:not(.calendarLegacyTab):not([data-view='calendar'])").forEach(button => {
        button.classList.toggle("active", !calendarMode && button.dataset.view === id);
      });
      nav.classList.toggle("show", calendarMode);
      nav.querySelectorAll("[data-calendar-view]").forEach(button => button.classList.toggle("active", button.dataset.calendarView === id));
      if (calendarMode) {
        activeCalendarView = id;
        localStorage.setItem("liferoute_calendar_view", id);
      }
      updateBackButton();
    };

    window.showView = function lifeRouteShowView(id) {
      const target = id === "calendar" ? activeCalendarView : id;
      if (!target || (!CALENDAR_VIEWS.includes(target) && !document.getElementById(target))) return;

      const before = currentState();
      if (!navigatingBack && before.id !== target) {
        historyStack.push(before.id);
        if (historyStack.length > 30) historyStack.shift();
      }

      originalShowView(target);
      syncNavigation(target);
      window.scrollTo({ top: 0, behavior: "smooth" });
    };

    calendarTab.onclick = () => window.showView("calendar");
    nav.querySelectorAll("[data-calendar-view]").forEach(button => {
      button.onclick = () => window.showView(button.dataset.calendarView);
    });

    let backRow = document.getElementById("lifeRouteBackRow");
    if (!backRow) {
      backRow = document.createElement("div");
      backRow.id = "lifeRouteBackRow";
      backRow.className = "lrBackRow";
      backRow.innerHTML = '<button type="button" class="lrBackButton" id="lifeRouteBackButton"><span aria-hidden="true">←</span><span>Back</span></button>';
      const header = document.querySelector("header");
      header?.after(backRow);
    }

    function updateBackButton() {
      const button = document.getElementById("lifeRouteBackButton");
      if (!button) return;
      const atHome = currentState().id === "today" && historyStack.length === 0;
      button.classList.toggle("isHome", atHome);
      button.setAttribute("aria-disabled", atHome ? "true" : "false");
    }

    document.getElementById("lifeRouteBackButton")?.addEventListener("click", () => {
      const target = historyStack.pop();
      navigatingBack = true;
      try {
        if (target) window.showView(target);
        else if (activeViewID() !== "today") window.showView("today");
      } finally {
        navigatingBack = false;
        updateBackButton();
      }
    });

    syncNavigation(activeViewID());
  };

  let manualRouteTimer = 0;
  let manualRouteID = "";
  let manualRouteOriginLabel = "";

  const manualRouteStatus = (text, className = "") => {
    const host = document.getElementById("manualAutoStatus");
    if (!host) return;
    host.textContent = text;
    host.className = `manualAutoStatus ${className}`.trim();
  };

  const earlierOriginForManual = () => {
    const date = document.getElementById("fDate")?.value || window.selectedDate;
    const start = document.getElementById("fStart")?.value || "23:59";
    const sameDay = Array.isArray(window.events) ? events
      .filter(event => event.date === date && !event.allDay && String(event.address || "").trim() && String(event.end || "00:00") <= start)
      .sort((a, b) => String(a.end).localeCompare(String(b.end))) : [];
    const previous = sameDay.at(-1);
    if (previous) return { address: previous.address, label: previous.title || "Previous event" };

    const todayKey = typeof window.localDateKey === "function" ? localDateKey(new Date()) : "";
    const live = window.nativeState?.currentLocation;
    if (date === todayKey && live && Number.isFinite(Number(live.latitude)) && Number.isFinite(Number(live.longitude))) {
      return { latitude: Number(live.latitude), longitude: Number(live.longitude), label: "Current location" };
    }

    const home = String(window.prefs?.homeAddress || "").trim() ||
      String((window.places || []).find(place => String(place.type || "").toLowerCase() === "home")?.address || "").trim();
    return home ? { address: home, label: "Home" } : null;
  };

  const requestManualDriveEstimate = () => {
    clearTimeout(manualRouteTimer);
    manualRouteTimer = setTimeout(() => {
      const address = String(document.getElementById("fAddress")?.value || "").trim();
      const date = document.getElementById("fDate")?.value || window.selectedDate || "";
      const start = document.getElementById("fStart")?.value || "12:00";
      const drive = document.getElementById("fDrive");
      if (!address || !date || !drive) return;

      const origin = earlierOriginForManual();
      if (!origin) {
        manualRouteStatus("Client address linked. Add a home address or earlier event to calculate the drive automatically.", "ready");
        return;
      }

      const cached = (window.events || [])
        .filter(event => String(event.address || "").trim().toLowerCase() === address.toLowerCase() && Number(event.drive || 0) > 0)
        .sort((a, b) => Number(b.drive || 0) - Number(a.drive || 0))[0];
      if (cached && !drive.value) {
        drive.value = Math.round(Number(cached.drive));
        drive.dataset.autoEstimate = "cached";
      }

      manualRouteID = `manual-preview|${Date.now()}`;
      manualRouteOriginLabel = origin.label || "Route origin";
      const segment = {
        id: manualRouteID,
        date,
        fromEventID: "manual-preview-origin",
        toEventID: "manual-preview-target",
        origin: origin.address || "",
        originLatitude: origin.latitude,
        originLongitude: origin.longitude,
        destination: address,
        departure: new Date(`${date}T${start}:00`).toISOString(),
        originLabel: manualRouteOriginLabel
      };

      manualRouteStatus(`Calculating drive from ${manualRouteOriginLabel}…`, "loading");
      if (!window.postNative?.({ action: "requestRouteTimes", requestNumber: Date.now(), segments: [segment] })) {
        manualRouteStatus(cached ? `Address linked · using a recent ${drive.value} min route estimate in web preview.` : "Address linked. Exact MapKit drive time calculates automatically in the iPhone build.", "ready");
      }
    }, 450);
  };

  const setupSmartManualAppointment = () => {
    const title = document.getElementById("fTitle");
    const address = document.getElementById("fAddress");
    const drive = document.getElementById("fDrive");
    const grid = title?.closest(".formgrid");
    if (!title || !address || !drive || !grid) return;

    if (!document.getElementById("manualAutoStatus")) {
      const status = document.createElement("div");
      status.id = "manualAutoStatus";
      status.className = "manualAutoStatus";
      status.textContent = "Enter a saved four-letter client code to link its address automatically.";
      grid.appendChild(status);
    }

    const syncClient = () => {
      const client = clientForTitle(title.value);
      if (client && String(client.address || "").trim()) {
        const code = codeForClient(client);
        if (!address.value.trim() || address.dataset.clientAutofill === "1") {
          address.value = String(client.address).trim();
          address.dataset.clientAutofill = "1";
          address.dataset.clientCode = code;
        }
        manualRouteStatus(`${code} address linked from Setup · calculating route…`, "loading");
        requestManualDriveEstimate();
      } else {
        if (address.dataset.clientAutofill === "1") {
          address.value = "";
          delete address.dataset.clientAutofill;
          delete address.dataset.clientCode;
        }
        manualRouteStatus("Enter a saved four-letter client code to link its address automatically.");
      }
    };

    title.addEventListener("input", syncClient);
    ["fDate", "fStart"].forEach(id => document.getElementById(id)?.addEventListener("change", requestManualDriveEstimate));
    address.addEventListener("input", () => {
      if (address.dataset.clientAutofill === "1") {
        delete address.dataset.clientAutofill;
        delete address.dataset.clientCode;
      }
      requestManualDriveEstimate();
    });

    const priorNativeEvent = window.lifeRouteNativeEvent;
    window.lifeRouteNativeEvent = function lifeRouteNativeEventWithManualPreview(evt) {
      if (typeof priorNativeEvent === "function") priorNativeEvent(evt);
      if (evt?.type !== "routeTimes" || !manualRouteID) return;
      const result = (Array.isArray(evt.results) ? evt.results : []).find(item => item.id === manualRouteID);
      if (!result) return;
      if (!result.error && Number(result.minutes || 0) > 0) {
        drive.value = Math.round(Number(result.minutes));
        drive.dataset.autoEstimate = "mapkit";
        const miles = Number(result.distanceMeters || 0) / 1609.344;
        manualRouteStatus(`Address linked · ${drive.value} min${miles > 0 ? ` · ${miles.toFixed(miles < 10 ? 1 : 0)} mi` : ""} from ${manualRouteOriginLabel}.`, "ready");
      } else {
        manualRouteStatus("Client address linked, but this route estimate is temporarily unavailable.", "ready");
      }
      manualRouteID = "";
    };
  };

  const loadFeeds = () => {
    try {
      const saved = JSON.parse(localStorage.getItem(FEED_KEY) || "[]");
      return Array.isArray(saved) ? saved.filter(feed => feed?.url) : [];
    } catch (_) {
      return [];
    }
  };

  let calendarFeeds = loadFeeds();
  const saveFeeds = () => localStorage.setItem(FEED_KEY, JSON.stringify(calendarFeeds));

  const platformHelp = platform => {
    const common = "Open your scheduling platform’s Calendar or Schedule settings and look for <b>iCal</b>, <b>ICS</b>, <b>Subscribe</b>, <b>External calendar</b>, or <b>Calendar sync</b>. Choose a read-only/private subscription link when offered, then paste that URL here. Menu names can vary by organization and software version.";
    const hints = {
      centralreach: "<b>CentralReach:</b> Check schedule/calendar settings for calendar sync, iCal, or an external-calendar subscription. Your organization may need to enable calendar sharing first.",
      rethink: "<b>Rethink:</b> Check Schedule/Calendar settings for export, iCal/ICS, or calendar subscription options.",
      theralytics: "<b>Theralytics:</b> Check Calendar/Schedule settings for calendar sync, export, iCal/ICS, or a subscription URL.",
      ensora: "<b>Ensora:</b> Check Schedule/Calendar settings for external-calendar, sync, iCal/ICS, or subscription options.",
      other: "<b>Other platform:</b> Search its help center for “iCal subscription,” “ICS feed,” “calendar sync,” or “subscribe to calendar.”"
    };
    return `${hints[platform] || hints.other}<br><br>${common}<br><br><b>Privacy:</b> Treat a private calendar URL like a password. LifeRoute stores it only on this device and does not send it to a third-party proxy.`;
  };

  const unfoldICS = text => String(text || "").replace(/\r?\n[ \t]/g, "");
  const icsUnescape = value => String(value || "")
    .replace(/\\n/gi, "\n").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");

  const icsDateToISO = raw => {
    const value = String(raw || "").trim();
    if (/^\d{8}$/.test(value)) {
      return `${value.slice(0,4)}-${value.slice(4,6)}-${value.slice(6,8)}`;
    }
    const match = value.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})?(Z)?$/);
    if (!match) return value;
    const [, y, mo, d, h, mi, s = "00", z] = match;
    if (z) return `${y}-${mo}-${d}T${h}:${mi}:${s}Z`;
    const local = new Date(Number(y), Number(mo)-1, Number(d), Number(h), Number(mi), Number(s));
    return local.toISOString();
  };

  const parseICS = (text, feed) => {
    const unfolded = unfoldICS(text);
    const blocks = unfolded.match(/BEGIN:VEVENT[\s\S]*?END:VEVENT/g) || [];
    return blocks.map((block, index) => {
      const lines = block.split(/\r?\n/);
      const values = {};
      lines.forEach(line => {
        const colon = line.indexOf(":");
        if (colon < 0) return;
        const keyWithParams = line.slice(0, colon);
        const key = keyWithParams.split(";")[0].toUpperCase();
        if (!values[key]) values[key] = [];
        values[key].push(line.slice(colon + 1));
      });
      const startRaw = values.DTSTART?.[0] || "";
      const endRaw = values.DTEND?.[0] || startRaw;
      const allDay = /^\d{8}$/.test(startRaw);
      return {
        id: `${feed.id}-${icsUnescape(values.UID?.[0] || index)}`,
        title: icsUnescape(values.SUMMARY?.[0] || feed.label || "Calendar event"),
        start: icsDateToISO(startRaw),
        end: icsDateToISO(endRaw),
        location: icsUnescape(values.LOCATION?.[0] || ""),
        calendarTitle: feed.label || feed.platform || "Calendar link",
        isAllDay: allDay,
        source: FEED_SOURCE
      };
    }).filter(event => event.start && event.end);
  };

  const renderFeedList = () => {
    const host = document.getElementById("calendarLinkList");
    if (!host) return;
    if (!calendarFeeds.length) {
      host.innerHTML = '<div class="tiny">No read-only calendar links saved yet.</div>';
      return;
    }
    host.innerHTML = calendarFeeds.map(feed => `
      <div class="calendarLinkItem">
        <div>
          <div class="title" style="font-size:12px">${htmlEscape(feed.label || "Calendar feed")}</div>
          <div class="calendarLinkURL">${htmlEscape(feed.url)}</div>
        </div>
        <button class="danger" type="button" data-remove-feed="${htmlEscape(feed.id)}">Remove</button>
      </div>
    `).join("");
    host.querySelectorAll("[data-remove-feed]").forEach(button => {
      button.onclick = () => {
        calendarFeeds = calendarFeeds.filter(feed => feed.id !== button.dataset.removeFeed);
        saveFeeds();
        renderFeedList();
        refreshCalendarFeeds();
      };
    });
  };

  const receiveFeedEvents = allEvents => {
    prefs.sources = Object.assign({}, prefs.sources || {}, { [FEED_SOURCE]: true, centralreach: false });
    if (typeof window.receiveProviderEvents === "function") {
      window.receiveProviderEvents(FEED_SOURCE, allEvents);
    }
    try { window.persist?.(); } catch (_) {}
    window.renderAll?.();
  };

  let nativeFeedPending = new Map();

  const refreshCalendarFeeds = async () => {
    const status = document.getElementById("calendarFeedStatus");
    if (!calendarFeeds.length) {
      receiveFeedEvents([]);
      if (status) status.textContent = "No calendar links to refresh.";
      return;
    }
    if (status) status.textContent = `Refreshing ${calendarFeeds.length} calendar link${calendarFeeds.length === 1 ? "" : "s"}…`;

    const nativeAvailable = !!window.webkit?.messageHandlers?.lifeRoute;
    if (nativeAvailable) {
      nativeFeedPending = new Map(calendarFeeds.map(feed => [feed.id, { feed, events: null, error: "" }]));
      calendarFeeds.forEach(feed => {
        window.postNative?.({ action: "fetchReadOnlyCalendarFeed", feedID: feed.id, url: feed.url });
      });
      return;
    }

    const loaded = await Promise.all(calendarFeeds.map(async feed => {
      try {
        const url = String(feed.url).replace(/^webcal:/i, "https:");
        const response = await fetch(url, { method: "GET", credentials: "omit", cache: "no-store" });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return { feed, events: parseICS(await response.text(), feed), error: "" };
      } catch (error) {
        return { feed, events: [], error: error?.message || "Could not load feed" };
      }
    }));

    receiveFeedEvents(loaded.flatMap(item => item.events));
    const failures = loaded.filter(item => item.error).length;
    if (status) status.textContent = failures
      ? `${loaded.length - failures} feed${loaded.length - failures === 1 ? "" : "s"} loaded · ${failures} blocked in web preview. The iPhone build can fetch private feeds natively.`
      : `${loaded.reduce((sum, item) => sum + item.events.length, 0)} events loaded from calendar links.`;
  };

  window.refreshLifeRouteCalendarFeeds = refreshCalendarFeeds;

  const setupCalendarLinks = () => {
    window.LifeRouteConfig = window.LifeRouteConfig || {};
    delete window.LifeRouteConfig.centralReach;
    prefs.sources = Object.assign({}, prefs.sources || {}, { centralreach: false, [FEED_SOURCE]: true });

    const centralIntegration = Array.from(document.querySelectorAll("#setup .integration")).find(node => /centralreach/i.test(node.textContent || ""));
    const centralCard = centralIntegration?.closest(".card");
    if (centralCard) centralCard.style.display = "none";
    const centralToggle = document.getElementById("srcCentral")?.closest(".toggleRow");
    if (centralToggle) centralToggle.style.display = "none";
    if (document.getElementById("srcCentral")) document.getElementById("srcCentral").checked = false;

    const inputsHeading = Array.from(document.querySelectorAll("#setup .sectionHead h2")).find(node => /calendar inputs/i.test(node.textContent || ""));
    const inputsSection = inputsHeading?.closest(".section");
    if (!inputsSection || document.getElementById("readOnlyCalendarLinks")) return;

    const section = document.createElement("div");
    section.className = "section";
    section.id = "readOnlyCalendarLinks";
    section.innerHTML = `
      <div class="sectionHead"><h2>Read-only calendar links</h2><span class="hint">iCal / ICS / webcal</span></div>
      <div class="card calendarLinkCard">
        <div class="formgrid">
          <div><label>Platform</label><select id="calendarLinkPlatform"><option value="centralreach">CentralReach</option><option value="rethink">Rethink</option><option value="theralytics">Theralytics</option><option value="ensora">Ensora</option><option value="other">Other</option></select></div>
          <div><label>Calendar label</label><input id="calendarLinkLabel" placeholder="Work schedule"></div>
          <div class="full"><label>Read-only calendar URL</label><input id="calendarLinkURL" inputmode="url" autocapitalize="none" autocomplete="off" placeholder="https://… .ics or webcal://…"></div>
        </div>
        <div class="calendarHelp" id="calendarLinkHelp"></div>
        <div class="calendarLinkActions"><button class="goldButton" type="button" id="addCalendarLink">Add calendar link</button><button class="secondary" type="button" id="refreshCalendarLinks">Refresh links</button></div>
        <div class="feedStatus" id="calendarFeedStatus"></div>
        <div class="calendarLinkList" id="calendarLinkList"></div>
      </div>
    `;
    inputsSection.after(section);

    const platform = document.getElementById("calendarLinkPlatform");
    const help = document.getElementById("calendarLinkHelp");
    const renderHelp = () => { if (help) help.innerHTML = platformHelp(platform?.value || "other"); };
    platform?.addEventListener("change", renderHelp);
    renderHelp();

    document.getElementById("addCalendarLink")?.addEventListener("click", () => {
      const urlField = document.getElementById("calendarLinkURL");
      const labelField = document.getElementById("calendarLinkLabel");
      const url = String(urlField?.value || "").trim();
      const label = String(labelField?.value || "").trim() || (platform?.selectedOptions?.[0]?.textContent || "Calendar");
      if (!/^(https?:\/\/|webcal:\/\/)/i.test(url)) {
        alert("Paste a read-only https:// or webcal:// calendar subscription link.");
        return;
      }
      const normalized = url.replace(/^webcal:/i, "https:");
      if (calendarFeeds.some(feed => feed.url.replace(/^webcal:/i, "https:") === normalized)) {
        alert("That calendar link is already saved.");
        return;
      }
      calendarFeeds.push({
        id: `feed-${Date.now()}-${Math.random().toString(36).slice(2,7)}`,
        label,
        platform: platform?.value || "other",
        url
      });
      saveFeeds();
      if (urlField) urlField.value = "";
      if (labelField) labelField.value = "";
      renderFeedList();
      refreshCalendarFeeds();
    });
    document.getElementById("refreshCalendarLinks")?.addEventListener("click", refreshCalendarFeeds);
    renderFeedList();

    const oldRefresh = window.refreshCalendars;
    if (typeof oldRefresh === "function" && !oldRefresh._lifeRouteCalendarLinksWrapped) {
      const wrapped = function refreshAllLifeRouteCalendars(...args) {
        const result = oldRefresh.apply(this, args);
        setTimeout(refreshCalendarFeeds, 100);
        return result;
      };
      wrapped._lifeRouteCalendarLinksWrapped = true;
      window.refreshCalendars = wrapped;
    }

    const priorRenderSources = window.renderSources;
    if (typeof priorRenderSources === "function") {
      window.renderSources = function renderSourcesWithoutCentralReach(...args) {
        const result = priorRenderSources.apply(this, args);
        document.querySelectorAll("#activeSources .chip").forEach(chip => {
          if (/centralreach/i.test(chip.textContent || "")) chip.remove();
        });
        if (window.activeSources && !Array.from(activeSources.querySelectorAll(".chip")).some(chip => /calendar link/i.test(chip.textContent || ""))) {
          const chip = document.createElement("span");
          chip.className = `chip ${calendarFeeds.length ? "on" : ""}`;
          chip.textContent = `${calendarFeeds.length ? "●" : "○"} Calendar Links`;
          activeSources.appendChild(chip);
        }
        return result;
      };
    }

    const sourceObserver = document.getElementById("activeSources");
    if (sourceObserver) {
      new MutationObserver(() => {
        sourceObserver.querySelectorAll(".chip").forEach(chip => {
          if (/centralreach/i.test(chip.textContent || "")) chip.remove();
        });
      }).observe(sourceObserver, { childList: true, subtree: true });
    }
  };

  const hookNativeCalendarFeed = () => {
    const prior = window.lifeRouteNativeEvent;
    window.lifeRouteNativeEvent = function lifeRouteNativeEventWithCalendarFeeds(evt) {
      if (typeof prior === "function") prior(evt);
      if (!evt || !["readOnlyCalendarFeed", "readOnlyCalendarFeedError"].includes(evt.type)) return;
      const pending = nativeFeedPending.get(String(evt.feedID || ""));
      if (!pending) return;
      if (evt.type === "readOnlyCalendarFeed") pending.events = parseICS(evt.text || "", pending.feed);
      else {
        pending.events = [];
        pending.error = evt.message || "Could not load feed";
      }
      nativeFeedPending.set(pending.feed.id, pending);

      const done = Array.from(nativeFeedPending.values()).every(item => Array.isArray(item.events));
      if (!done) return;

      const items = Array.from(nativeFeedPending.values());
      receiveFeedEvents(items.flatMap(item => item.events || []));
      const failures = items.filter(item => item.error).length;
      const status = document.getElementById("calendarFeedStatus");
      if (status) status.textContent = failures
        ? `${items.length - failures} calendar link${items.length - failures === 1 ? "" : "s"} loaded · ${failures} unavailable.`
        : `${items.reduce((sum, item) => sum + item.events.length, 0)} events loaded from calendar links.`;
      nativeFeedPending.clear();
    };
  };

  const boot = () => {
    installStyles();
    mountThemeFX();
    extendThemes();
    setupCalendarHub();
    setupSmartManualAppointment();
    setupCalendarLinks();
    hookNativeCalendarFeed();
    window.renderAll?.();
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot, { once: true });
  else boot();
})();
