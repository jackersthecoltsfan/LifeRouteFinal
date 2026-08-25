// LifeRoute planned-stop duration controls.
// Lets users set the likely dwell time for boundary and between-event stops.
(() => {
  if (window.__lifeRouteStopDurationV1Loaded) return;
  window.__lifeRouteStopDurationV1Loaded = true;

  const BOUNDARY_STORE = "liferoute_boundary_stops_v2";
  const GAP_STORE = "liferoute_selected_gap_routes_v2";
  const GENERATED_STORE = "liferoute_generated_days_v1";
  const PRESETS = [5, 10, 15, 20, 30, 45, 60];
  const clean = value => String(value || "").trim();
  const readObject = key => {
    try {
      const parsed = JSON.parse(localStorage.getItem(key) || "{}");
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
    } catch (_) { return {}; }
  };
  const writeObject = (key, value) => {
    try { localStorage.setItem(key, JSON.stringify(value || {})); } catch (_) {}
  };
  const currentDay = () => clean(window.selectedDate || "");
  const boundaryKey = mode => `${currentDay()}|${clean(mode)}`;
  const activeGeneratedDay = day => !!readObject(GENERATED_STORE)[day];

  let state = null;
  let suppressAutoPrompt = false;

  const ensureSheet = () => {
    let overlay = document.getElementById("lifeRouteStopDurationSheet");
    if (overlay) return overlay;
    overlay = document.createElement("div");
    overlay.id = "lifeRouteStopDurationSheet";
    overlay.className = "lrStopDurationOverlay";
    overlay.innerHTML = `
      <div class="lrStopDurationSheet" role="dialog" aria-modal="true" aria-labelledby="lrStopDurationTitle">
        <div class="lrStopDurationHandle"></div>
        <div class="lrStopDurationHead">
          <div class="grow">
            <div class="small lrStopDurationKicker">STOP LENGTH</div>
            <div class="title" id="lrStopDurationTitle">How long will you likely be here?</div>
            <div class="meta" id="lrStopDurationName">Planned stop</div>
          </div>
          <button type="button" class="lrStopDurationClose" data-lr-stop-duration-close aria-label="Close">×</button>
        </div>
        <div class="lrStopDurationPresets" id="lrStopDurationPresets"></div>
        <div class="lrStopDurationCustom">
          <label for="lrStopDurationCustomInput">Custom minutes</label>
          <div><input id="lrStopDurationCustomInput" type="number" inputmode="numeric" min="1" max="240" step="1" placeholder="e.g. 5"><button type="button" class="secondary" data-lr-stop-duration-custom>Set</button></div>
        </div>
        <div class="tiny lrStopDurationHint">LifeRoute uses this time when calculating when you need to leave for the next appointment.</div>
      </div>`;
    document.body.appendChild(overlay);
    return overlay;
  };

  const styles = document.createElement("style");
  styles.id = "lifeRouteStopDurationV1Styles";
  styles.textContent = `
    .lrStopDurationOverlay{position:fixed;inset:0;z-index:67000;display:none;align-items:flex-end;justify-content:center;padding:10px;background:rgba(2,7,14,.72);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px)}
    .lrStopDurationOverlay.show{display:flex}.lrStopDurationSheet{width:min(560px,100%);padding:16px;border:1px solid var(--line);border-radius:24px 24px 18px 18px;background:color-mix(in srgb,var(--panel) 97%,#07111f);box-shadow:0 30px 90px rgba(0,0,0,.5)}
    .lrStopDurationHandle{width:42px;height:4px;border-radius:99px;background:var(--line);margin:0 auto 13px}.lrStopDurationHead{display:flex;align-items:flex-start;gap:10px}.lrStopDurationKicker{font-size:8px!important;font-weight:950;letter-spacing:.12em;color:var(--gold)!important}.lrStopDurationHead .title{font-size:18px!important;line-height:1.15}.lrStopDurationHead .meta{margin-top:4px;font-size:10px!important}
    .lrStopDurationClose{width:44px;height:44px;min-height:44px!important;padding:0!important;border-radius:999px!important;border:1px solid var(--line);background:var(--panel2);color:var(--text);font-size:22px}.lrStopDurationPresets{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-top:16px}.lrStopDurationPreset{min-height:48px!important;border:1px solid var(--line);border-radius:13px;background:var(--panel2);color:var(--text);font-weight:900}.lrStopDurationPreset.active{border-color:var(--gold);box-shadow:inset 0 0 0 1px var(--gold);color:var(--gold)}
    .lrStopDurationCustom{margin-top:12px;padding-top:12px;border-top:1px solid var(--line)}.lrStopDurationCustom label{font-size:9px;color:var(--muted);margin-bottom:6px}.lrStopDurationCustom>div{display:grid;grid-template-columns:1fr auto;gap:8px}.lrStopDurationCustom input{min-height:44px!important}.lrStopDurationCustom button{min-width:72px;min-height:44px!important}.lrStopDurationHint{margin-top:10px;color:var(--muted);line-height:1.4}
    .lrPlannedDurationButton{min-height:36px!important;padding:7px 10px!important;font-size:9px!important;color:var(--gold)!important;border-color:color-mix(in srgb,var(--gold) 34%,var(--line))!important}
    @media(max-width:520px){.lrStopDurationOverlay{padding:7px}.lrStopDurationSheet{padding:14px}.lrStopDurationPresets{grid-template-columns:repeat(4,1fr);gap:6px}.lrStopDurationPreset{min-height:46px!important;padding:7px 5px!important}}
  `;
  document.head.appendChild(styles);

  const close = () => {
    const overlay = document.getElementById("lifeRouteStopDurationSheet");
    overlay?.classList.remove("show");
    state = null;
  };

  const refreshGeneratedDay = () => {
    const day = currentDay();
    if (!day || !activeGeneratedDay(day)) return;
    setTimeout(() => {
      try { window.generateLifeRouteDay?.(); } catch (_) {}
    }, 40);
  };

  const redraw = kind => {
    if (kind === "boundary") {
      try { window.renderToday?.(); } catch (_) {}
      requestAnimationFrame(() => window.decorateLifeRouteBoundaryStops?.());
    } else {
      try { window.renderToday?.(); } catch (_) {}
      requestAnimationFrame(() => window.decorateLifeRouteSelectedGaps?.());
    }
    setTimeout(decorateCards, 70);
  };

  const applyMinutes = value => {
    if (!state) return;
    const minutes = Math.max(1, Math.min(240, Math.round(Number(value || 0))));
    if (!minutes) return;
    const storeKey = state.kind === "boundary" ? BOUNDARY_STORE : GAP_STORE;
    const data = readObject(storeKey);
    const selection = data[state.key];
    if (!selection) { close(); return; }
    selection.stopMinutes = minutes;
    selection.durationUpdatedAt = new Date().toISOString();
    data[state.key] = selection;
    writeObject(storeKey, data);
    close();
    redraw(state?.kind || "boundary");
    refreshGeneratedDay();
  };

  const open = (kind, key, label) => {
    const storeKey = kind === "boundary" ? BOUNDARY_STORE : GAP_STORE;
    const data = readObject(storeKey);
    const selection = data[key];
    if (!selection) return false;
    state = { kind, key };
    const overlay = ensureSheet();
    const name = overlay.querySelector("#lrStopDurationName");
    if (name) name.textContent = clean(label || selection.label || selection.name || "Planned stop");
    const current = Math.max(1, Number(selection.stopMinutes || 5));
    const presets = overlay.querySelector("#lrStopDurationPresets");
    if (presets) presets.innerHTML = PRESETS.map(minutes => `<button type="button" class="lrStopDurationPreset${minutes === current ? " active" : ""}" data-lr-stop-duration-minutes="${minutes}">${minutes} min</button>`).join("");
    const custom = overlay.querySelector("#lrStopDurationCustomInput");
    if (custom) custom.value = PRESETS.includes(current) ? "" : String(current);
    overlay.classList.add("show");
    return true;
  };

  const decorateCards = () => {
    document.querySelectorAll("#timeline .lrBoundaryGap[data-boundary-mode]").forEach(card => {
      if (!card.classList.contains("lrBoundaryPlanned") || card.querySelector("[data-lr-boundary-duration]")) return;
      const key = boundaryKey(card.dataset.boundaryMode);
      const selection = readObject(BOUNDARY_STORE)[key];
      if (!selection) return;
      const actions = card.querySelector(".lrBoundaryPlanActions");
      if (!actions) return;
      const button = document.createElement("button");
      button.type = "button";
      button.className = "secondary lrPlannedDurationButton";
      button.dataset.lrBoundaryDuration = key;
      button.textContent = `${Math.max(1, Number(selection.stopMinutes || 5))} min stop`;
      actions.insertBefore(button, actions.firstChild);
    });

    document.querySelectorAll("#timeline .gapRouteSelected[data-selected-route-key],#timeline .gapRouteSelected").forEach(card => {
      if (card.querySelector("[data-lr-gap-duration]")) return;
      const key = clean(card.dataset.selectedRouteKey);
      const selection = readObject(GAP_STORE)[key];
      if (!key || !selection) return;
      const actions = card.querySelector(".selectedGapActions");
      if (!actions) return;
      const button = document.createElement("button");
      button.type = "button";
      button.className = "secondary lrPlannedDurationButton";
      button.dataset.lrGapDuration = key;
      button.textContent = `${Math.max(1, Number(selection.stopMinutes || 5))} min stop`;
      actions.insertBefore(button, actions.firstChild);
    });
  };

  const wrapBoundarySave = () => {
    const original = window.lifeRouteSaveBoundaryStop;
    if (typeof original !== "function" || original.__lrDurationWrapped) return;
    const wrapped = function(mode, stop) {
      const result = original.apply(this, arguments);
      if (result !== false && !suppressAutoPrompt) {
        const key = `${currentDay()}|${clean(mode)}`;
        const label = clean(stop?.name || stop?.label || "Planned stop");
        setTimeout(() => open("boundary", key, label), 30);
      }
      return result;
    };
    wrapped.__lrDurationWrapped = true;
    window.lifeRouteSaveBoundaryStop = wrapped;
  };

  document.addEventListener("click", event => {
    const closeButton = event.target.closest?.("[data-lr-stop-duration-close]");
    if (closeButton) { event.preventDefault(); close(); return; }
    const preset = event.target.closest?.("[data-lr-stop-duration-minutes]");
    if (preset) { event.preventDefault(); applyMinutes(preset.dataset.lrStopDurationMinutes); return; }
    const customButton = event.target.closest?.("[data-lr-stop-duration-custom]");
    if (customButton) { event.preventDefault(); applyMinutes(document.getElementById("lrStopDurationCustomInput")?.value); return; }
    const boundaryButton = event.target.closest?.("[data-lr-boundary-duration]");
    if (boundaryButton) { event.preventDefault(); event.stopImmediatePropagation(); open("boundary", boundaryButton.dataset.lrBoundaryDuration, "Planned stop"); return; }
    const gapButton = event.target.closest?.("[data-lr-gap-duration]");
    if (gapButton) { event.preventDefault(); event.stopImmediatePropagation(); open("gap", gapButton.dataset.lrGapDuration, "Planned stop"); return; }
  }, true);

  document.addEventListener("keydown", event => {
    if (event.key === "Escape" && document.getElementById("lifeRouteStopDurationSheet")?.classList.contains("show")) close();
  });

  const overlay = ensureSheet();
  overlay.addEventListener("click", event => { if (event.target === overlay) close(); });

  let queued = false;
  const install = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      wrapBoundarySave();
      decorateCards();
    });
  };
  const timeline = document.getElementById("timeline");
  if (timeline) new MutationObserver(install).observe(timeline, { childList: true, subtree: true });
  [0, 100, 350, 900].forEach(delay => setTimeout(install, delay));

  window.LifeRouteStopDurationV1 = { open, applyMinutes, decorateCards };
})();
