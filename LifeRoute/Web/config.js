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

  const originalNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithGoogle(evt) {
    if (typeof originalNativeEvent === "function") originalNativeEvent(evt);
    if (!evt || !evt.type) return;

    if (evt.type === "nativeStatus") {
      nativeState.googleCalendarConfigured = !!evt.googleCalendarConfigured;
      nativeState.googleCalendarConnected = !!evt.googleCalendarConnected;
      updateGoogleStatus();
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

  // Upgrade the existing Google Calendar card without duplicating the main UI markup.
  const googleBadge = document.getElementById("googleStatus");
  const googleCard = googleBadge?.closest(".card");
  const googleActions = googleCard?.querySelector(".placeActions");
  if (googleActions) {
    googleActions.innerHTML = `
      <button class="primary" onclick="connectGoogle()">Connect Google Calendar</button>
      <button class="secondary" onclick="refreshGoogleCalendar()">Refresh</button>
      <button class="secondary" onclick="disconnectGoogleCalendar()">Disconnect</button>
    `;
  }

  updateGoogleStatus();
  // Request status again now that the Google event wrapper is installed.
  postNative({action: "requestNativeStatus"});
});
