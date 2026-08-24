// Public, non-secret integration configuration only.
// Never commit OAuth client secrets, CentralReach tokens, or Apple private keys here.
window.LifeRouteConfig = {
  googleCalendar: {
    enabled: true,
    scopes: ["https://www.googleapis.com/auth/calendar.readonly"],
    mode: "native-read-only-oauth"
  },
  centralReach: {
    enabled: false,
    baseURL: "https://partners-api.centralreach.com/enterprise/v1/",
    mode: "read-only",
    scheduleReadEndpoints: {
      byProvider: "schedule/events/by-provider",
      byAppointmentWith: "schedule/events/by-appointment-with"
    }
  }
};

window.addEventListener("DOMContentLoaded", () => {
  // Migrate older saved preferences. Object.assign in the original UI is shallow,
  // so users who saved preferences before Google Calendar existed can otherwise
  // end up with prefs.sources.google === undefined, which hides every synced
  // Google event even though the native sync reports success.
  prefs.sources = Object.assign(
    { apple: true, google: true, centralreach: true },
    prefs.sources || {}
  );

  // Provider events are live data. Keep only manual events in local storage so
  // stale provider payloads do not survive between launches.
  window.persist = function persistLifeRouteState() {
    localStorage.setItem(
      STORE,
      JSON.stringify({
        events: events.filter(event => !event.source || event.source === "manual"),
        places,
        prefs
      })
    );
  };

  window.postNative = function postNativeSafely(payload) {
    try {
      const handler = window.webkit?.messageHandlers?.lifeRoute;
      if (!handler) return false;
      handler.postMessage(payload);
      return true;
    } catch (_) {
      return false;
    }
  };

  const oldEventCount = events.length;
  const oldPlaceCount = places.length;
  events = events.filter(event => !String(event.id || "").startsWith("demo-"));
  places = places.filter(place => !String(place.id || "").startsWith("demo-"));
  if (events.length !== oldEventCount || places.length !== oldPlaceCount) persist();

  // Branding.
  const brandMark = document.querySelector(".mark");
  if (brandMark) {
    brandMark.innerHTML = '<img src="liferoute-logo-source.png" alt="LifeRoute">';
    brandMark.style.background = "transparent";
    brandMark.style.overflow = "hidden";
    brandMark.style.boxShadow = "0 10px 30px rgba(0,0,0,.28)";
    brandMark.style.borderRadius = "14px";
    const logo = brandMark.querySelector("img");
    if (logo) {
      logo.style.width = "100%";
      logo.style.height = "100%";
      logo.style.objectFit = "cover";
      logo.style.display = "block";
      logo.onerror = () => { brandMark.textContent = "LR"; };
    }
  }

  // Calendar period navigation.
  let selectedWeekAnchor = dateFromKey(selectedDate);
  let selectedMonthAnchor = new Date(
    selectedWeekAnchor.getFullYear(),
    selectedWeekAnchor.getMonth(),
    1
  );

  const startOfWeek = value => {
    const d = value instanceof Date ? new Date(value) : dateFromKey(value);
    const day = d.getDay();
    const offset = (day + 6) % 7;
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() - offset);
  };

  const weekKeysFor = anchor => {
    const monday = startOfWeek(anchor);
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(monday);
      d.setDate(monday.getDate() + i);
      return localDateKey(d);
    });
  };

  const allVisibleEventsForDate = dateKey => events
    .filter(event => visibleSource(event) && event.date === dateKey)
    .sort((a, b) => {
      if (!!a.allDay !== !!b.allDay) return a.allDay ? -1 : 1;
      return mins(a.start) - mins(b.start);
    });

  const timedVisibleEventsForDate = dateKey => allVisibleEventsForDate(dateKey)
    .filter(event => !event.allDay);

  window.dayEvents = function liveDayEvents(dateKey) {
    return timedVisibleEventsForDate(dateKey);
  };

  window.weekDates = function selectedWeekDates() {
    return weekKeysFor(selectedWeekAnchor);
  };

  const dateLabel = date => date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric"
  });

  const weekLabel = () => {
    const keys = weekKeysFor(selectedWeekAnchor);
    const first = dateFromKey(keys[0]);
    const last = dateFromKey(keys[6]);
    if (first.getFullYear() !== last.getFullYear()) {
      return `${dateLabel(first)}, ${first.getFullYear()} – ${dateLabel(last)}, ${last.getFullYear()}`;
    }
    if (first.getMonth() !== last.getMonth()) {
      return `${dateLabel(first)} – ${dateLabel(last)}, ${last.getFullYear()}`;
    }
    return `${first.toLocaleDateString("en-US", { month: "long", day: "numeric" })}–${last.getDate()}, ${last.getFullYear()}`;
  };

  const monthLabel = () => selectedMonthAnchor.toLocaleDateString("en-US", {
    month: "long",
    year: "numeric"
  });

  window.changeWeek = function changeWeek(delta) {
    selectedWeekAnchor = new Date(
      selectedWeekAnchor.getFullYear(),
      selectedWeekAnchor.getMonth(),
      selectedWeekAnchor.getDate() + delta * 7
    );
    renderWeek();
  };

  window.goToCurrentWeek = function goToCurrentWeek() {
    selectedWeekAnchor = new Date();
    renderWeek();
  };

  window.changeMonth = function changeMonth(delta) {
    selectedMonthAnchor = new Date(
      selectedMonthAnchor.getFullYear(),
      selectedMonthAnchor.getMonth() + delta,
      1
    );
    renderMonth();
  };

  window.goToCurrentMonth = function goToCurrentMonth() {
    const now = new Date();
    selectedMonthAnchor = new Date(now.getFullYear(), now.getMonth(), 1);
    renderMonth();
  };

  window.openCalendarDay = function openCalendarDay(dateKey) {
    selectedDate = dateKey;
    selectedWeekAnchor = dateFromKey(dateKey);
    selectedMonthAnchor = new Date(
      selectedWeekAnchor.getFullYear(),
      selectedWeekAnchor.getMonth(),
      1
    );
    renderAll();
    showView("today");
  };

  // Month tab, period controls, and calendar styles.
  const style = document.createElement("style");
  style.textContent = `
    .tabs{grid-template-columns:repeat(5,1fr)!important}
    .periodNav{display:grid;grid-template-columns:auto 1fr auto auto;gap:8px;align-items:center;margin:0 0 14px}
    .periodNav .periodTitle{text-align:center;font-weight:950;font-size:14px;letter-spacing:-.2px}
    .periodNav button{padding:9px 11px}
    .monthSummary{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:12px}
    .monthMetric{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:11px}
    .monthMetric b{display:block;font-size:18px}.monthMetric span{font-size:10px;color:var(--muted)}
    .monthWeekdays,.monthGrid{display:grid;grid-template-columns:repeat(7,1fr);gap:5px}
    .monthWeekdays{margin:0 0 6px}.monthWeekdays div{text-align:center;font-size:9px;color:var(--muted);font-weight:900}
    .monthDay{min-height:84px;background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:7px;text-align:left;color:var(--text);overflow:hidden}
    .monthDay.outside{opacity:.38}.monthDay.today{box-shadow:inset 0 0 0 2px var(--gold)}
    .monthDay.hasEvents{border-color:rgba(120,185,255,.45)}
    .monthNumber{font-size:12px;font-weight:950;margin-bottom:5px}
    .monthEvent{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:8px;line-height:1.45;color:var(--muted);padding:2px 4px;border-radius:6px;background:var(--panel2);margin-top:3px}
    .monthEvent.allDay{color:var(--gold)}
    .monthMore{font-size:8px;color:var(--blue);margin-top:4px;font-weight:850}
    .weekEventPreview{margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    @media(max-width:680px){
      .tabs{gap:5px}.tab{padding:10px 3px;font-size:12px}
      .periodNav{grid-template-columns:auto 1fr auto}.periodNav .periodToday{grid-column:1/-1}
      .monthDay{min-height:68px;padding:5px;border-radius:9px}.monthEvent{font-size:7px}.monthNumber{font-size:11px}
    }
  `;
  document.head.appendChild(style);

  const tabs = document.querySelector(".tabs");
  if (tabs && !tabs.querySelector('[data-view="month"]')) {
    const monthTab = document.createElement("button");
    monthTab.className = "tab";
    monthTab.dataset.view = "month";
    monthTab.textContent = "Month";
    const placesTab = tabs.querySelector('[data-view="places"]');
    tabs.insertBefore(monthTab, placesTab || null);
  }

  const weekSection = document.getElementById("week");
  if (weekSection && !document.getElementById("weekPeriodNav")) {
    const nav = document.createElement("div");
    nav.id = "weekPeriodNav";
    nav.className = "periodNav";
    nav.innerHTML = `
      <button class="secondary" onclick="changeWeek(-1)" aria-label="Previous week">‹</button>
      <div class="periodTitle" id="weekPeriodLabel"></div>
      <button class="secondary" onclick="changeWeek(1)" aria-label="Next week">›</button>
      <button class="secondary periodToday" onclick="goToCurrentWeek()">Current week</button>
    `;
    weekSection.insertBefore(nav, weekSection.firstElementChild);
  }

  if (!document.getElementById("month")) {
    const monthSection = document.createElement("section");
    monthSection.id = "month";
    monthSection.className = "view";
    monthSection.innerHTML = `
      <div class="periodNav" id="monthPeriodNav">
        <button class="secondary" onclick="changeMonth(-1)" aria-label="Previous month">‹</button>
        <div class="periodTitle" id="monthPeriodLabel"></div>
        <button class="secondary" onclick="changeMonth(1)" aria-label="Next month">›</button>
        <button class="secondary periodToday" onclick="goToCurrentMonth()">Current month</button>
      </div>
      <div class="monthSummary">
        <div class="monthMetric"><b id="monthEventCount">0</b><span>events</span></div>
        <div class="monthMetric"><b id="monthScheduled">0m</b><span>scheduled</span></div>
        <div class="monthMetric"><b id="monthActiveDays">0</b><span>active days</span></div>
      </div>
      <div class="card">
        <div class="monthWeekdays"><div>Mon</div><div>Tue</div><div>Wed</div><div>Thu</div><div>Fri</div><div>Sat</div><div>Sun</div></div>
        <div class="monthGrid" id="monthGrid"></div>
      </div>
    `;
    weekSection?.after(monthSection);
  }

  document.querySelectorAll(".tab").forEach(button => {
    button.onclick = () => showView(button.dataset.view);
  });

  const originalShowView = window.showView;
  window.showView = function showLifeRouteView(id) {
    originalShowView(id);
    if (id === "week") renderWeek();
    if (id === "month") renderMonth();
  };

  // Robust provider-event normalization.
  const normalizeProviderDate = (value, allDay) => {
    const raw = String(value || "").trim();
    if (!raw) return null;

    const dateOnly = raw.match(/^(\d{4}-\d{2}-\d{2})$/);
    if (dateOnly) return { date: dateOnly[1], time: "00:00" };

    const parsed = new Date(raw);
    if (!Number.isNaN(parsed.getTime())) {
      return {
        date: localDateKey(parsed),
        time: `${String(parsed.getHours()).padStart(2, "0")}:${String(parsed.getMinutes()).padStart(2, "0")}`
      };
    }

    const loose = raw.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}):(\d{2})/);
    if (loose) return { date: loose[1], time: `${loose[2]}:${loose[3]}` };
    return null;
  };

  const focusWeekOnUpcomingEventsIfNeeded = () => {
    const currentKeys = weekKeysFor(selectedWeekAnchor);
    const hasCurrentWeekData = currentKeys.some(key => allVisibleEventsForDate(key).length > 0);
    if (hasCurrentWeekData) return;

    const today = localDateKey(new Date());
    const upcoming = events
      .filter(event => visibleSource(event) && event.date && event.date >= today)
      .sort((a, b) => a.date.localeCompare(b.date) || mins(a.start) - mins(b.start));

    if (upcoming.length) {
      selectedWeekAnchor = dateFromKey(upcoming[0].date);
      selectedMonthAnchor = new Date(
        selectedWeekAnchor.getFullYear(),
        selectedWeekAnchor.getMonth(),
        1
      );
    }
  };

  window.receiveProviderEvents = function receiveLiveProviderEvents(source, incoming) {
    const previousManualAndOtherProviders = events.filter(event => event.source !== source);
    const normalized = [];
    let skipped = 0;

    (incoming || []).forEach(item => {
      const allDay = !!item.isAllDay;
      const start = normalizeProviderDate(item.start, allDay);
      const end = normalizeProviderDate(item.end, allDay);
      if (!start || !end) {
        skipped += 1;
        return;
      }

      normalized.push({
        id: `${source}-${item.id || Math.random().toString(36).slice(2)}`,
        source,
        date: start.date,
        title: item.title || "Calendar event",
        start: allDay ? "00:00" : start.time,
        end: allDay ? "23:59" : end.time,
        address: item.location || item.address || "",
        calendarTitle: item.calendarTitle || "",
        allDay,
        drive: 0,
        buffer: 10
      });
    });

    events = previousManualAndOtherProviders.concat(normalized);
    nativeState.lastCalendarSync = {
      source,
      received: (incoming || []).length,
      loaded: normalized.length,
      skipped
    };

    focusWeekOnUpcomingEventsIfNeeded();
    persist();
    renderAll();
    return nativeState.lastCalendarSync;
  };

  // Selected-week rendering.
  window.analyzeWeek = function analyzeSelectedWeek() {
    const candidates = [];
    weekKeysFor(selectedWeekAnchor).forEach(key => {
      const list = timedVisibleEventsForDate(key);
      for (let i = 0; i < list.length - 1; i += 1) {
        const gap = mins(list[i + 1].start) - mins(list[i].end);
        if (gap > 0) candidates.push({ date: key, g: gap, a: list[i], b: list[i + 1] });
      }
    });
    candidates.sort((a, b) => b.g - a.g);

    const eventCount = weekKeysFor(selectedWeekAnchor)
      .reduce((count, key) => count + allVisibleEventsForDate(key).length, 0);

    if (!eventCount) {
      return "No events are loaded for this selected week. Use the arrows to choose another week, or refresh your calendars.";
    }
    if (!candidates.length) {
      return `LifeRoute loaded <b>${eventCount}</b> calendar event${eventCount === 1 ? "" : "s"} for this week. There are no positive gaps between timed commitments to rank yet.`;
    }

    const dead = candidates.reduce((total, item) => total + item.g, 0);
    const top = candidates[0];
    return `There are <b>${fmt(dead)}</b> between timed commitments this week. The largest block is <b>${dayName(top.date)} · ${fmt(top.g)}</b>, between <b>${esc(top.a.title)}</b> and <b>${esc(top.b.title)}</b>.${suggestionForGap(top.g)}`;
  };

  window.renderWeek = function renderSelectedWeek() {
    const dates = weekKeysFor(selectedWeekAnchor);
    const total = { work: 0, drive: 0, gap: 0, spread: 0 };
    const rows = [];
    let maxSpread = 1;

    dates.forEach(key => {
      const timed = timedVisibleEventsForDate(key);
      const all = allVisibleEventsForDate(key);
      const s = stats(timed);
      Object.keys(total).forEach(metric => { total[metric] += s[metric]; });
      maxSpread = Math.max(maxSpread, s.spread);
      rows.push({ key, timed, all, stats: s });
    });

    wWork.textContent = fmt(total.work);
    wDrive.textContent = fmt(total.drive);
    wGap.textContent = fmt(total.gap);
    wSpread.textContent = fmt(total.spread);

    const label = document.getElementById("weekPeriodLabel");
    if (label) label.textContent = weekLabel();

    weekChart.innerHTML = rows.map(row => {
      const d = dateFromKey(row.key);
      const allDayCount = row.all.filter(event => event.allDay).length;
      const preview = row.all.slice(0, 2).map(event => event.title).join(" • ");
      const countText = `${row.all.length} event${row.all.length === 1 ? "" : "s"}`;
      const allDayText = allDayCount ? ` · ${allDayCount} all-day` : "";
      return `<div class="weekday" onclick="openCalendarDay('${row.key}')">
        <b>${dayName(row.key).slice(0, 3)}<span class="tiny" style="display:block">${d.getMonth() + 1}/${d.getDate()}</span></b>
        <div>
          <div class="bar"><div class="fill" style="width:${Math.round(row.stats.spread / maxSpread * 100)}%"></div></div>
          <div class="tiny">${countText}${allDayText} · ${fmt(row.stats.work)} scheduled · ${fmt(row.stats.gap)} gaps</div>
          ${preview ? `<div class="tiny weekEventPreview">${esc(preview)}</div>` : ""}
        </div>
        <div>${fmt(row.stats.spread)}</div>
      </div>`;
    }).join("");

    weekInsight.innerHTML = analyzeWeek();
  };

  // Month rendering.
  window.renderMonth = function renderSelectedMonth() {
    const grid = document.getElementById("monthGrid");
    if (!grid) return;

    const year = selectedMonthAnchor.getFullYear();
    const month = selectedMonthAnchor.getMonth();
    const first = new Date(year, month, 1);
    const firstMondayOffset = (first.getDay() + 6) % 7;
    const gridStart = new Date(year, month, 1 - firstMondayOffset);
    const todayKey = localDateKey(new Date());

    let monthEvents = 0;
    let monthWork = 0;
    let activeDays = 0;
    const cells = [];

    for (let i = 0; i < 42; i += 1) {
      const d = new Date(gridStart);
      d.setDate(gridStart.getDate() + i);
      const key = localDateKey(d);
      const dayEventsAll = allVisibleEventsForDate(key);
      const inMonth = d.getMonth() === month;

      if (inMonth && dayEventsAll.length) {
        monthEvents += dayEventsAll.length;
        activeDays += 1;
        monthWork += stats(dayEventsAll.filter(event => !event.allDay)).work;
      }

      const previews = dayEventsAll.slice(0, 3).map(event => {
        const time = event.allDay ? "All day" : time12(event.start).replace(" ", "");
        return `<div class="monthEvent ${event.allDay ? "allDay" : ""}">${esc(time)} · ${esc(event.title)}</div>`;
      }).join("");

      cells.push(`<button class="monthDay ${inMonth ? "" : "outside"} ${key === todayKey ? "today" : ""} ${dayEventsAll.length ? "hasEvents" : ""}" onclick="openCalendarDay('${key}')">
        <div class="monthNumber">${d.getDate()}</div>
        ${previews}
        ${dayEventsAll.length > 3 ? `<div class="monthMore">+${dayEventsAll.length - 3} more</div>` : ""}
      </button>`);
    }

    grid.innerHTML = cells.join("");
    const label = document.getElementById("monthPeriodLabel");
    if (label) label.textContent = monthLabel();
    const count = document.getElementById("monthEventCount");
    const scheduled = document.getElementById("monthScheduled");
    const active = document.getElementById("monthActiveDays");
    if (count) count.textContent = String(monthEvents);
    if (scheduled) scheduled.textContent = fmt(monthWork);
    if (active) active.textContent = String(activeDays);
  };

  const originalRenderAll = window.renderAll;
  window.renderAll = function renderAllWithCalendarViews() {
    originalRenderAll();
    renderWeek();
    renderMonth();
  };

  // Native bridge.
  const updateGoogleStatus = () => {
    const badge = document.getElementById("googleStatus");
    if (!badge) return;
    const configured = !!nativeState?.googleCalendarConfigured;
    const connected = !!nativeState?.googleCalendarConnected;
    badge.textContent = connected ? "CONNECTED" : (configured ? "READY" : "SETUP NEEDED");
    badge.className = "badge " + (connected ? "green" : "gold");
  };

  const originalRenderSources = window.renderSources;
  window.renderSources = function renderSourcesWithGoogleStatus() {
    originalRenderSources();
    updateGoogleStatus();
  };

  window.connectGoogle = function connectGoogleCalendarNative() {
    if (!postNative({ action: "requestGoogleCalendar" })) {
      alert("Google Calendar connection is available inside the native iPhone app build.");
    }
  };

  window.refreshGoogleCalendar = function refreshGoogleCalendarNative() {
    postNative({ action: "refreshGoogleCalendar" });
  };

  window.disconnectGoogleCalendar = function disconnectGoogleCalendarNative() {
    if (confirm("Disconnect Google Calendar from LifeRoute on this iPhone?")) {
      postNative({ action: "disconnectGoogleCalendar" });
    }
  };

  window.refreshCalendars = function refreshAllConnectedCalendars() {
    let didRequest = false;

    if (nativeState?.appleCalendarConnected) {
      postNative({ action: "refreshAppleCalendar" });
      didRequest = true;
    } else if (nativeState?.appleCalendarStatus === "not-determined") {
      postNative({ action: "requestAppleCalendar" });
      didRequest = true;
    }

    if (nativeState?.googleCalendarConnected) {
      postNative({ action: "refreshGoogleCalendar" });
      didRequest = true;
    }

    if (!didRequest) {
      setStatus("Connect a calendar in Setup");
      showView("setup");
    } else {
      setStatus("Refreshing calendars…");
    }
  };

  const originalNativeEvent = window.lifeRouteNativeEvent;
  let autoAppleStarted = false;
  let autoGoogleStarted = false;

  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithLiveCalendars(evt) {
    if (typeof originalNativeEvent === "function") originalNativeEvent(evt);
    if (!evt || !evt.type) return;

    if (evt.type === "nativeStatus") {
      nativeState.googleCalendarConfigured = !!evt.googleCalendarConfigured;
      nativeState.googleCalendarConnected = !!evt.googleCalendarConnected;
      nativeState.appleCalendarStatus = evt.appleCalendarStatus || "unknown";
      updateGoogleStatus();

      if (evt.appleCalendarConnected && !autoAppleStarted) {
        autoAppleStarted = true;
        postNative({ action: "refreshAppleCalendar" });
      } else if (evt.appleCalendarStatus === "not-determined" && !autoAppleStarted) {
        autoAppleStarted = true;
        postNative({ action: "requestAppleCalendar" });
      }

      if (evt.googleCalendarConnected && !autoGoogleStarted) {
        autoGoogleStarted = true;
        postNative({ action: "refreshGoogleCalendar" });
      }
    }

    if (evt.type === "appleCalendarStatus") {
      nativeState.appleCalendarStatus = evt.status || nativeState.appleCalendarStatus;
    }

    if (evt.type === "googleCalendarStatus") {
      nativeState.googleCalendarConfigured = !!evt.configured;
      nativeState.googleCalendarConnected = !!evt.connected;
      updateGoogleStatus();
      if (evt.connected) setStatus("Google Calendar connected");
      if (evt.message && ["error", "setup-needed"].includes(evt.status)) alert(evt.message);
    }

    if (evt.type === "googleCalendarEvents") {
      nativeState.googleCalendarConfigured = !!evt.configured;
      nativeState.googleCalendarConnected = !!evt.connected;
      const result = receiveProviderEvents("google", evt.events || []);
      updateGoogleStatus();
      if (evt.connected) {
        const calendars = Number(evt.calendarCount || 0);
        const skippedText = result.skipped ? ` · ${result.skipped} skipped` : "";
        setStatus(`Google synced · ${result.loaded}/${result.received} events · ${calendars} calendar${calendars === 1 ? "" : "s"}${skippedText}`);
      }
    }

    if (evt.type === "appleCalendarEvents") {
      focusWeekOnUpcomingEventsIfNeeded();
      renderWeek();
      renderMonth();
    }
  };

  const googleBadge = document.getElementById("googleStatus");
  const googleCard = googleBadge?.closest(".card");
  const googleActions = googleCard?.querySelector(".placeActions");
  const googleMeta = googleCard?.querySelector(".meta");
  if (googleMeta) {
    googleMeta.textContent = "Read-only Google Calendar sync. Sign in once, then LifeRoute refreshes your calendars automatically.";
  }
  if (googleActions) {
    googleActions.innerHTML = `
      <button class="primary" onclick="connectGoogle()">Connect Google Calendar</button>
      <button class="secondary" onclick="refreshGoogleCalendar()">Refresh</button>
      <button class="secondary" onclick="disconnectGoogleCalendar()">Disconnect</button>
    `;
  }

  const bottomButtons = document.querySelectorAll(".bottomin button");
  const formerSampleButton = bottomButtons?.[0];
  if (formerSampleButton) {
    formerSampleButton.textContent = "Refresh calendars";
    formerSampleButton.setAttribute("onclick", "refreshCalendars()");
  }

  const readinessNotice = Array.from(document.querySelectorAll(".notice")).find(el =>
    el.textContent.includes("Integration readiness") ||
    el.textContent.includes("Waiting on credentials/API setup")
  ) || document.querySelector("#setup .notice");
  if (readinessNotice) {
    readinessNotice.innerHTML = `
      <b>Ready now:</b> Apple Calendar read, Google Calendar read-only sync, selectable week view, month view, Apple Maps handoff, Google Maps handoff, saved places, membership-aware gap suggestions, themes, and local schedule planning.<br><br>
      <b>Still waiting on later integrations:</b> CentralReach partner credentials, live travel-time/distance matrices, and automatic importing of Google Maps saved lists.
    `;
  }

  updateGoogleStatus();
  persist();
  renderAll();
  postNative({ action: "requestNativeStatus" });
});