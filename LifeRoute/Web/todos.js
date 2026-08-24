// LifeRoute To-Dos + gap-fit suggestions.
// To-dos are stored locally on-device. Location-based errands use the same native
// MapKit bridge as appointment routing to estimate previous stop -> errand -> next stop.
window.addEventListener("DOMContentLoaded", () => {
  const TODO_STORE = "liferoute_todos_v1";
  let todos = [];
  let activeGapRequest = null;
  let requestCounter = 0;

  try {
    const saved = JSON.parse(localStorage.getItem(TODO_STORE) || "[]");
    todos = Array.isArray(saved) ? saved : [];
  } catch (_) {
    todos = [];
  }
  window.lifeRouteTodos = todos;

  const saveTodos = () => {
    localStorage.setItem(TODO_STORE, JSON.stringify(todos));
    window.lifeRouteTodos = todos;
  };

  const uid = () => `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  const dueLabel = value => {
    if (!value) return "Anytime";
    const date = dateFromKey(value);
    return date.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
  };
  const priorityWeight = value => ({ high: 38, normal: 16, low: 0 })[value] ?? 16;
  const categoryEmoji = value => ({
    Errand: "🛍️", Shopping: "🛒", Chore: "🧹", Call: "📞", Pickup: "📦", Other: "✓"
  })[value] || "✓";

  const style = document.createElement("style");
  style.textContent = `
    .tabs{grid-template-columns:repeat(6,1fr)!important}
    .todoSummary{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:12px}
    .todoMetric{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:11px}
    .todoMetric b{display:block;font-size:18px}.todoMetric span{font-size:10px;color:var(--muted)}
    .todoCard.overdue{border-color:rgba(255,155,155,.45)}
    .todoCard.done{opacity:.55}
    .todoActions{display:flex;gap:7px;flex-wrap:wrap;margin-top:10px}
    .gapAction{margin-left:auto;white-space:nowrap}
    .gapSuggest{margin-top:11px;padding-top:11px;border-top:1px solid var(--line)}
    .gapSuggestHead{font-size:12px;font-weight:950;margin-bottom:8px}
    .gapOption{background:var(--panel2);border:1px solid var(--line);border-radius:13px;padding:10px;margin-top:7px}
    .gapOption.best{border-color:rgba(242,200,109,.55);box-shadow:inset 0 0 0 1px rgba(242,200,109,.13)}
    .gapOption .fit{color:var(--green);font-weight:900}.gapOption .miss{color:var(--red);font-weight:900}.gapOption .unknown{color:var(--gold);font-weight:900}
    .gapOptionButtons{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}.gapOptionButtons button{font-size:10px;padding:7px 9px}
    .gapClickable{cursor:pointer;transition:transform .12s,border-color .12s}.gapClickable:active{transform:scale(.99)}
    @media(max-width:680px){
      .tabs{grid-template-columns:repeat(3,1fr)!important}.tab{font-size:11px!important}
      .todoSummary{grid-template-columns:repeat(3,1fr)}
      .gapAction{width:100%;margin-top:7px}.card.gap .row{flex-wrap:wrap}
    }
  `;
  document.head.appendChild(style);

  // Rename the original Places tab and add To-Dos as a distinct destination.
  const tabs = document.querySelector(".tabs");
  const placesTab = tabs?.querySelector('[data-view="places"]');
  if (placesTab) placesTab.textContent = "Saved Places";
  const placesHero = document.querySelector("#places .hero h2");
  const placesHeroText = document.querySelector("#places .hero p");
  if (placesHero) placesHero.textContent = "Saved places";
  if (placesHeroText) placesHeroText.textContent = "Keep home, work, gyms, stores, cafés, parks, and other places LifeRoute can use for routing and gap suggestions.";

  if (tabs && !tabs.querySelector('[data-view="todos"]')) {
    const button = document.createElement("button");
    button.className = "tab";
    button.dataset.view = "todos";
    button.textContent = "To-Dos";
    const setup = tabs.querySelector('[data-view="setup"]');
    tabs.insertBefore(button, setup || null);
  }

  const placesSection = document.getElementById("places");
  if (!document.getElementById("todos")) {
    const section = document.createElement("section");
    section.id = "todos";
    section.className = "view";
    section.innerHTML = `
      <div class="hero">
        <h2>Things to fit into real life.</h2>
        <p>Add errands and flexible tasks that need to happen sometime soon. When you tap a gap, LifeRoute will rank what realistically fits there using task length, due date, priority, and route time.</p>
      </div>
      <div class="todoSummary">
        <div class="todoMetric"><b id="todoOpenCount">0</b><span>open</span></div>
        <div class="todoMetric"><b id="todoDueWeekCount">0</b><span>due this week</span></div>
        <div class="todoMetric"><b id="todoLocatedCount">0</b><span>route-ready</span></div>
      </div>
      <div class="section">
        <div class="sectionHead"><h2>Open to-dos</h2><span class="hint" id="todoCountHint"></span></div>
        <div id="todoList"></div>
      </div>
      <div class="section"><h2>Add a to-do</h2><div class="card">
        <div class="formgrid">
          <div class="full"><label>What needs to get done?</label><input id="todoTitle" placeholder="Task"></div>
          <div><label>Category</label><select id="todoCategory"><option>Errand</option><option>Shopping</option><option>Pickup</option><option>Chore</option><option>Call</option><option>Other</option></select></div>
          <div><label>Estimated task time</label><select id="todoDuration"><option value="10">10 min</option><option value="15">15 min</option><option value="20">20 min</option><option value="30" selected>30 min</option><option value="45">45 min</option><option value="60">1 hour</option><option value="90">1.5 hours</option></select></div>
          <div><label>Saved place (optional)</label><select id="todoSavedPlace"><option value="">Choose saved place…</option></select></div>
          <div><label>Priority</label><select id="todoPriority"><option value="normal" selected>Normal</option><option value="high">High</option><option value="low">Low</option></select></div>
          <div class="full"><label>Location / store (optional)</label><input id="todoAddress" placeholder="Address or place"></div>
          <div><label>Do by</label><input id="todoDue" type="date"></div>
          <div><label>Notes (optional)</label><input id="todoNotes" placeholder="Optional details…"></div>
        </div>
        <div class="placeActions"><button class="goldButton" onclick="addLifeRouteTodo()">Add to-do</button></div>
      </div></div>
      <div class="section" id="todoDoneSection" style="display:none">
        <div class="sectionHead"><h2>Completed</h2><span class="hint">recent</span></div>
        <div id="todoDoneList"></div>
      </div>
    `;
    placesSection?.after(section);
  }

  const populateSavedPlaces = () => {
    const select = document.getElementById("todoSavedPlace");
    if (!select) return;
    const current = select.value;
    select.innerHTML = '<option value="">Choose saved place…</option>' + places.map(place =>
      `<option value="${esc(place.id)}">${esc(place.name)} · ${esc(place.type || "Place")}</option>`
    ).join("");
    if (Array.from(select.options).some(option => option.value === current)) select.value = current;
  };

  const defaultDueDate = () => {
    const keys = typeof weekDates === "function" ? weekDates() : [];
    return keys.length ? keys[keys.length - 1] : localDateKey(new Date());
  };

  const getTodo = id => todos.find(todo => String(todo.id) === String(id));

  window.addLifeRouteTodo = function addLifeRouteTodo() {
    const title = document.getElementById("todoTitle")?.value.trim();
    if (!title) {
      alert("Add what you need to get done.");
      return;
    }
    const todo = {
      id: uid(),
      title,
      category: document.getElementById("todoCategory")?.value || "Errand",
      duration: Number(document.getElementById("todoDuration")?.value || 30),
      address: document.getElementById("todoAddress")?.value.trim() || "",
      priority: document.getElementById("todoPriority")?.value || "normal",
      dueDate: document.getElementById("todoDue")?.value || defaultDueDate(),
      notes: document.getElementById("todoNotes")?.value.trim() || "",
      completed: false,
      createdAt: new Date().toISOString()
    };
    todos.push(todo);
    saveTodos();
    ["todoTitle", "todoAddress", "todoNotes"].forEach(id => {
      const input = document.getElementById(id); if (input) input.value = "";
    });
    const savedPlace = document.getElementById("todoSavedPlace"); if (savedPlace) savedPlace.value = "";
    const due = document.getElementById("todoDue"); if (due) due.value = defaultDueDate();
    renderTodos();
    setStatus("To-do added");
  };

  window.completeLifeRouteTodo = function completeLifeRouteTodo(id) {
    const todo = getTodo(id);
    if (!todo) return;
    todo.completed = true;
    todo.completedAt = new Date().toISOString();
    saveTodos();
    renderTodos();
    renderToday();
  };

  window.reopenLifeRouteTodo = function reopenLifeRouteTodo(id) {
    const todo = getTodo(id);
    if (!todo) return;
    todo.completed = false;
    delete todo.completedAt;
    saveTodos();
    renderTodos();
    renderToday();
  };

  window.deleteLifeRouteTodo = function deleteLifeRouteTodo(id) {
    todos = todos.filter(todo => String(todo.id) !== String(id));
    window.lifeRouteTodos = todos;
    saveTodos();
    renderTodos();
    renderToday();
  };

  window.renderTodos = function renderTodos() {
    populateSavedPlaces();
    const dueInput = document.getElementById("todoDue");
    if (dueInput && !dueInput.value) dueInput.value = defaultDueDate();

    const open = todos.filter(todo => !todo.completed);
    const done = todos.filter(todo => todo.completed).slice(-8).reverse();
    const week = new Set(typeof weekDates === "function" ? weekDates() : []);
    const today = localDateKey(new Date());

    const openCount = document.getElementById("todoOpenCount");
    const dueWeekCount = document.getElementById("todoDueWeekCount");
    const locatedCount = document.getElementById("todoLocatedCount");
    const hint = document.getElementById("todoCountHint");
    if (openCount) openCount.textContent = String(open.length);
    if (dueWeekCount) dueWeekCount.textContent = String(open.filter(todo => todo.dueDate && week.has(todo.dueDate)).length);
    if (locatedCount) locatedCount.textContent = String(open.filter(todo => String(todo.address || "").trim()).length);
    if (hint) hint.textContent = `${open.length} open`;

    const list = document.getElementById("todoList");
    if (list) {
      if (!open.length) {
        list.innerHTML = '<div class="card empty">No open to-dos. Add something flexible and LifeRoute can start fitting it into gaps.</div>';
      } else {
        list.innerHTML = open.slice().sort((a, b) => {
          const pa = priorityWeight(a.priority), pb = priorityWeight(b.priority);
          if (pa !== pb) return pb - pa;
          return String(a.dueDate || "9999").localeCompare(String(b.dueDate || "9999"));
        }).map(todo => {
          const overdue = todo.dueDate && todo.dueDate < today;
          return `<div class="card todoCard ${overdue ? "overdue" : ""}">
            <div class="row"><div class="grow">
              <div class="small">${categoryEmoji(todo.category)} ${esc(todo.category || "To-do")} · ${fmt(todo.duration || 30)}${todo.priority === "high" ? " · High priority" : ""}</div>
              <div class="title">${esc(todo.title)}</div>
              <div class="meta">${todo.address ? esc(todo.address) : "Flexible / no location"}${todo.notes ? ` · ${esc(todo.notes)}` : ""}</div>
            </div><span class="badge ${overdue ? "" : "gold"}">${overdue ? "OVERDUE" : esc(dueLabel(todo.dueDate))}</span></div>
            <div class="todoActions">
              ${todo.address ? `<button class="secondary" onclick="routeTo('${encodeURIComponent(todo.address)}')">Open route</button>` : ""}
              <button class="primary" onclick="completeLifeRouteTodo('${todo.id}')">Done</button>
              <button class="danger" onclick="deleteLifeRouteTodo('${todo.id}')">Delete</button>
            </div>
          </div>`;
        }).join("");
      }
    }

    const doneSection = document.getElementById("todoDoneSection");
    const doneList = document.getElementById("todoDoneList");
    if (doneSection) doneSection.style.display = done.length ? "block" : "none";
    if (doneList) doneList.innerHTML = done.map(todo => `<div class="card todoCard done"><div class="row"><div class="grow"><div class="small">${categoryEmoji(todo.category)} Completed</div><div class="title">${esc(todo.title)}</div></div><button class="secondary" onclick="reopenLifeRouteTodo('${todo.id}')">Undo</button></div></div>`).join("");
  };

  const savedPlaceSelect = document.getElementById("todoSavedPlace");
  savedPlaceSelect?.addEventListener("change", event => {
    const place = places.find(item => String(item.id) === String(event.target.value));
    const address = document.getElementById("todoAddress");
    if (place && address) address.value = place.address || place.name || "";
  });

  const originalShowView = window.showView;
  window.showView = function showViewWithTodos(id) {
    originalShowView(id);
    if (id === "todos") renderTodos();
  };
  document.querySelectorAll(".tab").forEach(button => {
    button.onclick = () => showView(button.dataset.view);
  });

  const addMinutesISO = (dateKey, time, minutesToAdd) => {
    const date = new Date(`${dateKey}T${time || "12:00"}:00`);
    if (Number.isNaN(date.getTime())) return null;
    date.setMinutes(date.getMinutes() + Number(minutesToAdd || 0));
    return date.toISOString();
  };

  const dueUrgency = (todo, gapDate) => {
    if (!todo.dueDate) return 0;
    const due = dateFromKey(todo.dueDate);
    const gap = dateFromKey(gapDate);
    const days = Math.floor((due - gap) / 86400000);
    if (days < 0) return 75;
    if (days === 0) return 55;
    if (days <= 2) return 32;
    if (days <= 7) return 12;
    return 0;
  };

  const eligibleTodos = gapDate => todos.filter(todo => !todo.completed).slice().sort((a, b) => {
    const scoreA = priorityWeight(a.priority) + dueUrgency(a, gapDate);
    const scoreB = priorityWeight(b.priority) + dueUrgency(b, gapDate);
    return scoreB - scoreA;
  }).slice(0, 14);

  const renderGapSuggestions = context => {
    const panel = document.getElementById(context.panelId);
    if (!panel) return;
    const ranked = context.candidates.map(candidate => {
      const todo = candidate.todo;
      const drive = Number(candidate.outMinutes || 0) + Number(candidate.backMinutes || 0);
      const duration = Number(todo.duration || 30);
      const required = duration + drive;
      const slack = context.rawGap - required;
      const hasLocation = !!String(todo.address || "").trim();
      const routeComplete = !hasLocation || candidate.expectedLegs === 0 || candidate.successLegs === candidate.expectedLegs;
      const routeUnknown = hasLocation && candidate.expectedLegs === 0;
      const fit = routeComplete && slack >= 0;
      const urgency = dueUrgency(todo, context.date);
      let score = fit ? 1000 : -Math.abs(Math.min(0, slack));
      score += priorityWeight(todo.priority) + urgency;
      score -= drive * 1.4;
      if (fit) score -= Math.max(0, slack - 120) * .03;
      if (!routeComplete) score -= 180;
      return { ...candidate, drive, duration, required, slack, fit, routeComplete, routeUnknown, score };
    }).sort((a, b) => b.score - a.score);

    const best = ranked.filter(item => item.fit).slice(0, 5);
    const fallback = ranked.filter(item => !item.fit).slice(0, Math.max(0, 5 - best.length));
    const shown = best.concat(fallback);

    if (!shown.length) {
      panel.innerHTML = '<div class="gapSuggestHead">Nothing open to suggest yet.</div><div class="tiny">Add a to-do in the To-Dos tab and it will appear here when it can fit.</div>';
      panel.style.display = "block";
      return;
    }

    panel.innerHTML = `<div class="gapSuggestHead">Best options for this ${fmt(context.rawGap)} window</div>
      <div class="tiny">LifeRoute ranks task time, priority, due date, and available route time. Route estimates use Apple MapKit even if Google Maps is your navigation preference.</div>` + shown.map((item, index) => {
        const todo = item.todo;
        let status;
        if (!item.routeComplete) status = `<span class="unknown">Route incomplete</span>`;
        else if (item.routeUnknown) status = item.slack >= 0 ? `<span class="unknown">Time fits · route unknown</span>` : `<span class="miss">Needs ${fmt(Math.abs(item.slack))} more</span>`;
        else if (item.fit) status = `<span class="fit">Fits · ${fmt(item.slack)} left</span>`;
        else status = `<span class="miss">Needs ${fmt(Math.abs(item.slack))} more</span>`;

        const legs = [];
        if (item.outMinutes) legs.push(`${fmt(item.outMinutes)} there`);
        legs.push(`${fmt(item.duration)} task`);
        if (item.backMinutes) legs.push(`${fmt(item.backMinutes)} to next`);
        if (item.todo.address && !item.expectedLegs) legs.push("route unavailable from neighboring events");

        return `<div class="gapOption ${index === 0 && item.fit ? "best" : ""}">
          <div class="row"><div class="grow"><div class="small">${index === 0 && item.fit ? "★ BEST MATCH · " : ""}${categoryEmoji(todo.category)} ${esc(todo.category || "To-do")} · due ${esc(dueLabel(todo.dueDate))}</div><div class="title">${esc(todo.title)}</div><div class="meta">${todo.address ? esc(todo.address) : "Flexible / no location"}</div></div><div>${status}</div></div>
          <div class="tiny" style="margin-top:6px">${legs.join(" + ")}</div>
          <div class="gapOptionButtons">${todo.address ? `<button class="secondary" onclick="routeTo('${encodeURIComponent(todo.address)}')">Route there</button>` : ""}<button class="primary" onclick="completeLifeRouteTodo('${todo.id}')">Mark done</button></div>
        </div>`;
      }).join("");
    panel.style.display = "block";
  };

  window.openGapTodoSuggestions = function openGapTodoSuggestions(dateKey, gapIndex, panelId) {
    const panel = document.getElementById(panelId);
    if (!panel) return;
    const list = dayEvents(dateKey);
    const previous = list[gapIndex];
    const next = list[gapIndex + 1];
    if (!previous || !next) return;

    const rawGap = Math.max(0, mins(next.start) - mins(previous.end));
    const candidates = eligibleTodos(dateKey).map(todo => ({
      todo,
      outMinutes: 0,
      backMinutes: 0,
      expectedLegs: 0,
      successLegs: 0,
      failures: 0
    }));

    if (!candidates.length) {
      panel.innerHTML = '<div class="gapSuggestHead">No open to-dos yet.</div><div class="tiny">Add errands or flexible tasks in the To-Dos tab, then tap this gap again.</div>';
      panel.style.display = "block";
      return;
    }

    requestCounter += 1;
    const token = `todo-${requestCounter}-${Date.now()}`;
    const segments = [];
    const candidateByID = {};

    candidates.forEach(candidate => {
      const todo = candidate.todo;
      const address = String(todo.address || "").trim();
      if (!address) return;
      candidateByID[todo.id] = candidate;

      if (String(previous.address || "").trim()) {
        const id = `${token}|${todo.id}|out`;
        candidate.expectedLegs += 1;
        segments.push({
          id,
          date: dateKey,
          origin: previous.address,
          destination: address,
          departure: addMinutesISO(dateKey, previous.end, 0),
          todoID: todo.id,
          leg: "out"
        });
      }

      if (String(next.address || "").trim()) {
        const id = `${token}|${todo.id}|back`;
        candidate.expectedLegs += 1;
        segments.push({
          id,
          date: dateKey,
          origin: address,
          destination: next.address,
          departure: addMinutesISO(dateKey, previous.end, Number(todo.duration || 30) + 20),
          todoID: todo.id,
          leg: "back"
        });
      }
    });

    activeGapRequest = {
      token, panelId, date: dateKey, gapIndex, rawGap, previous, next,
      candidates, candidateByID
    };
    panel.innerHTML = `<div class="gapSuggestHead">Checking what fits…</div><div class="tiny">Comparing ${candidates.length} open to-do${candidates.length === 1 ? "" : "s"}${segments.length ? ` with ${segments.length} route leg${segments.length === 1 ? "" : "s"}` : ""}.</div>`;
    panel.style.display = "block";

    if (!segments.length) {
      renderGapSuggestions(activeGapRequest);
      return;
    }

    setStatus("Checking errands for this gap…");
    if (!postNative({ action: "requestRouteTimes", segments })) {
      renderGapSuggestions(activeGapRequest);
      setStatus("Gap suggestions ready · route data unavailable outside iPhone build");
    }
  };

  const decorateGapCards = () => {
    const list = dayEvents(selectedDate);
    const gapCards = Array.from(timeline.querySelectorAll(".card.gap"));
    gapCards.forEach((gap, index) => {
      if (!list[index + 1]) return;
      gap.classList.add("gapClickable");
      const panelId = `gapTodo-${selectedDate}-${index}`.replace(/[^a-zA-Z0-9_-]/g, "-");
      let panel = gap.querySelector(".gapSuggest");
      if (!panel) {
        panel = document.createElement("div");
        panel.className = "gapSuggest";
        panel.id = panelId;
        panel.style.display = "none";
        gap.appendChild(panel);
      }
      const row = gap.querySelector(".row");
      if (row && !row.querySelector(".gapAction")) {
        const button = document.createElement("button");
        button.className = "secondary gapAction";
        button.textContent = "What fits here?";
        button.onclick = event => {
          event.stopPropagation();
          openGapTodoSuggestions(selectedDate, index, panelId);
        };
        row.appendChild(button);
      }
      gap.onclick = event => {
        if (event.target.closest("button")) return;
        openGapTodoSuggestions(selectedDate, index, panelId);
      };
    });
  };

  const routeAwareRenderToday = window.renderToday;
  window.renderToday = function renderTodayWithTodoGaps() {
    routeAwareRenderToday();
    decorateGapCards();
  };

  const previousNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithTodoRoutes(evt) {
    if (typeof previousNativeEvent === "function") previousNativeEvent(evt);
    if (!evt || evt.type !== "routeTimes" || !activeGapRequest) return;
    const matching = (Array.isArray(evt.results) ? evt.results : []).filter(result => String(result.id || "").startsWith(`${activeGapRequest.token}|`));
    if (!matching.length) return;

    matching.forEach(result => {
      const parts = String(result.id).split("|");
      const todoID = parts[1];
      const leg = parts[2];
      const candidate = activeGapRequest.candidateByID[todoID];
      if (!candidate) return;
      if (result.error || !Number(result.minutes || 0)) {
        candidate.failures += 1;
        return;
      }
      candidate.successLegs += 1;
      if (leg === "out") candidate.outMinutes = Number(result.minutes || 0);
      if (leg === "back") candidate.backMinutes = Number(result.minutes || 0);
    });

    renderGapSuggestions(activeGapRequest);
    setStatus("Gap suggestions ready");
  };

  const existingSuggestionForGap = window.suggestionForGap;
  window.suggestionForGap = function suggestionForGapWithTodos(gapMinutes) {
    const base = typeof existingSuggestionForGap === "function" ? existingSuggestionForGap(gapMinutes) : "";
    const open = todos.filter(todo => !todo.completed && Number(todo.duration || 30) <= gapMinutes);
    if (!open.length) return base;
    const top = open.sort((a, b) => priorityWeight(b.priority) - priorityWeight(a.priority))[0];
    return `${base} You also have <b>${esc(top.title)}</b> in To-Dos; tap the gap to check whether its route really fits.`;
  };

  const setupNotice = document.querySelector("#setup .notice");
  if (setupNotice && !setupNotice.textContent.includes("To-Dos")) {
    setupNotice.innerHTML += "<br><br><b>To-Dos:</b> flexible errands and tasks can be ranked inside route-aware schedule gaps. Location-based to-dos use MapKit for the detour through the errand and onward to the next appointment.";
  }

  renderTodos();
  renderToday();
});