// LifeRoute travel-mode preference.
// Adds Driving / Walking / Transit as a global routing preference and attaches
// the selected mode to native route-time calculations and map handoffs.
(() => {
  const initTransportMode = () => {
    if (typeof prefs === "undefined" || typeof persist !== "function") return;

    const MODES = [
      { id: "driving", label: "Driving", icon: "🚙", note: "Car route times" },
      { id: "walking", label: "Walking", icon: "🚶", note: "Walking route times" },
      { id: "transit", label: "Transit", icon: "🚆", note: "Public transit route times" }
    ];
    const validModes = new Set(MODES.map(mode => mode.id));

    if (!validModes.has(String(prefs.transportMode || ""))) {
      prefs.transportMode = "driving";
      persist();
    }

    const modeInfo = () => MODES.find(mode => mode.id === prefs.transportMode) || MODES[0];

    const style = document.createElement("style");
    style.textContent = `
      .transportGrid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
      .transportChoice{background:var(--panel2);color:var(--text);border:1px solid var(--line);border-radius:15px;padding:12px 10px;text-align:left}
      .transportChoice.active{border-color:var(--gold);box-shadow:inset 0 0 0 1px var(--gold)}
      .transportIcon{font-size:21px;margin-bottom:6px}.transportName{font-size:12px;font-weight:950}.transportNote{font-size:9px;color:var(--muted);margin-top:3px;line-height:1.25}
      .transportCurrent{margin-top:9px;color:var(--muted);font-size:10px;line-height:1.4}
      @media(max-width:480px){.transportGrid{grid-template-columns:1fr 1fr 1fr}.transportChoice{padding:10px 8px}.transportName{font-size:11px}.transportNote{font-size:8px}}
    `;
    document.head.appendChild(style);

    const injectTransportControls = () => {
      if (document.getElementById("lifeRouteTransportSection")) return;
      const providerGrid = document.querySelector("#setup .providerGrid");
      const providerSection = providerGrid?.closest(".section");
      if (!providerSection) return;

      const section = document.createElement("div");
      section.className = "section";
      section.id = "lifeRouteTransportSection";
      section.innerHTML = `
        <div class="sectionHead"><h2>How are you getting around?</h2><span class="hint">used for route times</span></div>
        <div class="card">
          <div class="transportGrid" id="transportGrid"></div>
          <div class="transportCurrent" id="transportCurrent"></div>
        </div>
      `;
      providerSection.after(section);
    };

    const renderTransportControls = () => {
      injectTransportControls();
      const grid = document.getElementById("transportGrid");
      const current = document.getElementById("transportCurrent");
      if (!grid) return;
      grid.innerHTML = MODES.map(mode => `
        <button class="transportChoice ${prefs.transportMode === mode.id ? "active" : ""}" onclick="setLifeRouteTransportMode('${mode.id}')">
          <div class="transportIcon">${mode.icon}</div>
          <div class="transportName">${mode.label}</div>
          <div class="transportNote">${mode.note}</div>
        </button>
      `).join("");
      const selected = modeInfo();
      if (current) current.textContent = `${selected.icon} ${selected.label} is used when LifeRoute decides whether a route or errand fits inside a gap.`;
    };

    window.setLifeRouteTransportMode = function setLifeRouteTransportMode(mode) {
      if (!validModes.has(mode)) return;
      prefs.transportMode = mode;
      persist();
      renderTransportControls();
      const selected = modeInfo();
      if (typeof setStatus === "function") setStatus(`Travel mode · ${selected.label}`);
      if (typeof refreshRouteTimes === "function") refreshRouteTimes();
    };

    // Attach the selected travel mode to all route requests without requiring
    // each feature layer (calendar routes, To-Dos, grocery branches) to duplicate it.
    const originalPostNative = window.postNative;
    if (typeof originalPostNative === "function" && !originalPostNative.__lifeRouteTransportWrapped) {
      const wrappedPostNative = function postNativeWithTransport(payload) {
        if (!payload || typeof payload !== "object") return originalPostNative(payload);
        const next = { ...payload };
        if (next.action === "requestRouteTimes") {
          next.segments = (Array.isArray(next.segments) ? next.segments : []).map(segment => ({
            ...segment,
            transportMode: prefs.transportMode || "driving"
          }));
        }
        if (next.action === "openRoute") {
          next.transportMode = prefs.transportMode || "driving";
        }
        return originalPostNative(next);
      };
      wrappedPostNative.__lifeRouteTransportWrapped = true;
      window.postNative = wrappedPostNative;
    }

    // Show the current travel mode beside the selected maps provider.
    const originalProviderLabel = window.providerLabel;
    if (typeof originalProviderLabel === "function" && !originalProviderLabel.__lifeRouteTransportWrapped) {
      const wrappedProviderLabel = function providerLabelWithTransport() {
        const base = originalProviderLabel();
        return `${base} · ${modeInfo().label}`;
      };
      wrappedProviderLabel.__lifeRouteTransportWrapped = true;
      window.providerLabel = wrappedProviderLabel;
    }

    renderTransportControls();
    if (typeof renderProvider === "function") renderProvider();
  };

  if (document.readyState === "loading") {
    window.addEventListener("DOMContentLoaded", initTransportMode);
  } else {
    initTransportMode();
  }
})();
