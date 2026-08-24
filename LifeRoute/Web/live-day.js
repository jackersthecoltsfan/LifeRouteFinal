// LifeRoute generated-day mode: turn the chosen routes + calendar into one live plan.
(() => {
  const STORE = "liferoute_generated_days_v1";
  let activeDays = {};
  let ticker = 0;

  try {
    const parsed = JSON.parse(localStorage.getItem(STORE) || "{}");
    activeDays = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
  } catch (_) {
    activeDays = {};
  }

  const save = () => localStorage.setItem(STORE, JSON.stringify(activeDays));
  const icon = (name, size = 15) => typeof window.lifeRouteIcon === "function" ? window.lifeRouteIcon(name, size) : "";
  const safe = value => typeof esc === "function" ? esc(String(value || "")) : String(value || "");
  const at = (dateKey, time) => new Date(`${dateKey}T${time || "00:00"}:00`);
  const addMinutes = (date, minutes) => new Date(date.getTime() + Number(minutes || 0) * 60000);
  const fmtTime = date => date.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  const miles = meters => Number(meters || 0) / 1609.344;
  const distanceText = meters => {
    const value = miles(meters);
    return value > 0 ? `${value.toFixed(value < 10 ? 1 : 0)} mi` : "";
  };
  const countdownText = target => {
    const diff = target.getTime() - Date.now();
    if (diff <= 0) return "Now";
    const totalSeconds = Math.ceil(diff / 1000);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    if (hours) return `${hours}h ${minutes}m`;
    if (minutes >= 10) return `${minutes}m`;
    return `${minutes}m ${seconds}s`;
  };

  const selectionFor = (dateKey, previous, next) =>
    typeof window.lifeRouteSelectedGapFor === "function"
      ? window.lifeRouteSelectedGapFor(dateKey, String(previous?.id || ""), String(next?.id || ""))
      : null;

  const travelLegs = selection => {
    let out = Number(selection?.outMinutes || 0);
    let back = Number(selection?.backMinutes || 0);
    const total = Number(selection?.routeMinutes || 0);
    let approximate = false;
    if ((!out || !back) && total > 0) {
      approximate = true;
      if (!out && !back) {
        out = Math.max(1, Math.round(total / 2));
        back = Math.max(1, total - out);
      } else if (!out) out = Math.max(1, total - back);
      else if (!back) back = Math.max(1, total - out);
    }
    return { out, back, approximate };
  };

  const buildDay = dateKey => {
    const list = typeof dayEvents === "function" ? dayEvents(dateKey) : [];
    const blocks = [];
    const leaveActions = [];

    list.forEach((event, index) => {
      const start = at(dateKey, event.start);
      const end = at(dateKey, event.end);
      const buffer = Math.max(0, Number(event.buffer || 10));
      let leaveAt = null;
      let travelMinutes = 0;
      let travelDistanceMeters = Number(event.routeDistanceMiles || 0) * 1609.344;
      let leaveOrigin = index === 0 ? (event.routeOriginLabel || "Current location") : (list[index - 1]?.title || "Previous stop");

      if (index === 0) {
        travelMinutes = Math.max(0, Number(event.drive || 0));
        if (event.address && travelMinutes > 0) {
          leaveAt = addMinutes(start, -(travelMinutes + buffer));
          leaveActions.push({
            id: `${dateKey}-first-${event.id}`,
            time: leaveAt,
            title: `Leave for ${event.title}`,
            destination: event.address,
            detail: `${typeof fmt === "function" ? fmt(travelMinutes) : travelMinutes + "m"} travel${buffer ? ` + ${buffer}m buffer` : ""}`
          });
        }
      } else {
        const previous = list[index - 1];
        const selected = selectionFor(dateKey, previous, event);
        if (selected) {
          const legs = travelLegs(selected);
          const stopMinutes = Math.max(0, Number(selected.stopMinutes || 0));
          const previousEnd = at(dateKey, previous.end);
          const stopArrival = addMinutes(previousEnd, legs.out);
          const plannedStopEnd = addMinutes(stopArrival, stopMinutes);
          const leaveStopAt = addMinutes(start, -(legs.back + buffer));
          const stopDistanceOut = Number(selected.outDistanceMeters || 0);
          const stopDistanceBack = Number(selected.backDistanceMeters || 0);

          blocks.push({
            type: "stop",
            id: `stop-${selected.key}`,
            start: stopArrival,
            end: plannedStopEnd,
            title: selected.label || "Selected stop",
            address: selected.stop || "",
            subtitle: `${typeof fmt === "function" ? fmt(stopMinutes) : stopMinutes + "m"} planned stop`,
            travelIn: legs.out,
            travelOut: legs.back,
            distanceIn: stopDistanceOut,
            distanceOut: stopDistanceBack,
            approximate: !!selected.estimated || legs.approximate,
            leaveStopAt,
            nextTitle: event.title
          });

          leaveActions.push({
            id: `${dateKey}-stop-in-${selected.key}`,
            time: previousEnd,
            title: `Leave for ${selected.label || "selected stop"}`,
            destination: selected.stop || "",
            detail: legs.out ? `${typeof fmt === "function" ? fmt(legs.out) : legs.out + "m"} travel` : "Route ready in Maps"
          });
          leaveActions.push({
            id: `${dateKey}-stop-out-${selected.key}`,
            time: leaveStopAt,
            title: `Leave for ${event.title}`,
            destination: event.address || "",
            detail: `${legs.back ? (typeof fmt === "function" ? fmt(legs.back) : legs.back + "m") + " travel" : "Route ready in Maps"}${buffer ? ` + ${buffer}m buffer` : ""}`
          });

          leaveAt = leaveStopAt;
          travelMinutes = legs.back;
          travelDistanceMeters = stopDistanceBack;
          leaveOrigin = selected.label || "Selected stop";
        } else {
          travelMinutes = Math.max(0, Number(event.drive || 0));
          if (event.address && travelMinutes > 0) {
            leaveAt = addMinutes(start, -(travelMinutes + buffer));
            leaveActions.push({
              id: `${dateKey}-direct-${event.id}`,
              time: leaveAt,
              title: `Leave for ${event.title}`,
              destination: event.address,
              detail: `${typeof fmt === "function" ? fmt(travelMinutes) : travelMinutes + "m"} travel${buffer ? ` + ${buffer}m buffer` : ""}`
            });
          }
        }
      }

      blocks.push({
        type: "event",
        id: String(event.id),
        start,
        end,
        title: event.title || "Calendar event",
        address: event.address || "",
        subtitle: `${fmtTime(start)}–${fmtTime(end)}`,
        leaveAt,
        travelMinutes,
        travelDistanceMeters,
        leaveOrigin
      });
    });

    blocks.sort((a, b) => a.start - b.start);
    leaveActions.sort((a, b) => a.time - b.time);
    return { dateKey, list, blocks, leaveActions };
  };

  const notificationItems = plan => {
    const now = Date.now();
    const items = [];
    plan.leaveActions.forEach(action => {
      [
        { offset: -15, suffix: "15", title: "Leave in 15 minutes" },
        { offset: -5, suffix: "5", title: "Leave in 5 minutes" },
        { offset: 0, suffix: "now", title: "Time to leave" }
      ].forEach(reminder => {
        const fire = addMinutes(action.time, reminder.offset);
        if (fire.getTime() <= now + 1500) return;
        items.push({
          id: `${action.id}-${reminder.suffix}`,
          title: reminder.title,
          body: `${action.title.replace(/^Leave for /, "")} · ${action.detail}`,
          fireISO: fire.toISOString()
        });
      });
    });
    return items.slice(0, 48);
  };

  const scheduleNotifications = plan => {
    const items = notificationItems(plan);
    if (typeof postNative === "function" && postNative({
      action: "scheduleDayNotifications",
      dateKey: plan.dateKey,
      items
    })) {
      if (typeof setStatus === "function") setStatus(`Live Day ready · ${items.length} leave reminder${items.length === 1 ? "" : "s"}`);
    }
  };

  const ensureUI = () => {
    const hero = document.querySelector("#today .hero");
    if (!hero) return;
    let controls = document.getElementById("liveDayControls");
    if (!controls) {
      controls = document.createElement("div");
      controls.id = "liveDayControls";
      controls.className = "liveDayControls";
      controls.innerHTML = `
        <button class="goldButton liveDayGenerate" onclick="generateLifeRouteDay()">${icon("sparkles", 15)} Generate day</button>
        <button class="secondary liveDayEnd" style="display:none" onclick="endLifeRouteDay()">End Live Day</button>`;
      hero.appendChild(controls);
    }
    let panel = document.getElementById("liveDayPanel");
    if (!panel) {
      panel = document.createElement("div");
      panel.id = "liveDayPanel";
      panel.className = "liveDayPanel";
      hero.after(panel);
    }
  };

  const renderPlan = () => {
    ensureUI();
    const panel = document.getElementById("liveDayPanel");
    const generate = document.querySelector(".liveDayGenerate");
    const endButton = document.querySelector(".liveDayEnd");
    if (!panel || typeof selectedDate === "undefined") return;

    const active = !!activeDays[selectedDate];
    if (generate) generate.innerHTML = `${icon("sparkles", 15)} ${active ? "Regenerate day" : "Generate day"}`;
    if (endButton) endButton.style.display = active ? "" : "none";
    if (!active) {
      panel.classList.remove("show");
      panel.innerHTML = "";
      return;
    }

    const plan = buildDay(selectedDate);
    const now = new Date();
    const nextAction = plan.leaveActions.find(action => action.time > now) || null;
    const isToday = selectedDate === (typeof localDateKey === "function" ? localDateKey(now) : selectedDate);
    const nextBlock = plan.blocks.find(block => block.end > now) || null;

    const liveText = nextAction
      ? `<div class="liveDayCountdown"><span>Next leave</span><b data-live-day-countdown="${nextAction.time.toISOString()}">${countdownText(nextAction.time)}</b><small>${safe(nextAction.title)}</small></div>`
      : `<div class="liveDayCountdown"><span>${isToday ? "Live Day" : "Planned day"}</span><b>${isToday ? "Complete" : "Ready"}</b><small>${nextBlock ? safe(nextBlock.title) : "No more departures"}</small></div>`;

    panel.innerHTML = `
      <div class="liveDayHeader">
        <div><div class="small liveDayKicker">LIVE DAY</div><div class="title">${isToday ? "Your generated day" : "Generated plan"} · ${safe(typeof dayName === "function" ? dayName(selectedDate) : selectedDate)}</div><div class="meta">Leave times automatically include route time and arrival buffer.</div></div>
        <span class="badge green">${isToday ? "Live" : "Planned"}</span>
      </div>
      ${liveText}
      <div class="liveDaySequence">${plan.blocks.map(block => {
        if (block.type === "stop") {
          const dist = Number(block.distanceIn || 0) + Number(block.distanceOut || 0);
          return `<div class="liveDayRow stop">
            <div class="liveDayTime">${fmtTime(block.start)}</div>
            <div class="liveDayRail"><span></span></div>
            <div class="grow"><div class="small">${icon("route", 13)} SELECTED GAP ROUTE</div><div class="title">${safe(block.title)}</div><div class="meta">${safe(block.address)}</div><div class="tiny">${block.travelIn ? (typeof fmt === "function" ? fmt(block.travelIn) : block.travelIn + "m") + " there · " : ""}${safe(block.subtitle)} · leave by <b>${fmtTime(block.leaveStopAt)}</b>${block.travelOut ? " · " + (typeof fmt === "function" ? fmt(block.travelOut) : block.travelOut + "m") + " to " + safe(block.nextTitle) : ""}${dist ? " · " + distanceText(dist) : ""}${block.approximate ? " · estimated" : ""}</div></div>
          </div>`;
        }
        const leave = block.leaveAt ? `Leave ${safe(block.leaveOrigin)} at <b>${fmtTime(block.leaveAt)}</b>${block.travelMinutes ? " · " + (typeof fmt === "function" ? fmt(block.travelMinutes) : block.travelMinutes + "m") : ""}${block.travelDistanceMeters ? " · " + distanceText(block.travelDistanceMeters) : ""}` : "No route departure needed";
        return `<div class="liveDayRow event">
          <div class="liveDayTime">${fmtTime(block.start)}</div>
          <div class="liveDayRail"><span></span></div>
          <div class="grow"><div class="small">${icon("calendar", 13)} APPOINTMENT</div><div class="title">${safe(block.title)}</div><div class="meta">${safe(block.address || "No location")}</div><div class="tiny">${leave}</div></div>
        </div>`;
      }).join("")}</div>`;

    panel.classList.add("show");
  };

  const updateCountdown = () => {
    document.querySelectorAll("[data-live-day-countdown]").forEach(node => {
      const target = new Date(node.dataset.liveDayCountdown);
      if (!Number.isNaN(target.getTime())) node.textContent = countdownText(target);
    });
  };

  window.generateLifeRouteDay = () => {
    if (typeof selectedDate === "undefined") return;
    activeDays[selectedDate] = { generatedAt: new Date().toISOString() };
    save();
    const plan = buildDay(selectedDate);
    renderPlan();
    scheduleNotifications(plan);
  };

  window.endLifeRouteDay = () => {
    if (typeof selectedDate === "undefined") return;
    delete activeDays[selectedDate];
    save();
    renderPlan();
    if (typeof postNative === "function") postNative({ action: "scheduleDayNotifications", dateKey: selectedDate, items: [] });
    if (typeof setStatus === "function") setStatus("Live Day ended");
  };

  const previousNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithLiveDay(evt) {
    if (typeof previousNativeEvent === "function") previousNativeEvent(evt);
    if (!evt || evt.type !== "dayNotificationsStatus") return;
    if (typeof setStatus === "function") {
      if (evt.granted === false) setStatus("Live Day ready · notification permission is off");
      else setStatus(`Live Day ready · ${Number(evt.scheduled || 0)} leave reminders scheduled`);
    }
  };

  const previousRenderToday = window.renderToday;
  if (typeof previousRenderToday === "function" && !previousRenderToday.__lifeRouteLiveDay) {
    const wrapped = function renderTodayWithLiveDay(...args) {
      const result = previousRenderToday.apply(this, args);
      renderPlan();
      return result;
    };
    wrapped.__lifeRouteLiveDay = true;
    window.renderToday = wrapped;
  }

  const style = document.createElement("style");
  style.id = "liveDayStyles";
  style.textContent = `
    .liveDayControls{display:flex;gap:7px;flex-wrap:wrap;margin-top:13px}.liveDayControls button{display:inline-flex;align-items:center;gap:6px}
    .liveDayPanel{display:none;margin:0 0 13px;padding:14px;border-radius:19px;border:1px solid color-mix(in srgb,var(--blue) 22%,var(--line));background:linear-gradient(145deg,color-mix(in srgb,var(--blue) 6%,transparent),color-mix(in srgb,var(--gold) 3%,transparent)),color-mix(in srgb,var(--panel) 92%,transparent);backdrop-filter:blur(22px);-webkit-backdrop-filter:blur(22px);box-shadow:0 16px 42px rgba(0,0,0,.14)}.liveDayPanel.show{display:block}
    .liveDayHeader{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}.liveDayKicker{color:var(--gold)!important;font-size:8px!important;letter-spacing:.13em;font-weight:950!important;margin-bottom:3px}
    .liveDayCountdown{display:grid;grid-template-columns:auto 1fr;align-items:end;column-gap:10px;margin:12px 0;padding:12px;border-radius:15px;background:color-mix(in srgb,var(--panel2) 72%,transparent);border:1px solid color-mix(in srgb,var(--line) 70%,transparent)}.liveDayCountdown span{grid-column:1/-1;font-size:9px;color:var(--muted);text-transform:uppercase;letter-spacing:.08em;font-weight:900}.liveDayCountdown b{font-size:28px;letter-spacing:-1px;color:var(--text)}.liveDayCountdown small{font-size:11px;color:var(--gold);font-weight:800;padding-bottom:4px;text-align:right}
    .liveDaySequence{display:grid}.liveDayRow{display:grid;grid-template-columns:62px 16px 1fr;gap:8px;min-height:72px}.liveDayTime{font-size:10px;font-weight:900;color:var(--muted);padding-top:4px;text-align:right}.liveDayRail{position:relative;display:flex;justify-content:center}.liveDayRail:after{content:"";position:absolute;top:18px;bottom:-6px;width:1px;background:color-mix(in srgb,var(--line) 90%,transparent)}.liveDayRow:last-child .liveDayRail:after{display:none}.liveDayRail span{margin-top:5px;width:8px;height:8px;border-radius:50%;background:var(--blue);box-shadow:0 0 0 4px color-mix(in srgb,var(--blue) 10%,transparent);z-index:1}.liveDayRow.stop .liveDayRail span{background:var(--gold);box-shadow:0 0 0 4px color-mix(in srgb,var(--gold) 10%,transparent)}.liveDayRow .title{font-size:13.5px!important}.liveDayRow .small{font-size:8px!important;display:flex;align-items:center;gap:5px}.liveDayRow .tiny{margin-top:4px;line-height:1.45}
    @media(max-width:480px){.liveDayRow{grid-template-columns:48px 13px 1fr;gap:6px}.liveDayCountdown{grid-template-columns:1fr}.liveDayCountdown small{text-align:left}.liveDayHeader .badge{display:none}}
  `;
  document.head.appendChild(style);

  ensureUI();
  renderPlan();
  if (ticker) clearInterval(ticker);
  ticker = setInterval(updateCountdown, 1000);
})();