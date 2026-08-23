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

// Harden and extend the web/native bridge after the main UI script initializes.
// Provider-fed events stay in memory only; only manual events, places, and preferences persist locally.
window.addEventListener("DOMContentLoaded", () => {
  if (typeof window.persist === "function") {
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
  }

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

  // Remove any sample-week content left behind by an older build.
  const oldEventCount = events.length;
  const oldPlaceCount = places.length;
  events = events.filter(event => !String(event.id || "").startsWith("demo-"));
  places = places.filter(place => !String(place.id || "").startsWith("demo-"));
  if (events.length !== oldEventCount || places.length !== oldPlaceCount) {
    persist();
  }

  // Use the checked-in LifeRoute PNG artwork as the in-app brand mark.
  const brandMark = document.querySelector(".mark");
  if (brandMark) {
    brandMark.innerHTML = '<img alt="LifeRoute">';
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
      logo.src = "liferoute-logo-source.png";
      logo.onerror = () => { brandMark.textContent = "LR"; };
    }
  }

  const updateGoogleStatus = () => {
    const badge = document.getElementById("googleStatus");
    if (!badge) return;
    const configured = !!nativeState?.googleCalendarConfigured;
    const connected = !!nativeState?.googleCalendarConnected;
    badge.textContent = connected ? "CONNECTED" : (configured ? "READY" : "SETUP NEEDED");
    badge.className = "badge " + (connected ? "green" : "gold");
  };

  const originalRenderSources = window.renderSources;
  if (typeof originalRenderSources === "function") {
    window.renderSources = function renderSourcesWithGoogleStatus() {
      originalRenderSources();
      updateGoogleStatus();
    };
  }

  window.connectGoogle = function connectGoogleCalendarNative() {
    if (!postNative({action: "requestGoogleCalendar"})) {
      alert("Google Calendar connection is available inside the native iPhone app build.");
    }
  };

  window.refreshGoogleCalendar = function refreshGoogleCalendarNative() {
    postNative({action: "refreshGoogleCalendar"});
  };

  window.disconnectGoogleCalendar = function disconnectGoogleCalendarNative() {
    if (confirm("Disconnect Google Calendar from LifeRoute on this iPhone?")) {
      postNative({action: "disconnectGoogleCalendar"});
    }
  };

  window.refreshCalendars = function refreshAllConnectedCalendars() {
    let didRequest = false;

    if (nativeState?.appleCalendarConnected) {
      postNative({action: "refreshAppleCalendar"});
      didRequest = true;
    } else if (nativeState?.appleCalendarStatus === "not-determined") {
      postNative({action: "requestAppleCalendar"});
      didRequest = true;
    }

    if (nativeState?.googleCalendarConnected) {
      postNative({action: "refreshGoogleCalendar"});
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

      // Make calendar data real on launch: read immediately when permission already exists.
      // On a first install, ask once for Apple Calendar permission so the user can start testing.
      if (evt.appleCalendarConnected && !autoAppleStarted) {
        autoAppleStarted = true;
        postNative({action: "refreshAppleCalendar"});
      } else if (evt.appleCalendarStatus === "not-determined" && !autoAppleStarted) {
        autoAppleStarted = true;
        postNative({action: "requestAppleCalendar"});
      }

      if (evt.googleCalendarConnected && !autoGoogleStarted) {
        autoGoogleStarted = true;
        postNative({action: "refreshGoogleCalendar"});
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
      receiveProviderEvents("google", evt.events || []);
      updateGoogleStatus();
      if (evt.connected) {
        const count = (evt.events || []).length;
        const calendars = Number(evt.calendarCount || 0);
        setStatus(`Google synced · ${count} events · ${calendars} calendar${calendars === 1 ? "" : "s"}`);
      }
    }
  };

  // Upgrade the existing Google Calendar card without duplicating the main UI markup.
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

  // Replace the old sample-data action with a real calendar refresh action.
  const bottomButtons = document.querySelectorAll(".bottomin button");
  const formerSampleButton = bottomButtons?.[0];
  if (formerSampleButton) {
    formerSampleButton.textContent = "Refresh calendars";
    formerSampleButton.setAttribute("onclick", "refreshCalendars()");
  }

  // Keep the readiness copy aligned with what this build can actually do.
  const readinessNotice = Array.from(document.querySelectorAll(".notice")).find(el =>
    el.textContent.includes("Integration readiness") || el.textContent.includes("Waiting on credentials/API setup")
  ) || document.querySelector("#setup .notice");
  if (readinessNotice) {
    readinessNotice.innerHTML = `
      <b>Ready now:</b> Apple Calendar permission/read, Google Calendar read-only OAuth sync, Apple Maps handoff, Google Maps handoff, saved places, membership-aware gap suggestions, multi-source UI, themes, and local schedule planning.<br><br>
      <b>Still waiting on later integrations:</b> CentralReach partner credentials, live travel-time/distance matrices, and automatic importing of Google Maps saved lists.
    `;
  }

  updateGoogleStatus();
  renderAll();

  // Request status again now that the live-calendar event wrapper is installed.
  postNative({action: "requestNativeStatus"});
});
