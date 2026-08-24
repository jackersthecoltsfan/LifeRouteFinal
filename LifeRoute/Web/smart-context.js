// LifeRoute smart commute context: live location, home fallback, and ABA client locations.
(() => {
  window.addEventListener("DOMContentLoaded", () => {
    prefs.clients = Array.isArray(prefs.clients) ? prefs.clients : [];
    prefs.homeAddress = String(prefs.homeAddress || "");
    nativeState.currentLocation = nativeState.currentLocation || null;
    nativeState.locationStatus = nativeState.locationStatus || "unknown";

    const style = document.createElement("style");
    style.textContent = `
      .setupSubnav{display:flex;gap:7px;padding:5px;margin:2px 0 17px;border:1px solid var(--line);border-radius:16px;background:color-mix(in srgb,var(--panel) 82%,transparent);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px)}
      .setupSubnav button{flex:1;background:transparent;color:var(--muted);min-height:38px;border:0;border-radius:12px;font-size:12px;font-weight:850}.setupSubnav button.active{background:var(--panel2);color:var(--text);box-shadow:inset 0 0 0 1px var(--line)}
      .setupPane{display:none}.setupPane.active{display:block}
      .commuteCard{position:relative;overflow:hidden}.commuteCard:after{content:"";position:absolute;width:190px;height:190px;right:-90px;top:-110px;border-radius:50%;background:radial-gradient(circle,color-mix(in srgb,var(--blue) 16%,transparent),transparent 70%);pointer-events:none}
      .contextStatus{display:flex;gap:6px;flex-wrap:wrap;margin-top:9px}.contextPill{display:inline-flex;align-items:center;gap:6px;padding:6px 9px;border:1px solid var(--line);border-radius:999px;background:color-mix(in srgb,var(--panel2) 76%,transparent);font-size:10px;font-weight:800;color:var(--muted)}.contextPill.live{color:var(--green)}.contextPill.warn{color:var(--gold)}
      .setupActionRow{display:flex;gap:7px;flex-wrap:wrap;margin-top:10px}.setupActionRow button{font-size:11px;padding:9px 11px}
      .clientCodePreview{font-size:26px;font-weight:950;letter-spacing:-1px;color:var(--gold);min-width:62px}.clientCard{display:grid;grid-template-columns:auto 1fr auto;gap:12px;align-items:center}.clientCard .meta{word-break:break-word}
      .privacyLine{margin-top:8px;padding-top:8px;border-top:1px solid var(--line);font-size:10px;color:var(--muted)}
      .smartStrip{display:flex;gap:6px;flex-wrap:wrap;margin-top:12px}.smartStrip .contextPill{background:color-mix(in srgb,var(--panel2) 62%,transparent)}
      @media(max-width:680px){.clientCard{grid-template-columns:auto 1fr}.clientCard>.danger{grid-column:1/-1;justify-self:start}.setupActionRow button{flex:1}}
    `;
    document.head.appendChild(style);

    const formatPair = value => {
      const letters = String(value || "").replace(/[^a-z]/gi, "").slice(0, 2);
      if (!letters) return "";
      return letters.charAt(0).toUpperCase() + letters.slice(1).toLowerCase();
    };
    const clientCode = client => `${formatPair(client.first2)}${formatPair(client.last2)}`;
    const escapeRegex = value => String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const clientForTitle = title => {
      const raw = String(title || "").trim();
      if (!raw) return null;
      return prefs.clients.find(client => {
        const code = clientCode(client);
        if (code.length !== 4) return false;
        if (raw.toLowerCase() === code.toLowerCase()) return true;
        return new RegExp(`(^|[^a-z0-9])${escapeRegex(code)}([^a-z0-9]|$)`, "i").test(raw);
      }) || null;
    };

    const homeFallback = () => {
      if (String(prefs.homeAddress || "").trim()) return String(prefs.homeAddress).trim();
      const place = places.find(item => String(item.type || "").toLowerCase() === "home" && String(item.address || "").trim());
      return String(place?.address || "").trim();
    };

    const applyClientLocations = () => {
      let changed = false;
      events.forEach(event => {
        const matched = clientForTitle(event.title);
        if (event.addressSource === "client" && (!matched || !String(matched.address || "").trim())) {
          event.address = "";
          event.addressSource = "";
          event.clientCode = "";
          changed = true;
        }
        if (!matched || !String(matched.address || "").trim()) return;
        if (!String(event.address || "").trim() || event.addressSource === "client") {
          const nextAddress = String(matched.address).trim();
          const nextCode = clientCode(matched);
          if (event.address !== nextAddress || event.clientCode !== nextCode || event.addressSource !== "client") {
            event.address = nextAddress;
            event.addressSource = "client";
            event.clientCode = nextCode;
            changed = true;
          }
        }
      });
      return changed;
    };
    window.applyLifeRouteClientLocations = applyClientLocations;

    const buildSetupPanels = () => {
      const setup = document.getElementById("setup");
      if (!setup || document.getElementById("setupSubnav")) return;
      const existing = Array.from(setup.children);
      const nav = document.createElement("div");
      nav.id = "setupSubnav";
      nav.className = "setupSubnav";
      nav.innerHTML = '<button class="active" data-setup-pane="general">General</button><button data-setup-pane="clients">Clients</button>';

      const general = document.createElement("div");
      general.id = "setupGeneral";
      general.className = "setupPane active";
      existing.forEach(node => general.appendChild(node));

      const clients = document.createElement("div");
      clients.id = "setupClients";
      clients.className = "setupPane";
      clients.innerHTML = `
        <div class="section"><div class="sectionHead"><h2>Clients</h2><span class="hint">ABA-style initials only</span></div>
          <div class="card">
            <div class="formgrid">
              <div><label>First 2 initials</label><input id="clientFirst2" maxlength="2" autocapitalize="none"></div>
              <div><label>Last 2 initials</label><input id="clientLast2" maxlength="2" autocapitalize="none"></div>
              <div class="full"><label>Client address / service location</label><input id="clientAddress" placeholder="Street address or searchable place"></div>
            </div>
            <div class="row" style="margin-top:10px"><div><div class="tiny">Calendar match preview</div><div class="clientCodePreview" id="clientCodePreview">—</div></div><button class="goldButton" id="saveClientButton">Save client</button></div>
            <div class="privacyLine">LifeRoute stores only the four-letter ABA-style code and route address locally on this device. Calendar events with that same code can then inherit the saved address automatically.</div>
          </div>
        </div>
        <div class="section"><div class="sectionHead"><h2>Saved clients</h2><span class="hint" id="clientCount">0 clients</span></div><div id="clientList"></div></div>`;

      const commute = document.createElement("div");
      commute.className = "section";
      commute.innerHTML = `
        <div class="sectionHead"><h2>Commute intelligence</h2><span class="hint">live start + home fallback</span></div>
        <div class="card commuteCard">
          <div class="formgrid">
            <div class="full"><label>Home address</label><input id="homeAddressField" placeholder="Your home address"></div>
          </div>
          <div class="contextStatus" id="locationContextStatus"></div>
          <div class="setupActionRow"><button class="goldButton" id="saveHomeButton">Save home</button><button class="secondary" id="locationButton">Enable current location</button></div>
          <div class="tiny" style="margin-top:9px">For today, LifeRoute starts your first commute from your live location. Home is the fallback and the smarter anchor for future-day planning when your current position would be misleading.</div>
        </div>`;
      general.prepend(commute);

      setup.append(nav, general, clients);
      nav.querySelectorAll("button").forEach(button => {
        button.addEventListener("click", () => {
          nav.querySelectorAll("button").forEach(item => item.classList.toggle("active", item === button));
          general.classList.toggle("active", button.dataset.setupPane === "general");
          clients.classList.toggle("active", button.dataset.setupPane === "clients");
        });
      });
    };

    const renderLocationStatus = () => {
      const host = document.getElementById("locationContextStatus");
      const field = document.getElementById("homeAddressField");
      if (field && document.activeElement !== field) field.value = prefs.homeAddress || "";
      if (!host) return;
      const status = nativeState.locationStatus || "unknown";
      const live = nativeState.currentLocation;
      const home = homeFallback();
      const liveLabel = live ? "● Live location ready" : status === "denied" ? "Location permission off" : status === "locating" || status === "requesting" ? "Locating…" : "Live location not ready";
      host.innerHTML = `<span class="contextPill ${live ? "live" : "warn"}">${liveLabel}</span><span class="contextPill ${home ? "live" : "warn"}">${home ? "⌂ Home saved" : "⌂ Add home fallback"}</span><span class="contextPill">MapKit route intelligence</span>`;
      const button = document.getElementById("locationButton");
      if (button) button.textContent = live ? "Refresh current location" : status === "denied" ? "Location access off" : "Enable current location";
    };

    const renderClients = () => {
      const list = document.getElementById("clientList");
      const count = document.getElementById("clientCount");
      if (!list || !count) return;
      count.textContent = `${prefs.clients.length} client${prefs.clients.length === 1 ? "" : "s"}`;
      if (!prefs.clients.length) {
        list.innerHTML = '<div class="card empty">No clients saved yet. Add the four-letter calendar code and address once; LifeRoute will reuse it automatically.</div>';
        return;
      }
      list.innerHTML = prefs.clients.map(client => {
        const code = clientCode(client);
        return `<div class="card clientCard"><div class="clientCodePreview">${esc(code)}</div><div><div class="title">${esc(code)}</div><div class="meta">${esc(client.address || "No address")}</div><div class="tiny">Auto-links matching calendar events</div></div><button class="danger" onclick="window.removeLifeRouteClient('${encodeURIComponent(code)}')">Remove</button></div>`;
      }).join("");
    };

    const renderPreview = () => {
      const first = document.getElementById("clientFirst2");
      const last = document.getElementById("clientLast2");
      const preview = document.getElementById("clientCodePreview");
      if (!first || !last || !preview) return;
      first.value = formatPair(first.value);
      last.value = formatPair(last.value);
      const code = `${first.value}${last.value}`;
      preview.textContent = code.length === 4 ? code : "—";
    };

    const renderSmartStrip = () => {
      const hero = document.querySelector("#today .hero");
      if (!hero) return;
      let strip = document.getElementById("smartContextStrip");
      if (!strip) {
        strip = document.createElement("div");
        strip.id = "smartContextStrip";
        strip.className = "smartStrip";
        hero.appendChild(strip);
      }
      const matched = events.filter(event => event.addressSource === "client" && String(event.address || "").trim()).length;
      strip.innerHTML = `<span class="contextPill ${nativeState.currentLocation ? "live" : ""}">${nativeState.currentLocation ? "● Live commute start" : "○ Location fallback"}</span><span class="contextPill">${prefs.clients.length} client${prefs.clients.length === 1 ? "" : "s"} saved</span><span class="contextPill">${matched} calendar location${matched === 1 ? "" : "s"} linked</span>`;
    };

    buildSetupPanels();
    renderClients();
    renderLocationStatus();
    renderSmartStrip();

    const firstInput = document.getElementById("clientFirst2");
    const lastInput = document.getElementById("clientLast2");
    firstInput?.addEventListener("input", renderPreview);
    lastInput?.addEventListener("input", renderPreview);

    document.getElementById("saveHomeButton")?.addEventListener("click", () => {
      prefs.homeAddress = String(document.getElementById("homeAddressField")?.value || "").trim();
      persist();
      renderLocationStatus();
      setStatus(prefs.homeAddress ? "Home commute fallback saved" : "Home fallback cleared");
      setTimeout(() => window.refreshRouteTimes?.(), 120);
    });

    window.requestLifeRouteLocation = () => {
      nativeState.locationStatus = "requesting";
      renderLocationStatus();
      if (!postNative({ action: "requestCurrentLocation" })) {
        nativeState.locationStatus = "unavailable";
        renderLocationStatus();
        setStatus("Current location requires the iPhone app build");
      }
    };
    document.getElementById("locationButton")?.addEventListener("click", window.requestLifeRouteLocation);

    document.getElementById("saveClientButton")?.addEventListener("click", () => {
      const first2 = formatPair(document.getElementById("clientFirst2")?.value);
      const last2 = formatPair(document.getElementById("clientLast2")?.value);
      const address = String(document.getElementById("clientAddress")?.value || "").trim();
      if (first2.length !== 2 || last2.length !== 2 || !address) {
        alert("Add exactly two first-name letters, two last-name letters, and the client address.");
        return;
      }
      const code = `${first2}${last2}`;
      const existing = prefs.clients.find(client => clientCode(client).toLowerCase() === code.toLowerCase());
      if (existing) {
        existing.first2 = first2;
        existing.last2 = last2;
        existing.address = address;
      } else {
        prefs.clients.push({ first2, last2, address });
      }
      document.getElementById("clientFirst2").value = "";
      document.getElementById("clientLast2").value = "";
      document.getElementById("clientAddress").value = "";
      renderPreview();
      applyClientLocations();
      persist();
      renderClients();
      renderSmartStrip();
      renderAll();
      setStatus(`${code} location linked`);
      setTimeout(() => window.refreshRouteTimes?.(), 180);
    });

    window.removeLifeRouteClient = encodedCode => {
      const code = decodeURIComponent(encodedCode || "");
      prefs.clients = prefs.clients.filter(client => clientCode(client).toLowerCase() !== code.toLowerCase());
      applyClientLocations();
      persist();
      renderClients();
      renderSmartStrip();
      renderAll();
      setTimeout(() => window.refreshRouteTimes?.(), 180);
    };

    // Reconcile calendar events with saved ABA client addresses whenever a provider refreshes.
    const originalReceiveProviderEvents = window.receiveProviderEvents;
    if (typeof originalReceiveProviderEvents === "function") {
      window.receiveProviderEvents = function receiveProviderEventsWithClients(...args) {
        const result = originalReceiveProviderEvents.apply(this, args);
        if (applyClientLocations()) persist();
        renderSmartStrip();
        renderAll();
        setTimeout(() => window.refreshRouteTimes?.(), 160);
        return result;
      };
    }

    // Replace the older home-only route origin logic with context-aware routing.
    window.refreshRouteTimes = function refreshSmartRouteTimes() {
      if (applyClientLocations()) persist();
      const segments = [];
      const today = localDateKey(new Date());
      const live = nativeState.currentLocation;
      const home = homeFallback();

      weekDates().forEach(dateKey => {
        const list = dayEvents(dateKey);
        if (!list.length) return;
        list.forEach(event => {
          event.routePending = false;
          event.routeError = "";
          event.routeDistanceMiles = 0;
          event.routeOriginLabel = "";
        });

        const first = list[0];
        if (String(first?.address || "").trim()) {
          let origin = null;
          if (dateKey === today && live?.latitude != null && live?.longitude != null) {
            origin = {
              label: "Current location",
              address: "Current location",
              latitude: Number(live.latitude),
              longitude: Number(live.longitude),
              fromEventID: "current-location"
            };
          } else if (home) {
            origin = { label: "Home", address: home, fromEventID: "home" };
          } else if (live?.latitude != null && live?.longitude != null) {
            origin = {
              label: "Current location",
              address: "Current location",
              latitude: Number(live.latitude),
              longitude: Number(live.longitude),
              fromEventID: "current-location"
            };
          }

          if (origin) {
            first.routePending = true;
            segments.push({
              id: `${dateKey}|${origin.fromEventID}|${first.id}`,
              date: dateKey,
              fromEventID: origin.fromEventID,
              toEventID: String(first.id),
              origin: origin.address,
              originLatitude: origin.latitude,
              originLongitude: origin.longitude,
              destination: first.address,
              departure: new Date(`${dateKey}T${first.start || "12:00"}:00`).toISOString(),
              originLabel: origin.label
            });
          }
        }

        for (let index = 1; index < list.length; index += 1) {
          const previous = list[index - 1];
          const current = list[index];
          if (!String(previous.address || "").trim() || !String(current.address || "").trim()) continue;
          current.routePending = true;
          segments.push({
            id: `${dateKey}|${previous.id}|${current.id}`,
            date: dateKey,
            fromEventID: String(previous.id),
            toEventID: String(current.id),
            origin: previous.address,
            destination: current.address,
            departure: new Date(`${dateKey}T${previous.end || "12:00"}:00`).toISOString(),
            originLabel: previous.title || "Previous event"
          });
        }
      });

      renderSmartStrip();
      if (!segments.length) {
        nativeState.routeTimeStatus = "no-routable-events";
        renderAll();
        return;
      }

      nativeState.smartRouteRequest = Number(nativeState.smartRouteRequest || 0) + 1;
      nativeState.routeTimeRequest = nativeState.smartRouteRequest;
      nativeState.routeTimeStatus = "loading";
      nativeState.routeSegmentsRequested = segments.length;
      nativeState.routeSegmentMeta = Object.fromEntries(segments.map(segment => [segment.id, segment]));
      setStatus(`Calculating ${segments.length} route${segments.length === 1 ? "" : "s"}…`);
      renderAll();
      if (!postNative({ action: "requestRouteTimes", requestNumber: nativeState.smartRouteRequest, segments })) {
        nativeState.routeTimeStatus = "unavailable";
        setStatus("Route times require the iPhone app build");
      }
    };

    // Extend the existing native-event chain rather than replacing route/calendar handlers.
    const previousNativeEvent = window.lifeRouteNativeEvent;
    window.lifeRouteNativeEvent = function lifeRouteNativeEventWithLocation(evt) {
      if (typeof previousNativeEvent === "function") previousNativeEvent(evt);
      if (!evt?.type) return;
      if (evt.type === "currentLocationStatus") {
        nativeState.locationStatus = evt.status || "unknown";
        renderLocationStatus();
        renderSmartStrip();
      }
      if (evt.type === "currentLocation") {
        nativeState.locationStatus = "ready";
        nativeState.currentLocation = {
          latitude: Number(evt.latitude),
          longitude: Number(evt.longitude),
          accuracyMeters: Number(evt.accuracyMeters || 0),
          timestamp: evt.timestamp || ""
        };
        renderLocationStatus();
        renderSmartStrip();
        setTimeout(() => window.refreshRouteTimes?.(), 80);
      }
    };

    // Make the grocery error in the screenshot actionable when a calendar event lacks a location.
    const improveStoreMessage = () => {
      document.querySelectorAll(".storeChooser .tiny").forEach(node => {
        if (node.textContent.includes("Both neighboring calendar events need locations")) {
          node.textContent = "One or both appointments are missing a route location. Add client addresses in Setup → Clients (or add the location to the calendar event); LifeRoute will then compare store detours automatically.";
        }
      });
    };
    const observer = new MutationObserver(improveStoreMessage);
    observer.observe(document.body, { childList: true, subtree: true });

    if (applyClientLocations()) persist();
    renderAll();
    renderSmartStrip();

    // Ask for When-In-Use location once the native interface has settled. iOS itself
    // controls the permission prompt and will not repeatedly re-prompt after a choice.
    setTimeout(() => {
      if (!nativeState.currentLocation && nativeState.locationStatus !== "denied") {
        window.requestLifeRouteLocation();
      }
    }, 850);
  });
})();
