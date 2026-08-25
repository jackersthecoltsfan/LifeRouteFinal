// LifeRoute planning intelligence: AI-first organization with deterministic engines
// remaining authoritative for calendar, routing, travel time, stop duration and reminders.
(() => {
  if (window.__lifeRouteAIPlanningV1Loaded) return;
  window.__lifeRouteAIPlanningV1Loaded = true;

  const safe = value => typeof window.esc === "function"
    ? window.esc(String(value || ""))
    : String(value || "").replace(/[&<>"']/g, char => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[char]));
  const split = text => String(text || "").split(/[;\n]+/).map(value => value.trim()).filter(Boolean);
  const AI_STORE = "liferoute_ai_planning_v1";
  let sessionBypass = false;
  let dayRequestToken = 0;

  const readAIStore = () => {
    try { return JSON.parse(localStorage.getItem(AI_STORE) || "{}"); } catch (_) { return {}; }
  };
  const writeAIStore = value => {
    try { localStorage.setItem(AI_STORE, JSON.stringify(value)); } catch (_) {}
  };

  const engineLabel = engine => /foundation/i.test(String(engine || "")) ? "On-device Apple AI" : "Smart fallback";

  const installSessionAI = () => {
    const button = document.getElementById("generateSessionPlan");
    if (!button || button.dataset.lrAIPlanning === "1") return;
    button.dataset.lrAIPlanning = "1";
    button.innerHTML = `${typeof window.lifeRouteIcon === "function" ? window.lifeRouteIcon("sparkles", 14) : "✦"} Build smart plan`;

    document.addEventListener("click", async event => {
      const target = event.target?.closest?.("#generateSessionPlan");
      if (!target || sessionBypass) return;
      const hooks = window.LifeRouteFieldToolsAIHooks;
      const ai = window.LifeRouteAI;
      if (!hooks?.savePlan || !ai?.sessionPlan) return;

      event.preventDefault();
      event.stopImmediatePropagation();
      const minutes = Number(document.getElementById("sessionPlanMinutes")?.value || 60);
      const targets = split(document.getElementById("sessionPlanTargets")?.value);
      const reinforcers = split(document.getElementById("sessionPlanReinforcers")?.value);
      const client = String(document.getElementById("sessionPlanClient")?.value || "");
      const original = target.innerHTML;
      target.disabled = true;
      target.textContent = "AI organizing…";
      if (typeof window.setStatus === "function") window.setStatus("On-device AI is organizing the approved session priorities…");

      try {
        const result = await ai.sessionPlan({ minutes, targets, reinforcers, client });
        if (result?.blocks?.length) {
          let cursor = 0;
          const blocks = result.blocks.map(block => {
            const start = cursor;
            cursor += Number(block.minutes || 0);
            return { start, end: cursor, title: block.title, detail: block.detail };
          });
          const planState = {
            client,
            minutes,
            targets,
            reinforcers,
            blocks,
            aiEngine: result.engine,
            createdAt: new Date().toISOString()
          };
          hooks.savePlan(planState);
          queueMicrotask(() => {
            const row = document.querySelector("#sessionPlanOutput .sessionPlanResult .row");
            if (row && !row.querySelector(".lrAIPlanBadge")) row.insertAdjacentHTML("beforeend", `<span class="badge green lrAIPlanBadge">${safe(engineLabel(result.engine))}</span>`);
          });
          if (typeof window.setStatus === "function") window.setStatus("Smart session plan ready · review before use");
          return;
        }
      } catch (_) {}

      // Deterministic existing planner remains the zero-failure fallback.
      sessionBypass = true;
      target.disabled = false;
      target.innerHTML = original;
      target.click();
      sessionBypass = false;
      if (typeof window.setStatus === "function") window.setStatus("Session plan ready · deterministic fallback used");
    }, true);
  };

  const ensureNotesAI = () => {
    const card = document.getElementById("quickNotesTool");
    if (!card || document.getElementById("aiQuickNoteRecap")) return;
    const actions = card.querySelector(".toolActions");
    if (!actions) return;
    const button = document.createElement("button");
    button.id = "aiQuickNoteRecap";
    button.type = "button";
    button.className = "secondary";
    button.textContent = "AI recap";
    actions.appendChild(button);
    const output = document.createElement("div");
    output.id = "aiQuickNoteOutput";
    output.className = "lrAIInsight";
    output.hidden = true;
    card.appendChild(output);

    button.onclick = async () => {
      let notes = [];
      try {
        const field = JSON.parse(localStorage.getItem("liferoute_field_tools_v1") || "{}");
        const selected = String(document.getElementById("quickNoteClient")?.value || "");
        notes = (Array.isArray(field.notes) ? field.notes : [])
          .filter(note => !selected || String(note?.client || "") === selected)
          .slice(-12)
          .map(note => String(note?.text || "").trim())
          .filter(Boolean);
      } catch (_) {}
      if (!notes.length) {
        if (typeof window.setStatus === "function") window.setStatus("Save a scratch note before asking for a recap");
        return;
      }
      button.disabled = true;
      button.textContent = "Summarizing…";
      try {
        const result = await window.LifeRouteAI?.summarizeNotes?.({ notes });
        output.hidden = false;
        output.innerHTML = result?.text
          ? `<div class="small">AI SCRATCH-NOTE RECAP</div><div>${safe(result.text)}</div><div class="tiny">Factual recap only · not a billable clinical note</div>`
          : `<div class="tiny">On-device language AI is unavailable on this device. Your scratch notes remain local.</div>`;
      } finally {
        button.disabled = false;
        button.textContent = "AI recap";
      }
    };
  };

  const compactEvents = plan => (plan?.blocks || []).map(block => ({
    type: block.type,
    title: block.title,
    start: block.start instanceof Date ? block.start.toISOString() : block.start,
    end: block.end instanceof Date ? block.end.toISOString() : block.end,
    address: block.address || "",
    leaveAt: block.leaveAt instanceof Date ? block.leaveAt.toISOString() : block.leaveAt,
    travelMinutes: Number(block.travelMinutes || block.travelIn || 0),
    travelOut: Number(block.travelOut || 0),
    stopMinutes: block.type === "stop" ? Math.max(0, Math.round((new Date(block.end) - new Date(block.start)) / 60000)) : 0
  }));

  const ensureDayAIHost = () => {
    const panel = document.getElementById("liveDayPanel");
    if (!panel?.classList.contains("show")) return null;
    let host = document.getElementById("lifeRouteAIDayBrief");
    if (!host) {
      host = document.createElement("div");
      host.id = "lifeRouteAIDayBrief";
      host.className = "lrAIDayBrief";
      panel.insertBefore(host, panel.querySelector(".liveDaySequence") || null);
    }
    return host;
  };

  const refreshDayAI = async () => {
    const hooks = window.LifeRouteLiveDayAIHooks;
    const date = String(window.selectedDate || "");
    if (!hooks?.buildDay || !date) return;
    const plan = hooks.buildDay(date);
    const token = ++dayRequestToken;
    const host = ensureDayAIHost();
    if (!host) return;
    host.innerHTML = `<div class="small">AI DAY + ROUTE CHECK</div><div class="tiny">Reviewing fixed calendar and computed route facts…</div>`;

    const places = (Array.isArray(window.places) ? window.places : []).filter(place => place?.member !== "no").slice(0, 14).map(place => ({
      name: place.name,
      type: place.type,
      minMinutes: Number(place.min || 0)
    }));
    const fixed = compactEvents(plan);
    const nextAction = (plan.leaveActions || []).find(action => new Date(action.time).getTime() > Date.now()) || plan.leaveActions?.[0] || null;
    const routeFacts = nextAction ? {
      title: nextAction.title,
      leaveAt: nextAction.time instanceof Date ? nextAction.time.toISOString() : nextAction.time,
      destination: nextAction.destination,
      detail: nextAction.detail,
      plannedStops: fixed.filter(item => item.type === "stop")
    } : { plannedStops: fixed.filter(item => item.type === "stop") };

    const [day, route] = await Promise.all([
      window.LifeRouteAI?.dayBrief?.({ date, events: fixed, places }),
      window.LifeRouteAI?.routeBrief?.(routeFacts)
    ]);
    if (token !== dayRequestToken) return;

    const fallback = (() => {
      const stopCount = fixed.filter(item => item.type === "stop").length;
      const actionCount = (plan.leaveActions || []).length;
      return `${actionCount ? `${actionCount} computed departure${actionCount === 1 ? "" : "s"}` : "No routed departures"}${stopCount ? ` · ${stopCount} planned stop${stopCount === 1 ? "" : "s"}` : ""}. Fixed route math remains authoritative.`;
    })();
    host.innerHTML = `
      <div class="row"><div class="small">AI DAY + ROUTE CHECK</div><span class="badge green">${safe(day?.engine ? engineLabel(day.engine) : "Smart fallback")}</span></div>
      <div class="lrAIInsightText">${safe(day?.text || fallback)}</div>
      ${route?.text ? `<div class="lrAIRouteText"><b>Route insight:</b> ${safe(route.text)}</div>` : ""}
      <div class="tiny">AI never changes calendar times, MapKit travel times, stop durations, or leave-time calculations.</div>`;

    const stored = readAIStore();
    stored[date] = { text: day?.text || fallback, route: route?.text || "", savedAt: Date.now() };
    writeAIStore(stored);
  };

  const wrapGenerateDay = () => {
    const original = window.generateLifeRouteDay;
    if (typeof original !== "function" || original.__lifeRouteAIWrapped) return;
    const wrapped = function generateLifeRouteDayWithAI(...args) {
      const result = original.apply(this, args);
      setTimeout(refreshDayAI, 40);
      return result;
    };
    wrapped.__lifeRouteAIWrapped = true;
    window.generateLifeRouteDay = wrapped;
  };

  const style = document.createElement("style");
  style.id = "lifeRouteAIPlanningStyles";
  style.textContent = `
    .lrAIInsight,.lrAIDayBrief{margin-top:10px;padding:11px 12px;border-radius:14px;border:1px solid color-mix(in srgb,var(--blue) 28%,var(--line));background:linear-gradient(145deg,color-mix(in srgb,var(--blue) 8%,var(--panel2)),color-mix(in srgb,var(--gold) 5%,var(--panel2)));font-size:11px;line-height:1.5}.lrAIDayBrief{margin:10px 0 12px}.lrAIInsightText{margin-top:6px;font-size:12px;line-height:1.5}.lrAIRouteText{margin-top:7px;padding-top:7px;border-top:1px solid var(--line);font-size:11px}.lrAIPlanBadge{margin-left:auto}
  `;
  document.head.appendChild(style);

  const install = () => {
    installSessionAI();
    ensureNotesAI();
    wrapGenerateDay();
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", install, { once: true });
  else install();

  window.addEventListener("liferoute:clients-changed", install);
  window.LifeRouteAIPlanning = { refreshDayAI, install, version: "1.0.0" };
})();
