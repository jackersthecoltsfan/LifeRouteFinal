// LifeRoute route-time layer.
// Uses the native iOS bridge for Apple MapKit travel-time calculations.
window.addEventListener("DOMContentLoaded", () => {
  let routeRefreshTimer = null;
  let routeRequestNumber = 0;

  const eventByID = id => events.find(event => String(event.id) === String(id));
  const homePlace = () => places.find(place =>
    String(place.type || "").toLowerCase() === "home" && String(place.address || "").trim()
  );

  const departureISO = (dateKey, time) => {
    const value = new Date(`${dateKey}T${time || "12:00"}:00`);
    return Number.isNaN(value.getTime()) ? null : value.toISOString();
  };

  const distanceMiles = meters => Number(meters || 0) / 1609.344;

  const buildRouteSegments = () => {
    const segments = [];
    const home = homePlace();

    weekDates().forEach(dateKey => {
      const list = dayEvents(dateKey).filter(event => String(event.address || "").trim());
      if (!list.length) return;

      // Clear stale route metadata for the selected week before rebuilding it.
      list.forEach(event => {
        event.routePending = false;
        event.routeError = "";
        event.routeDistanceMiles = 0;
        event.routeOriginLabel = "";
      });

      if (home && list[0]?.address) {
        const first = list[0];
        first.routePending = true;
        segments.push({
          id: `${dateKey}|home|${first.id}`,
          date: dateKey,
          fromEventID: "home",
          toEventID: String(first.id),
          origin: home.address,
          destination: first.address,
          departure: departureISO(dateKey, first.start),
          originLabel: home.name || "Home"
        });
      }

      for (let index = 1; index < list.length; index += 1) {
        const previous = list[index - 1];
        const current = list[index];
        if (!previous.address || !current.address) continue;
        current.routePending = true;
        segments.push({
          id: `${dateKey}|${previous.id}|${current.id}`,
          date: dateKey,
          fromEventID: String(previous.id),
          toEventID: String(current.id),
          origin: previous.address,
          destination: current.address,
          departure: departureISO(dateKey, previous.end),
          originLabel: previous.title || "Previous event"
        });
      }
    });

    return segments;
  };

  window.refreshRouteTimes = function refreshRouteTimes() {
    const segments = buildRouteSegments();
    if (!segments.length) {
      nativeState.routeTimeStatus = "no-routable-events";
      renderAll();
      return;
    }

    routeRequestNumber += 1;
    nativeState.routeTimeRequest = routeRequestNumber;
    nativeState.routeTimeStatus = "loading";
    nativeState.routeSegmentsRequested = segments.length;
    nativeState.routeSegmentMeta = Object.fromEntries(segments.map(segment => [segment.id, segment]));
    setStatus(`Calculating ${segments.length} drive${segments.length === 1 ? "" : "s"}…`);
    renderAll();

    if (!postNative({ action: "requestRouteTimes", requestNumber: routeRequestNumber, segments })) {
      nativeState.routeTimeStatus = "unavailable";
      setStatus("Route times require the iPhone app build");
    }
  };

  const scheduleRouteRefresh = (delay = 650) => {
    clearTimeout(routeRefreshTimer);
    routeRefreshTimer = setTimeout(() => refreshRouteTimes(), delay);
  };

  // Route-aware schedule metrics. Travel to each event is stored on that event.
  window.stats = function routeAwareStats(list) {
    if (!list.length) return { work: 0, drive: 0, gap: 0, spread: 0 };
    let work = 0;
    let drive = 0;
    let gap = 0;

    list.forEach((event, index) => {
      work += Math.max(0, mins(event.end) - mins(event.start));
      drive += Number(event.drive || 0);
      if (index < list.length - 1) {
        const next = list[index + 1];
        const rawGap = Math.max(0, mins(next.start) - mins(event.end));
        const travel = Math.max(0, Number(next.drive || 0));
        gap += Math.max(0, rawGap - travel);
      }
    });

    return {
      work,
      drive,
      gap,
      spread: Math.max(0, mins(list.at(-1).end) - mins(list[0].start))
    };
  };

  window.analyzeDay = function analyzeRouteAwareDay(list) {
    if (list.length < 2) {
      return places.some(place => place.useInGaps)
        ? "Your saved places are ready for future gap suggestions once this day has at least two timed commitments."
        : "Add a gym, café, errand, park, or other frequent place so LifeRoute knows what kinds of gaps are actually useful to you.";
    }

    let best = { usable: -1, raw: 0, travel: 0, index: 0 };
    for (let index = 0; index < list.length - 1; index += 1) {
      const next = list[index + 1];
      const raw = mins(next.start) - mins(list[index].end);
      const travel = Math.max(0, Number(next.drive || 0));
      const usable = raw - travel;
      if (usable > best.usable) best = { usable, raw, travel, index };
    }

    if (best.raw < 0) return "Two appointments overlap. LifeRoute will flag overlaps before it tries to optimize the route.";
    const travelText = best.travel ? ` after about <b>${fmt(best.travel)}</b> of driving` : "";
    if (best.usable >= prefs.maxGap) {
      return `The biggest usable block is <b>${fmt(best.usable)}</b>${travelText}, between <b>${esc(list[best.index].title)}</b> and <b>${esc(list[best.index + 1].title)}</b>.${suggestionForGap(best.usable)}`;
    }
    return `Your largest usable between-event gap is <b>${fmt(Math.max(0, best.usable))}</b>${travelText}. This day is fairly condensed.`;
  };

  window.analyzeWeek = function analyzeRouteAwareWeek() {
    const candidates = [];
    let eventCount = 0;

    weekDates().forEach(dateKey => {
      const list = dayEvents(dateKey);
      eventCount += list.length;
      for (let index = 0; index < list.length - 1; index += 1) {
        const next = list[index + 1];
        const raw = mins(next.start) - mins(list[index].end);
        const travel = Math.max(0, Number(next.drive || 0));
        const usable = raw - travel;
        if (usable > 0) candidates.push({ date: dateKey, g: usable, raw, travel, a: list[index], b: next });
      }
    });

    candidates.sort((a, b) => b.g - a.g);
    if (!eventCount) return "No events are loaded for this selected week. Use the arrows to choose another week, or refresh your calendars.";
    if (!candidates.length) return `LifeRoute loaded <b>${eventCount}</b> timed event${eventCount === 1 ? "" : "s"} for this week, but there are no positive route-adjusted gaps to rank.`;

    const usableTotal = candidates.reduce((sum, item) => sum + item.g, 0);
    const top = candidates[0];
    const driveText = top.travel ? ` after ${fmt(top.travel)} of driving` : "";
    return `There are <b>${fmt(usableTotal)}</b> of usable time between commitments this week after route time. The largest block is <b>${dayName(top.date)} · ${fmt(top.g)}</b>${driveText}, between <b>${esc(top.a.title)}</b> and <b>${esc(top.b.title)}</b>.${suggestionForGap(top.g)}`;
  };

  // Show the actual route data in the Today timeline.
  window.renderToday = function renderRouteAwareToday() {
    const list = dayEvents(selectedDate);
    const summary = stats(list);
    const date = dateFromKey(selectedDate);
    const isToday = selectedDate === localDateKey(new Date());

    todayLabel.textContent = `${isToday ? "Today · " : ""}${date.toLocaleDateString("en-US", { weekday: "long", month: "short", day: "numeric" })}`;
    todayHero.textContent = list.length
      ? `${list.length} commitment${list.length === 1 ? "" : "s"}. Make the space between them useful.`
      : "A clear day is still a route.";
    mWork.textContent = fmt(summary.work);
    mDrive.textContent = fmt(summary.drive);
    mGap.textContent = fmt(summary.gap);
    mSpread.textContent = fmt(summary.spread);
    timeline.innerHTML = "";

    if (!list.length) timeline.innerHTML = '<div class="card empty">No timed events from your selected sources for this day.</div>';

    list.forEach((event, index) => {
      const card = document.createElement("div");
      card.className = "card";
      let travelText = "";
      if (event.address) {
        if (event.routePending) {
          travelText = "🚙 Calculating drive time…";
        } else if (Number(event.drive || 0) > 0) {
          const miles = Number(event.routeDistanceMiles || 0);
          const distance = miles > 0 ? ` · ${miles.toFixed(miles < 10 ? 1 : 0)} mi` : "";
          const origin = event.routeOriginLabel ? ` from ${esc(event.routeOriginLabel)}` : "";
          travelText = `🚙 ${fmt(event.drive)}${distance}${origin}`;
        } else if (event.routeError) {
          travelText = `🚙 Route time unavailable`;
        } else {
          travelText = "🚙 Route time pending";
        }
      }

      card.innerHTML = `<div class="row"><div class="grow"><div class="small">${time12(event.start)}–${time12(event.end)} · ${sourceLabel(event.source)}</div><div class="title">${esc(event.title)}</div><div class="meta">${esc(event.address || "No location")}</div></div>${event.source === "manual" ? `<button class="danger" onclick="removeEvent('${event.id}')">×</button>` : ""}</div>
        ${event.address ? `<div class="route"><span>${travelText}</span><button class="secondary" onclick="routeTo('${encodeURIComponent(event.address)}')">Route</button></div>` : ""}`;
      timeline.appendChild(card);

      if (index < list.length - 1) {
        const next = list[index + 1];
        const rawGap = Math.max(0, mins(next.start) - mins(event.end));
        const travel = Math.max(0, Number(next.drive || 0));
        const usable = Math.max(0, rawGap - travel);
        const gap = document.createElement("div");
        gap.className = "card gap";
        gap.innerHTML = `<div class="row"><div><div class="title">Usable gap · ${fmt(usable)}</div><div class="meta">${fmt(rawGap)} between events${travel ? ` − ${fmt(travel)} drive` : ""}</div></div><span class="${usable >= prefs.maxGap ? "warn" : "good"}">${usable >= prefs.maxGap ? "Opportunity" : "Compact"}</span></div>`;
        timeline.appendChild(gap);
      }
    });

    dayInsight.innerHTML = analyzeDay(list);
  };

  const currentNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithRoutes(evt) {
    if (typeof currentNativeEvent === "function") currentNativeEvent(evt);
    if (!evt || !evt.type) return;

    if (evt.type === "nativeStatus") {
      nativeState.routeTimeEngine = evt.routeTimeEngine || nativeState.routeTimeEngine;
    }

    if (evt.type === "appleCalendarEvents" || evt.type === "googleCalendarEvents") {
      scheduleRouteRefresh();
    }

    if (evt.type === "routeTimes") {
      const results = Array.isArray(evt.results) ? evt.results : [];
      const meta = nativeState.routeSegmentMeta || {};
      let loaded = 0;
      let failed = 0;

      results.forEach(result => {
        const segment = meta[result.id] || {};
        const target = eventByID(result.toEventID || segment.toEventID);
        if (!target) return;
        target.routePending = false;
        target.routeOriginLabel = segment.originLabel || "Previous event";

        if (result.error || !Number(result.minutes || 0)) {
          target.routeError = result.error || "Route unavailable";
          failed += 1;
          return;
        }

        target.drive = Number(result.minutes || 0);
        target.routeDistanceMiles = distanceMiles(result.distanceMeters);
        target.routeTimeSource = evt.engine || "apple-mapkit";
        target.routeError = "";
        loaded += 1;
      });

      nativeState.routeTimeStatus = "ready";
      nativeState.routeLegsLoaded = loaded;
      nativeState.routeLegsFailed = failed;
      setStatus(`Routes updated · ${loaded} drive${loaded === 1 ? "" : "s"}${failed ? ` · ${failed} unavailable` : ""}`);
      renderAll();
    }
  };

  // Refresh route data whenever the selected week changes.
  [["changeWeek", 250], ["goToCurrentWeek", 250], ["openCalendarDay", 250]].forEach(([name, delay]) => {
    const original = window[name];
    if (typeof original !== "function") return;
    window[name] = function routeAwareNavigation(...args) {
      const value = original.apply(this, args);
      scheduleRouteRefresh(delay);
      return value;
    };
  });

  const notice = document.querySelector("#setup .notice");
  if (notice && !notice.textContent.includes("MapKit route times")) {
    notice.innerHTML += "<br><br><b>Route timing:</b> Apple MapKit driving-time estimates are calculated natively on the iPhone. Your preferred maps app can still be Apple Maps or Google Maps for navigation.";
  }

  // Route calculations need the calendar events first. Native status/calendar refreshes
  // already run during startup, so this acts as a fallback for manually entered events.
  scheduleRouteRefresh(1400);
});
