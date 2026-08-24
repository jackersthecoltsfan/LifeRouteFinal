// LifeRoute field tools: quick notes, visual timer, First/Then, and session plan builder.
// Local-first utilities for direct session work. No cloud service is used by this module.
(() => {
  const STORE = "liferoute_field_tools_v1";
  let state = { notes: [], lastPlan: null };
  try {
    const parsed = JSON.parse(localStorage.getItem(STORE) || "{}");
    state = {
      notes: Array.isArray(parsed.notes) ? parsed.notes : [],
      lastPlan: parsed.lastPlan || null
    };
  } catch (_) {}

  const save = () => localStorage.setItem(STORE, JSON.stringify(state));
  const safe = value => typeof esc === "function" ? esc(String(value || "")) : String(value || "");
  const icon = (name, size = 15) => typeof window.lifeRouteIcon === "function" ? window.lifeRouteIcon(name, size) : "";
  const fmtPair = value => {
    const letters = String(value || "").replace(/[^a-z]/gi, "").slice(0, 2);
    return letters ? letters.charAt(0).toUpperCase() + letters.slice(1).toLowerCase() : "";
  };
  const clientCode = client => `${fmtPair(client?.first2)}${fmtPair(client?.last2)}`;
  const clientOptions = () => {
    const clients = typeof prefs !== "undefined" && Array.isArray(prefs.clients) ? prefs.clients : [];
    const codes = clients.map(clientCode).filter(code => code.length === 4);
    return ['<option value="">General / no client</option>']
      .concat(codes.map(code => `<option value="${safe(code)}">${safe(code)}</option>`))
      .join("");
  };
  const timeLabel = date => new Date(date).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  const dateLabel = date => new Date(date).toLocaleDateString("en-US", { month: "short", day: "numeric" });

  const ensureTab = () => {
    if (document.querySelector('.tab[data-view="tools"]')) return;
    const tabs = document.querySelector(".tabs");
    const setupTab = tabs?.querySelector('.tab[data-view="setup"]');
    if (!tabs) return;
    const button = document.createElement("button");
    button.className = "tab";
    button.dataset.view = "tools";
    button.innerHTML = `${icon("briefcase", 14)} <span>Tools</span>`;
    if (setupTab) tabs.insertBefore(button, setupTab);
    else tabs.appendChild(button);
    button.onclick = () => typeof showView === "function" ? showView("tools") : null;
  };

  const ensureView = () => {
    if (document.getElementById("tools")) return;
    const setup = document.getElementById("setup");
    if (!setup) return;
    const section = document.createElement("section");
    section.id = "tools";
    section.className = "view";
    section.innerHTML = `
      <div class="hero fieldToolsHero">
        <div class="small fieldToolsKicker">DIRECT SESSION TOOLKIT</div>
        <h2>Fast tools for the session itself.</h2>
        <p>Everything here runs locally in LifeRoute: a visual timer, quick scratch notes, First/Then support, and a simple session-plan organizer.</p>
        <div class="sourceLine"><span class="chip on">${icon("briefcase", 13)} Field tools</span><span class="chip">${icon("home", 13)} Local-first</span></div>
      </div>

      <div class="toolGrid">
        <div class="card toolCard" id="visualTimerTool">
          <div class="toolHead"><div class="toolIcon">${icon("clock", 20)}</div><div class="grow"><div class="title">Visual timer</div><div class="meta">Large countdown with an optional iPhone alert when time is up.</div></div></div>
          <div class="timerPresetRow">
            <button class="secondary timerPreset" data-minutes="1">1m</button>
            <button class="secondary timerPreset" data-minutes="2">2m</button>
            <button class="secondary timerPreset" data-minutes="3">3m</button>
            <button class="secondary timerPreset" data-minutes="5">5m</button>
            <button class="secondary timerPreset" data-minutes="10">10m</button>
          </div>
          <div class="toolInline"><input id="timerCustomMinutes" type="number" min="1" max="180" value="5" inputmode="numeric"><button class="goldButton" id="timerStartButton">Start timer</button></div>
          <div class="tiny">The countdown stays accurate after returning from another app because it uses an absolute end time.</div>
        </div>

        <div class="card toolCard" id="quickNotesTool">
          <div class="toolHead"><div class="toolIcon">${icon("check", 20)}</div><div class="grow"><div class="title">Quick session notes</div><div class="meta">Timestamped scratch notes you can use later when writing documentation.</div></div></div>
          <div class="toolInline">
            <select id="quickNoteClient">${clientOptions()}</select>
            <button class="secondary" id="refreshToolClients">Refresh clients</button>
          </div>
          <textarea id="quickNoteText" class="toolTextarea" rows="4" placeholder="Quick observation, caregiver update, target to remember, question for supervisor…"></textarea>
          <div class="toolActions"><button class="goldButton" id="saveQuickNote">${icon("check", 14)} Save note</button><button class="secondary" id="clearQuickNote">Clear</button></div>
          <div id="quickNoteList" class="quickNoteList"></div>
        </div>

        <div class="card toolCard" id="firstThenTool">
          <div class="toolHead"><div class="toolIcon">${icon("route", 20)}</div><div class="grow"><div class="title">First / Then</div><div class="meta">Instant full-screen visual support using simple text.</div></div></div>
          <div class="grid2">
            <div><label>First</label><input id="firstThenFirst" placeholder="First activity"></div>
            <div><label>Then</label><input id="firstThenThen" placeholder="Then activity"></div>
          </div>
          <div class="toolActions"><button class="goldButton" id="showFirstThen">Show board</button><button class="secondary" id="swapFirstThen">Swap</button></div>
        </div>

        <div class="card toolCard" id="sessionPlanTool">
          <div class="toolHead"><div class="toolIcon">${icon("week", 20)}</div><div class="grow"><div class="title">Session plan builder</div><div class="meta">Organize supervisor-approved targets into a practical session flow.</div></div></div>
          <div class="grid2">
            <div><label>Client</label><select id="sessionPlanClient">${clientOptions()}</select></div>
            <div><label>Session length</label><select id="sessionPlanMinutes"><option value="60" selected>1 hour</option><option value="90">1.5 hours</option><option value="120">2 hours</option><option value="180">3 hours</option><option value="240">4 hours</option></select></div>
          </div>
          <label style="margin-top:9px">Supervisor-approved targets / priorities</label>
          <textarea id="sessionPlanTargets" class="toolTextarea" rows="3" placeholder="Enter targets, separated by semicolons…"></textarea>
          <label style="margin-top:9px">Known reinforcers / useful activities</label>
          <textarea id="sessionPlanReinforcers" class="toolTextarea" rows="2" placeholder="Enter preferred activities or reinforcers…"></textarea>
          <div class="toolActions"><button class="goldButton" id="generateSessionPlan">${icon("sparkles", 14)} Build plan</button></div>
          <div class="notice toolClinicalNote">Use only goals, prompting procedures, reinforcement plans, and behavior protocols already authorized by the supervising clinician.</div>
          <div id="sessionPlanOutput"></div>
        </div>
      </div>`;

    setup.parentNode.insertBefore(section, setup);
  };

  // ----- Quick notes -----
  const renderNotes = () => {
    const host = document.getElementById("quickNoteList");
    if (!host) return;
    const recent = state.notes.slice(-8).reverse();
    if (!recent.length) {
      host.innerHTML = '<div class="tiny toolEmpty">No scratch notes yet.</div>';
      return;
    }
    host.innerHTML = recent.map(note => `
      <div class="quickNoteItem">
        <div class="quickNoteMeta"><span>${safe(note.client || "General")}</span><span>${safe(dateLabel(note.createdAt))} · ${safe(timeLabel(note.createdAt))}</span></div>
        <div class="quickNoteBody">${safe(note.text)}</div>
        <button class="quickNoteDelete" data-note-id="${safe(note.id)}" aria-label="Delete note">×</button>
      </div>`).join("");
    host.querySelectorAll(".quickNoteDelete").forEach(button => {
      button.onclick = () => {
        state.notes = state.notes.filter(note => note.id !== button.dataset.noteId);
        save();
        renderNotes();
      };
    });
  };

  const refreshClientSelects = () => {
    ["quickNoteClient", "sessionPlanClient"].forEach(id => {
      const select = document.getElementById(id);
      if (!select) return;
      const current = select.value;
      select.innerHTML = clientOptions();
      if (Array.from(select.options).some(option => option.value === current)) select.value = current;
    });
  };

  // ----- Visual timer -----
  let timer = {
    deadline: 0,
    durationMs: 0,
    remainingMs: 0,
    running: false,
    interval: 0
  };

  const ensureTimerOverlay = () => {
    let overlay = document.getElementById("visualTimerOverlay");
    if (overlay) return overlay;
    overlay = document.createElement("div");
    overlay.id = "visualTimerOverlay";
    overlay.className = "visualTimerOverlay";
    overlay.innerHTML = `
      <div class="visualTimerChrome">
        <button class="timerChromeButton" id="timerClose">${icon("check", 18)}</button>
        <div class="small">VISUAL TIMER</div>
        <button class="timerChromeButton" id="timerReset">Reset</button>
      </div>
      <div class="visualTimerCenter">
        <div class="visualTimerRing" id="visualTimerRing"><div class="visualTimerValue" id="visualTimerValue">5:00</div></div>
        <div class="visualTimerMessage" id="visualTimerMessage">Time remaining</div>
        <div class="visualTimerActions"><button class="goldButton" id="timerPauseResume">Pause</button><button class="secondary" id="timerPlusMinute">+1 minute</button></div>
      </div>`;
    document.body.appendChild(overlay);
    overlay.querySelector("#timerClose").onclick = () => overlay.classList.remove("show");
    overlay.querySelector("#timerReset").onclick = resetTimer;
    overlay.querySelector("#timerPauseResume").onclick = () => timer.running ? pauseTimer() : resumeTimer();
    overlay.querySelector("#timerPlusMinute").onclick = () => {
      if (timer.running) timer.deadline += 60000;
      else timer.remainingMs += 60000;
      timer.durationMs += 60000;
      scheduleTimerAlert();
      tickTimer();
    };
    return overlay;
  };

  const remainingMs = () => timer.running ? Math.max(0, timer.deadline - Date.now()) : Math.max(0, timer.remainingMs);
  const timerText = ms => {
    const seconds = Math.ceil(ms / 1000);
    const min = Math.floor(seconds / 60);
    const sec = seconds % 60;
    return `${min}:${String(sec).padStart(2, "0")}`;
  };
  const scheduleTimerAlert = () => {
    const ms = remainingMs();
    if (typeof postNative === "function") postNative({
      action: "scheduleToolTimer",
      seconds: timer.running && ms > 0 ? Math.ceil(ms / 1000) : 0,
      title: "Visual timer complete",
      body: "Time is up."
    });
  };
  const tickTimer = () => {
    const overlay = ensureTimerOverlay();
    const ms = remainingMs();
    const value = overlay.querySelector("#visualTimerValue");
    const ring = overlay.querySelector("#visualTimerRing");
    const message = overlay.querySelector("#visualTimerMessage");
    const pause = overlay.querySelector("#timerPauseResume");
    if (value) value.textContent = timerText(ms);
    const progress = timer.durationMs > 0 ? Math.max(0, Math.min(1, ms / timer.durationMs)) : 0;
    if (ring) ring.style.setProperty("--timer-progress", `${progress * 360}deg`);
    if (pause) pause.textContent = timer.running ? "Pause" : "Resume";

    if (timer.running && ms <= 0) {
      timer.running = false;
      timer.remainingMs = 0;
      if (message) message.textContent = "Time is up";
      if (ring) ring.classList.add("complete");
      if (timer.interval) clearInterval(timer.interval);
      timer.interval = 0;
      if (navigator.vibrate) navigator.vibrate([180, 80, 180]);
    } else {
      if (message) message.textContent = timer.running ? "Time remaining" : "Paused";
      if (ring) ring.classList.remove("complete");
    }
  };
  const startTimer = minutes => {
    const value = Math.max(1, Math.min(180, Number(minutes || 5)));
    timer.durationMs = value * 60000;
    timer.remainingMs = timer.durationMs;
    timer.deadline = Date.now() + timer.durationMs;
    timer.running = true;
    const overlay = ensureTimerOverlay();
    overlay.classList.add("show");
    if (timer.interval) clearInterval(timer.interval);
    timer.interval = setInterval(tickTimer, 250);
    scheduleTimerAlert();
    tickTimer();
  };
  function pauseTimer() {
    timer.remainingMs = remainingMs();
    timer.running = false;
    scheduleTimerAlert();
    tickTimer();
  }
  function resumeTimer() {
    if (timer.remainingMs <= 0) return;
    timer.deadline = Date.now() + timer.remainingMs;
    timer.running = true;
    if (!timer.interval) timer.interval = setInterval(tickTimer, 250);
    scheduleTimerAlert();
    tickTimer();
  }
  function resetTimer() {
    timer.running = false;
    timer.remainingMs = timer.durationMs || 5 * 60000;
    if (timer.interval) clearInterval(timer.interval);
    timer.interval = 0;
    scheduleTimerAlert();
    tickTimer();
  }

  // ----- First / Then -----
  const ensureFirstThenOverlay = () => {
    let overlay = document.getElementById("firstThenOverlay");
    if (overlay) return overlay;
    overlay = document.createElement("div");
    overlay.id = "firstThenOverlay";
    overlay.className = "firstThenOverlay";
    overlay.innerHTML = `
      <div class="firstThenTop"><button class="secondary" id="firstThenClose">Close</button><div class="small">FIRST / THEN</div><div style="width:64px"></div></div>
      <div class="firstThenBoard">
        <div class="firstThenPanel firstPanel"><div class="firstThenLabel">FIRST</div><div class="firstThenValue" id="firstThenFirstValue"></div></div>
        <div class="firstThenArrow">${icon("navigation", 42)}</div>
        <div class="firstThenPanel thenPanel"><div class="firstThenLabel">THEN</div><div class="firstThenValue" id="firstThenThenValue"></div></div>
      </div>`;
    document.body.appendChild(overlay);
    overlay.querySelector("#firstThenClose").onclick = () => overlay.classList.remove("show");
    return overlay;
  };

  // ----- Session plan -----
  const splitList = text => String(text || "").split(/[;\n]+/).map(value => value.trim()).filter(Boolean);
  const buildPlan = (minutes, targets, reinforcers) => {
    const total = Math.max(30, Number(minutes || 120));
    const warm = Math.max(8, Math.round(total * .10));
    const close = Math.max(8, Math.round(total * .08));
    const movement = Math.max(8, Math.round(total * .10));
    const core = Math.max(10, total - warm - close - movement);
    const firstCore = Math.round(core * .52);
    const secondCore = core - firstCore;
    const targetText = targets.length ? targets.join(" · ") : "Add supervisor-approved targets";
    const reinforcerText = reinforcers.length ? reinforcers.join(" · ") : "Use approved reinforcers / movement as appropriate";
    let cursor = 0;
    const block = (duration, title, detail) => {
      const start = cursor;
      cursor += duration;
      return { start, end: cursor, title, detail };
    };
    return [
      block(warm, "Pairing + regulation check", "Pair, observe readiness, review visual supports, and establish momentum."),
      block(firstCore, "Teaching / NET block", targetText),
      block(movement, "Reinforcement + movement", reinforcerText),
      block(secondCore, "Generalization + target practice", targetText),
      block(close, "Transition + wrap-up", "Finish planned transitions, organize quick notes/data, and prepare caregiver/supervisor handoff.")
    ];
  };

  const renderPlan = planState => {
    const host = document.getElementById("sessionPlanOutput");
    if (!host || !planState) return;
    host.innerHTML = `
      <div class="sessionPlanResult">
        <div class="row"><div><div class="small">SESSION FLOW</div><div class="title">${safe(planState.client || "General session")} · ${safe(planState.minutes)} min</div></div><span class="badge green">Draft</span></div>
        <div class="sessionPlanBlocks">${planState.blocks.map(block => `
          <div class="sessionPlanBlock"><div class="sessionPlanTime">${block.start}–${block.end}m</div><div><b>${safe(block.title)}</b><div class="tiny">${safe(block.detail)}</div></div></div>`).join("")}</div>
      </div>`;
  };

  const bind = () => {
    document.querySelectorAll(".timerPreset").forEach(button => {
      button.onclick = () => {
        const minutes = Number(button.dataset.minutes || 5);
        const input = document.getElementById("timerCustomMinutes");
        if (input) input.value = String(minutes);
        startTimer(minutes);
      };
    });
    document.getElementById("timerStartButton")?.addEventListener("click", () => {
      startTimer(Number(document.getElementById("timerCustomMinutes")?.value || 5));
    });

    document.getElementById("refreshToolClients")?.addEventListener("click", refreshClientSelects);
    document.getElementById("saveQuickNote")?.addEventListener("click", () => {
      const text = String(document.getElementById("quickNoteText")?.value || "").trim();
      if (!text) return;
      state.notes.push({
        id: `note-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
        client: String(document.getElementById("quickNoteClient")?.value || ""),
        text,
        createdAt: new Date().toISOString()
      });
      state.notes = state.notes.slice(-100);
      save();
      document.getElementById("quickNoteText").value = "";
      renderNotes();
      if (typeof setStatus === "function") setStatus("Quick note saved locally");
    });
    document.getElementById("clearQuickNote")?.addEventListener("click", () => {
      const field = document.getElementById("quickNoteText");
      if (field) field.value = "";
    });

    document.getElementById("swapFirstThen")?.addEventListener("click", () => {
      const first = document.getElementById("firstThenFirst");
      const then = document.getElementById("firstThenThen");
      if (!first || !then) return;
      [first.value, then.value] = [then.value, first.value];
    });
    document.getElementById("showFirstThen")?.addEventListener("click", () => {
      const firstField = document.getElementById("firstThenFirst");
      const thenField = document.getElementById("firstThenThen");
      const first = String(firstField?.value || "").trim();
      const then = String(thenField?.value || "").trim();
      if (!first || !then) {
        alert("Enter both the First and Then activities.");
        return;
      }
      const overlay = ensureFirstThenOverlay();
      overlay.querySelector("#firstThenFirstValue").textContent = first;
      overlay.querySelector("#firstThenThenValue").textContent = then;
      overlay.classList.add("show");
    });

    document.getElementById("generateSessionPlan")?.addEventListener("click", () => {
      const minutes = Number(document.getElementById("sessionPlanMinutes")?.value || 60);
      const targets = splitList(document.getElementById("sessionPlanTargets")?.value);
      const reinforcers = splitList(document.getElementById("sessionPlanReinforcers")?.value);
      const planState = {
        client: String(document.getElementById("sessionPlanClient")?.value || ""),
        minutes,
        targets,
        reinforcers,
        blocks: buildPlan(minutes, targets, reinforcers),
        createdAt: new Date().toISOString()
      };
      state.lastPlan = planState;
      save();
      renderPlan(planState);
      if (typeof setStatus === "function") setStatus("Session plan draft ready");
    });
  };

  const style = document.createElement("style");
  style.id = "fieldToolStyles";
  style.textContent = `
    .tabs{grid-template-columns:repeat(5,minmax(0,1fr))!important}.tab[data-view="tools"]{display:flex;align-items:center;justify-content:center;gap:5px}.fieldToolsKicker{font-size:8px!important;letter-spacing:.13em;font-weight:950!important;color:var(--gold)!important;margin-bottom:4px}.toolGrid{display:grid;grid-template-columns:1fr 1fr;gap:9px}.toolCard{margin:0!important}.toolHead{display:flex;gap:10px;align-items:center;margin-bottom:10px}.toolIcon{width:38px;height:38px;border-radius:12px;display:grid;place-items:center;background:color-mix(in srgb,var(--blue) 8%,var(--panel2));border:1px solid color-mix(in srgb,var(--line) 80%,transparent);color:var(--blue)}
    .timerPresetRow{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:8px}.timerPresetRow button{padding:7px 9px;font-size:10px}.toolInline{display:grid;grid-template-columns:1fr auto;gap:7px;align-items:center}.toolActions{display:flex;gap:7px;flex-wrap:wrap;margin-top:8px}.toolActions button{display:inline-flex;align-items:center;gap:6px}.toolTextarea{width:100%;resize:vertical;background:color-mix(in srgb,var(--panel2) 86%,transparent);color:var(--text);border:1px solid var(--line);border-radius:11px;padding:10px 11px;outline:none;font:inherit;font-size:12px;line-height:1.45}.toolTextarea:focus{border-color:var(--blue);box-shadow:0 0 0 3px color-mix(in srgb,var(--blue) 13%,transparent)}
    .quickNoteList{display:grid;gap:6px;margin-top:10px}.quickNoteItem{position:relative;padding:9px 30px 9px 10px;border-radius:12px;border:1px solid color-mix(in srgb,var(--line) 72%,transparent);background:color-mix(in srgb,var(--panel2) 67%,transparent)}.quickNoteMeta{display:flex;justify-content:space-between;gap:8px;font-size:8px;font-weight:900;color:var(--gold);text-transform:uppercase;letter-spacing:.05em}.quickNoteBody{font-size:11px;line-height:1.45;margin-top:4px;white-space:pre-wrap}.quickNoteDelete{position:absolute;right:6px;top:6px;width:24px;height:24px;padding:0;border-radius:8px;background:transparent;color:var(--muted)}.toolEmpty{padding:8px 2px}.toolClinicalNote{margin-top:9px!important}
    .visualTimerOverlay,.firstThenOverlay{position:fixed;inset:0;z-index:12000;background:linear-gradient(145deg,color-mix(in srgb,var(--bg) 96%,black),color-mix(in srgb,var(--bg2) 94%,black));display:none;color:var(--text);padding:calc(16px + env(safe-area-inset-top)) 16px calc(18px + env(safe-area-inset-bottom))}.visualTimerOverlay.show,.firstThenOverlay.show{display:block}.visualTimerChrome,.firstThenTop{display:grid;grid-template-columns:64px 1fr 64px;align-items:center;text-align:center}.timerChromeButton{background:transparent;color:var(--muted);padding:8px;font-size:10px}.visualTimerCenter{height:calc(100% - 60px);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:18px}.visualTimerRing{--timer-progress:360deg;width:min(72vw,360px);aspect-ratio:1;border-radius:50%;display:grid;place-items:center;position:relative;background:conic-gradient(var(--gold) 0 var(--timer-progress),color-mix(in srgb,var(--panel2) 82%,transparent) var(--timer-progress) 360deg);box-shadow:0 26px 90px rgba(0,0,0,.28)}.visualTimerRing:after{content:"";position:absolute;inset:15px;border-radius:50%;background:radial-gradient(circle at 36% 28%,color-mix(in srgb,var(--blue) 13%,transparent),transparent 40%),var(--bg)}.visualTimerRing.complete{background:conic-gradient(var(--green) 0 360deg)}.visualTimerValue{position:relative;z-index:1;font-size:clamp(54px,17vw,92px);font-weight:900;letter-spacing:-4px}.visualTimerMessage{font-size:13px;color:var(--muted);font-weight:850}.visualTimerActions{display:flex;gap:8px}
    .firstThenBoard{height:calc(100% - 70px);display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:16px;max-width:1000px;margin:auto}.firstThenPanel{min-height:54vh;border-radius:30px;border:1px solid color-mix(in srgb,var(--line) 85%,transparent);display:flex;flex-direction:column;align-items:center;justify-content:center;padding:28px;text-align:center;box-shadow:0 28px 90px rgba(0,0,0,.25)}.firstPanel{background:linear-gradient(145deg,color-mix(in srgb,var(--blue) 22%,var(--panel)),var(--panel))}.thenPanel{background:linear-gradient(145deg,color-mix(in srgb,var(--gold) 18%,var(--panel)),var(--panel))}.firstThenLabel{font-size:13px;letter-spacing:.16em;font-weight:950;color:var(--muted);margin-bottom:20px}.firstThenValue{font-size:clamp(34px,8vw,74px);line-height:1.05;font-weight:900;letter-spacing:-2px}.firstThenArrow{color:var(--gold)}
    .sessionPlanResult{margin-top:10px;padding-top:10px;border-top:1px solid var(--line)}.sessionPlanBlocks{display:grid;gap:6px;margin-top:9px}.sessionPlanBlock{display:grid;grid-template-columns:62px 1fr;gap:8px;padding:8px;border-radius:11px;background:color-mix(in srgb,var(--panel2) 66%,transparent);border:1px solid color-mix(in srgb,var(--line) 68%,transparent)}.sessionPlanTime{font-size:9px;font-weight:900;color:var(--gold)}.sessionPlanBlock b{font-size:11px}
    @media(max-width:680px){.tabs{gap:5px!important}.tab{padding:9px 4px!important;font-size:10px!important}.tab[data-view="tools"] span{display:inline}.toolGrid{grid-template-columns:1fr}.firstThenBoard{grid-template-columns:1fr;gap:9px;height:calc(100% - 60px)}.firstThenPanel{min-height:34vh;border-radius:22px}.firstThenArrow{transform:rotate(90deg);justify-self:center}.firstThenValue{font-size:clamp(34px,12vw,58px)}}
  `;
  document.head.appendChild(style);

  const start = () => {
    ensureTab();
    ensureView();
    bind();
    refreshClientSelects();
    renderNotes();
    renderPlan(state.lastPlan);
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();