// Public, non-secret integration configuration only.
// Never commit OAuth client secrets, CentralReach tokens, or Apple private keys here.
window.LifeRouteConfig = {
  googleCalendar: {
    enabled: false,
    clientId: "",
    scopes: ["https://www.googleapis.com/auth/calendar.readonly"],
    mode: "read-only"
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

// Harden the web/native bridge after the main UI script initializes.
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
});
